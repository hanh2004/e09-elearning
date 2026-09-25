import {before, beforeEach, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp} from 'firebase/firestore';
import {accountHandlers} from '../src/accounts.js';
import {userCodeKey, loginEmail} from '../src/policy.js';
import {backfillUserCodes} from '../scripts/backfill-user-codes.js';

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
});
after(async () => { await env?.cleanup(); if (app) await deleteApp(app); });
const input = (username, code='001') => ({operationId:randomBytes(16).toString('hex'),
  rows:[{username,name:'Học viên',password:'test-password',code}]});
async function create(manager='m1', username='learner', code='001') {
  await handlers.importUsers(manager,input(username,code));
  return (await db.collection('users').where('username','==',username).get()).docs[0];
}
const denied = (promise, code='permission-denied') => assert.rejects(promise, e=>e.code===code);

test('password reset requires two distinct roots and the owning manager', async () => {
  const learner = await create();
  const reset = {requestId:learner.id,userId:learner.id,password:'replacement-password'};
  await handlers.requestPasswordReset(null, {username:'LEARNER'});
  const ref = db.doc(`password_reset_requests/${learner.id}`);
  await denied(handlers.resolvePasswordReset('m1', reset), 'failed-precondition');
  await denied(handlers.updateUser('m1', {userId:learner.id,name:'Học viên',password:'bypass-password'}), 'failed-precondition');
  await denied(handlers.approvePasswordReset('m1', reset));
  await handlers.approvePasswordReset('root1', reset);
  await denied(handlers.approvePasswordReset('root1', reset));
  await handlers.requestPasswordReset(null, {username:'learner'});
  assert.equal((await ref.get()).data().status, 'approved_once');
  await handlers.approvePasswordReset('root2', reset);
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
  assert.equal((await ref.get()).data().firstApprovedBy, undefined);
});

test('failed Auth reset remains retryable and rules isolate reset requests', async () => {
  const learner = await create();
  const reset = {requestId:learner.id,userId:learner.id,password:'replacement-password'};
  await handlers.requestPasswordReset(null, {username:'learner'});
  const path = `password_reset_requests/${learner.id}`;
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), path)));
  await assertFails(getDoc(doc(env.authenticatedContext('m1').firestore(), path)));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('root1').firestore(), path)));
  await handlers.approvePasswordReset('root1', reset);
  await handlers.approvePasswordReset('root2', reset);
  await assertSucceeds(getDoc(doc(env.authenticatedContext('m1').firestore(), path)));
  await assertFails(getDoc(doc(env.authenticatedContext('m2').firestore(), path)));
  await assertFails(updateDoc(doc(env.authenticatedContext('m1').firestore(), path), {status:'completed'}));
  const failing = accountHandlers(db, {updateUser:async()=>{throw new Error('Auth temporarily unavailable');}});
  await assert.rejects(failing.resolvePasswordReset('m1', reset));
  assert.equal((await db.doc(path).get()).data().status, 'approved');
  await handlers.resolvePasswordReset('m1', reset);
  assert.equal((await db.doc(path).get()).data().status, 'completed');
});

