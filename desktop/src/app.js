import {Room,RoomEvent,Track} from 'livekit-client';
import QRCode from 'qrcode';
import './style.css';
import {initRemote} from './remote.js';
const $=s=>document.querySelector(s),video=$('#video');
let room=null,base='',owner='',pair=null,link='',poll=null,creating=false,frameCount=0;
$('#server').value=localStorage.getItem('screenlink-server')||(location.protocol==='https:'?location.origin:'');
function error(e){$('#error').textContent=e.message||String(e);}
async function api(path,method='GET',data){const r=await fetch(base+path,{method,headers:{Authorization:`Bearer ${owner}`,'Content-Type':'application/json'},body:data?JSON.stringify(data):undefined});const body=await r.json();if(!r.ok)throw Error(body.error||'Server request failed');return body;}
function status(s){$('#status').textContent=s;}
function showMode(mode){
 const remote=mode==='remote';$('#viewer').hidden=remote;$('#mirror-sidebar').hidden=remote;$('#remote-panel').hidden=!remote;
 $('#tab-mirror').setAttribute('aria-pressed',String(!remote));$('#tab-remote').setAttribute('aria-pressed',String(remote));
 $('#fullscreen').hidden=remote;localStorage.setItem('screenlink-mode',mode);
}
$('#tab-mirror').onclick=()=>showMode('mirror');$('#tab-remote').onclick=()=>showMode('remote');
$('#open-help').onclick=()=>$('#help-dialog').showModal();$('#close-help').onclick=()=>$('#help-dialog').close();
const savedPreset=localStorage.getItem('screenlink-preset');if(['fast','balanced','detail'].includes(savedPreset))$('#preset').value=savedPreset;
$('#preset').onchange=()=>localStorage.setItem('screenlink-preset',$('#preset').value);
$('#server').oninvalid=()=>{$('#connection-details').open=true;};$('#owner').oninvalid=()=>{$('#connection-details').open=true;};

