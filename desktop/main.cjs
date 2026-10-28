const {app,BrowserWindow}=require('electron');
const path=require('node:path');
let window;
app.whenReady().then(()=>{
  window=new BrowserWindow({width:1380,height:900,minWidth:900,minHeight:660,backgroundColor:'#0b1019',title:'ScreenLink',autoHideMenuBar:true,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}});
  window.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  window.webContents.on('will-navigate',e=>e.preventDefault());
  window.loadFile(path.join(__dirname,'dist','index.html'));
});
app.on('window-all-closed',()=>app.quit());
