import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { loginEmail, usernameKey } from '../src/policy.js';

const args = process.argv.slice(2);
const projectId = args[args.indexOf('--project') + 1];
if (!args.includes('--project') || !projectId) throw new Error('Specify --project <id>. Default is dry-run.');
const emulator = projectId.startsWith('demo-');
if (emulator && (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  throw new Error('Demo bootstrap requires both Firestore and Auth emulator hosts.');
}
if (!emulator && (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  throw new Error('Do not mix live projects and emulator hosts.');
}
initializeApp({ projectId, ...(emulator ? {} : { credential: applicationDefault() }) });
const db = getFirestore(); const auth = getAuth();
const names = ['admintong1', 'admintong2'];
const ids = names.map((name) => `root_${name}`);
function authorizeApply() {
  if (!emulator && process.env.ACCOUNT_MIGRATION_APPROVED !== projectId) {
    throw new Error('Live writes require ACCOUNT_MIGRATION_APPROVED=<project-id> after backup and cutover approval.');
  }
}
async function finishBootstrap() {
  for (const uid of ids) await auth.updateUser(uid, { disabled: false });
  await db.doc('system/access').update({ bootstrapComplete: true });
}
const config = await db.doc('system/access').get();
if (config.exists) {
  if (JSON.stringify(config.data().rootUids) !== JSON.stringify(ids)) throw new Error('Existing root configuration differs; refusing overwrite.');
  if (config.data().bootstrapComplete !== true && args.includes('--apply')) {
    authorizeApply();
    await finishBootstrap();
    console.log('Interrupted bootstrap completed. No passwords changed.');
    process.exit(0);
  }
  console.log('Root configuration already exists. No passwords or profiles changed.');
  process.exit(0);
}
const existing = (await db.collection('users').get()).docs;
for (const name of names) {
  if (existing.some((d) => String(d.data().username).toLowerCase() === name && d.id !== `root_${name}`)) {
    throw new Error(`Existing legacy username ${name}: resolve UID mapping before bootstrap; no overwrite performed.`);
  }
}
console.log(`Project ${projectId}: prepare exactly ${names.join(', ')}. Passwords are never printed.`);
if (!args.includes('--apply')) { console.log('Dry run only. Add --apply after reviewing project and backup.'); process.exit(0); }
authorizeApply();
const passwords = names.map((_, i) => process.env[`ROOT_PASSWORD_${i + 1}`] ?? (emulator ? '123456' : ''));
if (passwords.some((p) => p.length < 6) || (!emulator && passwords.some((p) => p === '123456'))) {
  throw new Error('Set ROOT_PASSWORD_1 and ROOT_PASSWORD_2 before live bootstrap. Temporary 123456 is emulator-only.');
}
for (let i = 0; i < names.length; i++) {
  try {
    await auth.createUser({ uid: ids[i], email: loginEmail(names[i]), password: passwords[i], disabled: true });
  } catch (error) {
    if (error.code !== 'auth/uid-already-exists') throw error;
    if ((await auth.getUser(ids[i])).email !== loginEmail(names[i])) throw new Error('Auth UID collision.');
  }
}
await db.runTransaction(async (tx) => {
  if ((await tx.get(db.doc('system/access'))).exists) throw new Error('Bootstrap already committed by another process.');
  for (const name of names) {
    if ((await tx.get(db.doc(`usernames/${usernameKey(name)}`))).exists) throw new Error('Reserved username collision.');
  }
  names.forEach((name, i) => {
    tx.create(db.doc(`users/${ids[i]}`), { name, username: name, role: 'super_admin',
      status: 'active', authVersion: 2, createdBy: null, createdAt: FieldValue.serverTimestamp() });
    tx.create(db.doc(`usernames/${usernameKey(name)}`), { uid: ids[i], username: name });
  });
  tx.create(db.doc('system/access'), { rootUids: ids, schemaVersion: 2, bootstrapComplete: false });
});
await finishBootstrap();
console.log('Two root profiles created. Change temporary passwords separately before sharing access.');
