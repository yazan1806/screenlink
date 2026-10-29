const {test}=require('node:test');const assert=require('node:assert/strict');
const {candidateRuntimeDirs,resolveSetup}=require('./runtime-paths.cjs');
test('OS account profile wins over portable environment and Electron overrides',async()=>{
 const paths=candidateRuntimeDirs({osHome:'C:\\Users\\Owner',userProfile:'C:\\Temp\\portable',home:'C:\\Temp\\portable',localAppData:'C:\\Temp\\portable\\Data',appData:'C:\\Temp\\portable\\Roaming'});
 assert.equal(paths[0],'C:\\Users\\Owner\\AppData\\Local\\ScreenLink');
 const result=await resolveSetup(paths,async file=>{if(!file.startsWith(paths[0]+'\\'))throw Object.assign(Error(),{code:'ENOENT'});});
 assert.equal(result.directory,paths[0]);
});
test('redirected application data is searched and duplicate profile paths are removed',async()=>{
 const paths=candidateRuntimeDirs({osHome:'C:\\Users\\Owner',userProfile:'c:\\users\\owner',home:'C:\\Users\\Owner',localAppData:'D:\\LocalData'});
 assert.equal(paths.length,2);
 const result=await resolveSetup(paths,async file=>{if(!file.startsWith('D:\\LocalData\\ScreenLink\\'))throw Object.assign(Error(),{code:'ENOENT'});});
 assert.equal(result.directory,'D:\\LocalData\\ScreenLink');assert.equal(result.checks[0].files['server.env'],'ENOENT');
});
test('incomplete or inaccessible folders are not selected and errors remain actionable',async()=>{
 const paths=['C:\\one','C:\\two'];
 const result=await resolveSetup(paths,async file=>{if(file==='C:\\one\\cloudflared.exe')throw Object.assign(Error(),{code:'EACCES'});if(file.startsWith('C:\\two'))throw Object.assign(Error(),{code:'ENOENT'});});
 assert.equal(result.directory,null);assert.equal(result.checks[0].files['server.env'],'ok');assert.equal(result.checks[0].files['cloudflared.exe'],'EACCES');
 assert.equal(JSON.stringify(result).includes('secret'),false);
});
