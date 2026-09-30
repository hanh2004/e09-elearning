import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const uid = 'admin_session_test';
const email = 'admin-session-test@accounts.invalid';
const password = 'session-test-password';
const tokenA = 'a'.repeat(64);
const tokenB = 'b'.repeat(64);
const projectId = process.env.GCLOUD_PROJECT || 'demo-e09';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Local Firestore and Auth emulators required.');
}

let app;
let auth;
let db;
let idToken;

before(async () => {
  app = initializeApp({ projectId }, 'admin-web-session-test');
  auth = getAuth(app);
  db = getFirestore(app);

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  await auth.createUser({ uid, email, password });
  await db.doc('system/access').set({ rootUids: [uid] });
  await db.doc(`users/${uid}`).set({ role: 'super_admin', status: 'active' });

  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  assert.equal(response.status, 200);
  idToken = (await response.json()).idToken;
});

after(async () => {
  if (db) {
    await db.doc(`admin_web_sessions/${uid}`).delete();
    await db.doc(`users/${uid}`).delete();
    await db.doc('system/access').delete();
  }
  if (auth) {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
  }
  if (app) await deleteApp(app);
});

async function call(name, data) {
  const response = await fetch(
    `http://${functionsHost}/demo-e09/asia-southeast1/${name}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data }),
    },
  );
  return { ok: response.ok, body: await response.json() };
}

test('account web sessions support Admin and learner roles', async () => {
  const firstClaim = await call('adminSessionClaim', {
    sessionToken: tokenA,
    takeOver: false,
  });
  assert.equal(firstClaim.ok, true);
  assert.deepEqual(firstClaim.body.result, { claimed: true, occupied: false });

  const occupied = await call('adminSessionClaim', {
    sessionToken: tokenB,
    takeOver: false,
  });
  assert.equal(occupied.ok, true);
  assert.deepEqual(occupied.body.result, { claimed: false, occupied: true });

  const firstHeartbeat = await call('adminSessionHeartbeat', {
    sessionToken: tokenA,
  });
  assert.deepEqual(firstHeartbeat.body.result, { active: true });

  const takeover = await call('adminSessionClaim', {
    sessionToken: tokenB,
    takeOver: true,
  });
  assert.equal(takeover.ok, true);
  assert.deepEqual(takeover.body.result, { claimed: true, occupied: false });

  const staleHeartbeat = await call('adminSessionHeartbeat', {
    sessionToken: tokenA,
  });
  assert.deepEqual(staleHeartbeat.body.result, { active: false });

  const staleApiCall = await call('accountGetSubUnits', {
    _adminWebSession: tokenA,
  });
  assert.equal(staleApiCall.ok, false);
  assert.equal(staleApiCall.body.error.status, 'UNAUTHENTICATED');

  const activeApiCall = await call('accountGetSubUnits', {
    _adminWebSession: tokenB,
  });
  assert.equal(activeApiCall.ok, true, JSON.stringify(activeApiCall.body));
  assert.deepEqual(activeApiCall.body.result, { managerId: '', subUnits: [] });

  const staleRelease = await call('adminSessionRelease', {
    sessionToken: tokenA,
  });
  assert.deepEqual(staleRelease.body.result, { released: false });

  const currentRelease = await call('adminSessionRelease', {
    sessionToken: tokenB,
  });
  assert.deepEqual(currentRelease.body.result, { released: true });

  const releasedHeartbeat = await call('adminSessionHeartbeat', {
    sessionToken: tokenB,
  });
  assert.deepEqual(releasedHeartbeat.body.result, { active: false });

  await db.doc(`users/${uid}`).set({ role: 'user', status: 'active' });
  const learnerClaim = await call('adminSessionClaim', {
    sessionToken: 'c'.repeat(64),
    takeOver: false,
  });
  assert.equal(learnerClaim.ok, true, JSON.stringify(learnerClaim.body));
  assert.deepEqual(learnerClaim.body.result, { claimed: true, occupied: false });
});
