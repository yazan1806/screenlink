import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {AccessToken,TrackSource} from 'livekit-server-sdk';
const random=()=>randomBytes(32).toString('hex');
const hash=x=>createHash('sha256').update(x).digest('hex');
const same=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
// Device credentials are separate from mirroring QR codes and are stored hashed on the PC.
export function createRemote({config,service,store,clock=Date.now}){
 let pending=null,mutation=false;
 let tail=Promise.resolve();
 async function jwt(identity,room,role,ttl=60){
  const t=new AccessToken(config.apiKey,config.apiSecret,{identity,ttl});
  t.addGrant({room,roomJoin:true,canPublish:role==='host',canSubscribe:role==='controller',canPublishData:role==='controller',canPublishSources:role==='host'?[TrackSource.SCREEN_SHARE,TrackSource.SCREEN_SHARE_AUDIO]:[]});
  return t.toJwt();
 }
 async function save(value){await store.save(value);}
 async function discovery(s){
  await service.createRoom({name:s.discovery,maxParticipants:10,emptyTimeout:86400});
  await service.updateRoomMetadata(s.discovery,JSON.stringify({server:config.publicUrl}));
 }
 async function handle(path,method,input,authorization,owner){
  const s=await store.load();
  if(path==='/api/remote/status'&&method==='GET'&&owner)return {enabled:!!s.enabled,devices:(s.devices||[]).map(d=>({id:d.id,name:d.name}))};
  if(path==='/api/remote/enable'&&method==='POST'&&owner){
   if(mutation)throw Object.assign(Error('Remote setup is busy.'),{status:409});mutation=true;
   try{const next={...s,enabled:true,room:s.room||`remote-${random()}`,discovery:s.discovery||`discovery-${random()}`,devices:s.devices||[]};await discovery(next);await save(next);return {enabled:true};}finally{mutation=false;}
  }
  if(path==='/api/remote/pair'&&method==='POST'&&owner){
   if(!s.enabled)throw Object.assign(Error('Enable remote access first.'),{status:409});
   pending={id:random(),key:random(),expires:clock()+600000};return {...pending};
  }
  if(path==='/api/remote/claim'&&method==='POST'){
   if(!s.enabled||!pending||clock()>pending.expires||!same(input.id,pending.id)||!same(input.key,pending.key))throw Object.assign(Error('Remote authorization code expired or was already used.'),{status:403});
   pending=null;const key=random(),id=random().slice(0,24);
   if(s.devices.length>=8)throw Object.assign(Error('Revoke an old device before adding another.'),{status:409});
   s.devices.push({id,keyHash:hash(key),name:'Your iPhone'});await save(s);
   return {id,key,server:config.publicUrl,serverUrl:config.livekitUrl,discoveryToken:await jwt(`discover-${id}`,s.discovery,'discovery',31536000)};
  }
  if(path==='/api/remote/host'&&method==='POST'&&owner){
   if(!s.enabled)throw Object.assign(Error('Remote access is disabled.'),{status:403});
   await discovery(s);await service.createRoom({name:s.room,maxParticipants:2,emptyTimeout:120});
   return {serverUrl:config.livekitUrl,token:await jwt('pc-host',s.room,'host'),devices:s.devices.map(d=>`device-${d.id}`)};
  }
  if(path==='/api/remote/connect'&&method==='POST'){
   const key=authorization?.startsWith('Bearer ')?authorization.slice(7):'';
   const d=s.enabled&&s.devices?.find(d=>same(d.keyHash,hash(key)));
   if(!d)throw Object.assign(Error('This device is not authorized for remote access.'),{status:401});
   return {serverUrl:config.livekitUrl,token:await jwt(`device-${d.id}`,s.room,'controller')};
  }
  if(path==='/api/remote/revoke'&&method==='POST'&&owner){
   // Rotate the room as well as credentials, invalidating outstanding controller JWTs.
   if(s.room)await service.deleteRoom(s.room);
   pending=null;await save({...s,enabled:false,room:null,devices:[]});return {enabled:false};
  }
  throw Object.assign(Error('Remote access request is not authorized.'),{status:401});
 }
 // Serialize claims, revocations and file updates so an overlapping claim cannot
 // restore a device that the owner has just revoked.
 return (...args)=>{const result=tail.then(()=>handle(...args));tail=result.catch(()=>{});return result;};
}
