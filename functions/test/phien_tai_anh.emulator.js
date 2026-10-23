import { before, after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
import { ref, uploadBytes, getMetadata } from 'firebase/storage';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  throw new Error('Local Firestore and Storage emulators required.');
}

let env;
const authTime = Math.floor(Date.now() / 1000);
const imageBytes = new Uint8Array([137, 80, 78, 71]);
const activeSession = () => ({ status: 'active', authTime, lastSeenAt: new Date() });
const storageFor = uid => env.authenticatedContext(uid, { auth_time: authTime }).storage('gs://demo-e09.appspot.com');
const upload = (uid, path) => uploadBytes(ref(storageFor(uid), path), imageBytes, { contentType: 'image/png' });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-e09',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8') },
  });
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'system/access'), { rootUids: ['upload-root', 'legacy-upload-root'] });
    await setDoc(doc(db, 'users/upload-root'), { role: 'super_admin', status: 'active', accountSession: activeSession() });
    await setDoc(doc(db, 'users/legacy-upload-root'), { role: 'super_admin', status: 'active' });
    await setDoc(doc(db, 'users/upload-user'), { role: 'user', status: 'active', name: 'Học viên', accountSession: activeSession() });
    await setDoc(doc(db, 'users/unlisted-root'), { role: 'super_admin', status: 'active', accountSession: activeSession() });
  });
});
after(async () => { await env?.cleanup(); });

async function setLease(uid, accountSession) {
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), `users/${uid}`), { accountSession });
  });
}

test('active root uploads with two Firestore documents; session lease and root UID membership are required', async () => {
  await assertSucceeds(upload('upload-root', 'courses/session-active.png'));
  await assertFails(upload('legacy-upload-root', 'courses/session-legacy.png'));
  await assertFails(upload('unlisted-root', 'courses/session-unlisted.png'));
  await assertSucceeds(upload('upload-user', 'avatars/upload-user/session-active.png'));
});

test('released, expired, replaced and malformed sessions cannot upload or read through the SDK', async () => {
  const invalid = [
    { ...activeSession(), status: 'released' },
    { ...activeSession(), lastSeenAt: new Date(Date.now() - 5 * 60000) },
    { ...activeSession(), authTime: authTime - 10 },
    { status: 'active', authTime },
  ];
  for (const [index, session] of invalid.entries()) {
    await setLease('upload-root', session);
    await setLease('upload-user', session);
    await assertFails(upload('upload-root', `courses/session-denied-${index}.png`));
    await assertFails(getMetadata(ref(storageFor('upload-root'), 'courses/session-active.png')));
    await assertFails(upload('upload-user', `avatars/upload-user/session-denied-${index}.png`));
  }
  await setLease('upload-root', activeSession());
  await assertSucceeds(upload('upload-root', 'courses/session-renewed.png'));
});

test('clients cannot forge the mirrored session lease in their profile', async () => {
  const db = env.authenticatedContext('upload-user', { auth_time: authTime }).firestore();
  await assertFails(updateDoc(doc(db, 'users/upload-user'), { accountSession: activeSession() }));
});
