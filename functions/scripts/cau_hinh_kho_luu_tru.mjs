import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://firebasestorage.googleapis.com',apiVersion:'v1alpha',auth:true});
const path='/projects/e09-elearning/defaultBucket';
try { await client.get(path); console.log('Default bucket already exists.'); }
catch(error) { if(error.status!==404) throw error; await client.post(path,{location:'ASIA-SOUTHEAST1'}); console.log('Default image bucket created in asia-southeast1.'); }
if(process.argv.includes('--enable-rules')) {
 const {getProjectNumber}=require('../node_modules/firebase-tools/lib/getProjectNumber.js');
 const {serviceAccountHasRoles,addServiceAccountToRoles}=require('../node_modules/firebase-tools/lib/gcp/resourceManager.js');
 const number=await getProjectNumber({project:'e09-elearning'});
 const email=`service-${number}@gcp-sa-firebasestorage.iam.gserviceaccount.com`;
 const roles=['roles/firebaserules.firestoreServiceAgent'];
 if(!await serviceAccountHasRoles(number,email,roles,true))await addServiceAccountToRoles(number,email,roles,true);
 console.log('Firebase Storage service agent can evaluate Firestore-backed image rules.');
}
