import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection, query, where, writeBatch, serverTimestamp } from 'firebase/firestore';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { accountHandlers } from '../src/accounts.js';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Emulators required; never run against live Firebase.');
const projectId = process.env.GCLOUD_PROJECT || 'demo-e09';
let env, app, db, auth, handlers;
const roots = ['root_admintong1', 'root_admintong2'];
const rootEmails = [
  '6cee932f6a2e32baf138fd77429565df5ac34fdefddd6f3dbb0804a23c94fdfe@accounts.invalid',
  '563b7df548c46e765b517d4db8ef94f17570d00a38206931ec11085e52e620cc@accounts.invalid',
];
const row = (username) => ({ name: 'Test User', username, password: '123456' });
let serial = 0;
const operationId = () => (++serial).toString(16).padStart(32, '0');
before(async () => {
  env = await initializeTestEnvironment({ projectId,
    firestore: { rules: readFileSync(new URL('../../firestore.spark.rules', import.meta.url), 'utf8') } });
  await env.clearFirestore();
  app = initializeApp({ projectId }, 'integration'); db = getFirestore(app); auth = getAuth(app);
  handlers = accountHandlers(db, auth);
  await db.doc('system/access').set({ rootUids: roots });
  for (const uid of roots) await db.doc(`users/${uid}`).set({ role: 'super_admin', status: 'active', username: uid });
});
after(async () => { await env?.cleanup(); if (app) await deleteApp(app); });

test('two-root approval and limited ownership end to end', async () => {
  const input = { unit: 'Đơn vị A', account: row('limited01'), operationId: operationId() };
  const request = await handlers.proposeAdmin(roots[0], input);
  assert.deepEqual(await handlers.proposeAdmin(roots[0], input), request);
  const requestDoc = (await db.doc(`admin_requests/${request.requestId}`).get()).data();
  const limited = requestDoc.targetUid;
  assert.equal(requestDoc.digest, undefined);
  assert.equal((await auth.getUser(limited)).disabled, true);
  await assert.rejects(handlers.decideAdmin(roots[0], { requestId: request.requestId, approve: true }), { code: 'permission-denied' });
  await assert.rejects(handlers.importUsers(limited, { rows: [row('tooearly')], operationId: operationId() }), { code: 'permission-denied' });
  await handlers.decideAdmin(roots[1], { requestId: request.requestId, approve: true });
  await handlers.decideAdmin(roots[1], { requestId: request.requestId, approve: true });
  await assert.rejects(handlers.decideAdmin(roots[1], { requestId: request.requestId, approve: false }));
  assert.equal((await auth.getUser(limited)).disabled, false);
  const payload = { rows: [row('own01'), row('own02')], operationId: operationId() };
  await handlers.importUsers(limited, payload);
  await handlers.importUsers(limited, payload);
  const own = (await db.collection('users').where('createdBy', '==', limited).get()).docs;
  assert.equal(own.length, 2);
  for (const user of own) { assert.equal(user.data().role, 'user'); assert.equal(user.data().password, undefined); }
  await handlers.updateUser(limited, { userId: own[0].id, name: 'Changed' });
  await assert.rejects(handlers.proposeAdmin(limited, { unit: 'Đơn vị A', account: row('badadmin'), operationId: operationId() }), { code: 'permission-denied' });
  await handlers.importUsers(roots[0], { rows: [row('notmine')], operationId: operationId() });
  const other = (await db.collection('users').where('username', '==', 'notmine').get()).docs[0];
  await assert.rejects(handlers.updateUser(limited, { userId: other.id, name: 'Forbidden' }), { code: 'permission-denied' });
  await assert.rejects(handlers.deleteUser(limited, { userId: other.id }), { code: 'permission-denied' });
  await handlers.deleteUser(limited, { userId: own[0].id });
  await assert.rejects(auth.getUser(own[0].id), { code: 'auth/user-not-found' });
  assert.equal((await own[0].ref.get()).exists, false);
  await assert.rejects(handlers.deleteUser(roots[0], { userId: roots[1] }), { code: 'permission-denied' });
  await assert.rejects(handlers.updateUser(roots[0], { userId: roots[1], name: 'takeover', password: 'abcdef' }), { code: 'permission-denied' });

  const limitedDb = env.authenticatedContext(limited, {
    email: 'limited@accounts.invalid',
  }).firestore();
  const remainingOwn = own[1];
  await db.doc('exam_attempts/owned-attempt').set({ userId: remainingOwn.id, examId: 'existing' });
  await db.doc('exam_attempts/other-attempt').set({ userId: other.id, examId: 'existing' });
  const ownUsername = (await db.collection('usernames').where('uid', '==', remainingOwn.id).get()).docs[0];
  const hardDelete = writeBatch(limitedDb);
  hardDelete.delete(doc(limitedDb, 'exam_attempts', 'owned-attempt'));
  hardDelete.delete(doc(limitedDb, 'usernames', ownUsername.id));
  hardDelete.delete(doc(limitedDb, 'users', remainingOwn.id));
  await assertSucceeds(hardDelete.commit());
  await assertFails((() => {
    const batch = writeBatch(limitedDb);
    batch.delete(doc(limitedDb, 'exam_attempts', 'other-attempt'));
    batch.delete(doc(limitedDb, 'users', other.id));
    return batch.commit();
  })());
  await assertSucceeds(getDocs(query(collection(limitedDb, 'users'), where('role', '==', 'user'), where('createdBy', '==', limited))));
  await assertSucceeds(getDocs(collection(limitedDb, 'users')));
  await assertSucceeds(getDoc(doc(limitedDb, 'users', other.id)));
  await assertFails(setDoc(doc(limitedDb, 'exams', 'bypass'), { title: 'Denied' }));
  await assertFails(updateDoc(doc(limitedDb, 'users', limited), { role: 'super_admin' }));
  await assertFails(setDoc(doc(limitedDb, 'users', 'fake'), { role: 'user', createdBy: limited }));
  await assertFails(getDocs(collection(limitedDb, 'admin_requests')));
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'system', 'app_status')));
  await assertFails(setDoc(doc(limitedDb, 'system', 'app_status'), { maintenance: true, updatedBy: limited }));
  await db.doc('exams/existing').set({ title: 'Existing' });
  await assertFails(updateDoc(doc(limitedDb, 'exams', 'existing'), { title: 'Updated' }));
  const rootDb = env.authenticatedContext(roots[0], {
    email: rootEmails[0],
  }).firestore();
  await assertSucceeds(setDoc(doc(rootDb, 'system', 'app_status'), {
    maintenance: true, updatedAt: new Date(), updatedBy: roots[0],
  }));
  await assertSucceeds(getDocs(collection(rootDb, 'admin_requests')));
  await assertSucceeds(setDoc(doc(rootDb, 'exams', 'allowed'), { title: 'Allowed' }));
  await assertFails(updateDoc(doc(rootDb, 'users', limited), { role: 'super_admin' }));
  await assertFails(updateDoc(doc(rootDb, 'system', 'access'), { rootUids: [roots[0], limited] }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users', roots[0])));
});

