import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {maintenanceHandlers} from '../src/bao_tri.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Local Firestore emulator required');

let env;
let app;
let db;
let handlers;

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-e09'});
  app = initializeApp({projectId: 'demo-e09'}, 'maintenance-test');
  db = getFirestore(app);
  handlers = maintenanceHandlers(db);
});

beforeEach(async () => {
  await env.clearFirestore();
  await db.doc('system/access').set({rootUids: ['root1', 'root2']});
  await db.doc('users/root1').set({role: 'super_admin', status: 'active'});
  await db.doc('users/root2').set({role: 'super_admin', status: 'active'});
});

after(async () => {
  await env?.cleanup();
  if (app) await deleteApp(app);
});

test('enabling maintenance leaves new and legacy exams unchanged', async () => {
  const activeRun = {status: 'in_progress', selectedAnswers: {q: 1}};
  const activeSession = {activeRunId: 'run1', issuedCount: 2, completedCount: 1};
  const legacyAttempt = {
    status: 'in_progress', selectedAnswers: {q: 0}, currentQuestionIndex: 3,
    attemptCount: 2,
  };
  await db.doc('exam_private_runs/run1').set(activeRun);
  await db.doc('exam_sessions/user_exam').set(activeSession);
  await db.doc('exam_attempts/legacy').set(legacyAttempt);

  assert.deepEqual(await handlers.setMode('root1', {maintenance: true}), {maintenance: true});

  assert.deepEqual((await db.doc('exam_private_runs/run1').get()).data(), activeRun);
  assert.deepEqual((await db.doc('exam_sessions/user_exam').get()).data(), activeSession);
  assert.deepEqual((await db.doc('exam_attempts/legacy').get()).data(), legacyAttempt);
});

test('turning maintenance off only changes the app status and keeps its epoch', async () => {
  const handler = maintenanceHandlers(db, () => 1_700_000_000_000);
  await handler.setMode('root1', {maintenance: true});
  const epoch = (await db.doc('system/app_status').get()).data().lastMaintenanceAt;
  const activeRun = {status: 'in_progress', selectedAnswers: {q: 1}};
  const activeSession = {activeRunId: 'run1', issuedCount: 1, completedCount: 0};
  await db.doc('exam_private_runs/run1').set(activeRun);
  await db.doc('exam_sessions/user_exam').set(activeSession);
  await db.doc('exam_attempts/legacy').set({status: 'in_progress', selectedAnswers: {q: 0}});

  assert.deepEqual(await handler.setMode('root1', {maintenance: false}), {maintenance: false});

  const status = (await db.doc('system/app_status').get()).data();
  assert.equal(status.maintenance, false);
  assert.equal(status.maintenanceStartedAt, undefined);
  assert.equal(status.lastMaintenanceAt.toMillis(), epoch.toMillis());
  assert.deepEqual((await db.doc('exam_private_runs/run1').get()).data(), activeRun);
  assert.deepEqual((await db.doc('exam_sessions/user_exam').get()).data(), activeSession);
  assert.equal((await db.doc('exam_attempts/legacy').get()).data().status, 'in_progress');
});

test('repeating enable keeps the original maintenance epoch', async () => {
  let now = 10_000;
  const handler = maintenanceHandlers(db, () => now);
  await handler.setMode('root1', {maintenance: true});
  const epoch = (await db.doc('system/app_status').get()).data().lastMaintenanceAt.toMillis();

  now = 20_000;
  await handler.setMode('root1', {maintenance: true});

  const status = (await db.doc('system/app_status').get()).data();
  assert.equal(status.lastMaintenanceAt.toMillis(), epoch);
  assert.equal(status.maintenanceStartedAt, undefined);
});

test('non-root cannot change app maintenance status', async () => {
  await db.doc('users/student').set({role: 'user', status: 'active'});
  await assert.rejects(handlers.setMode('student', {maintenance: true}),
    {code: 'permission-denied'});
  assert.equal((await db.doc('system/app_status').get()).exists, false);
});
