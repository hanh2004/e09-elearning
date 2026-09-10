import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
const account=getGlobalDefaultAccount();
await requireAuth({project:'e09-elearning',...account});
const db=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'});
try{
 const response=await db.get('/projects/e09-elearning/databases/(default)/documents/system/access');
 const ids=response.body.fields?.rootUids?.arrayValue?.values?.map(v=>v.stringValue)??[];
 console.log(JSON.stringify({rootConfigurationExists:true,rootUids:ids,valid:ids.length===2&&new Set(ids).size===2}));
}catch(error){console.log(JSON.stringify({rootConfigurationExists:false,status:error.status??error.context?.response?.statusCode??'unavailable'}));}
const billing=new Client({urlPrefix:'https://cloudbilling.googleapis.com',apiVersion:'v1'});
try{const response=await billing.get('/projects/e09-elearning/billingInfo');console.log(JSON.stringify({billingEnabled:response.body.billingEnabled===true}));}
catch{console.log(JSON.stringify({billingCheck:'unavailable'}));}