test('reverse proposer and rejection leave Auth disabled', async () => {
  const { requestId } = await handlers.proposeAdmin(roots[1], { unit: 'Đơn vị A', account: row('rejected01'), operationId: operationId() });
  await assert.rejects(handlers.decideAdmin(roots[1], { requestId, approve: false }), { code: 'permission-denied' });
  await handlers.decideAdmin(roots[0], { requestId, approve: false });
  const request = (await db.doc(`admin_requests/${requestId}`).get()).data();
  assert.equal((await auth.getUser(request.targetUid)).disabled, true);
  await assert.rejects(handlers.decideAdmin(roots[0], { requestId, approve: true }));
});

test('failed Auth provisioning activates no rows and same operation can resume', async () => {
  const badAuth = { createUser: async (input) => {
    if (input.displayName === 'Fail me') throw new Error('Simulated temporary Auth outage');
    return auth.createUser(input);
  }, getUser: (id) => auth.getUser(id), updateUser: (id, data) => auth.updateUser(id, data) };
  const failing = accountHandlers(db, badAuth);
  const payload = { rows: [row('recover01'), { ...row('recover02'), name: 'Fail me' }], operationId: operationId() };
  await assert.rejects(failing.importUsers(roots[0], payload));
  const partial = (await db.collection('users').where('username', '==', 'recover01').get()).docs[0];
  assert.equal(partial.data().status, 'provisioning');
  await assertFails(getDoc(doc(env.authenticatedContext(partial.id).firestore(), 'users', partial.id)));
  await handlers.importUsers(roots[0], payload);
  assert.equal((await partial.ref.get()).data().status, 'active');
  await assertSucceeds(getDoc(doc(env.authenticatedContext(partial.id).firestore(), 'users', partial.id)));
});

test('legacy User without a creator cannot be deleted by limited admin', async () => {
  const limited = (await db.collection('users').where('username', '==', 'limited01').get()).docs[0].id;
  await db.doc('users/legacy').set({ role: 'user', status: 'active', createdBy: null });
  await assert.rejects(handlers.deleteUser(limited, { userId: 'legacy' }), { code: 'permission-denied' });
  const results = await Promise.allSettled([0, 1].map(() => handlers.importUsers(roots[0], {
    rows: [row('race01')], operationId: operationId(),
  })));
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal((await db.collection('users').where('username', '==', 'race01').get()).size, 1);
});

