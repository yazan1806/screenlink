const path=require('node:path').win32;
const fs=require('node:fs/promises');
function candidateRuntimeDirs({osHome,userProfile,home,localAppData,appData,userData}){
 const values=[
  osHome&&path.join(osHome,'AppData','Local','ScreenLink'),
  userProfile&&path.join(userProfile,'AppData','Local','ScreenLink'),
  localAppData&&path.join(localAppData,'ScreenLink'),
  appData&&path.join(path.dirname(appData),'Local','ScreenLink'),
  home&&path.join(home,'AppData','Local','ScreenLink'),
  userData&&path.join(userData,'ScreenLink')
 ].filter(Boolean).map(v=>path.normalize(v));
 const seen=new Set();return values.filter(v=>{const key=v.toLowerCase();if(seen.has(key))return false;seen.add(key);return true;});
}
async function resolveSetup(candidates,access=fs.access){
 const checks=[];
 for(const dir of candidates){
  const check={directory:dir,files:{}};
  for(const name of ['server.env','cloudflared.exe']){
   try{await access(path.join(dir,name));check.files[name]='ok';}
   catch(e){check.files[name]=e.code||'unavailable';}
  }
  checks.push(check);
  if(Object.values(check.files).every(v=>v==='ok'))return {directory:dir,checks};
 }
 return {directory:null,checks};
}
module.exports={candidateRuntimeDirs,resolveSetup};
