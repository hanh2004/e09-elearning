import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const base='/projects/e09-elearning/databases/(default)/documents';
const config=(await client.get(`${base}/system/access`)).body;
const roots=config.fields.rootUids.arrayValue.values.map(v=>v.stringValue);
if(roots.length!==2)throw new Error('Expected two configured roots');
const result=await client.post(`${base}:runQuery`,{structuredQuery:{from:[{collectionId:'users'}],select:{fields:['role','unit','createdBy'].map(fieldPath=>({fieldPath}))}}});
const docs=result.body.filter(r=>r.document).map(r=>r.document);
const byId=new Map(docs.map(d=>[d.name.split('/').pop(),d]));
if(!roots.every(uid=>byId.get(uid)?.fields.role?.stringValue==='super_admin'))throw new Error('Root mismatch');
const writes=[];let unassignedAdmins=0;
for(const d of docs){
 const id=d.name.split('/').pop(),role=d.fields.role?.stringValue;
 const creator=d.fields.createdBy?.stringValue;
 let unit=roots.includes(id)?'E09':null;
 if(role==='user'&&creator){
  unit=roots.includes(creator)?'E09':byId.get(creator)?.fields.role?.stringValue==='admin'?byId.get(creator)?.fields.unit?.stringValue?.trim():null;
 }
 if(role==='admin'&&!d.fields.unit?.stringValue?.trim())unassignedAdmins++;
 if(unit&&unit!==d.fields.unit?.stringValue)writes.push({update:{name:d.name,fields:{unit:{stringValue:unit}}},updateMask:{fieldPaths:['unit']},currentDocument:{updateTime:d.updateTime}});
}
console.log(JSON.stringify({mode:process.argv.includes('--apply')?'apply':'dry-run',profilesToUpdate:writes.length,unassignedAdmins}));
if(process.argv.includes('--apply')){
 for(let i=0;i<writes.length;i+=200)await client.post(`${base}:commit`,{writes:writes.slice(i,i+200)});
 console.log('Unit migration completed; passwords, roles and histories unchanged.');
}
