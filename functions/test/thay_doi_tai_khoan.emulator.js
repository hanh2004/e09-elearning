import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp} from 'firebase/firestore';
import {accountHandlers} from '../src/tai_khoan.js';
import {normalizedKey, usernameKey, loginEmail} from '../src/quy_tac.js';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Local Firestore and Auth emulators required');
let env, app, db, handlers, auth;
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-e09', firestore:{rules:
    readFileSync(new URL('../../firestore.rules', import.meta.url),'utf8')}});
  app = initializeApp({projectId:'demo-e09'}, 'account-audit');
  db = getFirestore(app);
  auth = getAuth(app);
  handlers = accountHandlers(db, auth);
});
beforeEach(async () => {
  await env.clearFirestore();
  const oldAccounts = (await auth.listUsers()).users;
  if (oldAccounts.length) await auth.deleteUsers(oldAccounts.map(user=>user.uid));
  await db.doc('system/access').set({rootUids:['root1','root2']});
  for (const uid of ['root1','root2']) await db.doc(`users/${uid}`).set({role:'super_admin',status:'active'});
  for (const [uid,unit] of [['m1','D1'],['m2','D2']]) await db.doc(`users/${uid}`).set({
    role:'admin',status:'active',createdBy:'root1',approvedBy:'root2',unit,
  });
  for (const [managerId,unit] of [['m1','D1'],['m2','D2']]) {
    await db.doc(`unit_codes/${normalizedKey(unit)}`).set({unit,managerId});
  }
});
after(async () => { await env?.cleanup(); if (app) await deleteApp(app); });
const input = (username) => ({operationId:randomBytes(16).toString('hex'),
  rows:[{username,name:'Học viên',password:'test-password'}]});
async function create(manager='m1', username='learner') {
  await handlers.importUsers(manager,input(username));
  return (await db.collection('users').where('username','==',username).get()).docs[0];
}
const denied = (promise, code='permission-denied') => assert.rejects(promise, e=>e.code===code);

test('password reset is handled by the current manager, not unrelated admins', async () => {
  const learner = await create();
  const reset = {requestId:learner.id,userId:learner.id,password:'replacement-password'};
  await handlers.requestPasswordReset(null, {username:'LEARNER'});
  const ref = db.doc(`password_reset_requests/${learner.id}`);
  await denied(handlers.updateUser('m1', {userId:learner.id,name:'Học viên',password:'bypass-password'}), 'failed-precondition');
  await denied(handlers.resolvePasswordReset('m2', reset));
  await denied(handlers.resolvePasswordReset('root1', reset));
  await handlers.resolvePasswordReset('m1', reset);
  assert.equal((await ref.get()).data().status, 'completed');
  assert.ok(!JSON.stringify((await ref.get()).data()).includes(reset.password));
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`, {
    method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({email:loginEmail('learner'),password:reset.password,returnSecureToken:true}),
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).localId, learner.id);
  await handlers.requestPasswordReset(null, {username:'learner'});
  assert.equal((await ref.get()).data().status, 'pending');
});

test('rejected Auth password remains retryable and rules isolate reset requests', async () => {
  const learner = await create();
  const reset = {requestId:learner.id,userId:learner.id,password:'replacement-password'};
  await handlers.requestPasswordReset(null, {username:'learner'});
  const path = `password_reset_requests/${learner.id}`;
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), path)));
  // The owning manager must receive pending password-reset requests.
  await assertSucceeds(getDoc(doc(env.authenticatedContext('m1').firestore(), path)));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('root1').firestore(), path)));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('m1').firestore(), path)));
  await assertFails(getDoc(doc(env.authenticatedContext('m2').firestore(), path)));
  await assertFails(updateDoc(doc(env.authenticatedContext('m1').firestore(), path), {status:'completed'}));
  const failing = accountHandlers(db, {updateUser:async()=>{
    throw Object.assign(new Error('Rejected password'), {code:'auth/invalid-password'});
  }});
  await assert.rejects(failing.resolvePasswordReset('m1', reset));
  assert.equal((await db.doc(path).get()).data().status, 'pending');
  await handlers.resolvePasswordReset('m1', reset);
  assert.equal((await db.doc(path).get()).data().status, 'completed');
});

test('root can directly reset only a learner currently assigned to that root', async () => {
  const learner = await create('root1', 'root_learner');
  const reset = {requestId:learner.id,userId:learner.id,password:'replacement-password'};
  assert.deepEqual(await handlers.requestPasswordReset(null,
    {username:'root_learner'}), {matched:true,submitted:true});
  await denied(handlers.resolvePasswordReset('root2', reset));
  await handlers.resolvePasswordReset('root1', reset);
  assert.equal((await db.doc(`password_reset_requests/${learner.id}`).get()).data().status, 'completed');
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`, {
    method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({email:loginEmail('root_learner'),password:reset.password,returnSecureToken:true}),
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).localId, learner.id);
});