test('student attempts enforce ownership, deadline and no self deletion', async () => {
  const uid = 'student_attempt_rules';
  await db.doc(`users/${uid}`).set({ role: 'user', status: 'active', username: uid });
  await db.doc('exams/open-exam').set({
    title: 'Open', isOpen: true, durationMinutes: 30,
    closesAt: new Date(Date.now() + 60 * 60 * 1000),
  });
  await db.doc('exams/closed-exam').set({
    title: 'Closed', isOpen: false, durationMinutes: 30,
  });
  await db.doc('exams/legacy-open').set({ title: 'Legacy', isOpen: true });
  const studentDb = env.authenticatedContext(uid).firestore();
  const attempt = doc(studentDb, 'exam_attempts', 'student-open');
  await assertSucceeds(setDoc(attempt, {
    userId: uid,
    examId: 'open-exam',
    startedAt: serverTimestamp(),
    endsAt: new Date(Date.now() + 20 * 60 * 1000),
    status: 'in_progress',
    attemptCount: 0,
    selectedAnswers: {},
    currentQuestionIndex: 0,
  }));
  await assertFails(updateDoc(attempt, {
    status: 'completed', attemptCount: 1, diemSo: 99, bestScore: 99,
    correctAnswers: 10, totalQuestions: 10,
  }));
  await assertSucceeds(updateDoc(attempt, {
    status: 'completed',
    attemptCount: 1,
    diemSo: 8,
    bestScore: 8,
    bestCorrectAnswers: 4,
    correctAnswers: 4,
    totalQuestions: 5,
    examTitle: 'Open',
    lastAttemptAt: serverTimestamp(),
    bestCompletedAt: serverTimestamp(),
    completedAt: serverTimestamp(),
    bestAnswers: [],
    answers: [],
  }));
  await assertFails(deleteDoc(attempt));
  await assertFails(setDoc(doc(studentDb, 'exam_attempts', 'student-closed'), {
    userId: uid,
    examId: 'closed-exam',
    startedAt: serverTimestamp(),
    endsAt: new Date(Date.now() + 20 * 60 * 1000),
    status: 'in_progress',
    attemptCount: 0,
    selectedAnswers: {},
    currentQuestionIndex: 0,
  }));
  await assertSucceeds(setDoc(doc(studentDb, 'exam_attempts', 'student-legacy'), {
    userId: uid,
    examId: 'legacy-open',
    startedAt: serverTimestamp(),
    endsAt: new Date(Date.now() + 30 * 60 * 1000),
    status: 'in_progress',
    attemptCount: 0,
    selectedAnswers: {},
    currentQuestionIndex: 0,
  }));
});

test('learning access respects class, publication, ownership and schedule', async () => {
  await db.doc('users/learner_a').set({ role: 'user', status: 'active', classId: 'A', name: 'A' });
  await db.doc('users/learner_b').set({ role: 'user', status: 'active', classId: 'B', name: 'B' });
  const a = env.authenticatedContext('learner_a').firestore();
  const b = env.authenticatedContext('learner_b').firestore();
  await db.doc('courses/class_a').set({ title: 'A', published: true, audience: 'class:A' });
  await db.doc('courses/draft_a').set({ title: 'Draft', published: false, audience: 'class:A' });
  await db.doc('courses/class_a/lessons/one').set({ title: 'One', order: 1, type: 'text' });
  await assertSucceeds(getDoc(doc(a, 'courses/class_a')));
  await assertFails(getDoc(doc(b, 'courses/class_a')));
  await assertFails(getDoc(doc(a, 'courses/draft_a')));
  await assertSucceeds(getDocs(query(collection(a, 'courses'), where('published', '==', true), where('audience', 'in', ['all', 'class:A']))));
  await assertFails(getDocs(collection(a, 'courses')));
  await assertFails(getDoc(doc(b, 'courses/class_a/lessons/one')));
  const progress = { courseId: 'class_a', lessonId: 'one', completed: true, favorite: true, updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(a, 'users/learner_a/learning/class_a_one'), progress));
  await assertFails(setDoc(doc(a, 'users/learner_b/learning/class_a_one'), progress));
  await assertFails(setDoc(doc(b, 'users/learner_b/learning/class_a_one'), progress));
  await assertFails(setDoc(doc(a, 'users/learner_a/learning/missing'), { ...progress, lessonId: 'missing' }));
  await assertSucceeds(updateDoc(doc(a, 'users/learner_a'), { name: 'Updated', unit: 'Unit' }));
  await assertFails(updateDoc(doc(a, 'users/learner_a'), { classId: 'B' }));
  await assertFails(updateDoc(doc(a, 'users/learner_a'), { role: 'admin' }));
  await db.doc('learning_notifications/due').set({ audience: 'class:A', sendAt: new Date(Date.now() - 60000), title: 'Due', body: 'Text' });
  await db.doc('learning_notifications/later').set({ audience: 'class:A', sendAt: new Date(Date.now() + 600000), title: 'Later', body: 'Text' });
  await assertSucceeds(getDoc(doc(a, 'learning_notifications/due')));
  await assertFails(getDoc(doc(b, 'learning_notifications/due')));
  await assertFails(getDoc(doc(a, 'learning_notifications/later')));
  await assertSucceeds(getDocs(query(collection(a, 'learning_notifications'), where('audience', 'in', ['all', 'class:A', 'user:learner_a']), where('sendAt', '<=', new Date(Date.now() - 1000)))));
  await assertFails(setDoc(doc(a, 'learning_audit/spoof'), { actorId: roots[0], path: 'courses/class_a', action: 'save', at: serverTimestamp() }));
});

