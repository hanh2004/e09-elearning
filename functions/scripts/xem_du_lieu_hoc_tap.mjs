import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const base='/projects/e09-elearning/databases/(default)/documents';
const get=async(collection,fields)=>{
  const response=await client.post(`${base}:runQuery`,{structuredQuery:{from:[{collectionId:collection}],
    select:{fields:fields.map(fieldPath=>({fieldPath}))}}});
  return response.body.filter(row=>row.document).map(row=>row.document);
};
const users=await get('users',['role','status','unit','createdBy','username']);
const learners=users.filter(doc=>doc.fields?.role?.stringValue==='user' && ['active','blocked'].includes(doc.fields?.status?.stringValue));
const missing=learners.filter(doc=>!doc.fields?.username?.stringValue?.trim());
console.log(JSON.stringify({learners:learners.length,missingUsernames:missing.length,
  missingUnits:learners.filter(doc=>!doc.fields?.unit?.stringValue?.trim()).length,
  units:[...new Set(learners.filter(doc=>!doc.fields?.unit?.stringValue?.trim()).map(doc=>doc.fields?.unit?.stringValue||''))],
  courses:(await get('courses',['title','published'])).map(doc=>({id:doc.name.split('/').pop(),title:doc.fields?.title?.stringValue,published:doc.fields?.published?.booleanValue})),
  exams:(await get('exams',['title','courseId','maxAttempts'])).map(doc=>({id:doc.name.split('/').pop(),title:doc.fields?.title?.stringValue,courseId:doc.fields?.courseId?.stringValue,maxAttempts:doc.fields?.maxAttempts?.integerValue})),
},null,2));