test('pending admin deletion allows work and transfer; second root deletes only remaining learners', async () => {
  await db.doc('users/m1').update({username:'manager1'});
  const moved = await create('m1', 'moved_learner');
  const retained = await create('m1', 'retained_learner');
  const incoming = await create('m2', 'incoming_learner');
  await handlers.reassignUser('root1', {userId:incoming.id,managerId:'m1'});
  await handlers.requestAdminDeletion('root1', {userId:'m1'});
  assert.equal((await db.doc('users/m1').get()).data().adminDeletionPending, undefined);
  const createdWhilePending = await create('m1', 'pending_learner');
  await handlers.reassignUser('root1', {userId:moved.id,managerId:'m2'});
  await denied(handlers.decideAdminDeletion('root1', {requestId:'m1',approve:true}));
  await handlers.decideAdminDeletion('root2', {requestId:'m1',approve:true});
  for (const userId of ['m1', retained.id, incoming.id, createdWhilePending.id]) {
    assert.equal((await db.doc(`users/${userId}`).get()).exists, false);
    await assert.rejects(auth.getUser(userId), {code:'auth/user-not-found'});
  }
  assert.equal((await moved.ref.get()).data().createdBy, 'm2');
  assert.equal((await auth.getUser(moved.id)).disabled, false);
  assert.equal((await db.doc('admin_delete_requests/m1').get()).data().status, 'approved');
});

test('transfer cannot race a manager deletion that has already been approved', async () => {
  const learner = await create();
  await db.doc('users/m1').update({adminDeletionPending:true,adminDeletionRequestId:'m1'});
  await db.doc('admin_delete_requests/m1').set({status:'processing',createdBy:'root1',decidedBy:'root2'});
  await denied(handlers.reassignUser('root1', {userId:learner.id,managerId:'m2'}), 'failed-precondition');
  assert.equal((await learner.ref.get()).data().createdBy, 'm1');
  assert.equal((await learner.ref.get()).data().username, 'learner');
});

