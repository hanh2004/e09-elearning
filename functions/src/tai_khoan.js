// Ghép các nghiệp vụ tài khoản thành API callable.
// Từng nhóm nghiệp vụ nằm trong module riêng; quy_tac.js kiểm tra quyền và dữ liệu.
import { FieldValue } from 'firebase-admin/firestore';
import { createImportUsersHandler } from './nhap_hoc_vien.js';
import { createSetUnitHandler } from './gan_don_vi.js';
import { createPasswordResetHandlers } from './cap_lai_mat_khau.js';
import { fingerprint, isRoot, loginEmail, requireAdmin, requireDecision, rootIds,
  requireDelete, requireRoot, requireThat, requireUpdate, userCodeKey,
  makeUserCode, usernameKey, validateRows, validateUnit, validateSubUnit, userCodeSuffix } from './quy_tac.js';

// Mọi lần ghi dùng Admin SDK. Client không được tự gửi UID người thao tác hoặc vai trò.
export function accountHandlers(coSoDuLieu, xacThuc) {
  const stamp = () => FieldValue.serverTimestamp();
  async function nguCanh(giaoDich, maNguoiDung) {
    requireThat(typeof maNguoiDung === 'string' && maNguoiDung.length > 0, 'unauthenticated', 'Cần đăng nhập.');
    const cauHinh = (await giaoDich.get(coSoDuLieu.doc('system/access'))).data();
    const nguoiThaoTac = { ...(await giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}`))).data(), id: maNguoiDung };
    requireAdmin(nguoiThaoTac, cauHinh);
    requireThat(nguoiThaoTac.adminDeletionPending !== true, 'failed-precondition',
      'Tài khoản quản lý đang chờ duyệt xóa.');
    requireThat(nguoiThaoTac.unitChangePending !== true, 'failed-precondition',
      'Tài khoản đang đổi đơn vị. Hãy chờ thao tác hoàn tất rồi thử lại.');
    return { actor: nguoiThaoTac, config: cauHinh };
  }
  const userRef = (ma) => {
    requireThat(typeof ma === 'string' && /^[A-Za-z0-9_=-]{1,128}$/.test(ma),
      'invalid-argument', 'Mã tài khoản không hợp lệ.');
    return coSoDuLieu.doc(`users/${ma}`);
  };
  // Đọc trước, ghi sau để mọi thay đổi mã và đơn vị cùng thành công hoặc cùng hủy.
  async function unitReservation(giaoDich, donVi, managerId) {
    const giaTri = validateUnit(donVi);
    requireThat(userCodeKey(giaTri) !== userCodeKey('E09'), 'already-exists',
      'Mã E09 dành cho quản lý tổng. Hãy chọn mã đơn vị khác.');
    const thamChieu = coSoDuLieu.doc(`unit_codes/${userCodeKey(giaTri)}`);
    const reserved = await giaoDich.get(thamChieu);
    requireThat(!reserved.exists || reserved.data().managerId === managerId,
      'already-exists', 'Mã đơn vị đã được quản lý khác sử dụng.');
    // Giữ đường quét tương thích đến khi backfill đã lập đủ reservation cho dữ liệu cũ.
    const indexesReady = (await giaoDich.get(coSoDuLieu.doc('system/code_indexes'))).data()?.status === 'complete';
    if (!indexesReady) {
      const managers = await giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'admin'));
      requireThat(!managers.docs.some(banGhi => banGhi.id !== managerId &&
        banGhi.data().status !== 'rejected' && typeof banGhi.data().unit === 'string' &&
        userCodeKey(banGhi.data().unit) === userCodeKey(giaTri)),
      'already-exists', 'Mã đơn vị đã được quản lý khác sử dụng.');
    }
    return () => giaoDich.set(thamChieu, {unit: giaTri, managerId});
  }
  async function assignment({giaoDich, thamChieu, dich, donVi, managerId, actorId,
    existingLearners, requestedSuffix, unitChangeOperationId}) {
    const manager = (await giaoDich.get(userRef(managerId))).data();
    requireThat(manager?.adminDeletionPending !== true, 'failed-precondition',
      'Không thể chuyển học viên cho quản lý đang chờ duyệt xóa.');
    requireThat(manager?.unitChangePending !== true ||
      manager.unitChangeOperationId === unitChangeOperationId,
    'failed-precondition', 'Quản lý đang đổi đơn vị. Hãy thử lại sau.');
    if (dich.createdBy && dich.createdBy !== managerId) {
      const sourceManager = (await giaoDich.get(userRef(dich.createdBy))).data();
      requireThat(sourceManager?.adminDeletionPending !== true, 'failed-precondition',
        'Quản lý hiện tại đã được duyệt xóa và đang được xử lý. Không thể chuyển học viên lúc này.');
      requireThat(sourceManager?.unitChangePending !== true ||
        sourceManager.unitChangeOperationId === unitChangeOperationId,
      'failed-precondition', 'Đơn vị hiện tại đang được đổi. Hãy thử chuyển học viên sau.');
    }
    const suffix = typeof requestedSuffix === 'string'
      ? requestedSuffix.trim() : userCodeSuffix(dich, thamChieu.id);
    const maLoi = makeUserCode(donVi, suffix);
    const nextRef = coSoDuLieu.doc(`user_codes/${userCodeKey(maLoi)}`);
    const tiepTheo = await giaoDich.get(nextRef);
    requireThat(!tiepTheo.exists || tiepTheo.data().uid === thamChieu.id, 'already-exists',
      'Mã người dùng tại đơn vị mới đã được sử dụng.');
    if (!tiepTheo.exists) {
      const indexesReady = (await giaoDich.get(coSoDuLieu.doc('system/code_indexes'))).data()?.status === 'complete';
      if (!indexesReady) {
        const learners = existingLearners || await giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'user'));
        requireThat(!learners.docs.some(banGhi => banGhi.id !== thamChieu.id &&
          typeof banGhi.data().userCode === 'string' &&
          userCodeKey(banGhi.data().userCode) === userCodeKey(maLoi)),
        'already-exists', 'Mã người dùng tại đơn vị mới đã được sử dụng.');
      }
    }
    const oldRef = dich.userCode ? coSoDuLieu.doc(`user_codes/${userCodeKey(dich.userCode)}`) : null;
    const cu = oldRef && oldRef.path !== nextRef.path ? await giaoDich.get(oldRef) : null;
    const changed = userCodeKey(dich.unit || '') !== userCodeKey(donVi) || dich.createdBy !== managerId;
    return () => {
      giaoDich.set(nextRef, {uid: thamChieu.id, code: maLoi, createdBy: managerId, updatedAt: stamp()});
      if (cu?.exists && cu.data().uid === thamChieu.id) giaoDich.delete(oldRef);
      giaoDich.update(thamChieu, {unit: donVi, createdBy: managerId, userCode: maLoi, userCodeSuffix: suffix,
        originalCreatedBy: FieldValue.delete(),
        learnerDeletionPending: FieldValue.delete(),
        learnerDeletionRequestId: FieldValue.delete(),
        ...(changed ? {subUnit: '', unitNeedsConfirmation: true,
          unitAssignmentVersion: (dich.unitAssignmentVersion || 0) + 1} : {}),
        updatedBy: actorId, updatedAt: stamp()});
      if (changed) giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {
        actorId, targetUid: thamChieu.id, action: 'reassign_user',
        previousManagerId: dich.createdBy || null, previousUnit: dich.unit || null,
        managerId, unit: donVi, at: stamp(),
      });
    };
  }
  async function ensureAuth(maNguoiDung, dong) {
    try {
      await xacThuc.createUser({ uid: maNguoiDung, email: loginEmail(dong.username),
        password: dong.password, displayName: dong.name, disabled: true });
    } catch (loi) {
      if (loi.code !== 'auth/uid-already-exists') throw loi;
      const daTonTai = await xacThuc.getUser(maNguoiDung);
      requireThat(daTonTai.email === loginEmail(dong.username), 'already-exists', 'Tài khoản đã tồn tại.');
    }
  }
  const importUsers = createImportUsersHandler({
    coSoDuLieu,
    xacThuc,
    stamp,
    nguCanh,
    unitReservation,
    userRef,
    ensureAuth,
  });
  const setUnit = createSetUnitHandler({
    coSoDuLieu, userRef, nguCanh, requireRoot, requireThat, validateUnit,
    userCodeKey, makeUserCode, userCodeSuffix, unitReservation, assignment, stamp,
  });
  const passwordResetHandlers = createPasswordResetHandlers({
    coSoDuLieu, xacThuc, userRef, nguCanh, stamp,
  });

  async function proposeAdmin(maNguoiDung, dauVao) {
    const dong = validateRows([dauVao.account])[0];
    const donVi = validateUnit(dauVao.unit);
    requireThat(typeof dauVao.operationId === 'string' && /^[a-f0-9]{32}$/.test(dauVao.operationId),
      'invalid-argument', 'Thiếu mã thao tác.');
    const thamChieuYeuCau = coSoDuLieu.doc(`admin_requests/${maNguoiDung}_${dauVao.operationId}`);
    const digest = fingerprint({...dong,unit: donVi});
    const yeuCau = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(nguoiThaoTac, cauHinh);
      const cu = await giaoDich.get(thamChieuYeuCau);
      if (cu.exists) {
        const secret = (await giaoDich.get(coSoDuLieu.doc(`admin_request_secrets/${thamChieuYeuCau.id}`))).data();
        requireThat(secret?.digest === digest, 'invalid-argument', 'Mã thao tác đã được dùng.');
        return cu.data();
      }
      const nameRef = coSoDuLieu.doc(`usernames/${usernameKey(dong.username)}`);
      requireThat(!(await giaoDich.get(nameRef)).exists, 'already-exists', 'Tên đăng nhập đã được sử dụng.');
      const maTaiKhoanDich = coSoDuLieu.collection('users').doc().id;
      const reserveUnit = await unitReservation(giaoDich, donVi, maTaiKhoanDich);
      const giaTri = { targetUid: maTaiKhoanDich, name: dong.name, username: dong.username, unit: donVi,
        createdBy: maNguoiDung, status: 'provisioning' };
      // Mã băm là dữ liệu riêng, không lưu trong yêu cầu có thể đọc.
      reserveUnit();
      giaoDich.create(coSoDuLieu.doc(`admin_request_secrets/${thamChieuYeuCau.id}`), { digest });
      giaoDich.create(nameRef, { uid: maTaiKhoanDich, username: dong.username });
      giaoDich.create(userRef(maTaiKhoanDich), { name: dong.name, username: dong.username,
        role: 'admin', unit: donVi, status: 'pending', createdBy: maNguoiDung, createdAt: stamp() });
      giaoDich.create(thamChieuYeuCau, { ...giaTri, createdAt: stamp() });
      return { ...giaTri, digest };
    });
    if (yeuCau.status !== 'provisioning') return { requestId: thamChieuYeuCau.id };
    await ensureAuth(yeuCau.targetUid, dong);
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(nguoiThaoTac, cauHinh);
      const hienTai = (await giaoDich.get(thamChieuYeuCau)).data();
      if (hienTai.status === 'provisioning') giaoDich.update(thamChieuYeuCau, { status: 'pending' });
    });
    return { requestId: thamChieuYeuCau.id };
  }

  async function decideAdmin(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.requestId === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(dauVao.requestId) &&
      typeof dauVao.approve === 'boolean', 'invalid-argument', 'Yêu cầu không hợp lệ.');
    const thamChieu = coSoDuLieu.doc(`admin_requests/${dauVao.requestId}`);
    const tiepTheo = dauVao.approve ? 'approved' : 'rejected';
    const maTaiKhoanDich = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const yeuCau = (await giaoDich.get(thamChieu)).data();
      requireThat(yeuCau, 'not-found', 'Không tìm thấy yêu cầu.');
      requireDecision(nguoiThaoTac, cauHinh, yeuCau);
      requireThat(yeuCau.status === 'pending' ||
        (yeuCau.status === tiepTheo && yeuCau.decidedBy === maNguoiDung),
      'failed-precondition', 'Yêu cầu đã được xử lý hoặc chưa sẵn sàng.');
      const dich = (await giaoDich.get(userRef(yeuCau.targetUid))).data();
      requireThat(dich?.status === 'pending' ||
        (yeuCau.status === tiepTheo && dich?.status === (dauVao.approve ? 'active' : 'rejected')),
      'failed-precondition', 'Tài khoản đã thay đổi trạng thái.');
      const unitRef = dich.unit ? coSoDuLieu.doc(`unit_codes/${userCodeKey(dich.unit)}`) : null;
      const unitRecord = !dauVao.approve && unitRef ? await giaoDich.get(unitRef) : null;
      if (unitRecord?.exists && unitRecord.data().managerId === yeuCau.targetUid) giaoDich.delete(unitRef);
      giaoDich.update(thamChieu, { status: tiepTheo, decidedBy: maNguoiDung, decidedAt: stamp() });
      giaoDich.update(userRef(yeuCau.targetUid), { status: dauVao.approve ? 'active' : 'rejected',
        approvedBy: dauVao.approve ? maNguoiDung : null });
      return yeuCau.targetUid;
    });
    // Gửi lại cùng quyết định vẫn an toàn nếu Auth lỗi tạm thời.
    await xacThuc.updateUser(maTaiKhoanDich, { disabled: !dauVao.approve });
    return { status: tiepTheo };
  }

  async function deleteUser(maNguoiDung, dauVao, {approvedAdminDeletion = false} = {}) {
    const thamChieu = userRef(dauVao.userId);
    const duLieu = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const duLieu = (await giaoDich.get(thamChieu)).data();
      requireThat(duLieu, 'not-found', 'Không tìm thấy tài khoản.');
      requireThat(duLieu.unitChangePending !== true, 'failed-precondition',
        'Không thể xóa quản lý khi đang đổi đơn vị.');
      if (duLieu.role === 'user' && duLieu.createdBy) {
        const manager = (await giaoDich.get(userRef(duLieu.createdBy))).data();
        requireThat(manager?.unitChangePending !== true, 'failed-precondition',
          'Đơn vị hiện tại đang được đổi. Hãy thử xóa học viên sau.');
      }
      requireDelete(nguoiThaoTac, cauHinh, { ...duLieu, id: thamChieu.id });
      // Chỉ xóa tài khoản admin phụ mới cần hai quản lý tổng duyệt.
      // Học viên được chuyển đã mang createdBy của quản lý hiện tại nên xóa trực tiếp.
      requireThat(duLieu.role !== 'admin' ||
        (approvedAdminDeletion && duLieu.adminDeletionPending === true),
      'failed-precondition', 'Xóa quản lý phụ phải được hai quản lý tổng duyệt.');
      requireThat(['active','blocked','deleting'].includes(duLieu.status), 'failed-precondition', 'Tài khoản chưa thể xóa.');
      giaoDich.update(thamChieu, {status:'deleting'});
      return duLieu;
    });
    const [attempts, requests, adminOperations] = await Promise.all([
      coSoDuLieu.collection('exam_attempts').where('userId', '==', thamChieu.id).get(),
      coSoDuLieu.collection('admin_requests').where('targetUid', '==', thamChieu.id).get(),
      duLieu.role === 'admin'
        ? coSoDuLieu.collection('account_operations').where('createdBy', '==', thamChieu.id).get()
        : Promise.resolve({docs: []}),
    ]);
    const cacLuotThiRieng = await coSoDuLieu.collection('exam_private_runs').where('userId','==',thamChieu.id).get();
    const cacPhien = await coSoDuLieu.collection('exam_sessions').where('userId','==',thamChieu.id).get();
    const boGhi = coSoDuLieu.bulkWriter();
    for (const luotThi of cacLuotThiRieng.docs) boGhi.delete(luotThi.ref);
    for (const phien of cacPhien.docs) {
      const cacLuotThi = await phien.ref.collection('runs').get();
      for (const luotThi of cacLuotThi.docs) boGhi.delete(luotThi.ref);
      boGhi.delete(phien.ref);
    }
    for (const banGhi of attempts.docs) {
      const cacLuotThi = await banGhi.ref.collection('runs').get();
      for (const luotThi of cacLuotThi.docs) boGhi.delete(luotThi.ref);
      boGhi.delete(banGhi.ref);
    }
    const learning = await thamChieu.collection('learning').get();
    for (const tienDo of learning.docs) boGhi.delete(tienDo.ref);
    const notificationReads = await thamChieu.collection('notification_reads').get();
    for (const receipt of notificationReads.docs) boGhi.delete(receipt.ref);
    for (const banGhi of requests.docs) {
      boGhi.delete(banGhi.ref);
      boGhi.delete(coSoDuLieu.doc(`admin_request_secrets/${banGhi.id}`));
    }
    for (const operation of adminOperations.docs) boGhi.delete(operation.ref);
    // Yêu cầu cấp lại mật khẩu dùng UID làm ID nên xóa cùng hồ sơ học viên.
    boGhi.delete(coSoDuLieu.doc(`password_reset_requests/${thamChieu.id}`));
    await boGhi.close();
    try {
      await xacThuc.deleteUser(thamChieu.id);
    } catch (loi) {
      if (loi.code !== 'auth/user-not-found') throw loi;
    }
    // Giữ hồ sơ và tên đăng nhập trong lúc xóa cho tới khi Auth xong,
    // để có thể thử lại khi Auth tạm mất mà không tạo tài khoản mồ côi.
    await coSoDuLieu.runTransaction(async giaoDich => {
      const codeRef = duLieu.userCode ? coSoDuLieu.doc(`user_codes/${userCodeKey(duLieu.userCode)}`) : null;
      const unitRef = duLieu.role === 'admin' && duLieu.unit
        ? coSoDuLieu.doc(`unit_codes/${userCodeKey(duLieu.unit)}`) : null;
      const [maLoi, unitReservation] = await Promise.all([
        codeRef ? giaoDich.get(codeRef) : null,
        unitRef ? giaoDich.get(unitRef) : null,
      ]);
      giaoDich.delete(coSoDuLieu.doc(`usernames/${usernameKey(duLieu.username)}`));
      giaoDich.delete(thamChieu);
      if (maLoi?.exists && maLoi.data().uid === thamChieu.id) giaoDich.delete(codeRef);
      if (unitReservation?.exists && unitReservation.data().managerId === thamChieu.id) {
        giaoDich.delete(unitRef);
      }
    });
    return { deleted: true };
  }

  async function requestAdminDeletion(maNguoiDung, dauVao) {
    const targetRef = userRef(dauVao.userId);
    const requestRef = coSoDuLieu.doc(`admin_delete_requests/${targetRef.id}`);
    return coSoDuLieu.runTransaction(async giaoDich => {
      const {actor, config} = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(actor, config);
      const [targetSnapshot, requestSnapshot] = await Promise.all([
        giaoDich.get(targetRef), giaoDich.get(requestRef),
      ]);
      const target = targetSnapshot.data();
      requireThat(target?.role === 'admin' && ['active', 'blocked'].includes(target.status),
        'failed-precondition', 'Chỉ có thể đề xuất xóa quản lý phụ đang hoạt động hoặc bị khóa.');
      requireThat(target.unitChangePending !== true, 'failed-precondition',
        'Không thể xóa quản lý khi đang đổi đơn vị.');
      const oldRequest = requestSnapshot.data();
      if (['pending', 'processing'].includes(oldRequest?.status)) {
        requireThat(oldRequest.createdBy === maNguoiDung, 'already-exists',
          'Quản lý này đã có yêu cầu xóa đang chờ xử lý.');
        if (oldRequest.status === 'pending') {
          giaoDich.update(targetRef, {
            adminDeletionPending: FieldValue.delete(),
            adminDeletionRequestId: FieldValue.delete(),
          });
        }
        return {status: oldRequest.status};
      }
      if (oldRequest?.status === 'provisioning') {
        requireThat(oldRequest.createdBy === maNguoiDung, 'already-exists',
          'Quản lý này đã có yêu cầu xóa đang được tạo.');
        giaoDich.update(targetRef, {
          adminDeletionPending: FieldValue.delete(),
          adminDeletionRequestId: FieldValue.delete(),
        });
        giaoDich.update(requestRef, {status: 'pending', updatedAt: stamp()});
        return {status: 'pending'};
      }
      if (target.adminDeletionRequestId === requestRef.id) {
        giaoDich.update(targetRef, {
          adminDeletionPending: FieldValue.delete(),
          adminDeletionRequestId: FieldValue.delete(),
        });
      }
      giaoDich.set(requestRef, {
        targetUid: targetRef.id,
        name: target.name ?? '',
        username: target.username ?? '',
        unit: target.unit ?? '',
        createdBy: maNguoiDung,
        createdAt: stamp(),
        updatedAt: stamp(),
        status: 'pending',
      });
      return {status: 'pending'};
    });
  }

  async function decideAdminDeletion(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.requestId === 'string' && /^[A-Za-z0-9_=-]{1,128}$/.test(dauVao.requestId) &&
      typeof dauVao.approve === 'boolean', 'invalid-argument', 'Yêu cầu xóa không hợp lệ.');
    const requestRef = coSoDuLieu.doc(`admin_delete_requests/${dauVao.requestId}`);
    const targetRef = userRef(dauVao.requestId);
    const shouldProcess = await coSoDuLieu.runTransaction(async giaoDich => {
      const {actor, config} = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(actor, config);
      const request = (await giaoDich.get(requestRef)).data();
      requireThat(request, 'not-found', 'Không tìm thấy yêu cầu xóa.');
      if (request.status === 'processing') {
        requireThat(dauVao.approve, 'failed-precondition',
          'Yêu cầu đã được duyệt; chỉ có thể tiếp tục hoàn tất thao tác xóa.');
        return true;
      }
      requireDecision(actor, config, request);
      requireThat(request.status === 'pending', 'failed-precondition',
        'Yêu cầu xóa đã được xử lý hoặc chưa sẵn sàng.');
      const targetSnapshot = await giaoDich.get(targetRef);
      const target = targetSnapshot.data();
      requireThat(target?.role === 'admin' && ['active', 'blocked'].includes(target.status),
        'failed-precondition', 'Tài khoản quản lý không còn ở trạng thái có thể xóa.');
      if (!dauVao.approve) {
        giaoDich.update(requestRef, {status: 'rejected', decidedBy: maNguoiDung,
          decidedAt: stamp(), updatedAt: stamp()});
        if (target.adminDeletionRequestId === requestRef.id) {
          giaoDich.update(targetRef, {adminDeletionPending: FieldValue.delete(),
            adminDeletionRequestId: FieldValue.delete()});
        }
        return false;
      }
      requireThat(target.unitChangePending !== true, 'failed-precondition',
        'Không thể xóa quản lý khi đang đổi đơn vị.');
      const [assigned, operations] = await Promise.all([
        giaoDich.get(coSoDuLieu.collection('users').where('createdBy', '==', targetRef.id)),
        giaoDich.get(coSoDuLieu.collection('account_operations').where('createdBy', '==', targetRef.id)),
      ]);
      const learners = assigned.docs.filter(row => row.data().role === 'user');
      requireThat(!operations.docs.some(row => row.data().status === 'provisioning') &&
        !learners.some(row => row.data().status === 'provisioning'),
      'failed-precondition', 'Quản lý đang nhập học viên. Hãy đợi thao tác nhập hoàn tất rồi duyệt lại.');
      giaoDich.update(targetRef, {
        adminDeletionPending: true,
        adminDeletionRequestId: requestRef.id,
      });
      giaoDich.update(requestRef, {status: 'processing', decidedBy: maNguoiDung,
        decidedAt: stamp(), updatedAt: stamp()});
      return true;
    });

    if (!shouldProcess) return {status: 'rejected'};
    if (!(await targetRef.get()).exists) {
      await requestRef.update({status: 'approved', completedAt: stamp(), updatedAt: stamp()});
      return {status: 'approved'};
    }
    while (true) {
      const currentLearners = (await coSoDuLieu.collection('users')
        .where('createdBy', '==', targetRef.id).get()).docs
        .filter(row => row.data().role === 'user');
      if (currentLearners.length === 0) break;
      for (let start = 0; start < currentLearners.length; start += 20) {
        await Promise.all(currentLearners.slice(start, start + 20).map(row =>
          deleteUser(maNguoiDung, {userId: row.id})));
      }
    }
    const target = (await targetRef.get()).data();
    if (target) {
      await deleteUser(maNguoiDung, {userId: targetRef.id}, {approvedAdminDeletion: true});
    }
    await requestRef.update({status: 'approved', completedAt: stamp(), updatedAt: stamp()});
    return {status: 'approved'};
  }

  async function updateUser(maNguoiDung, dauVao) {
    const thamChieu = userRef(dauVao.userId);
    requireThat(!dauVao.password, 'failed-precondition',
      'Hãy xử lý yêu cầu cấp lại mật khẩu.');
    requireThat(typeof dauVao.name === 'string' && dauVao.name.trim().length > 0 && dauVao.name.length <= 100 &&
      !Object.hasOwn(dauVao, 'role') && !Object.hasOwn(dauVao, 'createdBy') && !Object.hasOwn(dauVao, 'username') &&
      !Object.hasOwn(dauVao, 'unit') &&
      (!Object.hasOwn(dauVao, 'userCodeSuffix') || typeof dauVao.userCodeSuffix === 'string'),
    'invalid-argument', 'Thông tin cập nhật không hợp lệ.');
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const dich = (await giaoDich.get(thamChieu)).data();
      requireThat(dich, 'not-found', 'Không tìm thấy tài khoản.');
      requireThat(dich.unitChangePending !== true, 'failed-precondition',
        'Không thể sửa tài khoản khi đang đổi đơn vị.');
      if (dich.role === 'user' && dich.createdBy) {
        const manager = (await giaoDich.get(userRef(dich.createdBy))).data();
        requireThat(manager?.unitChangePending !== true, 'failed-precondition',
          'Đơn vị hiện tại đang được đổi. Hãy thử sửa học viên sau.');
      }
      requireUpdate(nguoiThaoTac, cauHinh, { ...dich, id: thamChieu.id });
      requireThat(dich?.status === 'active', 'failed-precondition', 'Tài khoản chưa hoạt động.');
      requireThat(!Object.hasOwn(dauVao, 'userCodeSuffix') ||
        (dich.role === 'user' && dich.createdBy === nguoiThaoTac.id),
      'permission-denied', 'Chỉ quản lý phụ trách mới được đổi phần đuôi mã người dùng.');

      const oldSuffix = userCodeSuffix(dich, thamChieu.id);
      const nextUnit = dich.unit;
      const nextSuffix = Object.hasOwn(dauVao, 'userCodeSuffix')
        ? dauVao.userCodeSuffix.trim() : oldSuffix;
      const codeChanged = Object.hasOwn(dauVao, 'userCodeSuffix');
      const updates = { name: dauVao.name.trim(), updatedBy: maNguoiDung, updatedAt: stamp() };
      if (codeChanged) {
        const oldCode = dich.userCode || makeUserCode(dich.unit, oldSuffix);
        const newCode = makeUserCode(nextUnit, nextSuffix);
        const oldRef = coSoDuLieu.doc(`user_codes/${userCodeKey(oldCode)}`);
        const nextRef = coSoDuLieu.doc(`user_codes/${userCodeKey(newCode)}`);
        const [oldReservation, nextReservation, learners] = await Promise.all([
          giaoDich.get(oldRef), giaoDich.get(nextRef),
          giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'user')),
        ]);
        requireThat(!nextReservation.exists || nextReservation.data().uid === thamChieu.id,
          'already-exists', 'Mã người dùng đã được sử dụng.');
        requireThat(!learners.docs.some(row => row.id !== thamChieu.id &&
          typeof row.data().userCode === 'string' && userCodeKey(row.data().userCode) === userCodeKey(newCode)),
        'already-exists', 'Mã người dùng đã được sử dụng.');
        if (oldRef.path !== nextRef.path && oldReservation.exists && oldReservation.data().uid === thamChieu.id) {
          giaoDich.delete(oldRef);
        }
        giaoDich.set(nextRef, { uid: thamChieu.id, code: newCode,
          createdBy: dich.createdBy || maNguoiDung, updatedAt: stamp() });
        updates.userCode = newCode;
        updates.userCodeSuffix = nextSuffix;
        giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {
          actorId: maNguoiDung, targetUid: thamChieu.id, action: 'change_user_code_suffix',
          previousCode: oldCode, code: newCode, at: stamp(),
        });
      }
      giaoDich.update(thamChieu, updates);
    });
    return { updated: true };
  }

  async function checkUsernames(maNguoiDung, dauVao) {
    requireThat(Array.isArray(dauVao.usernames) && dauVao.usernames.length <= 200 &&
      dauVao.usernames.every((n) => typeof n === 'string' && n.length <= 64),
    'invalid-argument', 'Danh sách không hợp lệ.');
    await coSoDuLieu.runTransaction(async (giaoDich) => { await nguCanh(giaoDich, maNguoiDung); });
    const refs = dauVao.usernames.map((ten) => coSoDuLieu.doc(`usernames/${usernameKey(ten)}`));
    if (!refs.length) return { existing: [] };
    const cacBanGhi = await coSoDuLieu.getAll(...refs);
    return { existing: dauVao.usernames.filter((_, i) => cacBanGhi[i].exists) };
  }
  async function setStatus(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.disabled === 'boolean', 'invalid-argument', 'Trạng thái không hợp lệ.');
    const thamChieu = userRef(dauVao.userId);
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const {actor: nguoiThaoTac,config: cauHinh} = await nguCanh(giaoDich,maNguoiDung);
      const dich = (await giaoDich.get(thamChieu)).data();
      requireThat(dich, 'not-found', 'Không tìm thấy tài khoản.');
      requireUpdate(nguoiThaoTac,cauHinh,{...dich,id:thamChieu.id});
      requireThat(['active','blocked'].includes(dich.status), 'failed-precondition', 'Tài khoản đang chờ xử lý.');
      if (dauVao.disabled) giaoDich.update(thamChieu,{status:'blocked',updatedBy:maNguoiDung,updatedAt:stamp()});
    });
    await xacThuc.updateUser(thamChieu.id,{disabled:dauVao.disabled});
    if(dauVao.disabled) await xacThuc.revokeRefreshTokens(thamChieu.id);
    else await thamChieu.update({status:'active',updatedBy:maNguoiDung,updatedAt:stamp()});
    await coSoDuLieu.collection('account_audit').add({actorId:maNguoiDung,targetUid:thamChieu.id,action:dauVao.disabled?'block':'unblock',at:stamp()});
    return {status:dauVao.disabled?'blocked':'active'};
  }
  async function getSubUnits(maNguoiDung) {
    return coSoDuLieu.runTransaction(async giaoDich => {
      const learner = (await giaoDich.get(userRef(maNguoiDung))).data();
      requireThat(learner?.status === 'active', 'permission-denied', 'Tài khoản chưa hoạt động.');
      const managerId = learner.createdBy;
      if (!managerId) return {managerId: '', subUnits: []};
      const manager = (await giaoDich.get(userRef(managerId))).data();
      return {managerId, subUnits: Array.isArray(manager?.subUnits)
        ? manager.subUnits.filter(giaTri => typeof giaTri === 'string' && giaTri.trim().length > 0)
        : []};
    });
  }
  async function setSubUnits(maNguoiDung, dauVao) {
    requireThat(Array.isArray(dauVao.subUnits) && dauVao.subUnits.length <= 200,
      'invalid-argument', 'Danh sách trực thuộc không hợp lệ.');
    const cacGiaTri = [...new Set(dauVao.subUnits.map(validateSubUnit))];
    const targetRef = userRef(maNguoiDung);
    await coSoDuLieu.runTransaction(async giaoDich => {
      const {actor: nguoiThaoTac, config: cauHinh} = await nguCanh(giaoDich, maNguoiDung);
      const dich = (await giaoDich.get(targetRef)).data();
      requireThat(
        (isRoot(nguoiThaoTac, cauHinh) && dich?.role === 'super_admin') ||
          (!isRoot(nguoiThaoTac, cauHinh) && dich?.role === 'admin' &&
            ['active', 'pending'].includes(dich.status)),
        'permission-denied',
        'Chỉ được quản lý trực thuộc của chính tài khoản đang đăng nhập.',
      );
      giaoDich.update(targetRef, {subUnits: cacGiaTri, updatedBy: maNguoiDung, updatedAt: stamp()});
      giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {
        actorId: maNguoiDung, targetUid: maNguoiDung, action: 'set_sub_units', subUnits: cacGiaTri, at: stamp(),
      });
    });
    return {updated: true, subUnits: cacGiaTri};
  }
  async function reassignUser(maNguoiDung, dauVao) {
    const targetRef = userRef(dauVao.userId);
    const managerRef = userRef(dauVao.managerId);
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(nguoiThaoTac, cauHinh);
      const dich = (await giaoDich.get(targetRef)).data();
      const manager = (await giaoDich.get(managerRef)).data();
      requireThat(dich?.role === 'user' && ['active', 'blocked'].includes(dich.status),
        'failed-precondition', 'Chỉ có thể chuyển học viên đang hoạt động hoặc bị khóa.');
      const managerIsRoot = manager?.role === 'super_admin' &&
        manager.status === 'active' && rootIds(cauHinh).includes(managerRef.id);
      const managerIsApprovedAdmin = manager?.role === 'admin' && manager.status === 'active' &&
        rootIds(cauHinh).includes(manager.createdBy) && rootIds(cauHinh).includes(manager.approvedBy) &&
        manager.createdBy !== manager.approvedBy;
      requireThat(managerIsRoot || managerIsApprovedAdmin,
        'failed-precondition', 'Quản lý mới chưa hoạt động hoặc chưa được phê duyệt.');
      const targetUnit = validateUnit(managerIsRoot ? 'E09' : manager.unit);
      requireThat(managerIsRoot || dich.createdBy === managerRef.id ||
        userCodeKey(targetUnit) !== userCodeKey(dich.unit || ''),
      'failed-precondition', 'Học viên đang do quản lý này phụ trách.');
      const reserve = managerIsRoot
        ? () => {}
        : await unitReservation(giaoDich, targetUnit, managerRef.id);
      const write = await assignment({
        giaoDich, thamChieu: targetRef, dich, donVi: targetUnit,
        managerId: managerRef.id, actorId: maNguoiDung,
      });
      const resetRequest = await giaoDich.get(coSoDuLieu.doc(`password_reset_requests/${targetRef.id}`));
      requireThat(resetRequest.data()?.status !== 'processing', 'failed-precondition',
        'Đang cấp lại mật khẩu. Thử chuyển quản lý sau khi hoàn tất.');
      reserve();
      write();
      if (resetRequest.exists && ['pending', 'approved_once', 'approved'].includes(resetRequest.data().status)) {
        giaoDich.update(resetRequest.ref, { managerId: managerRef.id, status: 'pending',
          firstApprovedBy: FieldValue.delete(), firstApprovedAt: FieldValue.delete(),
          secondApprovedBy: FieldValue.delete(), secondApprovedAt: FieldValue.delete(), updatedAt: stamp() });
      }
    });
    return { updated: true };
  }
  return { setUnit, setStatus, importUsers, proposeAdmin, decideAdmin, deleteUser,
    requestAdminDeletion, decideAdminDeletion, updateUser,
    checkUsernames, reassignUser, setSubUnits, getSubUnits, ...passwordResetHandlers };
}
