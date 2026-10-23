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

async function assertStorageLease(status) {
  const [account, session] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    db.doc(`admin_web_sessions/${uid}`).get(),
  ]);
  const lease = account.data().accountSession;
  assert.deepEqual(Object.keys(lease).sort(), ['authTime', 'lastSeenAt', 'status']);
  assert.equal(lease.status, status);
  assert.equal(lease.authTime, session.data().authTime);
  assert.ok(lease.lastSeenAt.toMillis() > Date.now() - 60_000);
}

test('account web sessions support Admin and learner roles', async () => {
  const firstClaim = await call('adminSessionClaim', {
    sessionToken: tokenA,
    takeOver: false,
  });
  assert.equal(firstClaim.ok, true);
  assert.deepEqual(firstClaim.body.result, { claimed: true, occupied: false });
  await assertStorageLease('active');

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
  await assertStorageLease('active');

  const takeover = await call('adminSessionClaim', {
    sessionToken: tokenB,
    takeOver: true,
  });
  assert.equal(takeover.ok, true);
  assert.deepEqual(takeover.body.result, { claimed: true, occupied: false });
  const takeoverLease = (await db.doc(`users/${uid}`).get()).data().accountSession;
  await assertStorageLease('active');

  const staleHeartbeat = await call('adminSessionHeartbeat', {
    sessionToken: tokenA,
  });
  assert.deepEqual(staleHeartbeat.body.result, { active: false });
  assert.deepEqual((await db.doc(`users/${uid}`).get()).data().accountSession, takeoverLease);

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
  assert.deepEqual((await db.doc(`users/${uid}`).get()).data().accountSession, takeoverLease);

  const currentRelease = await call('adminSessionRelease', {
    sessionToken: tokenB,
  });
  assert.deepEqual(currentRelease.body.result, { released: true });
  await assertStorageLease('released');

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
  await assertStorageLease('active');
});

test('reauthenticated learner renews the same session before submitting feedback', async () => {
  await db.doc(`users/${uid}`).set({role:'user',status:'active'});
  await db.doc(`admin_web_sessions/${uid}`).delete();
  const claim = await call('adminSessionClaim', {sessionToken:tokenA,takeOver:false});
  assert.deepEqual(claim.body.result, {claimed:true,occupied:false});
  const oldAuthTime = JSON.parse(Buffer.from(idToken.split('.')[1], 'base64url')).auth_time;
  // Auth timestamps have whole-second precision; ensure reauthentication changes it.
  await new Promise(resolve => setTimeout(resolve, 1100));
  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key',
    {
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({email,password,returnSecureToken:true}),
    },
  );
  assert.equal(response.status, 200);
  idToken = (await response.json()).idToken;
  const newAuthTime = JSON.parse(Buffer.from(idToken.split('.')[1], 'base64url')).auth_time;
  assert.ok(newAuthTime > oldAuthTime);
  const feedback = {_adminWebSession:tokenA,category:'idea',message:'A useful application suggestion.'};
  const stale = await call('feedbackSubmit', feedback);
  assert.equal(stale.ok, false);
  assert.equal(stale.body.error.status, 'UNAUTHENTICATED');

  const renewed = await call('adminSessionClaim', {sessionToken:tokenA,takeOver:false});
  assert.deepEqual(renewed.body.result, {claimed:true,occupied:false});
  await assertStorageLease('active');
  const heartbeat = await call('adminSessionHeartbeat', {sessionToken:tokenA});
  assert.deepEqual(heartbeat.body.result, {active:true});
  const submitted = await call('feedbackSubmit', feedback);
  assert.equal(submitted.ok, true, JSON.stringify(submitted.body));
  assert.equal(submitted.body.result.submitted, true);
  await db.doc(`feedback/${submitted.body.result.feedbackId}`).delete();
  await db.doc(`feedback_limits/${uid}`).delete();
});
