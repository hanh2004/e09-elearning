import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
let ready=true;
for(const group of ['courses','learning_notifications']){
 const result=await client.get(`/projects/e09-elearning/databases/(default)/collectionGroups/${group}/indexes`);
 for(const index of result.body.indexes??[]){
  console.log(`${group}: ${index.state}`);
  if(index.state!=='READY')ready=false;
 }
}
if(!ready)process.exitCode=2;
for(const site of ['e09-elearning','e09-elearning-admin']){
 for(const asset of ['/','/main.dart.js']){
  const result=await fetch(`https://${site}.web.app${asset}`,{method:'HEAD'});
  if(!result.ok)throw new Error(`Hosting check failed: ${site}${asset} (${result.status})`);
  console.log(`${site}${asset}: ${result.status}`);
 }
}
