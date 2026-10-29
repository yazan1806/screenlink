const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('screenLink',{
  getLocalSetup:()=>ipcRenderer.invoke('screenlink:local-setup'),
  setRemoteEnabled:enabled=>ipcRenderer.invoke('screenlink:remote-enabled',enabled),
  getDesktopSource:()=>ipcRenderer.invoke('screenlink:desktop-source'),
  sendInput:data=>ipcRenderer.invoke('screenlink:input',data),
  releaseInput:()=>ipcRenderer.invoke('screenlink:release-input'),
  onConnectionLost:callback=>ipcRenderer.on('screenlink:connection-lost',()=>callback())
});
