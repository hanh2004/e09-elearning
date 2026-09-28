import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { examHandlers } from '../src/bai_kiem_tra.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required');
let app, db, api;
before(async () => {
  app = initializeApp({projectId:'demo-e09'}, 'study-before-exam');
  db = getFirestore(app);
  api = examHandlers(db);
  await db.doc('users/study-user').set({role:'user',status:'active'});
  await db.doc('users/study-other').set({role:'user',status:'active'});
  await db.doc('courses/study-course').set({published:true});
  await db.doc('courses/study-course/lessons/study').set({learningMode:'study_exam',examId:'study-exam'});
  await db.doc('courses/study-course/lessons/only').set({learningMode:'study_only'});
  await db.doc('exams/study-exam').set({isOpen:true,durationMinutes:10});
  await db.doc('exams/study-exam/questions/q').set({questionText:'Q',options:['A','B'],correctAnswerIndex:0});
});
after(async () => { if (app) await deleteApp(app); });

for (const mode of ['scheduled', 'manual']) {
  test(`course ${mode} deadline finalizes only saved answers and keeps the deadline timestamp`, async () => {
    let now = Date.now();
    const handler = examHandlers(db, () => now);
    const courseId = `deadline-${mode}`;
    const course = db.doc(`courses/${courseId}`);
    await course.set({published:true,learningMode:'study_exam',examId:courseId,
      ...(mode === 'scheduled' ? {endsAt:Timestamp.fromMillis(now+10000)} : {})});
    await course.collection('lessons').doc('l').set({order:1});
    const progress = db.doc(`users/study-user/learning/${courseId}_l`);
    await progress.set({courseId,lessonId:'l',studyCompleted:true,completed:false});
    await db.doc(`exams/${courseId}`).set({isOpen:true,durationMinutes:10});
    await db.doc(`exams/${courseId}/questions/q`).set({questionText:'Q',options:['A','B'],correctAnswerIndex:0});
    const input = {examId:courseId,courseId,lessonId:'l'};
    const run = await handler.start('study-user',input);
    await handler.save('study-user',{runId:run.runId,revision:0,selectedAnswers:{q:0}});
    now += 10000;
    if (mode === 'manual') await course.update({endsAt:Timestamp.fromMillis(now)});
    const deadline = now;
    now += 5000; // Network delivery after the deadline must not lose the result.
    const expiredResult = await handler.start('study-user',input);
    assert.equal(expiredResult.expired,true);
    assert.equal(expiredResult.score,10);
    const result = await handler.submit('study-user',{runId:run.runId,revision:1,selectedAnswers:{q:1}});
    assert.equal(result.expired,true);
    assert.equal(result.score,10);
    assert.equal((await progress.get()).data().completedAt.toMillis(),deadline);
    assert.equal((await handler.history('study-user')).runs.find(r=>r.runId===run.runId).completedAt,deadline);
    await handler.submit('study-user',{runId:run.runId,revision:1,selectedAnswers:{q:1}});
    assert.equal((await handler.history('study-user')).runs.filter(r=>r.runId===run.runId).length,1);
  });
}

