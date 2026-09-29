import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc,getDoc,getDocs,collection,query,where,setDoc,updateDoc,deleteDoc,serverTimestamp } from 'firebase/firestore';
import { initializeApp,deleteApp } from 'firebase-admin/app';
import { getFirestore,Timestamp } from 'firebase-admin/firestore';
import { examHandlers } from '../src/bai_kiem_tra.js';
import { courseHandlers } from '../src/khoa_hoc.js';
import { accountHandlers } from '../src/tai_khoan.js';
if(!process.env.FIRESTORE_EMULATOR_HOST)throw new Error('Emulator required.');
let env,app,db,handlers;
let now=Date.now();
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-e09',firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
  await env.clearFirestore();app=initializeApp({projectId:'demo-e09'},'secure-exam-test');db=getFirestore(app);handlers=examHandlers(db,()=>now);
  await db.doc('system/access').set({rootUids:['root1','root2']});
  await db.doc('users/u').set({role:'user',status:'active',name:'U'});await db.doc('users/v').set({role:'user',status:'active',name:'V'});
});
after(async()=>{await env?.cleanup();if(app)await deleteApp(app);});
async function startStudiedExam(uid,input) { return handlers.start(uid,{courseId:'exam_'+input.examId,lessonId:'study',...input}); }
async function exam(id,limit=2){await db.doc('courses/exam_'+id).set({published:true});await db.doc('courses/exam_'+id+'/lessons/study').set({learningMode:'study_exam',examId:id});await db.doc('users/u/learning/exam_'+id+'_study').set({courseId:'exam_'+id,lessonId:'study',completed:true});await db.doc(`exams/${id}`).set({title:id,isOpen:true,durationMinutes:1,maxAttempts:limit});await db.doc(`exams/${id}/questions/q`).set({questionText:'2+2?',options:['3','4'],correctAnswerIndex:1});}
function pausePrivateRunsQuery(firestore) {
  let batDauTruyVan;
  let moTruyVan;
  const truyVanDaBatDau = new Promise((resolve) => { batDauTruyVan = resolve; });
  const choPhepTruyVan = new Promise((resolve) => { moTruyVan = resolve; });
  const proxyTruyVan = (truyVan) => new Proxy(truyVan, {
    get(target, property) {
      if (property === 'get') return async () => {
        batDauTruyVan();
        await choPhepTruyVan;
        return target.get();
      };
      const giaTri = Reflect.get(target, property, target);
      return typeof giaTri === 'function' ? giaTri.bind(target) : giaTri;
    },
  });
  const proxyCollection = (collectionRef) => new Proxy(collectionRef, {
    get(target, property) {
      if (property === 'where') return (...args) => proxyTruyVan(target.where(...args));
      const giaTri = Reflect.get(target, property, target);
      return typeof giaTri === 'function' ? giaTri.bind(target) : giaTri;
    },
  });
  const coSoDuLieuTamDung = new Proxy(firestore, {
    get(target, property) {
      if (property === 'collection') return (ten) => {
        const collectionRef = target.collection(ten);
        return ten === 'exam_private_runs' ? proxyCollection(collectionRef) : collectionRef;
      };
      const giaTri = Reflect.get(target, property, target);
      return typeof giaTri === 'function' ? giaTri.bind(target) : giaTri;
    },
  });
  return { coSoDuLieuTamDung, truyVanDaBatDau, mo: moTruyVan };
}
test('limited admin reads reports and content but cannot mutate learning or exams',async()=>{
 await db.doc('users/limited_readonly').set({role:'admin',status:'active',createdBy:'root1',approvedBy:'root2'});
 await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
 const limited=env.authenticatedContext('limited_readonly').firestore(),root=env.authenticatedContext('root1').firestore();
  const content={title:'Root course',published:true,publishedAt:new Date(Date.now()+60000),audience:'all',updatedBy:'root1',coverUrl:'icon:book'};
 await assertSucceeds(setDoc(doc(root,'courses/root_content'),content));
 await assertSucceeds(setDoc(doc(root,'courses/root_content/lessons/l'),{title:'Lesson',order:1,type:'text',updatedBy:'root1',coverUrl:'icon:book'}));
 for(const path of ['courses/root_content','courses/root_content/lessons/l','exams/readonly','exams/readonly/questions/q','learning_events/readonly','learning_notifications/readonly']) {
  if(!path.startsWith('courses'))await db.doc(path).set({title:'Existing'});
  await assertSucceeds(getDoc(doc(limited,path)));
  await assertFails(updateDoc(doc(limited,path),{title:'Changed',updatedBy:'limited_readonly'}));
  await assertFails(deleteDoc(doc(limited,path)));
 }
 await assertFails(setDoc(doc(limited,'courses/new'),{...content,updatedBy:'limited_readonly'}));
 await assertSucceeds(getDocs(collection(limited,'exam_attempts')));
 await assertSucceeds(getDocs(collection(limited,'users')));
});
test('published lessons reach all learners; drafts and anonymous access stay denied',async()=>{
 await db.doc('courses/shared').set({title:'Shared',published:true,audience:'class:old'});
 await db.doc('courses/shared/lessons/one').set({title:'One',type:'text',order:1});
 await db.doc('courses/draft').set({title:'Draft',published:false,audience:'all'});
 const student=env.authenticatedContext('u').firestore();
 await assertSucceeds(getDocs(query(collection(student,'courses'),where('published','==',true))));
 await assertSucceeds(getDoc(doc(student,'courses/shared/lessons/one')));
 await assertFails(getDoc(doc(student,'courses/draft')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'courses/shared')));
});
test('simultaneous start reserves one run and strips answer keys',async()=>{
  await exam('concurrent');const [a,b]=await Promise.all([startStudiedExam('u',{examId:'concurrent'}),startStudiedExam('u',{examId:'concurrent'})]);
  assert.equal(a.runId,b.runId);assert.equal(a.questions[0].correctIndex,undefined);assert.equal(a.questions[0].explanation,undefined);
  const catalog=await handlers.list('u');assert.equal(catalog.exams.find(e=>e.id==='concurrent').usedAttempts,1);
});
test('server ignores client scores, rejects spoofed writes, limits attempts',async()=>{
  await exam('grade',1);const run=await startStudiedExam('u',{examId:'grade'});
  const result=await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers:{q:0},score:10});assert.equal(result.score,0);
  assert.equal((await handlers.submit('u',{runId:run.runId})).score,0);
  await assert.rejects(startStudiedExam('u',{examId:'grade'}),{code:'resource-exhausted'});
  const client=env.authenticatedContext('u').firestore();
  await assertFails(getDoc(doc(client,'exams/grade/questions/q')));await assertFails(getDoc(doc(client,'exams/grade')));
  await assertFails(getDoc(doc(client,`exam_private_runs/${run.runId}`)));
  await assertFails(setDoc(doc(client,'exam_attempts/spoof'),{userId:'u',examId:'grade',diemSo:10}));
  await assertFails(updateDoc(doc(client,'users/u'),{role:'super_admin'}));
});
test('expiry grades saved answers and allows a new run without deadlock',async()=>{
  await exam('expiry');const run=await startStudiedExam('u',{examId:'expiry'});
  await handlers.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});now+=61000;
  const result=await startStudiedExam('u',{examId:'expiry'});assert.equal(result.status,'completed');assert.equal(result.score,10);assert.equal(result.expired,true);
  const next=await startStudiedExam('u',{examId:'expiry'});assert.notEqual(next.runId,run.runId);
  await assert.rejects(handlers.save('v',{runId:next.runId,revision:0,selectedAnswers:{}}),{code:'permission-denied'});
});
test('abandoned run is graded from saved answers when resumed after its deadline',async()=>{
  await exam('resume_expired');
  await db.doc('courses/exam_resume_expired').update({endsAt:Timestamp.fromMillis(now+5000)});
  const run=await startStudiedExam('u',{examId:'resume_expired'});
  await handlers.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  now+=6000;
  const result=await startStudiedExam('u',{examId:'resume_expired'});
  assert.equal(result.status,'completed');
  assert.equal(result.expired,true);
  assert.equal(result.score,10);
  const sessions=await db.collection('exam_sessions').where('examId','==','resume_expired').get();
  assert.equal(sessions.size,1);
  assert.equal(sessions.docs[0].data().completedCount,1);
  assert.equal(sessions.docs[0].data().activeRunId,null);
});
test('exam heartbeat marks a live run and stops after maintenance begins',async()=>{
  await exam('heartbeat');
  const run=await startStudiedExam('u',{examId:'heartbeat'});
  await assertSucceeds(handlers.heartbeat('u',{runId:run.runId}));
  const active=(await db.doc(`exam_private_runs/${run.runId}`).get()).data();
  assert.equal(typeof active.lastActivityAt?.toMillis,'function');
  await db.doc('system/app_status').set({maintenance:true});
  await assert.rejects(handlers.heartbeat('u',{runId:run.runId}),{code:'failed-precondition'});
  await db.doc('system/app_status').set({maintenance:false});
});
test('stale writes cannot replace progress and snapshot survives question edits',async()=>{
  await exam('snapshot');const run=await startStudiedExam('u',{examId:'snapshot'});
  await handlers.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  await assert.rejects(handlers.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:0}}),{code:'aborted'});
  await db.doc('exams/snapshot/questions/q').update({correctAnswerIndex:0});
  const result=await handlers.submit('u',{runId:run.runId,revision:1,selectedAnswers:{q:1}});assert.equal(result.score,10);assert.equal(result.review,undefined);
});
test('legacy completed and abandoned runs count toward limit',async()=>{
  await exam('legacy',2);await db.doc('exam_attempts/old').set({userId:'u',examId:'legacy',attemptCount:1,status:'in_progress'});
  assert.equal((await handlers.list('u')).exams.find(e=>e.id==='legacy').usedAttempts,2);
  await assert.rejects(startStudiedExam('u',{examId:'legacy'}),{code:'resource-exhausted'});
});

