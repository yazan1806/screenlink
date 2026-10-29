import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {TokenVerifier,TrackSource} from 'livekit-server-sdk';
import {createApp} from './app.mjs';
const config={ownerKey:'x'.repeat(64),livekitUrl:'wss://test.livekit.cloud',apiKey:'test-key',apiSecret:'secret'.repeat(8)};
async function fixture(t,options={}){
 const rooms=new Set();let failDelete=false,now=Date.now();
 const service={async createRoom(o){assert.equal(o.maxParticipants,2);rooms.add(o.name);},async deleteRoom(name){if(failDelete)throw Error('offline');rooms.delete(name);}};
 const server=createApp({config,roomService:service,clock:()=>now,...options});server.listen(0,'127.0.0.1');await once(server,'listening');t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
 const base=`http://127.0.0.1:${server.address().port}`;
 async function call(path,{method='GET',owner=true,data,raw}={}){const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(owner?{Authorization:`Bearer ${config.ownerKey}`}:{})},body:raw??(data?JSON.stringify(data):undefined)});return {status:r.status,body:await r.json()};}
 return {call,rooms,setTime:v=>now=v,failDelete:v=>failDelete=v};
}
test('configuration errors are explicit and public responses contain no credentials',async t=>{
 const f=await fixture(t,{config:{}});assert.equal((await f.call('/health')).body.configured,false);assert.equal((await f.call('/api/session',{method:'POST'})).status,503);
});
test('owner auth, least-privilege JWT grants, exclusive claim and disconnect',async t=>{
 const f=await fixture(t);assert.equal((await f.call('/api/session',{method:'POST',owner:false})).status,401);
 const s=await f.call('/api/session',{method:'POST',data:{preset:'detail'}});assert.equal(s.status,201);assert.equal(f.rooms.size,1);
 const verify=new TokenVerifier(config.apiKey,config.apiSecret),viewer=await verify.verify(s.body.token);
 assert.equal(viewer.video.canPublish,false);assert.equal(viewer.video.canSubscribe,true);
 assert.equal(JSON.stringify(s.body).includes(config.apiSecret),false);assert.equal(JSON.stringify(s.body).includes(config.ownerKey),false);
 assert.equal((await f.call('/api/claim',{method:'POST',owner:false,data:{id:s.body.id,key:'wrong'}})).status,403);
 const claims=await Promise.all(Array.from({length:5},()=>f.call('/api/claim',{method:'POST',owner:false,data:{id:s.body.id,key:s.body.pairKey}})));
 assert.equal(claims.filter(c=>c.status===200).length,1);assert.equal(claims.filter(c=>c.status===403).length,4);
 const phone=await verify.verify(claims.find(c=>c.status===200).body.token);
 assert.equal(phone.sub,'phone');assert.equal(phone.video.canSubscribe,false);assert.equal(phone.video.canPublish,true);assert.equal(phone.video.canPublishData,false);assert.deepEqual(phone.video.canPublishSources,['screen_share','microphone']);
 assert.equal(phone.exp-phone.nbf,60);assert.equal(phone.video.room,viewer.video.room);
 assert.equal((await f.call('/api/session',{method:'DELETE'})).status,200);assert.equal(f.rooms.size,0);assert.equal((await f.call('/api/session')).body.id,null);
});
test('expiration, replacement, malformed requests and no false disconnect success',async t=>{
 const f=await fixture(t);let s=(await f.call('/api/session',{method:'POST'})).body;
 f.setTime(s.expires+1);assert.equal((await f.call('/api/claim',{method:'POST',owner:false,data:{id:s.id,key:s.pairKey}})).status,403);
 const old=s;s=(await f.call('/api/session',{method:'POST',data:{preset:'invalid'}})).body;assert.equal(s.preset,'balanced');assert.equal(f.rooms.size,1);assert.notEqual(s.id,old.id);
 assert.equal((await f.call('/api/claim',{method:'POST',owner:false,data:{id:old.id,key:old.pairKey}})).status,403);
 assert.equal((await f.call('/api/claim',{method:'POST',owner:false,raw:'{'})).status,400);
 assert.equal((await f.call('/api/claim',{method:'POST',owner:false,raw:'x'.repeat(5000)})).status,413);
 f.failDelete(true);assert.equal((await f.call('/api/session',{method:'DELETE'})).status,502);assert.equal((await f.call('/api/session')).body.id,s.id);
 f.failDelete(false);assert.equal((await f.call('/api/session',{method:'DELETE'})).status,200);
});
