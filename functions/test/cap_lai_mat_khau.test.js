import test from 'node:test';
import assert from 'node:assert/strict';
import { createPasswordResetHandlers } from '../src/cap_lai_mat_khau.js';
import { usernameKey } from '../src/quy_tac.js';

function fixture() {
  const data = new Map([
    [`usernames/${usernameKey('learner')}`, { uid:'learner-id' }],
    ['users/learner-id', { role:'user',status:'active',username:'learner',createdBy:'manager-id' }],
    ['users/manager-id', { role:'admin',status:'active' }],
  ]);
  const db = {
    doc(path) {
      return { path, async get() {
        const value=data.get(path);
        return { exists:value!==undefined, data:()=>value };
      } };
    },
    async runTransaction(callback) {
      const writes=[];
      const result=await callback({
        get:ref=>ref.get(),
        set:(ref,value)=>writes.push([ref.path,value]),
        update:(ref,value)=>writes.push([ref.path,{...data.get(ref.path),...value}]),
      });
      for(const [path,value] of writes) data.set(path,value);
      return result;
    },
  };
  return { data,handlers:createPasswordResetHandlers({
    coSoDuLieu:db,userRef:id=>db.doc(`users/${id}`),stamp:()=>new Date(),
  }) };
}

test('old APK password-reset payload ignores codeSuffix and selects the current manager by username', async()=>{
  const f=fixture();
  assert.deepEqual(await f.handlers.requestPasswordReset(null,{
    username:'LEARNER',codeSuffix:'retired-or-incorrect-code',
  }),{matched:true,submitted:true});
  const request=f.data.get('password_reset_requests/learner-id');
  assert.equal(request.managerId,'manager-id');
  assert.equal(Object.hasOwn(request,'codeSuffix'),false);
  assert.deepEqual(await f.handlers.requestPasswordReset(null,{
    username:'unknown',codeSuffix:'learner',
  }),{matched:false,submitted:false});
});

test('legacy compatibility still rejects injected management and malformed fields',async()=>{
  const f=fixture();
  for(const input of [
    {username:'learner',managerId:'forged'},
    {username:'learner',codeSuffix:{uid:'forged'}},
    {username:'learner',codeSuffix:'a'.repeat(129)},
  ]) await assert.rejects(f.handlers.requestPasswordReset(null,input),{code:'invalid-argument'});
  assert.equal(f.data.has('password_reset_requests/learner-id'),false);
});