test('auto prefix, different units, duplicate suffix and concurrent creation', async()=>{
  const first=await create();
  assert.equal(first.data().userCode,'D1-001');
  assert.equal(first.data().unitNeedsConfirmation,true);
  await denied(handlers.importUsers('m1',input('other')), 'already-exists');
  const second=await create('m2','other');
  assert.equal(second.data().userCode,'D2-001');
  const results=await Promise.allSettled([
    handlers.importUsers('m1',input('racer1','002')),
    handlers.importUsers('m1',input('racer2','002')),
  ]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.filter(r=>r.status==='rejected')[0].reason.code,'already-exists');
  const reservation=await db.doc(`user_codes/${userCodeKey('d1-002')}`).get();
  assert.equal((await db.doc(`users/${reservation.data().uid}`).get()).data().userCode,'D1-002');
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
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2',userCodeSuffix:'999'});
  const after=(await learner.ref.get()).data();
  const loginResponse = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`,{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email:loginEmail('learner'),password:'test-password',returnSecureToken:true}),
  });
  assert.equal(loginResponse.status,200);
  assert.equal((await loginResponse.json()).localId,learner.id);
  assert.equal(after.createdBy,'m2'); assert.equal(after.originalCreatedBy,'m1');
  assert.equal(after.userCode,'D2-001'); assert.equal(after.subUnit,'');
  assert.equal(after.unitNeedsConfirmation,true); assert.equal(after.unitAssignmentVersion,1);
  assert.deepEqual(await Promise.all(paths.map(async p=>(await db.doc(p).get()).data())),before);
  assert.equal((await db.doc(`user_codes/${userCodeKey('D1-001')}`).get()).exists,false);
  await denied(handlers.updateUser('m1',{userId:learner.id,name:'Old manager'}));
  await handlers.updateUser('m2',{userId:learner.id,name:'New manager'});
  await learner.ref.update({subUnit:'Đội mới',unitNeedsConfirmation:false});
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2',userCodeSuffix:'001'});
  assert.equal((await learner.ref.get()).data().unitNeedsConfirmation,false);
  assert.equal((await learner.ref.get()).data().unitAssignmentVersion,1);
});
test('collision and unapproved manager abort transfer without partial changes', async()=>{
  const first=await create(); await create('m2','other');
  const original=first.data();
  await denied(handlers.reassignUser('root1',{userId:first.id,managerId:'m2',userCodeSuffix:'001'}),'already-exists');
  assert.deepEqual((await first.ref.get()).data(),original);
  assert.equal((await db.doc(`user_codes/${userCodeKey('D1-001')}`).get()).data().uid,first.id);
  await db.doc('users/m2').update({approvedBy:'root1'});
  await denied(handlers.reassignUser('root1',{userId:first.id,managerId:'m2',userCodeSuffix:'002'}),'failed-precondition');
});
test('root changes only the code unit; owning manager changes only the suffix', async()=>{
  const learner = await create('m1', 'codeowner', '0007');
  await handlers.updateUser('root1', {userId:learner.id,name:'Học viên',unit:'NEW'});
  let data = (await learner.ref.get()).data();
  assert.equal(data.userCode, 'NEW-0007');
  assert.equal(data.userCodeSuffix, '0007');
  assert.equal((await db.doc(`user_codes/${userCodeKey('D1-0007')}`).get()).exists, false);
  assert.equal((await db.doc(`user_codes/${userCodeKey('NEW-0007')}`).get()).data().uid, learner.id);
  await denied(handlers.updateUser('m2', {
    userId:learner.id,name:'Forbidden',userCodeSuffix:'0099',
  }));
  await denied(handlers.updateUser('m1', {
    userId:learner.id,name:'Forbidden',unit:'OTHER',
  }));
  await denied(handlers.updateUser('root1', {
    userId:learner.id,name:'Forbidden',userCodeSuffix:'0099',
  }));
  await handlers.updateUser('m1', {
    userId:learner.id,name:'Updated',userCodeSuffix:'0099',
  });
  data = (await learner.ref.get()).data();
  assert.equal(data.userCode, 'NEW-0099');
  assert.equal(data.unit, 'NEW');
  assert.equal(data.userCodeSuffix, '0099');
  assert.equal((await db.doc(`user_codes/${userCodeKey('NEW-0007')}`).get()).exists, false);
  assert.equal((await db.doc(`user_codes/${userCodeKey('NEW-0099')}`).get()).data().uid, learner.id);
});
test('unit rename updates every prefix, confirmation and reserves unique unit', async()=>{
  const first=await create(); const second=await create('m1','second','002');
  await denied(handlers.setUnit('root1',{userId:'m1',unit:' d2 '}),'already-exists');
  await handlers.setUnit('root1',{userId:'m1',unit:'D3',codes:{[first.id]:'999',[second.id]:'998'}});
  for (const [learner,code] of [[first,'001'],[second,'002']]) {
    const data=(await learner.ref.get()).data();
    assert.equal(data.userCode,`D3-${code}`); assert.equal(data.unitNeedsConfirmation,true);
    assert.equal(data.unitAssignmentVersion,1);
    assert.equal((await db.doc(`user_codes/${userCodeKey(`D3-${code}`)}`).get()).data().uid,learner.id);
  }
  const third=await create('m1','third','003'); assert.equal(third.data().userCode,'D3-003');
  await denied(handlers.proposeAdmin('root1',{operationId:randomBytes(16).toString('hex'),
    account:{name:'Manager',username:'manager3',password:'test-password'},unit:'d3'}),'already-exists');
  assert.equal((await db.doc(`unit_codes/${userCodeKey('D1')}`).get()).exists,false);
});
test('unit rename collision rolls back manager and all learners', async()=>{
  const first=await create();
  await db.doc(`user_codes/${userCodeKey('D3-001')}`).set({uid:'someone-else'});
  await denied(handlers.setUnit('root1',{userId:'m1',unit:'D3',codes:{[first.id]:'001'}}),'already-exists');
  assert.deepEqual((await first.ref.get()).data(),first.data());
  assert.equal((await db.doc('users/m1').get()).data().unit,'D1');
  assert.equal((await db.doc(`unit_codes/${userCodeKey('D3')}`).get()).exists,false);
});
test('completed import retry preserves current assignment and cannot create a second account', async()=>{
  const request=input('retry'); await handlers.importUsers('m1',request);
  const retryLearner=(await db.collection('users').where('username','==','retry').get()).docs[0];
  await handlers.setUnit('root1',{userId:'m1',unit:'D3',codes:{[retryLearner.id]:'001'}});
  await handlers.importUsers('m1',request);
  const docs=await db.collection('users').where('username','==','retry').get();
  assert.equal(docs.size,1); assert.equal(docs.docs[0].data().userCode,'D3-001');
});
test('legacy custom suffix and reservation are preserved/repaired', async()=>{
  await db.doc('users/legacy').set({role:'user',status:'active',name:'Legacy',username:'legacy',
    unit:'D1',userCode:'D1-CUSTOM',createdBy:'m1'});
  await handlers.reassignUser('root1',{userId:'legacy',managerId:'m2',userCodeSuffix:'CUSTOM'});
  assert.equal((await db.doc('users/legacy').get()).data().userCode,'D2-CUSTOM');
  assert.equal((await db.doc(`user_codes/${userCodeKey('D2-CUSTOM')}`).get()).data().uid,'legacy');
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
  for (const change of [{unit:'Forged'},{createdBy:'m2'},{userCode:'D2-999'},
    {unitAssignmentVersion:5},{avatarUrl:'https://example.org/new.png'}]) await assertFails(updateDoc(ref,change));
  await handlers.reassignUser('root1',{userId:learner.id,managerId:'m2',userCodeSuffix:'002'});
  await assertFails(updateDoc(ref,{...confirm,subUnit:'Stale form'}));
  await assertFails(updateDoc(ref,{unitNeedsConfirmation:false}));
  await assertSucceeds(updateDoc(ref,{...confirm,subUnit:'Đội 2',unitConfirmedVersion:1}));
  await assertFails(setDoc(doc(client,`user_codes/forged`),{uid:learner.id}));
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
test('legacy backfill previews, reserves unique codes, is repeatable and keeps progress', async()=>{
  await db.doc('users/old').set({role:'user',status:'active',createdBy:'m1',unit:'D1',username:'old-user',name:'Old'});
  await db.doc('users/old/learning/c_l').set({completed:true});
  assert.deepEqual(await backfillUserCodes(db),{mode:'dry-run',managers:2,learners:1});
  assert.equal((await db.doc('users/old').get()).data().userCode,undefined);
  await backfillUserCodes(db,true);
  const first=(await db.doc('users/old').get()).data();
  assert.equal(first.userCode,'D1-old-user');
  await backfillUserCodes(db,true);
  assert.deepEqual((await db.doc('users/old').get()).data(),first);
  assert.deepEqual((await db.doc('users/old/learning/c_l').get()).data(),{completed:true});
  await db.doc('users/another').set({role:'user',status:'active',createdBy:'m1',unit:'D1',username:'old-user'});
  await denied(backfillUserCodes(db,true),'already-exists');
  assert.equal((await db.doc('users/another').get()).data().userCode,undefined);
});
test('transfers and unit changes preserve manager-owned custom suffixes without replacement codes', async()=>{
  const first=await create('m1','first','101.A');
  const second=await create('m1','second','102@B');
  await handlers.reassignUser('root1',{userId:first.id,managerId:'m2'});
  assert.equal((await first.ref.get()).data().userCode,'D2-101.A');
  await handlers.reassignUser('root1',{userId:first.id,managerId:'m1',userCodeSuffix:'forged'});
  assert.equal((await first.ref.get()).data().userCode,'D1-101.A');
  await handlers.setUnit('root1',{userId:'m1',unit:'D3',codes:{[first.id]:'forged'}});
  assert.equal((await first.ref.get()).data().userCode,'D3-101.A');
  assert.equal((await second.ref.get()).data().userCode,'D3-102@B');
  await handlers.setUnit('root1',{userId:'m1',unit:'d3'});
  assert.equal((await first.ref.get()).data().unitAssignmentVersion,3);
  assert.equal((await second.ref.get()).data().unitAssignmentVersion,1);
});
test('rejected manager releases unused unit code and learner deletion releases only their code', async()=>{
  const request=await handlers.proposeAdmin('root1',{operationId:randomBytes(16).toString('hex'),
    account:{name:'Manager',username:'manager3',password:'test-password'},unit:'D3'});
  await handlers.decideAdmin('root2',{requestId:request.requestId,approve:false});
  assert.equal((await db.doc(`unit_codes/${userCodeKey('D3')}`).get()).exists,false);
  const learner=await create();
  await handlers.deleteUser('m1',{userId:learner.id});
  assert.equal((await db.doc(`user_codes/${userCodeKey('D1-001')}`).get()).exists,false);
  await assert.rejects(auth.getUser(learner.id), e=>e.code==='auth/user-not-found');
});