test('notification read receipts are private and limited to visible, due notices',async()=>{
  await db.doc('learning_notifications/public').set({title:'Test',body:'Test',audience:'all',sendAt:Timestamp.fromMillis(1)});
  await db.doc('learning_notifications/private').set({title:'Test',body:'Test',audience:'user:v',sendAt:Timestamp.fromMillis(1)});
  await db.doc('learning_notifications/future').set({title:'Test',body:'Test',audience:'all',sendAt:Timestamp.fromMillis(Date.now()+3600000)});
  const u=env.authenticatedContext('u').firestore();
  await assertSucceeds(setDoc(doc(u,'users/u/notification_reads/public'),{readAt:serverTimestamp()}));
  await assertFails(setDoc(doc(u,'users/u/notification_reads/private'),{readAt:serverTimestamp()}));
  await assertFails(setDoc(doc(u,'users/u/notification_reads/future'),{readAt:serverTimestamp()}));
  await assertFails(setDoc(doc(u,'users/v/notification_reads/public'),{readAt:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('v').firestore(),'users/u/notification_reads/public')));
  await assertFails(setDoc(doc(u,'users/u/notification_reads/public'),{readAt:serverTimestamp(),role:'admin'}));
});

test('shuffled questions resume unchanged and grade against shuffled snapshot',async()=>{
  await exam('shuffle');
  await db.doc('exams/shuffle').update({shuffleQuestions:true,shuffleAnswers:true,showSolutions:true});
  await db.doc('exams/shuffle/questions/q2').set({questionText:'3+3?',options:['6','7','8'],correctAnswerIndex:0});
  const run=await startStudiedExam('u',{examId:'shuffle'});
  const resumed=await startStudiedExam('u',{examId:'shuffle'});
  assert.deepEqual(resumed.questions,run.questions);
  const selectedAnswers=Object.fromEntries(run.questions.map(q=>[q.id,q.options.indexOf(q.id==='q'?'4':'6')]));
  const result=await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers});
  assert.equal(result.score,10);
  assert.equal(result.review.length,2);
});

