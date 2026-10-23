// One-time cleanup of the retired learner-code fields and reservation collection.
// Default is a read-only dry run. --apply writes to the explicitly named project.
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {FieldPath, FieldValue, getFirestore} from 'firebase-admin/firestore';
import {usernameKey} from '../src/quy_tac.js';

const args = process.argv.slice(2);
const projectIndex = args.indexOf('--project');
const projectId = projectIndex >= 0 ? args[projectIndex + 1] : '';
if (!projectId || projectId.startsWith('--')) {
  throw new Error('Usage: node scripts/migrate_user_identifiers.js --project <firebase-project-id> [--apply]');
}

const demo = projectId.startsWith('demo-');
if (demo && !process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('For demo projects, set FIRESTORE_EMULATOR_HOST to the intended emulator.');
}
if (!demo && process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Refusing a live-project migration while FIRESTORE_EMULATOR_HOST is set.');
}
initializeApp({projectId, ...(demo ? {} : {credential: applicationDefault()})});
const db = getFirestore();

const [profiles, oldCodeIndexes, usernames, operations, oldIndexState] = await Promise.all([
  db.collection('users').orderBy(FieldPath.documentId()).get(),
  db.collection('user_codes').get(),
  db.collection('usernames').get(),
  db.collection('account_operations').get(),
  db.doc('system/code_indexes').get(),
]);

if (oldIndexState.data()?.status === 'running') {
  throw new Error('The retired account-index backfill is running. Stop it before migrating.');
}
const inFlight = operations.docs.find(doc => doc.data().status === 'provisioning');
if (inFlight) throw new Error(`Account operation ${inFlight.id} is provisioning. Wait until it finishes before migrating.`);
const inFlightProfile = profiles.docs.find(doc => doc.data().status === 'provisioning');
if (inFlightProfile) throw new Error(`Account ${inFlightProfile.id} is provisioning. Wait until it finishes before migrating.`);

const usernameOwners = new Map();
const usernameReservations = new Map(usernames.docs.map(doc => [doc.id, doc]));
for (const profile of profiles.docs) {
  const username = profile.data().username;
  if (typeof username !== 'string' || !username.trim()) continue;
  const value = username.trim();
  const key = usernameKey(value);
  const previous = usernameOwners.get(key);
  if (previous && previous !== profile.id) {
    throw new Error(`Duplicate username after normalization at profiles ${previous} and ${profile.id}. Resolve it first.`);
  }
  usernameOwners.set(key, profile.id);
  const reservation = usernameReservations.get(key);
  if (reservation && reservation.data().uid !== profile.id) {
    throw new Error(`Username reservation for profile ${profile.id} belongs to ${reservation.data().uid}. Resolve it first.`);
  }
}

const learners = profiles.docs.filter(profile => profile.data().role === 'user');
for (const profile of learners) {
  const username = profile.data().username;
  if (typeof username !== 'string' || !/^[A-Za-z0-9_.@-]{3,64}$/.test(username.trim())) {
    throw new Error(`Student profile ${profile.id} has no valid username. Resolve it before migrating.`);
  }
}

const legacyProfiles = profiles.docs.filter(profile =>
  Object.hasOwn(profile.data(), 'userCode') || Object.hasOwn(profile.data(), 'userCodeSuffix'));
const namedProfiles = profiles.docs.filter(profile =>
  typeof profile.data().username === 'string' && profile.data().username.trim());
console.log(`Project: ${projectId}`);
console.log(`Profiles with legacy code fields to remove: ${legacyProfiles.length}`);
console.log(`Username reservations to ensure: ${namedProfiles.length}`);
console.log(`Legacy reservation documents to delete: ${oldCodeIndexes.size}`);
console.log(`Legacy index-state document to delete: ${oldIndexState.exists ? 1 : 0}`);

if (!args.includes('--apply')) {
  console.log('Dry run only. No writes were made. Back up Firestore and pause account changes before using --apply.');
  process.exit(0);
}

// Keep username reservations as the single uniqueness check for all accounts.
// Apply in bounded, repeatable batches during a maintenance window.
const writes = [];
for (const profile of legacyProfiles) {
  writes.push({type: 'update', ref: profile.ref, data: {
    userCode: FieldValue.delete(), userCodeSuffix: FieldValue.delete(),
  }});
}
for (const profile of namedProfiles) {
  const username = profile.data().username.trim();
  writes.push({type: 'set', ref: db.doc(`usernames/${usernameKey(username)}`), data: {
    uid: profile.id, username,
  }});
}
for (const doc of oldCodeIndexes.docs) writes.push({type: 'delete', ref: doc.ref});
if (oldIndexState.exists) writes.push({type: 'delete', ref: oldIndexState.ref});

for (let start = 0; start < writes.length; start += 450) {
  const batch = db.batch();
  for (const write of writes.slice(start, start + 450)) {
    if (write.type === 'update') batch.update(write.ref, write.data);
    else if (write.type === 'set') batch.set(write.ref, write.data);
    else batch.delete(write.ref);
  }
  await batch.commit();
}
console.log(`Migration complete. Removed old code fields from ${legacyProfiles.length} profiles and deleted ${oldCodeIndexes.size} old reservations.`);
