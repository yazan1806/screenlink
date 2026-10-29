import {Room,RoomEvent,Track} from 'livekit-client';
import QRCode from 'qrcode';
export async function initRemote(api){
 const $=s=>document.querySelector(s),note=$('#remote-status');
 let room=null,stream=null,allowed=new Set(),capturePromise=null,refreshTimer=null;
 function stopCapture(){stream?.getTracks().forEach(t=>t.stop());stream=null;}
 async function close(){clearInterval(refreshTimer);refreshTimer=null;await room?.disconnect();room=null;stopCapture();await window.screenLink?.setRemoteEnabled(false);}
 async function capture(){
  if(stream||capturePromise)return;
  capturePromise=(async()=>{
   try{
    const id=await window.screenLink.getDesktopSource();
    const video={mandatory:{chromeMediaSource:'desktop',chromeMediaSourceId:id,maxWidth:2560,maxHeight:1440,maxFrameRate:60}};
    try{stream=await navigator.mediaDevices.getUserMedia({video,audio:{mandatory:{chromeMediaSource:'desktop'}}});}
    catch{stream=await navigator.mediaDevices.getUserMedia({video,audio:false});}
    for(const track of stream.getTracks())await room.localParticipant.publishTrack(track,{source:track.kind==='video'?Track.Source.ScreenShare:Track.Source.ScreenShareAudio,simulcast:false,videoCodec:'h264',screenShareEncoding:{maxBitrate:20000000,maxFramerate:60}});
    note.textContent='Remote iPhone connected · PC screen and control active';
   }catch(e){stopCapture();note.textContent='Remote capture failed: '+e.message;}
   finally{capturePromise=null;}
  })();await capturePromise;
 }
 async function refresh(){
  const s=await api('/api/remote/status');
  if(!s.enabled){await close();return;}
  allowed=new Set(s.devices.map(d=>`device-${d.id}`));
  if(room)for(const p of room.remoteParticipants.values())if(allowed.has(p.identity))await capture();
  $('#remote-devices').textContent=`${s.devices.length} authorized iPhone${s.devices.length===1?'':'s'}`;
 }
 async function host(){
  await close();const access=await api('/api/remote/host','POST');allowed=new Set(access.devices);
  await window.screenLink.setRemoteEnabled(true);
  room=new Room({adaptiveStream:false,dynacast:true});
  room.on(RoomEvent.ParticipantConnected,p=>{if(allowed.has(p.identity))capture();});
  room.on(RoomEvent.ParticipantDisconnected,async()=>{if(!room)return;if(![...room.remoteParticipants.values()].some(p=>allowed.has(p.identity))){for(const pub of room.localParticipant.trackPublications.values())if(pub.track)await room.localParticipant.unpublishTrack(pub.track);stopCapture();note.textContent='Remote access ready · no iPhone connected';}});
  let count=0,start=0;
  room.on(RoomEvent.DataReceived,(bytes,participant,kind,topic)=>{
   if(!participant||!allowed.has(participant.identity)||topic!=='screenlink-input'||bytes.length>8192||!stream)return;
   const now=Date.now();if(now-start>1000){start=now;count=0;}if(++count>120)return;
   try{const data=JSON.parse(new TextDecoder().decode(bytes));window.screenLink.sendInput(data);}catch{}
  });
  room.on(RoomEvent.Disconnected,()=>{stopCapture();note.textContent='Remote connection lost. Restart ScreenLink to restore access.';});
  await room.connect(access.serverUrl,access.token,{autoSubscribe:false});
  for(const p of room.remoteParticipants.values())if(allowed.has(p.identity))await capture();
  refreshTimer=setInterval(()=>refresh().catch(e=>{note.textContent=e.message;}),5000);
  note.textContent='Remote access ready · PC must remain on and signed in';
  $('#remote-enable').hidden=true;$('#remote-authorize').hidden=false;$('#remote-revoke').hidden=false;
 }
 $('#remote-enable').onclick=async()=>{try{await api('/api/remote/enable','POST');await host();}catch(e){note.textContent=e.message;}};
 $('#remote-authorize').onclick=async()=>{
  try{const p=await api('/api/remote/pair','POST');const setup=await window.screenLink.getLocalSetup();const u=new URL('screenlink://remote');u.searchParams.set('server',setup.server);u.searchParams.set('id',p.id);u.searchParams.set('key',p.key);$('#remote-qr').src=await QRCode.toDataURL(u.href,{width:360,margin:2});$('#remote-qr').hidden=false;note.textContent='Scan in the iPhone Remote PC tab. This authorizes unattended desktop access. Expires in 10 minutes.';}catch(e){note.textContent=e.message;}
 };
 $('#remote-revoke').onclick=async()=>{try{await api('/api/remote/revoke','POST');await close();$('#remote-qr').hidden=true;$('#remote-enable').hidden=false;$('#remote-authorize').hidden=true;$('#remote-revoke').hidden=true;$('#remote-devices').textContent='No authorized devices';note.textContent='Remote access disabled. All device credentials revoked.';}catch(e){note.textContent=e.message;}};
 try{const s=await api('/api/remote/status');if(s.enabled)await host();}catch(e){note.textContent=e.message;}
}