test('deleting a blocked account is retryable after Auth failure and cleans read receipts',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await db.doc('users/cleanup_retry').set({role:'user',status:'blocked',name:'User',username:'cleanup_retry'});
  await db.doc('users/cleanup_retry/notification_reads/public').set({readAt:Timestamp.now()});
  let failed=false;
  const accounts=accountHandlers(db,{deleteUser:async()=>{if(!failed){failed=true;throw new Error('temporary Auth outage');}}});
  await assert.rejects(accounts.deleteUser('u',{userId:'cleanup_retry'}),{code:'permission-denied'});
  await assert.rejects(accounts.deleteUser('root1',{userId:'cleanup_retry'}),/temporary Auth outage/);
  assert.equal((await db.doc('users/cleanup_retry').get()).data().status,'deleting');
  await accounts.deleteUser('root1',{userId:'cleanup_retry'});
  assert.equal((await db.doc('users/cleanup_retry').get()).exists,false);
  assert.equal((await db.collection('users/cleanup_retry/notification_reads').get()).empty,true);
});

test('unit assignment is root-only, follows creator on import and cannot be forged by students',async()=>{
  await db.doc('system/code_indexes').set({status:'complete'});
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  const accounts=accountHandlers(db,{createUser:async()=>{},updateUser:async()=>{}});
  const proposal=await accounts.proposeAdmin('root1',{unit:'Đơn vị A',account:{name:'Admin A',username:'unitadmin',password:'123456'},operationId:'e'.repeat(32)});
  const adminId=(await db.doc(`admin_requests/${proposal.requestId}`).get()).data().targetUid;
  await db.doc(`users/${adminId}`).update({status:'active',approvedBy:'root2'});
  await accounts.importUsers(adminId,{rows:[{name:'Student',username:'unitstudent',password:'123456',unit:'forged'}],operationId:'f'.repeat(32)});
  const learner=(await db.collection('users').where('username','==','unitstudent').get()).docs[0];
  assert.equal(learner.data().unit,'Đơn vị A');
  await assert.rejects(accounts.setUnit(adminId,{userId:adminId,unit:'B'}),{code:'permission-denied'});
  await accounts.setUnit('root1',{userId:adminId,unit:'Đơn vị B',codes:{[learner.id]:'unitstudent'}});
  assert.equal((await learner.ref.get()).data().unit,'Đơn vị B');
  const studentClient=env.authenticatedContext(learner.id).firestore();
  await assertSucceeds(updateDoc(doc(studentClient,`users/${learner.id}`),{subUnit:'Đội 1'}));
  await assertFails(updateDoc(doc(studentClient,`users/${learner.id}`),{subUnit:'x'.repeat(201)}));
  await assertFails(updateDoc(doc(studentClient,`users/${adminId}`),{subUnit:'Đội khác'}));
  await assertFails(updateDoc(doc(studentClient,`users/${learner.id}`),{unit:'E09'}));
  await accounts.setUnit('root1',{userId:adminId,unit:'Đơn vị C',codes:{[learner.id]:'unitstudent'}});
  assert.equal((await learner.ref.get()).data().unit,'Đơn vị C');
  assert.equal((await learner.ref.get()).data().subUnit,'');
  await accounts.importUsers('root1',{rows:[{name:'Root student',username:'e09student',password:'123456'}],operationId:'a'.repeat(32)});
  assert.equal((await db.collection('users').where('username','==','e09student').get()).docs[0].data().unit,'E09');
});
test('expired submit cannot introduce unsaved answers; private history stays private',async()=>{
  await exam('late');const run=await startStudiedExam('u',{examId:'late'});now+=61000;
  const result=await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});assert.equal(result.score,0);
  assert.equal((await handlers.history('u')).runs.some(r=>r.runId===run.runId),false);
  await db.doc('courses/exam_late').update({endsAt:Timestamp.fromMillis(now-1)});
  const history=await handlers.history('u');assert.ok(history.runs.some(r=>r.runId===run.runId));
  const sessions=await db.collection('exam_sessions').where('examId','==','late').get();
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u').firestore(),`exam_sessions/${sessions.docs[0].id}/runs/${run.runId}`)));
  await assertFails(getDoc(doc(env.authenticatedContext('v').firestore(),`exam_sessions/${sessions.docs[0].id}/runs/${run.runId}`)));
});

