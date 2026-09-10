import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
import {ref,uploadBytes} from 'firebase/storage';
test('image uploads enforce identity, role, size and content type',async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-e09',firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')},storage:{rules:readFileSync(new URL('../../storage.rules',import.meta.url),'utf8')}});
 try {
 await env.withSecurityRulesDisabled(async ctx=>{
  for(const [id,role] of [['pupil','user'],['root1','super_admin']]) await setDoc(doc(ctx.firestore(),`users/${id}`),{role,status:'active'});
  await setDoc(doc(ctx.firestore(),'system/access'),{rootUids:['root1','root2']});
  await setDoc(doc(ctx.firestore(),'users/limited'),{role:'admin',status:'active',createdBy:'root1',approvedBy:'root2'});
 });
 const pupil=env.authenticatedContext('pupil').storage(),root=env.authenticatedContext('root1').storage();
 const data=new Uint8Array([137,80,78,71]);
 await assertSucceeds(uploadBytes(ref(pupil,'avatars/pupil/ok.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'avatars/other/no.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'lessons/c/no.png'),data,{contentType:'image/png'}));
 await assertSucceeds(uploadBytes(ref(root,'lessons/c/ok.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(env.authenticatedContext('limited').storage(),'lessons/c/limited.png'),data,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(pupil,'avatars/pupil/no.txt'),data,{contentType:'text/plain'}));
 await assertFails(uploadBytes(ref(pupil,'avatars/pupil/large.png'),new Uint8Array(5*1024*1024+1),{contentType:'image/png'}));
 } finally {await env.cleanup();}
});
