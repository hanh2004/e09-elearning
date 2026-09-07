import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Emulators required.');
test('migration dry-run, stable UID/history, password removal and safe rerun', async () => {
  const app = initializeApp({ projectId: 'demo-e09' }, 'migration-test');
  const db = getFirestore(app); const auth = getAuth(app);
  try {
    await db.doc('users/legacy_student').set({ name: 'Student', username: 'legacy01', password: '123456', role: 'user' });
    await db.doc('users/legacy_admin').set({ name: 'Admin', username: 'legacyadmin', password: '123456', role: 'admin' });
    await db.doc('exam_attempts/history').set({ userId: 'legacy_student', examId: 'exam01', diemSo: 8 });
    const run = (apply) => execFileSync(process.execPath, ['scripts/migrate.js', '--project', 'demo-e09', ...(apply ? ['--apply'] : [])], { env: process.env, encoding: 'utf8' });
    run(false);
    assert.equal((await db.doc('users/legacy_student').get()).data().password, '123456');
    const output = run(true);
    assert.equal(output.includes('123456'), false);
    assert.equal((await db.doc('users/legacy_student').get()).data().password, undefined);
    assert.equal((await db.doc('users/legacy_student').get()).data().createdBy, null);
    assert.equal((await auth.getUser('legacy_student')).disabled, false);
    assert.equal((await auth.getUser('legacy_admin')).disabled, true);
    assert.equal((await db.doc('users/legacy_admin').get()).data().status, 'legacy_disabled');
    assert.equal((await db.doc('exam_attempts/history').get()).data().userId, 'legacy_student');
    assert.equal((await db.doc('exam_attempts/history').get()).data().diemSo, 8);
    assert.match(run(true), /0 legacy profiles/);
  } finally { await deleteApp(app); }
});
