import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {examHandlers} from '../src/bai_kiem_tra.js';
import {maintenanceHandlers} from '../src/bao_tri.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Local emulator required');
let env, app, db, exams, now;
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-e09'});
  app = initializeApp({projectId:'demo-e09'}, 'automatic-expiry');
  db = getFirestore(app);
});
beforeEach(async () => {
  await env.clearFirestore();
  now = Date.now();
  exams = examHandlers(db, () => now);
  await db.doc('system/access').set({rootUids:['root1','root2']});
  await db.doc('users/root1').set({role:'super_admin',status:'active'});
  await db.doc('users/root2').set({role:'super_admin',status:'active'});
  await db.doc('users/u').set({role:'user',status:'active'});
  await db.doc('courses/c').set({published:true,learningMode:'study_exam',examId:'e',endsAt:Timestamp.fromMillis(now+60000)});
  await db.doc('courses/c/lessons/l').set({title:'Lesson'});
  await db.doc('users/u/learning/c_l').set({courseId:'c',lessonId:'l',studyCompleted:true});
  await db.doc('exams/e').set({isOpen:true,durationMinutes:1,maxAttempts:2});
  await db.doc('exams/e/questions/q').set({questionText:'Q',options:['A','B'],correctAnswerIndex:1});
});
after(async () => {await env?.cleanup(); if (app) await deleteApp(app);});
async function start() {
  const run = await exams.start('u',{courseId:'c',lessonId:'l',examId:'e'});
  await exams.save('u',{runId:run.runId,revision:0,selectedAnswers:{q:1}});
  return run;
}

test('paused run automatically becomes one result at its original deadline, including during maintenance', async () => {
  const run = await start();
  await exams.heartbeat('u',{runId:run.runId,active:false});
  await maintenanceHandlers(db, () => now).setMode('root1',{maintenance:true});
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).exists,true);
  now += 61000;
  const [a,b] = await Promise.all([exams.expireRuns(),exams.expireRuns()]);
  assert.equal(a.failed+b.failed,0);
  assert.equal(a.completed+b.completed,1);
  const stored = (await db.doc(`exam_private_runs/${run.runId}`).get()).data();
  assert.equal(stored.result.score,10);
  assert.equal(stored.result.expired,true);
  assert.equal(stored.completedAt.toMillis(),run.endsAt);
  const session = (await db.collection('exam_sessions').get()).docs[0];
  assert.equal(session.data().completedCount,1);
  assert.equal(session.data().issuedCount,1);
  assert.equal((await session.ref.collection('runs').get()).size,1);
  assert.deepEqual(await exams.expireRuns(),{completed:0,failed:0});
});

test('expiry worker grades an active run at its deadline during maintenance', async () => {
  const run = await start();
  await maintenanceHandlers(db, () => now).setMode('root1',{maintenance:true});
  now += 61000;
  assert.deepEqual(await exams.expireRuns(),{completed:1,failed:0});
  const stored = (await db.doc(`exam_private_runs/${run.runId}`).get()).data();
  assert.equal(stored.status,'completed');
  assert.equal(stored.result.expired,true);
  assert.equal(stored.completedAt.toMillis(),run.endsAt);
  const session = (await db.collection('exam_sessions').get()).docs[0].data();
  assert.equal(session.issuedCount,1);
  assert.equal(session.completedCount,1);
});

test('resuming a paused run remains available and counted when maintenance starts', async () => {
  const run = await start();
  await exams.heartbeat('u',{runId:run.runId,active:false});
  await exams.start('u',{courseId:'c',lessonId:'l',examId:'e'});
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).data().isActive,true);
  await maintenanceHandlers(db, () => now).setMode('root1',{maintenance:true});
  assert.equal((await db.doc(`exam_private_runs/${run.runId}`).get()).data().status,'in_progress');
  const session = (await db.collection('exam_sessions').get()).docs[0].data();
  assert.equal(session.issuedCount,1);
  assert.equal(session.completedCount,0);
});

test('history finalizes an expired abandoned run without reopening the exam', async () => {
  const run = await start();
  await exams.heartbeat('u',{runId:run.runId,active:false});
  now += 61000;
  const history = await exams.history('u');
  assert.equal(history.runs.length,1);
  assert.equal(history.runs[0].runId,run.runId);
  assert.equal(history.runs[0].score,10);
});
