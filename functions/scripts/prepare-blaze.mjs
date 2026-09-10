import {createRequire} from 'node:module';
import {loginEmail} from '../src/policy.js';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const base='/projects/e09-elearning/databases/(default)/documents';
const response=await client.post(`${base}:runQuery`,{structuredQuery:{from:[{collectionId:'users'}],where:{fieldFilter:{field:{fieldPath:'role'},op:'EQUAL',value:{stringValue:'super_admin'}}},select:{fields:[{fieldPath:'username'},{fieldPath:'status'}]}}});
const users=response.body.filter(row=>row.document).map(({document:d})=>({uid:d.name.split('/').pop(),username:d.fields.username?.stringValue,status:d.fields.status?.stringValue}));
if(users.length!==2||new Set(users.map(u=>u.username)).size!==2||!['admintong1','admintong2'].every(n=>users.some(u=>u.username===n&&u.status==='active')))throw new Error('Unexpected root profiles; no write made.');
const auth=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1',auth:true});
const lookup=await auth.post('/projects/e09-elearning/accounts:lookup',{localId:users.map(u=>u.uid)});
if(!users.every(u=>lookup.body.users?.some(a=>a.localId===u.uid&&a.email===loginEmail(u.username)&&!a.disabled)))throw new Error('Auth profile mismatch; no write made.');
console.log(JSON.stringify({verifiedRoots:users.map(u=>({uid:u.uid,username:u.username})),mode:process.argv.includes('--apply')?'apply':'dry-run'}));
if(process.argv.includes('--apply')){
 const fields={rootUids:{arrayValue:{values:users.map(u=>({stringValue:u.uid}))}},schemaVersion:{integerValue:'3'},bootstrapComplete:{booleanValue:true}};
 await client.post(`${base}:commit`,{writes:[{update:{name:`projects/e09-elearning/databases/(default)/documents/system/access`,fields},currentDocument:{exists:false}}]});
 console.log('Created backend root configuration; existing accounts unchanged.');
}