test('submission completes the course even with a failing score and archives its identity', async () => {
  await db.doc('courses/completion').set({published:true, title:'Khóa hoàn thành', learningMode:'study_exam', examId:'completion-exam'});
  await db.doc('exams/completion-exam').set({isOpen:true,durationMinutes:10});
  await db.doc('exams/completion-exam/questions/q').set({questionText:'Q',options:['A','B'],correctAnswerIndex:0});
  for (const lessonId of ['one','two']) {
    await db.doc(`courses/completion/lessons/${lessonId}`).set({order:1});
    await db.doc(`users/study-user/learning/completion_${lessonId}`).set({courseId:'completion',lessonId,completed:false,studyCompleted:true,studyCompletedAt:Timestamp.now()});
  }
  const input = {examId:'completion-exam',courseId:'completion',lessonId:'two'};
  const run = await api.start('study-user',input);
  assert.equal((await db.doc('users/study-user/learning/completion_one').get()).data().completed,false);
  assert.equal((await api.history('study-user')).runs.some(r=>r.courseId==='completion'),false);
  const result = await api.submit('study-user',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  assert.equal(result.passed,false);
  for (const lessonId of ['one','two']) {
    const progress = (await db.doc(`users/study-user/learning/completion_${lessonId}`).get()).data();
    assert.equal(progress.completed,true);
    assert.equal(progress.examCompleted,true);
    assert.equal(progress.completedExamId,'completion-exam');
  }
  assert.equal((await api.history('study-user')).runs.some(r=>r.courseId==='completion'),false);
  await db.doc('courses/completion').update({endsAt:Timestamp.fromMillis(Date.now()-1)});
  const records = (await api.history('study-user')).runs.filter(r=>r.courseId==='completion');
  assert.equal(records.length,1);
  assert.equal(records[0].courseTitle,'Khóa hoàn thành');
  assert.equal(records[0].score,0);
  await api.submit('study-user',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  assert.equal((await api.history('study-user')).runs.filter(r=>r.courseId==='completion').length,1);
});

test('course exam requires all lessons and cannot fall back to an old lesson exam', async () => {
  const course = db.doc('courses/full-course');
  await course.set({published:true,learningMode:'study_exam',examId:'final-exam'});
  await course.collection('lessons').doc('a').set({learningMode:'study_exam',examId:'study-exam'});
  await course.collection('lessons').doc('b').set({learningMode:'study_only'});
  await db.doc('exams/final-exam').set({isOpen:true,durationMinutes:10});
  await db.doc('exams/final-exam/questions/q').set({questionText:'Final',options:['A','B'],correctAnswerIndex:0});
  const input = {examId:'final-exam',courseId:'full-course',lessonId:'a'};
  await db.doc('users/study-user/learning/full-course_a').set({courseId:'full-course',lessonId:'a',completed:true});
  await assert.rejects(api.start('study-user',input), {code:'failed-precondition'});
  await assert.rejects(api.start('study-user',{...input,examId:'study-exam'}), {code:'failed-precondition'});
  await db.doc('users/study-other/learning/full-course_b').set({courseId:'full-course',lessonId:'b',completed:true});
  await assert.rejects(api.start('study-user',input), {code:'failed-precondition'});
  await db.doc('users/study-user/learning/full-course_b').set({courseId:'full-course',lessonId:'b',completed:true});
  await assert.rejects(api.start('study-user',{...input,lessonId:'missing'}), {code:'failed-precondition'});
  const run = await api.start('study-user', input);
  assert.equal(run.questions.length,1);
  await course.update({learningMode:'study_only',examId:''});
  await assert.rejects(api.start('study-user',input), {code:'failed-precondition'});
  await assert.rejects(api.start('study-user',{...input,examId:'study-exam'}), {code:'failed-precondition'});
});

test('questions require completed study for the current learner and matching lesson', async () => {
  const input = {examId:'study-exam',courseId:'study-course',lessonId:'study'};
  await assert.rejects(api.start('study-user',{examId:'study-exam'}), {code:'failed-precondition'});
  await assert.rejects(api.start('study-user',input), {code:'failed-precondition'});
  const progress = db.doc('users/study-user/learning/study-course_study');
  await progress.set({courseId:'study-course',lessonId:'study',completed:false});
  await assert.rejects(api.start('study-user',{...input,completed:true}), {code:'failed-precondition'});
  await progress.update({completed:true});
  await assert.rejects(api.start('study-other',input), {code:'failed-precondition'});
  await assert.rejects(api.start('study-user',{...input,lessonId:'only'}), {code:'failed-precondition'});
  await assert.rejects(api.start('study-user',{...input,examId:'other-exam'}), {code:'failed-precondition'});
  const run = await api.start('study-user',input);
  assert.equal(run.questions.length,1);
  assert.equal(run.questions[0].correctIndex,undefined);
  assert.equal(run.courseId,input.courseId);
  assert.equal(run.lessonId,input.lessonId);
  assert.equal((await api.start('study-user',input)).runId,run.runId);
  await assert.rejects(api.start('study-user',{examId:'study-exam'}), {code:'failed-precondition'});
  await db.doc('courses/study-course').update({endsAt:Timestamp.fromMillis(1)});
  const expired = await api.start('study-user',input);
  assert.equal(expired.expired,true);
  assert.equal(expired.score,0);
});
