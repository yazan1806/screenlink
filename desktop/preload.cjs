const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('screenLink',{
  getLocalSetup:()=>ipcRenderer.invoke('screenlink:local-setup'),
  onConnectionLost:callback=>ipcRenderer.on('screenlink:connection-lost',()=>callback())
});