test('root deletion cleans snapshots, sessions and reports; students cannot delete exams',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('delete');const run=await startStudiedExam('u',{examId:'delete'});
  await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  await assert.rejects(handlers.deleteExam('u',{examId:'delete'}),{code:'permission-denied'});
  await handlers.deleteExam('root1',{examId:'delete'});
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).exists,false);
  assert.equal((await db.collection('exam_sessions').where('examId','==','delete').get()).empty,true);
  assert.equal((await db.collection('exam_attempts').where('examId','==','delete').get()).empty,true);
  assert.equal((await db.doc('exams/delete').get()).exists,false);
});
test('course deletion removes its exam, runs, results and learning progress',async()=>{
  await exam('course_cleanup');
  await db.doc('courses/exam_course_cleanup').update({examId:'course_cleanup'});
  await db.doc('exams/course_cleanup').update({courseId:'exam_course_cleanup'});
  const run=await startStudiedExam('u',{examId:'course_cleanup'});
  await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  const courses=courseHandlers(db);
  await assert.rejects(courses.deleteCourse('u',{courseId:'exam_course_cleanup'}),{code:'permission-denied'});
  await courses.deleteCourse('root1',{courseId:'exam_course_cleanup'});
  assert.equal((await db.doc('courses/exam_course_cleanup').get()).exists,false);
  assert.equal((await db.doc('courses/exam_course_cleanup/lessons/study').get()).exists,false);
  assert.equal((await db.doc('exams/course_cleanup').get()).exists,false);
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).exists,false);
  assert.equal((await db.collection('exam_sessions').where('examId','==','course_cleanup').get()).empty,true);
  assert.equal((await db.collection('exam_attempts').where('examId','==','course_cleanup').get()).empty,true);
  assert.equal((await db.doc('users/u/learning/exam_course_cleanup_study').get()).exists,false);
});

