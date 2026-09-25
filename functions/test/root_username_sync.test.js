import assert from 'node:assert/strict';
import test from 'node:test';
import { loginEmail, usernameKey } from '../src/policy.js';
import { createRootUsernameSyncHandler } from '../src/root_username_sync.js';

function fakeFirebase(seed, authUsers) {
  const records = new Map(Object.entries(seed));
  const users = new Map(Object.entries(authUsers).map(([uid, user]) => [uid, {...user}]));
  const ref = (path) => ({path, id: path.split('/').at(-1)});
  const snapshot = (path) => ({
    id: ref(path).id,
    ref: ref(path),
    exists: records.has(path),
    data: () => records.get(path),
  });
  const db = {
    doc: ref,
    collection: (name) => ({
      where: (field, _operator, value) => ({kind: 'query', name, field, value}),
    }),
    runTransaction: (callback) => callback({
      get: async (target) => {
        if (target.kind === 'query') {
          const docs = [...records.entries()]
            .filter(([path, data]) => path.startsWith(`${target.name}/`) && data[target.field] === target.value)
            .map(([path]) => snapshot(path));
          return {docs};
        }
        return snapshot(target.path);
      },
      set: (target, data) => records.set(target.path, data),
      update: (target, data) => records.set(target.path, {...records.get(target.path), ...data}),
      delete: (target) => records.delete(target.path),
    }),
  };
  const auth = {
    getUser: async (uid) => users.get(uid),
    updateUser: async (uid, updates) => users.set(uid, {...users.get(uid), ...updates}),
  };
  return {db, auth, records, users};
}

const updateEvent = (uid, before, after) => ({
  params: {uid},
  data: {before: {data: () => before}, after: {data: () => after}},
});

test('đổi tên root trong hồ sơ đồng bộ index và email giả, giữ UID và mật khẩu', async () => {
  const uid = 'root-one';
  const {db, auth, records, users} = fakeFirebase({
    [`users/${uid}`]: {username: 'rootold', role: 'super_admin'},
    'system/access': {rootUids: [uid, 'root-two']},
    [`usernames/${usernameKey('rootold')}`]: {uid, username: 'rootold'},
  }, {[uid]: {uid, email: loginEmail('rootold'), passwordMarker: 'unchanged'}});
  // Khi Function nhận event, thay đổi hồ sơ đã xảy ra trong Firestore.
  records.set(`users/${uid}`, {username: 'rootnew', role: 'super_admin'});

  await createRootUsernameSyncHandler(db, auth)(updateEvent(uid,
    {username: 'rootold', role: 'super_admin'},
    {username: 'rootnew', role: 'super_admin'}));

  assert.equal(records.get(`users/${uid}`).username, 'rootnew');
  assert.equal(records.has(`usernames/${usernameKey('rootold')}`), false);
  assert.deepEqual(records.get(`usernames/${usernameKey('rootnew')}`),
    {uid, username: 'rootnew'});
  assert.equal(users.get(uid).email, loginEmail('rootnew'));
  assert.equal(users.get(uid).passwordMarker, 'unchanged');
});

test('tên đã có người dùng thì tự khôi phục tên cũ, không đổi Authentication', async () => {
  const uid = 'root-one';
  const {db, auth, records, users} = fakeFirebase({
    [`users/${uid}`]: {username: 'rootold', role: 'super_admin'},
    'system/access': {rootUids: [uid, 'root-two']},
    [`usernames/${usernameKey('rootold')}`]: {uid, username: 'rootold'},
    [`usernames/${usernameKey('taken')}`]: {uid: 'other-user', username: 'taken'},
  }, {[uid]: {uid, email: loginEmail('rootold')}});
  records.set(`users/${uid}`, {username: 'taken', role: 'super_admin'});

  await createRootUsernameSyncHandler(db, auth)(updateEvent(uid,
    {username: 'rootold', role: 'super_admin'},
    {username: 'taken', role: 'super_admin'}));

  assert.equal(records.get(`users/${uid}`).username, 'rootold');
  assert.equal(records.get(`usernames/${usernameKey('rootold')}`).uid, uid);
  assert.equal(records.get(`usernames/${usernameKey('taken')}`).uid, 'other-user');
  assert.equal(users.get(uid).email, loginEmail('rootold'));
});

test('không đồng bộ hồ sơ không thuộc hai UID admin tổng', async () => {
  const uid = 'learner';
  const {db, auth, records} = fakeFirebase({
    [`users/${uid}`]: {username: 'newname', role: 'user'},
    'system/access': {rootUids: ['root-one', 'root-two']},
  }, {});

  await createRootUsernameSyncHandler(db, auth)(updateEvent(uid,
    {username: 'oldname', role: 'user'}, {username: 'newname', role: 'user'}));

  assert.equal(records.get(`users/${uid}`).username, 'newname');
});
