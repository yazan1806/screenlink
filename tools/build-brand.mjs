import {mkdir,writeFile,copyFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {Resvg} from '../desktop/node_modules/@resvg/resvg-js/index.js';
import pngToIco from '../desktop/node_modules/png-to-ico/index.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const defs='<defs><linearGradient id="a" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#94F4DF"/><stop offset="1" stop-color="#3CCEBB"/></linearGradient><linearGradient id="b" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#C6D1FF"/><stop offset="1" stop-color="#839BFA"/></linearGradient></defs>';
// Two offset screen corners meet to form an S: screen + link, at icon scale.
const mark='<path d="M654 264H418c-85 0-138 53-138 138v82c0 79 49 128 128 128h106" fill="none" stroke="url(#a)" stroke-width="92" stroke-linecap="round" stroke-linejoin="round"/><path d="M370 760h236c85 0 138-53 138-138v-82c0-79-49-128-128-128H510" fill="none" stroke="url(#b)" stroke-width="92" stroke-linecap="round" stroke-linejoin="round"/>';
const svg=(background)=>`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${defs}${background?'<rect width="1024" height="1024" fill="#0C1829"/>':''}${mark}</svg>`;
for(const dir of ['brand','desktop/public','desktop/assets','ios/App/Assets.xcassets/AppIcon.appiconset','ios/App/Assets.xcassets/BrandIcon.imageset','ios/App/Assets.xcassets/AccentColor.colorset'])await mkdir(path.join(root,dir),{recursive:true});
await writeFile(path.join(root,'brand/screenlink-mark.svg'),svg(false));
await writeFile(path.join(root,'brand/screenlink-icon.svg'),svg(true));
const png=new Resvg(svg(true),{fitTo:{mode:'width',value:1024}}).render().asPng();
await writeFile(path.join(root,'brand/ScreenLink-Icon-1024.png'),png);
for(const [name,color] of [['light','#17273B'],['dark','#F3F7FF']]){
 const lockup=`<svg xmlns="http://www.w3.org/2000/svg" width="720" height="160" viewBox="0 0 720 160">${defs}<g transform="translate(0 0) scale(.15625)">${mark}</g><text x="172" y="106" font-family="Segoe UI,Arial,sans-serif" font-size="76" font-weight="650" letter-spacing="-3" fill="${color}">ScreenLink</text></svg>`;
 await writeFile(path.join(root,`brand/screenlink-wordmark-${name}.svg`),lockup);
}
for(const name of ['screenlink-mark.svg','screenlink-icon.svg'])await copyFile(path.join(root,'brand',name),path.join(root,'desktop/public',name));
await writeFile(path.join(root,'desktop/assets/icon.ico'),await pngToIco(Buffer.from(png)));
await writeFile(path.join(root,'ios/App/Assets.xcassets/Contents.json'),JSON.stringify({info:{author:'xcode',version:1}},null,2));
for(const folder of ['AppIcon.appiconset','BrandIcon.imageset'])await writeFile(path.join(root,'ios/App/Assets.xcassets',folder,'icon.png'),png);
await writeFile(path.join(root,'ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json'),JSON.stringify({images:[{filename:'icon.png',idiom:'universal',platform:'ios',size:'1024x1024'}],info:{author:'xcode',version:1}},null,2));
await writeFile(path.join(root,'ios/App/Assets.xcassets/BrandIcon.imageset/Contents.json'),JSON.stringify({images:[{filename:'icon.png',idiom:'universal'}],info:{author:'xcode',version:1}},null,2));
await writeFile(path.join(root,'ios/App/Assets.xcassets/AccentColor.colorset/Contents.json'),JSON.stringify({colors:[{idiom:'universal',color:{'color-space':'srgb',components:{red:'0.000',green:'0.435',blue:'0.443',alpha:'1.000'}}},{idiom:'universal',appearances:[{appearance:'luminosity',value:'dark'}],color:{'color-space':'srgb',components:{red:'0.580',green:'0.957',blue:'0.875',alpha:'1.000'}}}],info:{author:'xcode',version:1}},null,2));
console.log('Brand SVGs, 1024px opaque icon, Windows ICO and iOS assets generated.');
