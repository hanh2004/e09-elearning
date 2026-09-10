import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,signInWithEmailAndPassword} from 'firebase/auth';
import {getStorage,ref,uploadBytes,getDownloadURL} from 'firebase/storage';
const require=createRequire(import.meta.url);
const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
const admin=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const text=readFileSync(new URL('../../lib/firebase_options.dart',import.meta.url),'utf8');
const apiKey=text.match(/static const FirebaseOptions web = FirebaseOptions\([\s\S]*?apiKey: '([^']+)'/)[1];
const base='https://identitytoolkit.googleapis.com/v1/';
async function authCall(name,data){const res=await fetch(`${base}${name}?key=${apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});const json=await res.json();if(!res.ok)throw new Error(`Auth smoke request failed (${res.status})`);return json;}
let credential;let path;let imagePath;let imageApp;
try{
 const email=`qa_blaze_${randomBytes(12).toString('hex')}@accounts.invalid`, password=randomBytes(24).toString('base64url');
 credential=await authCall('accounts:signUp',{email,password,returnSecureToken:true});
 if(!/^[A-Za-z0-9_-]+$/.test(credential.localId))throw new Error('Invalid temporary user id');
 path=`/projects/e09-elearning/databases/(default)/documents/users/${credential.localId}`;
 await admin.patch(path,{fields:{name:{stringValue:'Kiểm tra triển khai tạm thời'},role:{stringValue:'user'},status:{stringValue:'active'},createdBy:{stringValue:'deployment-smoke'}}});
 if(process.argv.includes('--image-upload')){
  imagePath=`avatars/${credential.localId}/smoke.png`;
  imageApp=initializeApp({apiKey,projectId:'e09-elearning',storageBucket:'e09-elearning.firebasestorage.app'},'image-smoke');
  await signInWithEmailAndPassword(getAuth(imageApp),email,password);
  const imageRef=ref(getStorage(imageApp),imagePath);
  await uploadBytes(imageRef,readFileSync(new URL('../../lib/assets/images/logo.png',import.meta.url)),{contentType:'image/png'});
  await getDownloadURL(imageRef);
  console.log('Authenticated avatar upload: passed');
 }
 let catalog;
 for(const method of ['examList','examHistory']){
  const response=await fetch(`https://asia-southeast1-e09-elearning.cloudfunctions.net/${method}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${credential.idToken}`},body:JSON.stringify({data:{}})});
  const payload=await response.json();if(!response.ok||payload.error)throw new Error(`${method} smoke failed (${response.status}, ${payload.error?.status??'unknown'})`);
  if(method==='examList')catalog=payload.result;
  console.log(`${method}: authenticated request passed`);
 }
 if(process.argv.includes('--expect-secure-rules')&&catalog?.exams?.length){
  const response=await fetch(`https://firestore.googleapis.com/v1/projects/e09-elearning/databases/(default)/documents/exams/${encodeURIComponent(catalog.exams[0].id)}`,{headers:{Authorization:`Bearer ${credential.idToken}`}});
  if(response.status!==403)throw new Error(`Answer-key isolation failed (${response.status})`);
  console.log('Direct student access to exam answer source: denied');
 }
}finally{
 let cleaned=true;
 if(imageApp)await deleteApp(imageApp);
 if(imagePath){try{const storage=new Client({urlPrefix:'https://storage.googleapis.com',apiVersion:'storage/v1',auth:true});await storage.delete(`/b/e09-elearning.firebasestorage.app/o/${encodeURIComponent(imagePath)}`);}catch(error){if(error.status!==404)cleaned=false;}}
 if(path){try{await admin.delete(path);}catch{cleaned=false;}}
 if(credential){try{await authCall('accounts:delete',{idToken:credential.idToken});}catch{cleaned=false;}}
 if(!cleaned)throw new Error('Temporary deployment account cleanup requires attention');
 if(credential)console.log('Temporary deployment account removed');
}
