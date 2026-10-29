import http from 'node:http';
import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {AccessToken,RoomServiceClient,TrackSource} from 'livekit-server-sdk';
import {readFile} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {createRemote} from './remote.mjs';
const random=()=>randomBytes(24).toString('hex');
const same=(a,b)=>typeof a==='string'&&typeof b==='string'&&timingSafeEqual(createHash('sha256').update(a).digest(),createHash('sha256').update(b).digest());
const send=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
async function body(req){let chunks=[],length=0;for await(const chunk of req){length+=chunk.length;if(length>4096)throw Object.assign(Error('Request too large'),{status:413});chunks.push(chunk);}try{return JSON.parse(Buffer.concat(chunks).toString()||'{}');}catch{throw Object.assign(Error('Invalid JSON'),{status:400});}}
export function createApp({config,roomService,remoteStore,clock=Date.now,publicDir=resolve(import.meta.dirname,'../desktop/dist')}={}){
  let session=null,mutating=false;
  const limits=new Map();
  const ready=()=>Boolean(config.ownerKey?.length>=32&&config.livekitUrl?.startsWith('wss://')&&config.apiKey&&config.apiSecret);
  const service=roomService||(ready()?new RoomServiceClient(config.livekitUrl.replace(/^wss:/,'https:'),config.apiKey,config.apiSecret):null);
  const remote=remoteStore?createRemote({config,service,store:remoteStore,clock}):null;
  async function token(role,s){const t=new AccessToken(config.apiKey,config.apiSecret,{identity:role,name:role==='phone'?'Your iPhone':'Your PC',ttl:60});t.addGrant({room:s.room,roomJoin:true,canPublish:role==='phone',canSubscribe:role==='viewer',canPublishData:false,canPublishSources:role==='phone'?[TrackSource.SCREEN_SHARE,TrackSource.MICROPHONE]:[]});return t.toJwt();}
  async function end(s){await service.deleteRoom(s.room).catch(e=>{if(e.code!=='not_found'&&e.status!==404)throw e;});}
  const server=http.createServer(async(req,res)=>{
    res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
    // Requests carry explicit bearer credentials. No ambient cookies or credentialed CORS.
    res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');res.setHeader('Access-Control-Allow-Methods','GET,POST,DELETE,OPTIONS');
    if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
    const url=new URL(req.url,'http://localhost');
    try{
      if(url.pathname==='/health'){send(res,200,{ok:true,configured:ready()});return;}
      if(url.pathname.startsWith('/api/')){
        if(!ready()){send(res,503,{error:'Hosting setup is incomplete. Configure LiveKit and your owner key.'});return;}
        const owner=same(req.headers.authorization,`Bearer ${config.ownerKey}`);
        if(url.pathname.startsWith('/api/remote/')&&remote){
          const ip=req.socket.remoteAddress,now=clock(),key='remote:'+ip;let rate=limits.get(key);
          if(!rate||now-rate.start>60000){rate={start:now,count:0};limits.set(key,rate);}
          if(!owner&&++rate.count>30){send(res,429,{error:'Too many attempts. Wait one minute.'});return;}
          send(res,200,await remote(url.pathname,req.method,req.method==='POST'?await body(req):{},req.headers.authorization,owner));return;
        }
        if(url.pathname!=='/api/claim'&&!owner){send(res,401,{error:'Your personal access key is missing or incorrect.'});return;}
        if(url.pathname==='/api/session'&&req.method==='POST'){
          if(mutating){send(res,409,{error:'A session change is already in progress.'});return;}
          mutating=true;
          try{
            const input=await body(req);const preset=['fast','balanced','detail'].includes(input.preset)?input.preset:'balanced';
            if(session){await end(session);session=null;}
            const s={id:random(),pairKey:random(),room:`screenlink-${random()}`,created:clock(),expires:clock()+600000,claimed:false,preset};
            await service.createRoom({name:s.room,maxParticipants:2,emptyTimeout:120,departureTimeout:20});
            session=s;send(res,201,{id:s.id,pairKey:s.pairKey,expires:s.expires,preset,serverUrl:config.livekitUrl,token:await token('viewer',s)});
          }finally{mutating=false;}return;
        }
        if(url.pathname==='/api/claim'&&req.method==='POST'){
          const ip=req.socket.remoteAddress;const now=clock();let rate=limits.get(ip);
          if(!rate||now-rate.start>60000){rate={start:now,count:0};limits.set(ip,rate);}
          if(++rate.count>30){send(res,429,{error:'Too many pairing attempts. Wait one minute.'});return;}
          const input=await body(req),s=session;
          if(!s||s.expires<=now||s.claimed||!same(input.id,s.id)||!same(input.key,s.pairKey)){send(res,403,{error:'Pairing code expired or already used. Generate a new QR on the PC.'});return;}
          // Consume synchronously before the asynchronous JWT operation, preventing duplicate claims.
          s.claimed=true;
          send(res,200,{serverUrl:config.livekitUrl,token:await token('phone',s),preset:s.preset});return;
        }
        if(url.pathname==='/api/session'&&req.method==='GET'){
          send(res,200,session?{id:session.id,claimed:session.claimed,expires:session.expires}:{id:null});return;
        }
        if(url.pathname==='/api/session'&&req.method==='DELETE'){
          if(mutating){send(res,409,{error:'Session change in progress.'});return;}
          mutating=true;
          try{if(session){session.claimed=true;await end(session);session=null;}send(res,200,{ok:true});}finally{mutating=false;}return;
        }
        send(res,404,{error:'Unknown endpoint'});return;
      }
      if(req.method!=='GET'){send(res,405,{error:'Method not allowed'});return;}
      const relative=url.pathname==='/'?'index.html':decodeURIComponent(url.pathname).slice(1);
      const path=resolve(publicDir,relative);
      if(!path.startsWith(resolve(publicDir)+String.fromCharCode(47))&&!path.startsWith(resolve(publicDir)+String.fromCharCode(92))){send(res,404,{error:'Not found'});return;}
      try{const bytes=await readFile(path);res.writeHead(200,{'Content-Type':({'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml'})[extname(path)]||'application/octet-stream'});res.end(bytes);}catch{send(res,404,{error:'Not found'});}
    }catch(e){send(res,e.status||502,{error:e.status?e.message:'The media service could not complete this request. Check its configuration and try again.'});}
  });
  // Remove abandoned rooms and keep the public pairing rate-limit map bounded.
  const timer=setInterval(async()=>{for(const [ip,r] of limits)if(clock()-r.start>60000)limits.delete(ip);const s=session;if(!mutating&&s&&((!s.claimed&&clock()>s.expires)||clock()-s.created>14400000)){mutating=true;try{await end(s);if(session===s)session=null;}catch{/* Retry next tick; never claim disconnect succeeded. */}finally{mutating=false;}}},30000);
  timer.unref();server.on('close',()=>clearInterval(timer));return server;
}
