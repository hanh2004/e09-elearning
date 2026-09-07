import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { loginEmail, usernameKey, validateRows } from '../src/policy.js';

const args = process.argv.slice(2);
const projectId = args[args.indexOf('--project') + 1];
if (!args.includes('--project') || !projectId) throw new Error('Specify --project <id>. Default is dry-run.');
const demo = projectId.startsWith('demo-');
if (demo && (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST)) throw new Error('Both emulator hosts required.');
if (!demo && (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) throw new Error('Mixed emulator/live environment.');
initializeApp({ projectId, ...(demo ? {} : { credential: applicationDefault() }) });
const db = getFirestore(); const auth = getAuth();
const docs = (await db.collection('users').get()).docs;
const seen = new Set(); const plan = [];
for (const doc of docs) {
  const data = doc.data();
  const key = usernameKey(String(data.username ?? ''));
  if (seen.has(key)) throw new Error(`Duplicate normalized username at document ${doc.id}; fix before migration.`);
  seen.add(key);
  if (data.authVersion === 2 || !Object.hasOwn(data, 'password')) continue;
  if (!/^[A-Za-z0-9_=-]{1,128}$/.test(doc.id)) throw new Error(`UID requires manual mapping: ${doc.id}`);
  validateRows([{ name: data.name, username: data.username, password: String(data.password).trim() }]);
  const role = String(data.role).trim().toLowerCase();
  if (!['user', 'học viên', 'admin', 'giáo viên'].includes(role)) throw new Error(`Unsupported legacy role at ${doc.id}`);
  plan.push({ doc, data, key, student: role === 'user' || role === 'học viên' });
}
console.log(`Project ${projectId}: ${plan.length} legacy profiles; IDs and history preserved. Old admins/teachers will be disabled, never auto-promoted.`);
if (!args.includes('--apply')) { console.log('Dry run only. No writes.'); process.exit(0); }
if (!demo && process.env.ACCOUNT_MIGRATION_APPROVED !== projectId) throw new Error('Backup and explicit cutover approval required.');
for (const { doc, data, key, student } of plan) {
  const reservation = await db.doc(`usernames/${key}`).get();
  if (reservation.exists && reservation.data().uid !== doc.id) throw new Error(`Username collision at ${doc.id}`);
  try {
    await auth.createUser({ uid: doc.id, email: loginEmail(data.username), password: String(data.password).trim(), disabled: true });
  } catch (error) {
    if (error.code !== 'auth/uid-already-exists') throw error;
    if ((await auth.getUser(doc.id)).email !== loginEmail(data.username)) throw new Error(`Auth collision at ${doc.id}`);
  }
  // Enable Auth first; new rules still deny access until the profile is active.
  await auth.updateUser(doc.id, { disabled: !student });
  await db.runTransaction(async (tx) => {
    const latest = (await tx.get(doc.ref)).data();
    const currentReservation = await tx.get(db.doc(`usernames/${key}`));
    if (currentReservation.exists && currentReservation.data().uid !== doc.id) throw new Error('Concurrent username reservation.');
    if (latest.authVersion === 2) return;
    if (latest.username !== data.username || latest.password !== data.password) throw new Error('Legacy data changed during migration; stop writes and retry.');
    tx.set(db.doc(`usernames/${key}`), { uid: doc.id, username: data.username });
    tx.update(doc.ref, { password: FieldValue.delete(), role: student ? 'user' : 'legacy_admin',
      status: student ? 'active' : 'legacy_disabled', authVersion: 2,
      createdBy: null, migratedAt: FieldValue.serverTimestamp() });
  });
}
console.log('Migration complete. No passwords logged. Legacy admin access requires a separately approved new account.');