function hideVideo(){video.srcObject=null;video.style.display='none';$('#placeholder').hidden=false;}
const audioTracks=new Map();
async function disconnectLocal(){clearInterval(poll);poll=null;const old=room;room=null;if(old)await old.disconnect();for(const a of audioTracks.values())a.remove();audioTracks.clear();hideVideo();}
async function end(){try{await api('/api/session','DELETE');await disconnectLocal();pair=null;$('#pairing').hidden=true;$('#setup').hidden=false;status('Session ended');$('#error').textContent='';$('#notice').textContent='The media room was closed. Create a fresh code to reconnect.';}catch(e){error(e);}}
$('#end').onclick=end;
$('#setup').onsubmit=async e=>{
 e.preventDefault();if(creating)return;creating=true;$('#create').disabled=true;$('#error').textContent='';$('#notice').textContent='';
 try{
  const url=new URL($('#server').value.trim());if(url.protocol!=='https:'&&!(['localhost','127.0.0.1'].includes(url.hostname)&&url.protocol==='http:'))throw Error('Use your server’s HTTPS address.');
  base=url.origin;owner=$('#owner').value.trim();if(owner.length<32)throw Error('Enter your personal access key from the server settings.');
  localStorage.setItem('screenlink-server',base);
  await disconnectLocal();status('Creating your private session…');
  pair=await api('/api/session','POST',{preset:$('#preset').value});
  const u=new URL('screenlink://pair');u.searchParams.set('server',base);u.searchParams.set('id',pair.id);u.searchParams.set('key',pair.pairKey);link=u.toString();
  $('#qr').src=await QRCode.toDataURL(link,{width:360,margin:2,errorCorrectionLevel:'M'});
  room=new Room({adaptiveStream:false,dynacast:true});
  room.on(RoomEvent.TrackSubscribed,(track)=>{if(track.kind===Track.Kind.Audio){const a=track.attach();a.volume=Number($('#volume').value);a.muted=$('#mute-audio').checked;document.body.append(a);audioTracks.set(track.sid,a);a.play().catch(()=>{$('#notice').textContent='Click Enable PC sound to start audio playback.';});return;}if(track.source!==Track.Source.ScreenShare)return;track.attach(video);video.style.display='block';$('#placeholder').hidden=true;video.play().catch(error);status('Live from your iPhone');});
  room.on(RoomEvent.TrackUnsubscribed,track=>{track.detach();if(track.kind===Track.Kind.Audio){audioTracks.get(track.sid)?.remove();audioTracks.delete(track.sid);return;}hideVideo();status('Screen sharing stopped');});
  room.on(RoomEvent.Reconnecting,()=>status('Reconnecting…'));
  room.on(RoomEvent.Reconnected,()=>status('Connection restored'));
  room.on(RoomEvent.ParticipantDisconnected,()=>{hideVideo();status('iPhone disconnected');});
  room.on(RoomEvent.Disconnected,()=>{hideVideo();status('Session disconnected');});
  await room.connect(pair.serverUrl,pair.token,{autoSubscribe:true});
  $('#setup').hidden=true;$('#pairing').hidden=false;status('Ready to mirror · scan on your iPhone');
  poll=setInterval(async()=>{try{const s=await api('/api/session');if(s.id!==pair?.id){await disconnectLocal();$('#pairing').hidden=true;$('#setup').hidden=false;pair=null;status('Session expired or replaced');}else if(s.claimed)$('#expires').textContent='Paired · Approve sharing on your iPhone';}catch(e){error(e);}},5000);
 }catch(e){error(e);await disconnectLocal();status('Setup needs attention');}finally{creating=false;$('#create').disabled=false;}
};
$('#copy').onclick=async()=>{try{await navigator.clipboard.writeText(link);$('#notice').textContent='Pairing link copied. Paste it into ScreenLink on the iPhone if scanning is unavailable.';}catch(e){error(e);}};
const viewer=$('#viewer');
function fitVideo(){
 const mode=$('#orientation').value,portrait=video.videoHeight>=video.videoWidth;
 const rotate=(mode==='portrait'&&!portrait)||(mode==='landscape'&&portrait);
 video.style.transform=rotate?'rotate(90deg)':'none';
 const width=Math.max(100,viewer.clientWidth-48),height=Math.max(100,viewer.clientHeight-110);
 video.style.width=(rotate?height:width)+'px';video.style.height=(rotate?width:height)+'px';
}
async function toggleFullscreen(){try{if(document.fullscreenElement)await document.exitFullscreen();else await viewer.requestFullscreen();fitVideo();}catch(e){error(e);}}
$('#fullscreen').onclick=toggleFullscreen;
$('#video-fullscreen').onclick=toggleFullscreen;
$('#orientation').onchange=fitVideo;
$('#enable-audio').onclick=()=>room?.startAudio().catch(error);
function updateAudio(){for(const a of audioTracks.values()){a.volume=Number($('#volume').value);a.muted=$('#mute-audio').checked;}}
$('#volume').oninput=updateAudio;$('#mute-audio').onchange=updateAudio;
video.addEventListener('loadedmetadata',fitVideo);video.addEventListener('resize',fitVideo);
window.addEventListener('resize',fitVideo);
document.addEventListener('fullscreenchange',()=>{$('#video-fullscreen').textContent=document.fullscreenElement?'Exit fullscreen ↙':'Fullscreen ↗';fitVideo();});

if('requestVideoFrameCallback' in video){const count=()=>{frameCount++;video.requestVideoFrameCallback(count);};video.requestVideoFrameCallback(count);}
setInterval(()=>{if(video.srcObject)$('#stats').textContent=`${video.videoWidth} × ${video.videoHeight} · ${frameCount} displayed fps · WebRTC`;else $('#stats').textContent='Waiting for a video stream';frameCount=0;if(pair&&$('#expires').textContent.startsWith('Paired')===false)$('#expires').textContent=Date.now()<pair.expires?`Single-use code · ${Math.ceil((pair.expires-Date.now())/60000)} min remaining`:'Pairing expired — end session and create a new code';},1000);
window.addEventListener('beforeunload',()=>{room?.disconnect();});
if(window.screenLink){
 $('#create').disabled=true;status('Starting your personal connection…');
 try{
  const setup=await window.screenLink.getLocalSetup();
  if(setup?.error)throw Error(setup.error);
  if(setup){$('#server').value=setup.server;$('#owner').value=setup.owner;base=setup.server;owner=setup.owner;$('#notice').textContent='Personal connection ready. Keep ScreenLink running while sharing.';$('#create').disabled=false;$('#setup').requestSubmit();await initRemote(api);$('#tab-remote').disabled=false;showMode(localStorage.getItem('screenlink-mode')||'mirror');}
  else{status('Ready to set up');$('#create').disabled=false;}
 }catch(e){error(e);status('Connection needs attention');$('#create').disabled=false;}
 window.screenLink.onConnectionLost(()=>{status('Pairing connection stopped');$('#error').textContent='The temporary pairing connection stopped. Stop sharing on your iPhone and restart ScreenLink.';});
}
