import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { loginEmail } from '../src/policy.js';

if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulators required.');
const bootstrap = () => execFileSync(process.execPath,
  ['scripts/bootstrap.js', '--project', 'demo-e09', '--apply'], { env: process.env, encoding: 'utf8' });
async function login(username, password = '123456') {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: loginEmail(username), password, returnSecureToken: true }),
  });
  return { ok: response.ok, body: await response.json() };
}
async function call(method, token, data) {
  const response = await fetch(`http://127.0.0.1:5001/demo-e09/asia-southeast1/${method}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  return { ok: response.ok, body: await response.json() };
}
test('bootstrap is repeat-safe and callable auth enforces both approvers', async () => {
  bootstrap(); bootstrap();
  const root1 = await login('admintong1'); const root2 = await login('admintong2');
  assert.equal(root1.ok, true); assert.equal(root2.ok, true);
  assert.equal((await login('admintong1', 'wrong-password')).ok, false);
  const data = { account: { name: 'Admin Test', username: 'callableadmin', password: '123456' }, operationId: 'c'.repeat(32) };
  assert.equal((await call('accountProposeAdmin', null, data)).ok, false);
  const proposal = await call('accountProposeAdmin', root1.body.idToken, data);
  assert.equal(proposal.ok, true, JSON.stringify(proposal.body));
  assert.equal((await login('callableadmin')).ok, false);
  const decision = { requestId: proposal.body.result.requestId, approve: true };
  assert.equal((await call('accountDecideAdmin', root1.body.idToken, decision)).ok, false);
  assert.equal((await call('accountDecideAdmin', root2.body.idToken, decision)).ok, true);
  const limited = await login('callableadmin'); assert.equal(limited.ok, true);
  const imported = await call('accountImportUsers', limited.body.idToken, {
    rows: [{ name: 'User Test', username: 'callableuser', password: '123456' }], operationId: 'd'.repeat(32),
  });
  assert.equal(imported.ok, true, JSON.stringify(imported.body));
  assert.equal((await login('callableuser')).ok, true);
});