for (const linkedAt of ['course', 'lesson']) {
  test(`course deletion cleans legacy exam linked at ${linkedAt} without an owner field`, async () => {
    const examId = `legacy_cleanup_${linkedAt}`;
    const courseId = `exam_${examId}`;
    await exam(examId);
    if (linkedAt === 'course') await db.doc(`courses/${courseId}`).update({examId});
    const run = await startStudiedExam('u', {examId});
    await handlers.submit('u', {runId:run.runId,revision:0,selectedAnswers:{q:1}});
    await courseHandlers(db).deleteCourse('root1', {courseId});
    assert.equal((await db.doc(`courses/${courseId}`).get()).exists, false);
    assert.equal((await db.doc(`exams/${examId}`).get()).exists, false);
    assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).exists, false);
    assert.equal((await db.collection('exam_attempts').where('examId','==',examId).get()).empty, true);
  });
}

test('course deletion preserves a shared exam and lets an active learner finish before retry', async () => {
  const examId = 'shared_course_cleanup';
  const courseId = `exam_${examId}`;
  await exam(examId);
  await db.doc(`exams/${examId}`).update({courseId});
  await db.doc(`courses/${courseId}`).update({examId});
  await db.doc('courses/keep_shared_course').set({examId});
  const run = await startStudiedExam('u', {examId});
  const courses = courseHandlers(db);
  await assert.rejects(courses.deleteCourse('root1', {courseId}), {code:'failed-precondition'});
  assert.equal((await db.doc(`courses/${courseId}`).get()).data().deleting, false);
  await handlers.submit('u', {runId:run.runId,revision:0,selectedAnswers:{q:1}});
  await courses.deleteCourse('root1', {courseId});
  assert.equal((await db.doc(`courses/${courseId}`).get()).exists, false);
  const retainedExam = (await db.doc(`exams/${examId}`).get()).data();
  assert.equal(retainedExam.isOpen, true);
  assert.equal(retainedExam.courseId, undefined);
  assert.equal((await db.doc('courses/keep_shared_course').get()).data().examId, examId);
  assert.equal((await db.doc(`exams/${examId}/questions/q`).get()).exists, true);
});

