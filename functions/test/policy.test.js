import test from 'node:test';
import assert from 'node:assert/strict';
import { loginEmail, requireAdmin, requireDecision, requireDelete, requireRoot, requireUpdate, validateRows } from '../src/policy.js';
const config = { rootUids: ['root1', 'root2'] };
const root = (id) => ({ id, role: 'super_admin', status: 'active' });
const admin = { id: 'limited', role: 'admin', status: 'active', createdBy: 'root1', approvedBy: 'root2' };
test('only the configured two roots have full access', () => {
  requireRoot(root('root1'), config); requireRoot(root('root2'), config);
  assert.throws(() => requireRoot(root('third'), config));
  assert.throws(() => requireRoot(admin, config));
});
test('unapproved and self-approved admins are rejected', () => {
  requireAdmin(admin, config);
  for (const changes of [{ approvedBy: null }, { approvedBy: 'root1' }, { status: 'pending' }, { status: 'deleted' }]) {
    assert.throws(() => requireAdmin({ ...admin, ...changes }, config));
  }
});
test('only the other root can decide in either direction', () => {
  requireDecision(root('root2'), config, { createdBy: 'root1' });
  requireDecision(root('root1'), config, { createdBy: 'root2' });
  assert.throws(() => requireDecision(root('root1'), config, { createdBy: 'root1' }));
  assert.throws(() => requireDecision(admin, config, { createdBy: 'root1' }));
});
test('limited admin can delete only Users they created', () => {
  requireDelete(admin, config, { id: 'student', role: 'user', createdBy: 'limited' });
  for (const target of [
    { id: 'student2', role: 'user', createdBy: 'other' },
    { id: 'legacy', role: 'user' },
    { id: 'otherAdmin', role: 'admin', createdBy: 'limited' },
    { id: 'root1', role: 'super_admin' },
  ]) {
    assert.throws(() => requireDelete(admin, config, target));
  }
  assert.throws(() => requireDelete(root('root1'), config, { id: 'root2', role: 'super_admin' }));
});
test('limited admin can update only Users they created', () => {
  requireUpdate(admin, config, { id: 'student', role: 'user', createdBy: 'limited' });
  assert.throws(() => requireUpdate(admin, config,
    { id: 'student2', role: 'user', createdBy: 'other' }));
  assert.throws(() => requireUpdate(admin, config,
    { id: 'otherAdmin', role: 'admin', createdBy: 'limited' }));
  requireUpdate(root('root1'), config,
    { id: 'student2', role: 'user', createdBy: 'other' });
  assert.throws(() => requireUpdate(root('root1'), config,
    { id: 'root1', role: 'super_admin' }));
});
test('payload cannot inject a role or creator; duplicate names ignore case', () => {
  const row = { name: 'An', username: 'user01', password: '123456' };
  assert.equal(validateRows([row]).length, 1);
  assert.throws(() => validateRows([{ ...row, role: 'super_admin' }]));
  assert.throws(() => validateRows([{ ...row, createdBy: 'root1' }]));
  assert.throws(() => validateRows([row, { ...row, username: 'USER01' }]));
  assert.throws(() => validateRows(Array(201).fill(row)));
});
test('username email mapping is deterministic and case insensitive', () => {
  assert.equal(loginEmail(' User01 '), loginEmail('user01'));
  assert.match(loginEmail('admintong1'), /^[a-f0-9]{64}@accounts\.invalid$/);
});
