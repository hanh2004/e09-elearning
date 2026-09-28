import { before, after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp, Timestamp, deleteDoc } from 'firebase/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required');
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-e09',
    firestore: {rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
test('exam lessons can save study but cannot forge final completion', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db,'users/exam-reader'),{role:'user',status:'active'});
    await setDoc(doc(db,'courses/exam-reader'),{published:true,learningMode:'study_exam',examId:'e'});
    await setDoc(doc(db,'courses/exam-reader/lessons/l'),{minimumStudySeconds:1});
    await setDoc(doc(db,'users/exam-reader/learning/exam-reader_l'),{
      courseId:'exam-reader',lessonId:'l',completed:false,startedAt:Timestamp.fromMillis(Date.now()-60000),updatedAt:Timestamp.now()});
  });
  const db = env.authenticatedContext('exam-reader').firestore();
  const ref = doc(db,'users/exam-reader/learning/exam-reader_l');
  await assertFails(updateDoc(ref,{completed:true,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{completed:true,examCompleted:true,completedExamId:'e',completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{studyCompleted:true,studyCompletedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{completed:true,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(setDoc(ref,{courseId:'exam-reader',lessonId:'l',completed:false,startedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('ended courses lock root edits, lesson changes and learner progress', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/locked-root'), {role:'super_admin',status:'active'});
    await setDoc(doc(db, 'system/access'), {rootUids:['locked-root']});
    await setDoc(doc(db, 'users/locked-user'), {role:'user',status:'active'});
    await setDoc(doc(db, 'courses/locked'), {title:'Ended',published:true,audience:'all',
      coverUrl:'https://example.org/c.png',updatedBy:'locked-root',endsAt:Timestamp.fromMillis(Date.now()-10000)});
    await setDoc(doc(db, 'courses/locked/lessons/one'), {title:'One',order:1,type:'text',
      coverUrl:'https://example.org/l.png',minimumStudySeconds:1,updatedBy:'locked-root'});
    await setDoc(doc(db, 'users/locked-user/learning/locked_one'), {
      courseId:'locked',lessonId:'one',completed:false,
      startedAt:Timestamp.fromMillis(Date.now()-60000),updatedAt:Timestamp.fromMillis(Date.now()-60000)});
  });
  const root = env.authenticatedContext('locked-root').firestore();
  await assertFails(updateDoc(doc(root,'courses/locked'), {endsAt:Timestamp.fromMillis(Date.now()+60000)}));
  await assertSucceeds(deleteDoc(doc(root,'courses/locked')));
  await assertFails(updateDoc(doc(root,'courses/locked/lessons/one'), {title:'Changed'}));
  await assertSucceeds(deleteDoc(doc(root,'courses/locked/lessons/one')));
  const user = env.authenticatedContext('locked-user').firestore();
  await assertFails(updateDoc(doc(user,'users/locked-user/learning/locked_one'), {
    completed:true,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('published covers are enforced', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db=context.firestore();
    await setDoc(doc(db,'users/editor'),{role:'super_admin',status:'active'});
    await setDoc(doc(db,'system/access'),{rootUids:['editor']});
  });
  const root=env.authenticatedContext('editor').firestore();
  const course={title:'New',published:true,publishedAt:Timestamp.fromMillis(Date.now()+60000),audience:'all',updatedBy:'editor'};
  await assertFails(setDoc(doc(root,'courses/cover'),course));
  await assertSucceeds(setDoc(doc(root,'courses/cover'),{...course,coverUrl:'https://example.org/cover.png'}));
  const lesson={title:'Lesson',order:1,type:'text',minimumStudySeconds:60,updatedBy:'editor'};
  await assertFails(setDoc(doc(root,'courses/cover/lessons/one'),lesson));
  await assertSucceeds(setDoc(doc(root,'courses/cover/lessons/one'),{...lesson,coverUrl:'https://example.org/lesson.png'}));
  const review={rating:5,updatedAt:serverTimestamp()};
  await assertFails(setDoc(doc(root,'courses/review/reviews/reviewer'),review));
});
test('duration checked on server; completion cannot be reset or deleted', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/timed'), {role:'user', status:'active'});
    await setDoc(doc(db, 'courses/timed'), {published:true});
    await setDoc(doc(db, 'courses/timed/lessons/one'), {minimumStudySeconds:60});
  });
  const db = env.authenticatedContext('timed').firestore();
  const ref = doc(db,'users/timed/learning/timed_one');
  const start = {courseId:'timed',lessonId:'one',completed:false,startedAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(setDoc(ref,{...start,completed:true,completedAt:serverTimestamp()}));
  await assertFails(setDoc(ref,{...start,startedAt:Timestamp.fromMillis(0)}));
  await assertSucceeds(setDoc(ref,start));
  await assertFails(updateDoc(ref,{completed:true,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(),ref.path),{startedAt:Timestamp.fromMillis(Date.now()-65000)});
  });
  await assertSucceeds(updateDoc(ref,{completed:true,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(setDoc(ref,start));
  await assertFails(updateDoc(ref,{completed:false,updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(doc(env.authenticatedContext('other').firestore(),ref.path),start));
});