test('course deletion respects live locks and recovers an expired deletion', async () => {
  await exam('course_lock');
  const courseId = 'exam_course_lock';
  const ref = db.doc(`courses/${courseId}`);
  await ref.update({deleting:true,deletingOperationId:'first',deletingLeaseUntil:Date.now()+60000});
  await assert.rejects(courseHandlers(db).deleteCourse('root1', {courseId}), {code:'failed-precondition'});
  await ref.update({deletingLeaseUntil:Date.now()-1});
  await courseHandlers(db).deleteCourse('root1', {courseId});
  assert.equal((await ref.get()).exists, false);
});

test('course deletion locks new study, exam starts and lesson edits before cleanup', async () => {
  const examId = 'locked_course_cleanup';
  const courseId = `exam_${examId}`;
  await exam(examId);
  await db.doc('courses/another_locked_course').set({examId});
  const paused = pausePrivateRunsQuery(db);
  const deletion = courseHandlers(paused.coSoDuLieuTamDung).deleteCourse('root1', {courseId});
  await paused.truyVanDaBatDau;
  try {
    await assert.rejects(startStudiedExam('u', {examId}), {code:'failed-precondition'});
    const root = env.authenticatedContext('root1').firestore();
    await assertFails(setDoc(doc(root, `courses/${courseId}/lessons/new`), {
      title:'Bài mới',order:1,type:'text',updatedBy:'root1',coverUrl:'icon:book',
    }));
    const learner = env.authenticatedContext('v').firestore();
    await assertFails(setDoc(doc(learner, `users/v/learning/${courseId}_study`), {
      courseId,lessonId:'study',completed:false,startedAt:serverTimestamp(),updatedAt:serverTimestamp(),
    }));
  } finally {
    paused.mo();
    await deletion;
  }
  assert.equal((await db.doc(`courses/${courseId}`).get()).exists, false);
  assert.equal((await db.doc(`courses/${courseId}/lessons/new`).get()).exists, false);
});
test('lesson deletion removes its exclusive exam and invalidates active runs',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('lesson_cleanup');
  const run=await startStudiedExam('u',{examId:'lesson_cleanup'});
  const courses=courseHandlers(db);
  await courses.deleteLesson('root1',{courseId:'exam_lesson_cleanup',lessonId:'study'});
  assert.equal((await db.doc('courses/exam_lesson_cleanup/lessons/study').get()).exists,false);
  assert.equal((await db.doc('users/u/learning/exam_lesson_cleanup_study').get()).exists,false);
  assert.equal((await db.doc('exams/lesson_cleanup').get()).exists,false);
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).exists,false);
  assert.equal((await db.collection('exam_sessions').where('examId','==','lesson_cleanup').get()).empty,true);
  assert.equal((await db.collection('exam_attempts').where('examId','==','lesson_cleanup').get()).empty,true);
  await assert.rejects(handlers.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:1} }));
});
test('lesson deletion preserves shared exam and blocks until its active run is finished',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('shared_lesson_exam');
  const courseId='exam_shared_lesson_exam';
  await db.doc(`courses/${courseId}`).update({learningMode:'study_exam',examId:'shared_lesson_exam'});
  await db.doc(`courses/${courseId}/lessons/other`).set({learningMode:'study_exam',examId:'shared_lesson_exam'});
  await db.doc(`users/u/learning/${courseId}_other`).set({courseId,lessonId:'other',studyCompleted:true});
  const run=await startStudiedExam('u',{examId:'shared_lesson_exam'});
  const courses=courseHandlers(db);
  await assert.rejects(courses.deleteLesson('root1',{courseId,lessonId:'study'}),
    {code:'failed-precondition'});
  assert.equal((await db.doc(`courses/${courseId}/lessons/study`).get()).exists,true);
  assert.equal((await db.doc('exams/shared_lesson_exam').get()).exists,true);
  await handlers.submit('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  await courses.deleteLesson('root1',{courseId,lessonId:'study'});
  assert.equal((await db.doc(`courses/${courseId}/lessons/study`).get()).exists,false);
  assert.equal((await db.doc('courses/exam_shared_lesson_exam').get()).data().examId,'shared_lesson_exam');
  assert.equal((await db.doc('courses/exam_shared_lesson_exam/lessons/other').get()).exists,true);
  assert.equal((await db.doc('exams/shared_lesson_exam').get()).exists,true);
  assert.equal((await db.collection('exam_attempts').where('examId','==','shared_lesson_exam').get()).empty,false);
});
test('lesson deletion preserves an exam still linked to another course',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('external_shared_exam');
  await db.doc('courses/another-course').set({examId:'external_shared_exam'});
  const courses=courseHandlers(db);
  await courses.deleteLesson('root1',{courseId:'exam_external_shared_exam',lessonId:'study'});
  assert.equal((await db.doc('courses/exam_external_shared_exam/lessons/study').get()).exists,false);
  assert.equal((await db.doc('courses/another-course').get()).data().examId,'external_shared_exam');
  assert.equal((await db.doc('exams/external_shared_exam').get()).exists,true);
});
test('lesson deletion locks the lesson before checking active runs, preventing a concurrent exam start',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('delete_start_race');
  const courseId='exam_delete_start_race';
  await db.doc(`courses/${courseId}/lessons/other`).set({learningMode:'study_exam',examId:'delete_start_race'});
  const paused=pausePrivateRunsQuery(db);
  const courses=courseHandlers(paused.coSoDuLieuTamDung);
  const deletion=courses.deleteLesson('root1',{courseId,lessonId:'study'});
  await paused.truyVanDaBatDau;
  assert.equal((await db.doc(`courses/${courseId}/lessons/study`).get()).data().deleting,true);
  await assert.rejects(startStudiedExam('u',{examId:'delete_start_race'}),{code:'failed-precondition'});
  paused.mo();
  await deletion;
  assert.equal((await db.doc(`courses/${courseId}/lessons/study`).get()).exists,false);
  assert.equal((await db.collection('exam_private_runs').where('examId','==','delete_start_race').get()).empty,true);
});
test('lesson deletion recovers expired locks but does not steal a live deletion lock',async()=>{
  await db.doc('users/root1').set({role:'super_admin',status:'active',name:'Root'});
  await exam('stale_delete_lock');
  const staleCourseId='exam_stale_delete_lock';
  await db.doc(`courses/${staleCourseId}/lessons/study`).update({
    deleting:true,
    deletingOperationId:'abandoned-operation',
    deletingLeaseUntil:Date.now()-1,
  });
  const courses=courseHandlers(db);
  await courses.deleteLesson('root1',{courseId:staleCourseId,lessonId:'study'});
  assert.equal((await db.doc(`courses/${staleCourseId}/lessons/study`).get()).exists,false);

  await exam('live_delete_lock');
  const liveCourseId='exam_live_delete_lock';
  await db.doc(`courses/${liveCourseId}/lessons/study`).update({
    deleting:true,
    deletingOperationId:'active-operation',
    deletingLeaseUntil:Date.now()+60_000,
  });
  await assert.rejects(courses.deleteLesson('root1',{courseId:liveCourseId,lessonId:'study'}),
    {code:'failed-precondition'});
  assert.equal((await db.doc(`courses/${liveCourseId}/lessons/study`).get()).data().deletingOperationId,'active-operation');
});
