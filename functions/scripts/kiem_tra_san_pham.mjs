// Read-only: deployment metadata and aggregate identity health. Never prints credentials.
import {createRequire} from 'node:module';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://cloudfunctions.googleapis.com',apiVersion:'v2',auth:true});
const deployed=(await client.get('/projects/e09-elearning/locations/asia-southeast1/functions')).body.functions||[];
console.log(JSON.stringify({functions:deployed.map(f=>({name:f.name.split('/').pop(),state:f.state,updated:f.updateTime}))},null,2));
const expected=[...readFileSync(new URL('../src/diem_vao.js',import.meta.url),'utf8').matchAll(/^export const (\w+) =/gm)].map(match=>match[1]);
const deployedNames=new Set(deployed.map(f=>f.name.split('/').pop()));
console.log(JSON.stringify({localFunctionCount:expected.length,missingFunctions:expected.filter(name=>!deployedNames.has(name))}));
const rules=new Client({urlPrefix:'https://firebaserules.googleapis.com',apiVersion:'v1',auth:true});
const releases=(await rules.get('/projects/e09-elearning/releases')).body.releases||[];
for(const release of releases) {
  const local=release.name.endsWith('/cloud.firestore')?'firestore.rules':release.name.includes('/firebase.storage/')?'storage.rules':null;
  if(!local) continue;
  const set=(await rules.get('/'+release.rulesetName)).body;
  const content=set.source?.files?.find(f=>f.name.endsWith('.rules'))?.content;
  console.log(JSON.stringify({rules:local,matchesLocal:content?.replace(/\r\n/g,'\n')===readFileSync(new URL('../../'+local,import.meta.url),'utf8').replace(/\r\n/g,'\n')}));
}
const sha=buffer=>createHash('sha256').update(buffer).digest('hex');
for(const portal of ['admin','user']) {
  const origin=portal==='admin'?'https://e09-elearning-admin.web.app':'https://e09-elearning.web.app';
  for(const file of ['main.dart.js','assets/AssetManifest.bin.json','assets/FontManifest.json',
    'assets/fonts/MaterialIcons-Regular.otf',portal==='admin'?'assets/lib/assets/images/wed_logo.png':'assets/lib/assets/images/logo.png']) {
    const response=await fetch(`${origin}/${file}`,{signal:AbortSignal.timeout(30000)});
    const bytes=Buffer.from(await response.arrayBuffer());
    const localPath=new URL(`../../build/${portal}_web/${file}`,import.meta.url);
    const local=existsSync(localPath)?readFileSync(localPath):null;
    console.log(JSON.stringify({portal,file,status:response.status,type:response.headers.get('content-type'),matchesLocal:local?sha(bytes)===sha(local):null,localAvailable:local!==null,bytes:bytes.length}));
  }
}