test('exam run history is atomic, immutable and private', async () => {
  await db.doc('users/run_student').set({ role: 'user', status: 'active', name: 'Run' });
  await db.doc('exams/run_exam').set({ isOpen: true, durationMinutes: 30 });
  await db.doc('exam_attempts/run_attempt').set({ userId: 'run_student', examId: 'run_exam', status: 'in_progress', attemptCount: 0, endsAt: new Date(Date.now() + 60000) });
  const client = env.authenticatedContext('run_student').firestore();
  const run = { userId: 'run_student', examId: 'run_exam', examTitle: 'Run', score: 7, correctAnswers: 7, totalQuestions: 10, answers: [], runNumber: 1, completedAt: serverTimestamp() };
  await assertFails(setDoc(doc(client, 'exam_attempts/run_attempt/runs/1'), run));
  const batch = writeBatch(client);
  batch.update(doc(client, 'exam_attempts/run_attempt'), { status: 'completed', attemptCount: 1, bestScore: 7, diemSo: 7, correctAnswers: 7, totalQuestions: 10 });
  batch.set(doc(client, 'exam_attempts/run_attempt/runs/1'), run);
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(client, 'exam_attempts/run_attempt/runs/1')));
  await assertFails(updateDoc(doc(client, 'exam_attempts/run_attempt/runs/1'), { score: 10 }));
  await assertFails(getDoc(doc(env.authenticatedContext('learner_b').firestore(), 'exam_attempts/run_attempt/runs/1')));
});

test('attempt progress cannot extend deadlines or replace best score', async () => {
  await db.doc('users/audit_student').set({ role: 'user', status: 'active', name: 'Audit' });
  await db.doc('exams/audit_exam').set({ isOpen: true, durationMinutes: 5, maxAttempts: 3 });
  const original = { userId:'audit_student', examId:'audit_exam', status:'in_progress', attemptCount:1, bestScore:7, diemSo:7,
    startedAt: new Date(Date.now()-10000), endsAt:new Date(Date.now()+60000) };
  await db.doc('exam_attempts/audit_attempt').set(original);
  const client = env.authenticatedContext('audit_student').firestore();
  const ref = doc(client, 'exam_attempts/audit_attempt');
  await assertSucceeds(updateDoc(ref, { selectedAnswers:{'0':1}, lastSavedAt:serverTimestamp() }));
  await assertFails(updateDoc(ref, { endsAt:new Date(Date.now()+3600000) }));
  await assertFails(updateDoc(ref, { bestScore:10 }));
  await db.doc('exam_attempts/audit_attempt').update({status:'completed'});
  await assertFails(updateDoc(ref, {status:'in_progress', bestScore:10, startedAt:serverTimestamp(), endsAt:new Date(Date.now()+240000)}));
  await assertSucceeds(updateDoc(ref, {status:'in_progress', selectedAnswers:{}, currentQuestionIndex:0, startedAt:serverTimestamp(), endsAt:new Date(Date.now()+240000)}));
});

test('backend account deletion removes learning and run subcollections', async () => {
  await handlers.importUsers(roots[0], {rows:[row('audit_cleanup')], operationId:operationId()});
  const user = (await db.collection('users').where('username','==','audit_cleanup').get()).docs[0];
  await user.ref.collection('learning').doc('c_l').set({completed:true});
  await db.doc('exam_attempts/cleanup').set({userId:user.id, examId:'e'});
  await db.doc('exam_attempts/cleanup/runs/1').set({score:8});
  await handlers.deleteUser(roots[0], {userId:user.id});
  assert.equal((await user.ref.collection('learning').get()).empty, true);
  assert.equal((await db.collection('exam_attempts/cleanup/runs').get()).empty, true);
});
