// Refuse publishing a partial Flutter build (missing images, manifests or icon fonts).
import {readFileSync, statSync} from 'node:fs';
import {resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
export function verifyWebBuild(directory) {
  const root=resolve(directory);
  const required=file=>{
    const path=resolve(root,file);
    if(!path.startsWith(root+sep) || !statSync(path).isFile() || !statSync(path).size) {
      throw new Error(`Missing or empty web asset: ${file}`);
    }
    return readFileSync(path);
  };
  for(const file of ['index.html','main.dart.js','flutter_bootstrap.js','assets/AssetManifest.bin',
    'assets/AssetManifest.bin.json','manifest.json','favicon.png']) required(file);
  const pubspec=readFileSync(new URL('../../pubspec.yaml',import.meta.url),'utf8');
  const portal=root.toLowerCase().endsWith(`${sep}user_web`) ? 'user' : 'admin';
  const userOnlyExclusions=new Set(['lib/assets/images/wed_logo.png','lib/assets/templates/users_template.xlsx']);
  const declared=[...pubspec.matchAll(/^\s+- ((?:lib\/assets|assets)\/[^\r\n]+)$/gm)]
    .map(m=>m[1].trim())
    .filter(file=>portal!=='user' || !userOnlyExclusions.has(file));
  const manifest=Buffer.from(JSON.parse(required('assets/AssetManifest.bin.json').toString()),'base64');
  for(const file of declared) {
    required('assets/'+file);
    if(!manifest.includes(Buffer.from(file))) throw new Error(`Asset manifest missing: ${file}`);
  }
  const fonts=JSON.parse(required('assets/FontManifest.json'));
  if(!fonts.some(font=>font.family==='MaterialIcons')) throw new Error('Missing MaterialIcons family');
  for(const font of fonts) for(const entry of font.fonts) required('assets/'+entry.asset);
  const pwa=JSON.parse(required('manifest.json'));
  for(const icon of pwa.icons||[]) required(icon.src);
  for(const variant of ['', 'chromium/']) {
    required(`canvaskit/${variant}canvaskit.js`);
    const wasm=required(`canvaskit/${variant}canvaskit.wasm`);
    if(wasm.subarray(0,4).toString('hex')!=='0061736d') throw new Error('Invalid CanvasKit WASM');
  }
  console.log(`Verified Flutter web bundle: ${root} (${declared.length} assets, ${fonts.length} font families)`);
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  if(!process.argv[2]) throw new Error('Usage: node xac_minh_ban_web.mjs <output directory>');
  verifyWebBuild(process.argv[2]);
}
