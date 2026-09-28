import test from 'node:test';
import assert from 'node:assert/strict';
import { rootPasswordRecoveryHandlers } from '../src/khoi_phuc_mat_khau_quan_tri_tong.js';
import { usernameKey } from '../src/quy_tac.js';

function fixture() {
  const data = new Map([
    ['system/access', { rootUids: ['root-a', 'root-b'] }],
    ['users/root-a', { role: 'super_admin', status: 'active', username: 'ROOTA', name: 'Admin A' }],
    ['users/root-b', { role: 'super_admin', status: 'active', username: 'ROOTB', name: 'Admin B' }],
    [`usernames/${usernameKey('ROOTA')}`, { uid: 'root-a' }],
    [`usernames/${usernameKey('ROOTB')}`, { uid: 'root-b' }],
  ]);
  const db = {
    doc(path) {
      return {
        path,
        async get() {
          const value = data.get(path);
          return { exists: value !== undefined, data: () => value };
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const tx = {
        async get(ref) {
          const value = data.get(ref.path);
          return { exists: value !== undefined, data: () => value };
        },
        set(ref, value) { writes.push(['set', ref.path, value]); },
        update(ref, value) { writes.push(['update', ref.path, value]); },
      };
      const result = await callback(tx);
      for (const [kind, path, value] of writes) {
        data.set(path, kind === 'update' ? { ...data.get(path), ...value } : value);
      }
      return result;
    },
  };
  const auth = {
    passwords: new Map(),
    revoked: [],
    async updateUser(uid, updates) { this.passwords.set(uid, updates.password); },
    async revokeRefreshTokens(uid) { this.revoked.push(uid); },
  };
  return { data, auth, handlers: rootPasswordRecoveryHandlers(db, auth) };
}

const proof = 'A'.repeat(43);

test('admin tổng còn lại duyệt một lần rồi chủ tài khoản tự đặt mật khẩu', async () => {
  const f = fixture();
  await f.handlers.requestRootPasswordReset(null, { username: 'roota', proof });
  const request = f.data.get('password_reset_requests/root-a');
  assert.equal(request.status, 'pending');
  assert.equal(request.type, 'root_recovery');
  assert.notEqual(request.proofHash, proof);
  assert.equal(Object.hasOwn(request, 'password'), false);

  await assert.rejects(
    f.handlers.approveRootPasswordReset('root-a', { requestId: 'root-a' }),
    { code: 'permission-denied' },
  );
  await f.handlers.approveRootPasswordReset('root-b', { requestId: 'root-a' });
  assert.equal(
    (await f.handlers.rootPasswordResetStatus(null, { username: 'roota', proof })).status,
    'approved',
  );

  await f.handlers.finishRootPasswordReset(null, {
    username: 'roota', proof, password: 'new-root-password-123',
  });
  assert.equal(f.auth.passwords.get('root-a'), 'new-root-password-123');
  assert.deepEqual(f.auth.revoked, ['root-a']);
  assert.equal(f.data.get('password_reset_requests/root-a').status, 'completed');
});

test('không cho dùng mã sai, tài khoản không phải root hoặc chính mình duyệt', async () => {
  const f = fixture();
  await f.handlers.requestRootPasswordReset(null, { username: 'roota', proof });
  await assert.rejects(
    f.handlers.finishRootPasswordReset(null, {
      username: 'roota', proof: 'B'.repeat(43), password: 'new-root-password-123',
    }),
    { code: 'failed-precondition' },
  );
  await f.handlers.requestRootPasswordReset(null, {
    username: 'unknown', proof: 'C'.repeat(43),
  });
  assert.equal(f.data.has('password_reset_requests/unknown'), false);
});
