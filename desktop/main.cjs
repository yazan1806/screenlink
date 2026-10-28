const {app,BrowserWindow,ipcMain}=require('electron');
const path=require('node:path');
const fs=require('node:fs/promises');
const {pathToFileURL}=require('node:url');
const {spawn}=require('node:child_process');
let window,localServer,tunnel,localOrigin,localKey,quitting=false,startup;
const runtimeDir=path.join(process.env.LOCALAPPDATA||app.getPath('userData'),'ScreenLink');
function parsePrivateEnv(text){
  const values={};
  for(const line of text.split(/\r?\n/)){const match=line.match(/^([A-Z_]+)=(.*)$/);if(!match)continue;values[match[1]]=match[2].startsWith('"')?JSON.parse(match[2]):match[2];}
  return values;
}
async function startPersonalConnection(){
  const configPath=path.join(runtimeDir,'server.env'),binary=path.join(runtimeDir,'cloudflared.exe');
  try{await fs.access(configPath);await fs.access(binary);}catch{return null;}
  await fs.writeFile(path.join(runtimeDir,'connection.json'),JSON.stringify({phase:'starting',pid:process.pid}));
  const env=parsePrivateEnv(await fs.readFile(configPath,'utf8'));
  if(!env.LIVEKIT_API_SECRET||!env.SCREENLINK_OWNER_KEY)throw Error('The private ScreenLink configuration is incomplete.');
  const serverPath=app.isPackaged?path.join(process.resourcesPath,'server','app.mjs'):path.join(__dirname,'..','server','app.mjs');
  const {createApp}=await import(pathToFileURL(serverPath).href);
  localKey=env.SCREENLINK_OWNER_KEY;
  localServer=createApp({config:{ownerKey:localKey,livekitUrl:env.LIVEKIT_URL,apiKey:env.LIVEKIT_API_KEY,apiSecret:env.LIVEKIT_API_SECRET},publicDir:path.join(__dirname,'dist')});
  await new Promise((resolve,reject)=>{localServer.once('error',reject);localServer.listen(0,'127.0.0.1',resolve);});
  localOrigin=`http://127.0.0.1:${localServer.address().port}`;
  const address=await new Promise((resolve,reject)=>{
    let found=false,buffer='';
    const timeout=setTimeout(()=>{reject(Error('The temporary internet connection timed out. Restart ScreenLink or use a hosted server.'));tunnel?.kill();},45000);
    tunnel=spawn(binary,['tunnel','--no-autoupdate','--url',localOrigin,'--protocol','http2'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
    const inspect=chunk=>{buffer=(buffer+chunk.toString()).slice(-16000);const match=buffer.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);if(match&&!found){found=true;clearTimeout(timeout);resolve(match[0]);}};
    tunnel.stdout.on('data',inspect);tunnel.stderr.on('data',inspect);
    tunnel.on('error',()=>{clearTimeout(timeout);reject(Error('The temporary internet connection could not start.'));});
    tunnel.on('exit',()=>{clearTimeout(timeout);if(!found)reject(Error('The temporary internet connection stopped before it was ready.'));else if(!quitting)window?.webContents.send('screenlink:connection-lost');});
  });
  let reachable=false;
  for(let attempt=0;attempt<10;attempt++){
    try{const r=await fetch(address+'/health',{signal:AbortSignal.timeout(3000)});const health=await r.json();if(r.ok&&health.configured){reachable=true;break;}}catch{}
    await new Promise(resolve=>setTimeout(resolve,1000));
  }
  if(!reachable)throw Error('The public pairing address is not reachable yet. Restart ScreenLink and try again.');
  await fs.writeFile(path.join(runtimeDir,'connection.json'),JSON.stringify({phase:'ready',pid:process.pid,server:address,localOrigin}));
  return {server:address,owner:localKey};
}
app.whenReady().then(()=>{
  window=new BrowserWindow({width:1380,height:900,minWidth:900,minHeight:660,backgroundColor:'#0b1019',title:'ScreenLink',autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  window.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  window.webContents.on('will-navigate',e=>e.preventDefault());
  startup=startPersonalConnection().catch(async e=>{await fs.writeFile(path.join(runtimeDir,'connection.json'),JSON.stringify({phase:'error',error:e.message})).catch(()=>{});return {error:e.message};});
  ipcMain.handle('screenlink:local-setup',event=>{if(event.sender!==window.webContents)throw Error('Unsupported caller');return startup;});
  window.loadFile(path.join(__dirname,'dist','index.html'));
});
app.on('before-quit',event=>{
  if(quitting||!localServer)return;
  event.preventDefault();quitting=true;
  (async()=>{
    try{await fetch(localOrigin+'/api/session',{method:'DELETE',headers:{Authorization:`Bearer ${localKey}`},signal:AbortSignal.timeout(4000)});}catch{}
    tunnel?.kill();localServer.closeAllConnections();localServer.close();app.exit(0);
  })();
});
app.on('window-all-closed',()=>app.quit());
