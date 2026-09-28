import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
import {ref,uploadBytes,getDownloadURL} from 'firebase/storage';
test('image uploads enforce identity, role, size and content type',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-e09',firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')},storage:{rules:readFileSync(new URL('../../storage.rules',import.meta.url),'utf8')}});
 try {
 await env.withSecurityRulesDisabled(async ctx=>{
  for(const [id,role] of [['pupil','user'],['root1','super_admin']]) await setDoc(doc(ctx.firestore(),`users/${id}`),{role,status:'active'});
  await setDoc(doc(ctx.firestore(),'system/access'),{rootUids:['root1','root2']});
  await setDoc(doc(ctx.firestore(),'users/limited'),{role:'admin',status:'active',createdBy:'root1',approvedBy:'root2'});
 });
 const storageFor=ctx=>ctx.storage('gs://demo-e09.appspot.com');
 const pupil=storageFor(env.authenticatedContext('pupil')),root=storageFor(env.authenticatedContext('root1'));
 const data=new Uint8Array([137,80,78,71]);
 await assertSucceeds(uploadBytes(ref(pupil,'avatars/pupil/ok.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'avatars/other/no.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'lessons/c/no.png'),data,{contentType:'image/png'}));
 await assertSucceeds(uploadBytes(ref(root,'lessons/c/ok.png'),data,{contentType:'image/png'}));
 await assertSucceeds(uploadBytes(ref(root,'courses/cover.png'),data,{contentType:'image/png'}));
 // A real image must survive upload, URL lookup and download unchanged.
 const imageBytes=readFileSync(new URL('../../assets/sample-content/course-study.png',import.meta.url));
 const imageRef=ref(root,'courses/real-cover.png');
 await assertSucceeds(uploadBytes(imageRef,imageBytes,{contentType:'image/png'}));
 const imageUrl=await getDownloadURL(imageRef);
 const response=await fetch(imageUrl);
 if(!response.ok || !Buffer.from(await response.arrayBuffer()).equals(imageBytes))throw new Error('Uploaded image cannot be viewed');
 const rootDb=env.authenticatedContext('root1').firestore();
 const publishedAt=new Date(Date.now()+5*60*1000);
 await assertSucceeds(setDoc(doc(rootDb,'courses/image-course'),{title:'Image test',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:imageUrl}));
 await assertSucceeds(setDoc(doc(rootDb,'courses/image-course/lessons/image-lesson'),{title:'Image lesson',order:1,type:'text',updatedBy:'root1',coverUrl:imageUrl}));
 // Only the demo project's authenticated tokens may save emulator HTTP URLs.
 const productionRoot=env.authenticatedContext('root1',{aud:'e09-elearning'}).firestore();
 await assertFails(setDoc(doc(productionRoot,'courses/production-http'),{title:'Rejected HTTP',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:imageUrl}));
 await assertSucceeds(setDoc(doc(productionRoot,'courses/production-https'),{title:'HTTPS',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:'https://example.org/cover.png'}));
 await assertFails(setDoc(doc(rootDb,'courses/external-http'),{title:'Rejected external HTTP',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:'http://example.org/cover.png'}));
 await assertSucceeds(setDoc(doc(rootDb,'courses/icon-course'),{title:'Icon test',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:'icon:book'}));
 await assertFails(setDoc(doc(rootDb,'courses/bad-icon'),{title:'Invalid icon',published:true,publishedAt,audience:'all',updatedBy:'root1',coverUrl:'icon:unknown'}));
 await assertSucceeds(uploadBytes(ref(root,'courses/large.png'),new Uint8Array(20*1024*1024),{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(root,'courses/too-large.png'),new Uint8Array(20*1024*1024+1),{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'courses/no.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(storageFor(env.authenticatedContext('limited')),'courses/limited.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(storageFor(env.authenticatedContext('limited')),'lessons/c/limited.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'avatars/pupil/no.txt'),data,{contentType:'text/plain'}));
 await assertFails(uploadBytes(ref(storageFor(env.unauthenticatedContext()),'courses/anonymous.png'),data,{contentType:'image/png'}));
 } finally {await env.cleanup();}
});
