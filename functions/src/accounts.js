import { FieldValue } from 'firebase-admin/firestore';
import { fingerprint, isRoot, loginEmail, requireAdmin, requireDecision,
  requireDelete, requireRoot, requireThat, requireUpdate, usernameKey, validateRows } from './policy.js';

// All writes use the Admin SDK. The client cannot supply actor IDs or roles.
export function accountHandlers(db, auth) {
  const stamp = () => FieldValue.serverTimestamp();
  async function context(tx, uid) {
    requireThat(typeof uid === 'string' && uid.length > 0, 'unauthenticated', 'Cần đăng nhập.');
    const config = (await tx.get(db.doc('system/access'))).data();
    const actor = { ...(await tx.get(db.doc(`users/${uid}`))).data(), id: uid };
    requireAdmin(actor, config);
    return { actor, config };
  }
  const userRef = (id) => {
    requireThat(typeof id === 'string' && /^[A-Za-z0-9_=-]{1,128}$/.test(id),
      'invalid-argument', 'Mã tài khoản không hợp lệ.');
    return db.doc(`users/${id}`);
  };
  async function ensureAuth(uid, row) {
    try {
      await auth.createUser({ uid, email: loginEmail(row.username),
        password: row.password, displayName: row.name, disabled: true });
    } catch (error) {
      if (error.code !== 'auth/uid-already-exists') throw error;
      const existing = await auth.getUser(uid);
      requireThat(existing.email === loginEmail(row.username), 'already-exists', 'Tài khoản đã tồn tại.');
    }
  }

  async function importUsers(uid, input) {
    const rows = validateRows(input.rows);
    requireThat(typeof input.operationId === 'string' && /^[a-f0-9]{32}$/.test(input.operationId),
      'invalid-argument', 'Thiếu mã thao tác.');
    const opRef = db.doc(`account_operations/${uid}_${input.operationId}`);
    const digest = fingerprint(rows);
    const op = await db.runTransaction(async (tx) => {
      const {actor,config} = await context(tx, uid);
      const unit = isRoot(actor,config) ? 'E09' : actor.unit;
      requireThat(typeof unit === 'string' && unit.trim().length > 0, 'failed-precondition', 'Admin chưa được phân đơn vị. Liên hệ admin tổng.');
      const old = await tx.get(opRef);
      if (old.exists) {
        requireThat(old.data().digest === digest, 'invalid-argument', 'Mã thao tác đã được dùng cho dữ liệu khác.');
        return old.data();
      }
      const refs = rows.map((r) => db.doc(`usernames/${usernameKey(r.username)}`));
      for (const ref of refs) {
        requireThat(!(await tx.get(ref)).exists, 'already-exists', 'Tên đăng nhập đã được sử dụng hoặc đang chờ xử lý.');
      }
      const ids = rows.map(() => db.collection('users').doc().id);
      rows.forEach((row, i) => {
        tx.create(refs[i], { uid: ids[i], username: row.username });
        tx.create(userRef(ids[i]), { name: row.name, username: row.username,
          role: 'user', unit:unit.trim(), status: 'provisioning', createdBy: uid, createdAt: stamp() });
      });
      const value = { ids, digest, status: 'provisioning', createdBy: uid };
      tx.create(opRef, { ...value, createdAt: stamp() });
      return value;
    });
    if (op.status === 'completed') return { count: op.ids.length };
    // Auth and Firestore are not one transaction: provision all Auth records
    // first. Profiles stay inaccessible until the final atomic activation.
    for (let start = 0; start < rows.length; start += 10) {
      const results = await Promise.allSettled(rows.slice(start, start + 10).map(async (row, i) => {
        const id = op.ids[start + i];
        await ensureAuth(id, row);
        await auth.updateUser(id, { disabled: false });
      }));
      const failed = results.find((r) => r.status === 'rejected');
      if (failed) throw failed.reason;
    }
    await db.runTransaction(async (tx) => {
      const {actor,config}=await context(tx,uid);
      const unit=isRoot(actor,config)?'E09':actor.unit;
      requireThat(typeof unit==='string'&&unit.trim().length>0,'failed-precondition','Admin chưa được phân đơn vị.');
      const current = (await tx.get(opRef)).data();
      if (current.status === 'completed') return;
      for (const id of op.ids) {
        requireThat((await tx.get(userRef(id))).data()?.status === 'provisioning',
          'failed-precondition', 'Tài khoản đang được xử lý bởi thao tác khác.');
      }
      for (const id of op.ids) tx.update(userRef(id), { status: 'active',unit:unit.trim() });
      tx.update(opRef, { status: 'completed', completedAt: stamp() });
    });
    return { count: op.ids.length };
  }

  async function proposeAdmin(uid, input) {
    const row = validateRows([input.account])[0];
    const unit = typeof input.unit === 'string' ? input.unit.trim() : '';
    requireThat(unit.length > 0 && unit.length <= 200, 'invalid-argument', 'Nhập đơn vị của admin phụ (tối đa 200 ký tự).');
    requireThat(typeof input.operationId === 'string' && /^[a-f0-9]{32}$/.test(input.operationId),
      'invalid-argument', 'Thiếu mã thao tác.');
    const requestRef = db.doc(`admin_requests/${uid}_${input.operationId}`);
    const digest = fingerprint({...row,unit});
    const request = await db.runTransaction(async (tx) => {
      const { actor, config } = await context(tx, uid);
      requireRoot(actor, config);
      const old = await tx.get(requestRef);
      if (old.exists) {
        const secret = (await tx.get(db.doc(`admin_request_secrets/${requestRef.id}`))).data();
        requireThat(secret?.digest === digest, 'invalid-argument', 'Mã thao tác đã được dùng.');
        return old.data();
      }
      const nameRef = db.doc(`usernames/${usernameKey(row.username)}`);
      requireThat(!(await tx.get(nameRef)).exists, 'already-exists', 'Tên đăng nhập đã được sử dụng.');
      const targetUid = db.collection('users').doc().id;
      const value = { targetUid, name: row.name, username: row.username, unit,
        createdBy: uid, status: 'provisioning' };
      // Digest is private, never stored on the readable request.
      tx.create(db.doc(`admin_request_secrets/${requestRef.id}`), { digest });
      tx.create(nameRef, { uid: targetUid, username: row.username });
      tx.create(userRef(targetUid), { name: row.name, username: row.username,
        role: 'admin', unit, status: 'pending', createdBy: uid, createdAt: stamp() });
      tx.create(requestRef, { ...value, createdAt: stamp() });
      return { ...value, digest };
    });
    if (request.status !== 'provisioning') return { requestId: requestRef.id };
    await ensureAuth(request.targetUid, row);
    await db.runTransaction(async (tx) => {
      const { actor, config } = await context(tx, uid);
      requireRoot(actor, config);
      const current = (await tx.get(requestRef)).data();
      if (current.status === 'provisioning') tx.update(requestRef, { status: 'pending' });
    });
    return { requestId: requestRef.id };
  }

  async function decideAdmin(uid, input) {
    requireThat(typeof input.requestId === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(input.requestId) &&
      typeof input.approve === 'boolean', 'invalid-argument', 'Yêu cầu không hợp lệ.');
    const ref = db.doc(`admin_requests/${input.requestId}`);
    const next = input.approve ? 'approved' : 'rejected';
    const targetUid = await db.runTransaction(async (tx) => {
      const { actor, config } = await context(tx, uid);
      const request = (await tx.get(ref)).data();
      requireThat(request, 'not-found', 'Không tìm thấy yêu cầu.');
      requireDecision(actor, config, request);
      requireThat(request.status === 'pending' ||
        (request.status === next && request.decidedBy === uid),
      'failed-precondition', 'Yêu cầu đã được xử lý hoặc chưa sẵn sàng.');
      const target = (await tx.get(userRef(request.targetUid))).data();
      requireThat(target?.status === 'pending' ||
        (request.status === next && target?.status === (input.approve ? 'active' : 'rejected')),
      'failed-precondition', 'Tài khoản đã thay đổi trạng thái.');
      tx.update(ref, { status: next, decidedBy: uid, decidedAt: stamp() });
      tx.update(userRef(request.targetUid), { status: input.approve ? 'active' : 'rejected',
        approvedBy: input.approve ? uid : null });
      return request.targetUid;
    });
    // Retrying the same decision is safe if the Auth update fails transiently.
    await auth.updateUser(targetUid, { disabled: !input.approve });
    return { status: next };
  }

  async function deleteUser(uid, input) {
    const ref = userRef(input.userId);
    const data = await db.runTransaction(async (tx) => {
      const { actor, config } = await context(tx, uid);
      const data = (await tx.get(ref)).data();
      requireThat(data, 'not-found', 'Không tìm thấy tài khoản.');
      requireDelete(actor, config, { ...data, id: ref.id });
      requireThat(['active','blocked','deleting'].includes(data.status), 'failed-precondition', 'Tài khoản chưa thể xóa.');
      tx.update(ref, {status:'deleting'});
      return data;
    });
    const [attempts, requests] = await Promise.all([
      db.collection('exam_attempts').where('userId', '==', ref.id).get(),
      db.collection('admin_requests').where('targetUid', '==', ref.id).get(),
    ]);
    const privateRuns = await db.collection('exam_private_runs').where('userId','==',ref.id).get();
    const sessions = await db.collection('exam_sessions').where('userId','==',ref.id).get();
    const writer = db.bulkWriter();
    for (const run of privateRuns.docs) writer.delete(run.ref);
    for (const session of sessions.docs) {
      const runs = await session.ref.collection('runs').get();
      for (const run of runs.docs) writer.delete(run.ref);
      writer.delete(session.ref);
    }
    for (const doc of attempts.docs) {
      const runs = await doc.ref.collection('runs').get();
      for (const run of runs.docs) writer.delete(run.ref);
      writer.delete(doc.ref);
    }
    const learning = await ref.collection('learning').get();
    for (const progress of learning.docs) writer.delete(progress.ref);
    const notificationReads = await ref.collection('notification_reads').get();
    for (const receipt of notificationReads.docs) writer.delete(receipt.ref);
    for (const doc of requests.docs) {
      writer.delete(doc.ref);
      writer.delete(db.doc(`admin_request_secrets/${doc.id}`));
    }
    await writer.close();
    try {
      await auth.deleteUser(ref.id);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    // Keep the deleting profile and username reserved until Auth deletion succeeds,
    // so a transient Auth outage can be retried without orphaning the account.
    const finalize = db.batch();
    finalize.delete(db.doc(`usernames/${usernameKey(data.username)}`));
    finalize.delete(ref);
    await finalize.commit();
    return { deleted: true };
  }

  async function updateUser(uid, input) {
    const ref = userRef(input.userId);
    requireThat(typeof input.name === 'string' && input.name.trim().length > 0 && input.name.length <= 100 &&
      (!input.password || (typeof input.password === 'string' && input.password.length >= 6 && input.password.length <= 128)) &&
      !Object.hasOwn(input, 'role') && !Object.hasOwn(input, 'createdBy') && !Object.hasOwn(input, 'username'),
    'invalid-argument', 'Chỉ được sửa họ tên và đặt lại mật khẩu.');
    await db.runTransaction(async (tx) => {
      const { actor, config } = await context(tx, uid);
      const target = (await tx.get(ref)).data();
      requireThat(target, 'not-found', 'Không tìm thấy tài khoản.');
      requireUpdate(actor, config, { ...target, id: ref.id });
      requireThat(target?.status === 'active', 'failed-precondition', 'Tài khoản chưa hoạt động.');
      tx.update(ref, { name: input.name.trim(), updatedBy: uid, updatedAt: stamp() });
    });
    if (input.password) {
      await auth.updateUser(ref.id, { password: input.password });
      await auth.revokeRefreshTokens(ref.id);
    }
    return { updated: true };
  }

  async function checkUsernames(uid, input) {
    requireThat(Array.isArray(input.usernames) && input.usernames.length <= 200 &&
      input.usernames.every((n) => typeof n === 'string' && n.length <= 64),
    'invalid-argument', 'Danh sách không hợp lệ.');
    await db.runTransaction(async (tx) => { await context(tx, uid); });
    const refs = input.usernames.map((name) => db.doc(`usernames/${usernameKey(name)}`));
    if (!refs.length) return { existing: [] };
    const docs = await db.getAll(...refs);
    return { existing: input.usernames.filter((_, i) => docs[i].exists) };
  }
  async function setStatus(uid, input) {
    requireThat(typeof input.disabled === 'boolean', 'invalid-argument', 'Trạng thái không hợp lệ.');
    const ref = userRef(input.userId);
    await db.runTransaction(async (tx) => {
      const {actor,config} = await context(tx,uid);
      const target = (await tx.get(ref)).data();
      requireThat(target, 'not-found', 'Không tìm thấy tài khoản.');
      requireUpdate(actor,config,{...target,id:ref.id});
      requireThat(['active','blocked'].includes(target.status), 'failed-precondition', 'Tài khoản đang chờ xử lý.');
      if (input.disabled) tx.update(ref,{status:'blocked',updatedBy:uid,updatedAt:stamp()});
    });
    await auth.updateUser(ref.id,{disabled:input.disabled});
    if(input.disabled) await auth.revokeRefreshTokens(ref.id);
    else await ref.update({status:'active',updatedBy:uid,updatedAt:stamp()});
    await db.collection('account_audit').add({actorId:uid,targetUid:ref.id,action:input.disabled?'block':'unblock',at:stamp()});
    return {status:input.disabled?'blocked':'active'};
  }
  async function setUnit(uid,input) {
    const unit=typeof input.unit==='string'?input.unit.trim():'';
    requireThat(unit.length>0&&unit.length<=200,'invalid-argument','Đơn vị không hợp lệ.');
    const ref=userRef(input.userId);
    await db.runTransaction(async tx=>{
      const {actor,config}=await context(tx,uid);requireRoot(actor,config);
      const target=(await tx.get(ref)).data();
      requireThat(target?.role==='admin'&&['active','pending'].includes(target.status),'failed-precondition','Chọn admin phụ đang hoạt động hoặc chờ duyệt.');
      tx.update(ref,{unit,updatedAt:stamp(),updatedBy:uid});
    });
    // Read the latest creator on every transaction so concurrent reassignments converge.
    const children=await db.collection('users').where('createdBy','==',ref.id).get();
    for(const child of children.docs) await db.runTransaction(async tx=>{
      const parent=(await tx.get(ref)).data();const current=(await tx.get(child.ref)).data();
      if(current?.role==='user'&&current.createdBy===ref.id)tx.update(child.ref,{unit:parent.unit,updatedAt:stamp(),updatedBy:uid});
    });
    const requests=await db.collection('admin_requests').where('targetUid','==',ref.id).get();
    for(const request of requests.docs)await db.runTransaction(async tx=>{
      const parent=(await tx.get(ref)).data();tx.update(request.ref,{unit:parent.unit});
    });
    await db.collection('account_audit').add({actorId:uid,targetUid:ref.id,action:'assign_unit',unit,at:stamp()});
    return {updated:true};
  }
  return { setUnit, setStatus, importUsers, proposeAdmin, decideAdmin, deleteUser, updateUser, checkUsernames };
}