test('username is the only globally unique learner identifier, including concurrent creation', async()=>{
  const first=await create('m1','unique-learner');
  assert.equal(first.data().username,'unique-learner');
  assert.equal(first.data().unitNeedsConfirmation,true);
  await denied(handlers.importUsers('m2',input('UNIQUE-LEARNER')), 'already-exists');
  const results=await Promise.allSettled([
    handlers.importUsers('m1',input('same-racer')),
    handlers.importUsers('m2',input('SAME-RACER')),
  ]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.filter(r=>r.status==='rejected')[0].reason.code,'already-exists');
});
test('imports all 200 supported users without one oversized transaction', async()=>{
  const operationId=randomBytes(16).toString('hex');
  const rows=Array.from({length:200},(_,i)=>({
    username:`bulk${i}`,name:`Học viên ${i}`,password:'test-password',
  }));
  const result=await handlers.importUsers('m1',{operationId,rows});
  assert.equal(result.count,200);
  const learners=await db.collection('users').where('createdBy','==','m1').get();
  assert.equal(learners.size,200);
  assert.ok(learners.docs.every(doc=>doc.data().status==='active' &&
    doc.data().provisioningOperationId===undefined));
});
test('resumes a partially completed import with the same operation ID', async()=>{
  const request=input('retry-first');
  request.rows.push({username:'retry-second',name:'Học viên',password:'test-password'});
  let failOnce=true;
  const retryableAuth={
    createUser:auth.createUser.bind(auth),
    getUser:auth.getUser.bind(auth),
    updateUser:async(uid,values)=>{
      if(failOnce && values.disabled===false){failOnce=false;throw new Error('temporary Auth outage');}
      return auth.updateUser(uid,values);
    },
  };
  const resumable=accountHandlers(db,retryableAuth);
  await assert.rejects(resumable.importUsers('m1',request));
  assert.equal((await db.collection('users').where('status','==','provisioning').get()).size,2);
  assert.equal((await db.doc(`account_operations/m1_${request.operationId}`).get()).data().status,'provisioning');
  const result=await resumable.importUsers('m1',request);
  assert.equal(result.count,2);
  assert.equal((await db.collection('users').where('createdBy','==','m1').get()).size,2);
});
test('interrupted import keeps its manager unit fixed until activation finishes', async () => {
  const request = input('interrupted-unit-import');
  let transactionCount = 0;
  const interruptedDb = new Proxy(db, {
    get(target, property) {
      if (property === 'runTransaction') return (...args) => {
        if (++transactionCount === 2) throw new Error('interrupted after reservation');
        return target.runTransaction(...args);
      };
      const value = Reflect.get(target, property, target);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  await assert.rejects(accountHandlers(interruptedDb, auth).importUsers('m1', request),
    /interrupted after reservation/);
  assert.equal((await db.doc(`account_operations/m1_${request.operationId}`).get()).data().status,
    'provisioning');
  assert.equal((await db.collection('users').where('createdBy','==','m1').get()).size, 0);

  await denied(handlers.setUnit('root1', {userId:'m1',unit:'D3'}), 'failed-precondition');
  assert.equal((await db.doc('users/m1').get()).data().unit, 'D1');
  await handlers.importUsers('m1', request);
  await handlers.setUnit('root1', {userId:'m1',unit:'D3'});
  const learner = (await db.collection('users').where('username','==',request.rows[0].username).get()).docs[0];
  assert.equal(learner.data().unit, 'D3');
  assert.equal(learner.data().status, 'active');
});

test('parallel retries of one import operation stay idempotent', async()=>{
  const request=input('parallel-first');
  request.rows.push({username:'parallel-second',name:'Học viên',password:'test-password'});
  const results=await Promise.all([
    handlers.importUsers('m1',request),
    handlers.importUsers('m1',request),
  ]);
  assert.deepEqual(results.map(result=>result.count),[2,2]);
  assert.equal((await db.collection('users').where('createdBy','==','m1').get()).size,2);
  assert.equal((await db.collection('account_operations').get()).size,1);
});
test('transfer keeps UID, all study/exam records and hands management to new manager', async()=>{
  const learner=await create();
  const paths=[`users/${learner.id}/learning/c_l`,`exam_attempts/${learner.id}_e`,
    `exam_attempts/${learner.id}_e/runs/r`,`exam_sessions/${learner.id}_e`,
    `exam_private_runs/r`,`courses/c/reviews/${learner.id}`];
  for (const path of paths) await db.doc(path).set({userId:learner.id,score:9,completed:true});
  const before=await Promise.all(paths.map(async p=>(await db.doc(p).get()).data()));
  await learner.ref.update({subUnit:'Đội cũ',unitNeedsConfirmation:false});
  await denied(handlers.reassignUser('m1',{userId:learner.id,managerId:'m2'}));
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2'});
  const after=(await learner.ref.get()).data();
  const loginResponse = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`,{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email:loginEmail('learner'),password:'test-password',returnSecureToken:true}),
  });
  assert.equal(loginResponse.status,200);
  assert.equal((await loginResponse.json()).localId,learner.id);
  assert.equal(after.createdBy,'m2'); assert.equal(after.originalCreatedBy,undefined);
  assert.equal(after.username,'learner'); assert.equal(after.subUnit,'');
  assert.equal(after.unitNeedsConfirmation,true); assert.equal(after.unitAssignmentVersion,1);
  assert.deepEqual(await Promise.all(paths.map(async p=>(await db.doc(p).get()).data())),before);
  await denied(handlers.updateUser('m1',{userId:learner.id,name:'Old manager'}));
  await handlers.updateUser('m2',{userId:learner.id,name:'New manager'});
  await learner.ref.update({subUnit:'Đội mới',unitNeedsConfirmation:false});
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2'});
  assert.equal((await learner.ref.get()).data().unitNeedsConfirmation,false);
  assert.equal((await learner.ref.get()).data().unitAssignmentVersion,1);
});
test('unapproved manager cannot receive a learner', async()=>{
  const first=await create(); await create('m2','other');
  const original=first.data();
  await db.doc('users/m2').update({approvedBy:'root1'});
  await denied(handlers.reassignUser('root1',{userId:first.id,managerId:'m2'}),'failed-precondition');
  assert.deepEqual((await first.ref.get()).data(),original);
});
test('learner unit changes only through transfer; username stays fixed', async()=>{
  const learner = await create('m1', 'unitowner');
  await denied(handlers.updateUser('root1', {
    userId:learner.id,name:'Học viên',unit:'NEW',
  }), 'invalid-argument');
  let data = (await learner.ref.get()).data();
  assert.equal(data.unit, 'D1');
  await denied(handlers.updateUser('m1', {
    userId:learner.id,name:'Forbidden',unit:'OTHER',
  }), 'invalid-argument');
  await handlers.updateUser('m1', {
    userId:learner.id,name:'Updated',
  });
  data = (await learner.ref.get()).data();
  assert.equal(data.username, 'unitowner');
  assert.equal(data.unit, 'D1');
});
test('unit rename updates learner assignments without changing usernames', async()=>{
  const first=await create(); const second=await create('m1','second');
  await denied(handlers.setUnit('root1',{userId:'m1',unit:' d2 '}),'already-exists');
  await handlers.setUnit('root1',{userId:'m1',unit:'D3'});
  for (const learner of [first,second]) {
    const data=(await learner.ref.get()).data();
    assert.equal(data.username,learner.data().username); assert.equal(data.unit,'D3');
    assert.equal(data.unitNeedsConfirmation,true);
    assert.equal(data.unitAssignmentVersion,1);
  }
  const third=await create('m1','third'); assert.equal(third.data().username,'third');
  await denied(handlers.proposeAdmin('root1',{operationId:randomBytes(16).toString('hex'),
    account:{name:'Manager',username:'manager3',password:'test-password'},unit:'d3'}),'already-exists');
  assert.equal((await db.doc(`unit_codes/${normalizedKey('D1')}`).get()).exists,false);
});
test('unit rename updates cohorts larger than one transaction safely in pages', async()=>{
  const batch = db.batch();
  for (let index = 0; index < 113; index++) {
    const uid = `users/bulk-${String(index).padStart(3,'0')}`;
    batch.set(db.doc(uid), {
      role:'user',status:'active',createdBy:'m1',unit:'D1',username:`bulkuser${index}`,
    });
  }
  await batch.commit();

  let interrupted = false;
  const interruptedDb = new Proxy(db, {
    get(target, property) {
      const value = target[property];
      if (property === 'runTransaction') return async (...args) => {
        const operation = (await target.doc('unit_change_operations/m1').get()).data();
        if (!interrupted && operation?.status === 'running' && operation.processed > 0) {
          interrupted = true;
          throw new Error('simulated connection loss');
        }
        return value.apply(target, args);
      };
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  const interruptedHandlers = accountHandlers(interruptedDb, auth);
  await assert.rejects(interruptedHandlers.setUnit('root1',{userId:'m1',unit:'D3'}), /simulated connection loss/);
  assert.equal((await db.doc('users/bulk-000').get()).data().unit,'D3');
  assert.equal((await db.doc('users/bulk-112').get()).data().unit,'D1');
  assert.equal((await db.doc('users/m1').get()).data().unitChangePending,true);

  const result = await handlers.setUnit('root1',{userId:'m1',unit:'D3'});
  assert.deepEqual(result,{updated:true,processed:113});
  assert.equal((await db.doc('users/m1').get()).data().unit,'D3');
  assert.equal((await db.doc('users/bulk-000').get()).data().unit,'D3');
  assert.equal((await db.doc(`unit_codes/${normalizedKey('D1')}`).get()).exists,false);
  assert.equal((await db.doc(`unit_codes/${normalizedKey('D3')}`).get()).data().managerId,'m1');
  assert.equal((await db.collection('users').where('createdBy','==','m1').get()).size,113);
  assert.equal((await db.doc('users/m1').get()).data().unitChangePending,false);
  assert.equal((await db.doc('unit_change_operations/m1').get()).data().status,'complete');
});
test('unit rename collision rolls back manager and all learners', async()=>{
  const first=await create();
  const managerBefore=(await db.doc('users/m1').get()).data();
  await db.doc(`unit_codes/${normalizedKey('D3')}`).set({unit:'D3',managerId:'m2'});
  await denied(handlers.setUnit('root1',{userId:'m1',unit:'D3'}),'already-exists');
  assert.deepEqual((await first.ref.get()).data(),first.data());
  assert.equal((await db.doc('users/m1').get()).data().unit,'D1');
  assert.equal((await db.doc(`unit_codes/${normalizedKey('D3')}`).get()).data().managerId,'m2');
  assert.deepEqual((await db.doc('users/m1').get()).data(),managerBefore);
  assert.equal((await db.doc('unit_change_operations/m1').get()).exists,false);
});
test('completed import retry preserves current assignment and cannot create a second account', async()=>{
  const request=input('retry'); await handlers.importUsers('m1',request);
  const retryLearner=(await db.collection('users').where('username','==','retry').get()).docs[0];
  await handlers.setUnit('root1',{userId:'m1',unit:'D3'});
  await handlers.importUsers('m1',request);
  const docs=await db.collection('users').where('username','==','retry').get();
  assert.equal(docs.size,1); assert.equal(docs.docs[0].data().username,'retry');
});
test('manager subordinate list controls learner selection', async()=>{
  await handlers.setSubUnits('m1',{subUnits:['Đội 1','Tổ kỹ thuật','Đội 1']});
  const learner=await create('m1','subunit-user','003');
  const client=env.authenticatedContext(learner.id).firestore();
  // A learner may read its own manager's active profile so the profile form
  // can resolve the manager's configured subordinate list.
  await assertSucceeds(getDoc(doc(client,'users/m1')));
  assert.deepEqual(await handlers.getSubUnits(learner.id),{managerId:'m1',subUnits:['Đội 1','Tổ kỹ thuật']});
  await denied(handlers.setSubUnits(learner.id,{subUnits:['Giả mạo']}));
  const managerClient=env.authenticatedContext('m1').firestore();
  await assertFails(updateDoc(doc(managerClient,'users/m2'),{subUnits:['Giả mạo']}));
  await assertFails(updateDoc(doc(client,`users/${learner.id}`),{subUnits:['Giả mạo']}));
  await assertSucceeds(updateDoc(doc(managerClient,'users/m1'),{subUnits:['Đội 1','Tổ kỹ thuật']}));
  await assertSucceeds(updateDoc(doc(client,`users/${learner.id}`),{subUnit:'Đội 1'}));
  await assertFails(updateDoc(doc(client,`users/${learner.id}`),{subUnit:'Đội khác'}));
  assert.deepEqual((await db.doc('users/m1').get()).data().subUnits,['Đội 1','Tổ kỹ thuật']);
  await assert.rejects(handlers.setSubUnits('m1',{subUnits:['']}),e=>e.code==='invalid-argument');
  await handlers.setSubUnits('root1',{subUnits:['Khối tổng']});
  await handlers.importUsers('root1',{operationId:'b'.repeat(32),rows:[{
    name:'Root learner',username:'root-subunit-user',password:'test-password',subUnit:'Khối tổng',
  }]});
  const rootLearner=(await db.collection('users').where('username','==','root-subunit-user').get()).docs[0];
  assert.equal(rootLearner.data().subUnit,'Khối tổng');
  await handlers.setSubUnits('m1',{subUnits:['Tổ kỹ thuật']});
  assert.deepEqual((await handlers.getSubUnits(learner.id)).subUnits,['Tổ kỹ thuật']);
  await assertFails(updateDoc(doc(client,`users/${learner.id}`),{subUnit:'Đội 1',name:'Changed'}));
  await assertSucceeds(updateDoc(doc(client,`users/${learner.id}`),{subUnit:'Tổ kỹ thuật'}));
  await learner.ref.update({status:'blocked'});
  await denied(handlers.getSubUnits(learner.id));
});
test('learner rules require nonempty current unit confirmation, reject stale/forged identity', async()=>{
  const learner=await create();
  const client=env.authenticatedContext(learner.id).firestore();
  const ref=doc(client,`users/${learner.id}`);
  const confirm={unitNeedsConfirmation:false,unitConfirmedAt:serverTimestamp(),unitConfirmedVersion:0};
  await assertFails(updateDoc(ref,{...confirm,subUnit:''}));
  await assertFails(updateDoc(ref,{...confirm,subUnit:'   '}));
  await assertSucceeds(updateDoc(ref,{...confirm,subUnit:'Đội 1'}));
  await assertSucceeds(updateDoc(ref,{name:'New name'}));
  for (const change of [{unit:'Forged'},{createdBy:'m2'},
    {unitAssignmentVersion:5},{avatarUrl:'https://example.org/new.png'}]) await assertFails(updateDoc(ref,change));
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2'});
  await assertFails(updateDoc(ref,{...confirm,subUnit:'Stale form'}));
  await assertFails(updateDoc(ref,{unitNeedsConfirmation:false}));
  await assertSucceeds(updateDoc(ref,{...confirm,subUnit:'Đội 2',unitConfirmedVersion:1}));
});
test('notifications for managers are hidden from learners, all notifications are readable', async()=>{
  const learner=await create();
  for (const audience of ['all','managers']) await db.doc(`learning_notifications/${audience}`).set({
    title:'Notice',body:'Text',audience,sendAt:new Date(Date.now()-10000),
  });
  const pupil=env.authenticatedContext(learner.id).firestore();
  const manager=env.authenticatedContext('m1').firestore();
  await assertFails(getDoc(doc(pupil,'learning_notifications/managers')));
  await assertSucceeds(getDoc(doc(pupil,'learning_notifications/all')));
  await assertSucceeds(getDoc(doc(manager,'learning_notifications/managers')));
  await assertSucceeds(getDoc(doc(manager,'learning_notifications/all')));
});
test('transfers and unit changes leave learner usernames unchanged', async()=>{
  const first=await create('m1','first');
  const second=await create('m1','second');
  await handlers.reassignUser('root1',{userId:first.id,managerId:'m2'});
  assert.equal((await first.ref.get()).data().username,'first');
  await handlers.reassignUser('root1',{userId:first.id,managerId:'m1'});
  assert.equal((await first.ref.get()).data().username,'first');
  await handlers.setUnit('root1',{userId:'m1',unit:'D3'});
  assert.equal((await first.ref.get()).data().username,'first');
  assert.equal((await second.ref.get()).data().username,'second');
  await handlers.setUnit('root1',{userId:'m1',unit:'d3'});
  assert.equal((await first.ref.get()).data().unitAssignmentVersion,3);
  assert.equal((await second.ref.get()).data().unitAssignmentVersion,1);
});
test('rejected manager releases unit reservation and learner deletion clears username reservation', async()=>{
  const request=await handlers.proposeAdmin('root1',{operationId:randomBytes(16).toString('hex'),
    account:{name:'Manager',username:'manager3',password:'test-password'},unit:'D3'});
  await handlers.decideAdmin('root2',{requestId:request.requestId,approve:false});
  assert.equal((await db.doc(`unit_codes/${normalizedKey('D3')}`).get()).exists,false);
  const learner=await create();
  await handlers.deleteUser('m1',{userId:learner.id});
  assert.equal((await db.doc(`usernames/${usernameKey('learner')}`).get()).exists,false);
  await assert.rejects(auth.getUser(learner.id), e=>e.code==='auth/user-not-found');
});
