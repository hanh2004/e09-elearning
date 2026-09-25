// API TÀI KHOẢN: tạo/import học viên, duyệt admin, sửa hồ sơ và khóa/xóa tài khoản.
// accountHandlers chứa từng thao tác; policy.js kiểm tra quyền và dữ liệu đầu vào.
import { FieldValue } from 'firebase-admin/firestore';
import { fingerprint, isRoot, loginEmail, requireAdmin, requireDecision, rootIds,
  requireDelete, requireRoot, requireThat, requireUpdate, userCodeKey,
  makeUserCode, usernameKey, validateRows, validateUnit, validateSubUnit, userCodeSuffix } from './policy.js';

// Mọi lần ghi dùng Admin SDK. Client không được tự gửi UID người thao tác hoặc vai trò.
export function accountHandlers(coSoDuLieu, xacThuc) {
  const stamp = () => FieldValue.serverTimestamp();
  async function nguCanh(giaoDich, maNguoiDung) {
    requireThat(typeof maNguoiDung === 'string' && maNguoiDung.length > 0, 'unauthenticated', 'Cần đăng nhập.');
    const cauHinh = (await giaoDich.get(coSoDuLieu.doc('system/access'))).data();
    const nguoiThaoTac = { ...(await giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}`))).data(), id: maNguoiDung };
    requireAdmin(nguoiThaoTac, cauHinh);
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
    // Bao gồm tài khoản cũ chưa có bản ghi giữ mã.
    const managers = await giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'admin'));
    requireThat(!managers.docs.some(banGhi => banGhi.id !== managerId &&
      banGhi.data().status !== 'rejected' && typeof banGhi.data().unit === 'string' &&
      userCodeKey(banGhi.data().unit) === userCodeKey(giaTri)),
    'already-exists', 'Mã đơn vị đã được quản lý khác sử dụng.');
    return () => giaoDich.set(thamChieu, {unit: giaTri, managerId});
  }
  async function assignment(giaoDich, thamChieu, dich, donVi, managerId, actorId, existingLearners, requestedSuffix) {
    const suffix = typeof requestedSuffix === 'string'
      ? requestedSuffix.trim() : userCodeSuffix(dich, thamChieu.id);
    const maLoi = makeUserCode(donVi, suffix);
    const nextRef = coSoDuLieu.doc(`user_codes/${userCodeKey(maLoi)}`);
    const tiepTheo = await giaoDich.get(nextRef);
    requireThat(!tiepTheo.exists || tiepTheo.data().uid === thamChieu.id, 'already-exists',
      'Mã người dùng tại đơn vị mới đã được sử dụng.');
    if (!tiepTheo.exists) {
      const learners = existingLearners || await giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'user'));
      requireThat(!learners.docs.some(banGhi => banGhi.id !== thamChieu.id &&
        typeof banGhi.data().userCode === 'string' &&
        userCodeKey(banGhi.data().userCode) === userCodeKey(maLoi)),
      'already-exists', 'Mã người dùng tại đơn vị mới đã được sử dụng.');
    }
    const oldRef = dich.userCode ? coSoDuLieu.doc(`user_codes/${userCodeKey(dich.userCode)}`) : null;
    const cu = oldRef && oldRef.path !== nextRef.path ? await giaoDich.get(oldRef) : null;
    const changed = userCodeKey(dich.unit || '') !== userCodeKey(donVi) || dich.createdBy !== managerId;
    if (changed && dich.userCode) requireThat(userCodeKey(dich.userCode) !== userCodeKey(maLoi),
      'invalid-argument', 'Mã mới phải khác mã cũ.');
    return () => {
      giaoDich.set(nextRef, {uid: thamChieu.id, code: maLoi, createdBy: managerId, updatedAt: stamp()});
      if (cu?.exists && cu.data().uid === thamChieu.id) giaoDich.delete(oldRef);
      giaoDich.update(thamChieu, {unit: donVi, createdBy: managerId, userCode: maLoi, userCodeSuffix: suffix,
        originalCreatedBy: dich.originalCreatedBy || dich.createdBy || managerId,
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

  async function importUsers(maNguoiDung, dauVao) {
    const cacDong = validateRows(dauVao.rows);
    requireThat(typeof dauVao.operationId === 'string' && /^[a-f0-9]{32}$/.test(dauVao.operationId),
      'invalid-argument', 'Thiếu mã thao tác.');
    const opRef = coSoDuLieu.doc(`account_operations/${maNguoiDung}_${dauVao.operationId}`);
    const digest = fingerprint(cacDong);
    const op = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const {actor: nguoiThaoTac,config: cauHinh} = await nguCanh(giaoDich, maNguoiDung);
      const cu = await giaoDich.get(opRef);
      if (cu.exists) {
        requireThat(cu.data().digest === digest, 'invalid-argument', 'Mã thao tác đã được dùng cho dữ liệu khác.');
        return cu.data();
      }
      const donVi = isRoot(nguoiThaoTac,cauHinh) ? 'E09' : nguoiThaoTac.unit;
      requireThat(typeof donVi === 'string' && donVi.trim().length > 0, 'failed-precondition', 'Quản lý chưa được phân mã đơn vị. Liên hệ quản lý tổng.');
      const allowedSubUnits = new Set(Array.isArray(nguoiThaoTac.subUnits) ? nguoiThaoTac.subUnits : []);
      const reserveUnit = isRoot(nguoiThaoTac, cauHinh) ? () => {} : await unitReservation(giaoDich, donVi, maNguoiDung);
      const suffixes = cacDong.map((dong) => (dong.code || dong.username).trim());
      const codes = suffixes.map((suffix) => makeUserCode(donVi, suffix));
      const codeKeys = codes.map((maLoi) => userCodeKey(maLoi));
      requireThat(new Set(codeKeys).size === codeKeys.length,
        'already-exists', 'Mã người dùng bị trùng trong danh sách.');
      const refs = cacDong.map((r) => coSoDuLieu.doc(`usernames/${usernameKey(r.username)}`));
      for (const thamChieu of refs) {
        requireThat(!(await giaoDich.get(thamChieu)).exists, 'already-exists', 'Tên đăng nhập đã được sử dụng hoặc đang chờ xử lý.');
      }
      const codeRefs = codeKeys.map((khoa) => coSoDuLieu.doc(`user_codes/${khoa}`));
      for (const thamChieu of codeRefs) {
        requireThat(!(await giaoDich.get(thamChieu)).exists, 'already-exists', 'Mã người dùng đã được sử dụng. Hãy chọn mã khác.');
      }
      const learners = await giaoDich.get(coSoDuLieu.collection('users').where('role', '==', 'user'));
      requireThat(!learners.docs.some(banGhi => typeof banGhi.data().userCode === 'string' &&
        codeKeys.includes(userCodeKey(banGhi.data().userCode))),
      'already-exists', 'Mã người dùng đã được sử dụng. Hãy chọn mã khác.');
      const ids = cacDong.map(() => coSoDuLieu.collection('users').doc().id);
      reserveUnit();
      cacDong.forEach((dong, i) => {
        if (dong.subUnit) requireThat(allowedSubUnits.has(dong.subUnit),
          'permission-denied', 'Trực thuộc không thuộc quản lý đang tạo học viên.');
        giaoDich.create(refs[i], { uid: ids[i], username: dong.username });
        giaoDich.create(codeRefs[i], { uid: ids[i], code: codes[i], createdBy: maNguoiDung, createdAt: stamp() });
        giaoDich.create(userRef(ids[i]), { name: dong.name, username: dong.username,
          role: 'user',           unit:donVi.trim(), ...(dong.subUnit ? {subUnit: dong.subUnit} : {}),
          userCode: codes[i], userCodeSuffix: suffixes[i],
          status: 'provisioning', createdBy: maNguoiDung, originalCreatedBy: maNguoiDung,
          unitNeedsConfirmation: true, unitAssignmentVersion: 0, createdAt: stamp() });
      });
      const giaTri = { ids, digest, status: 'provisioning', createdBy: maNguoiDung };
      giaoDich.create(opRef, { ...giaTri, createdAt: stamp() });
      return giaTri;
    });
    if (op.status === 'completed') return { count: op.ids.length };
    // Auth và Firestore không nằm trong cùng transaction: tạo các bản Auth trước.
    // Hồ sơ vẫn bị khóa cho tới lần kích hoạt nguyên tử cuối cùng.
    for (let batDau = 0; batDau < cacDong.length; batDau += 10) {
      const cacKetQua = await Promise.allSettled(cacDong.slice(batDau, batDau + 10).map(async (dong, i) => {
        const ma = op.ids[batDau + i];
        await ensureAuth(ma, dong);
        await xacThuc.updateUser(ma, { disabled: false });
      }));
      const failed = cacKetQua.find((r) => r.status === 'rejected');
      if (failed) throw failed.reason;
    }
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const {actor: nguoiThaoTac,config: cauHinh}=await nguCanh(giaoDich,maNguoiDung);
      requireAdmin(nguoiThaoTac, cauHinh);
      const hienTai = (await giaoDich.get(opRef)).data();
      if (hienTai.status === 'completed') return;
      for (const ma of op.ids) {
        requireThat((await giaoDich.get(userRef(ma))).data()?.status === 'provisioning',
          'failed-precondition', 'Tài khoản đang được xử lý bởi thao tác khác.');
      }
      // setUnit đồng bộ cả hồ sơ provisioning; không ghi đè đơn vị đã giữ mã.
      for (const ma of op.ids) giaoDich.update(userRef(ma), { status: 'active' });
      giaoDich.update(opRef, { status: 'completed', completedAt: stamp() });
    });
    return { count: op.ids.length };
  }

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

  async function deleteUser(maNguoiDung, dauVao) {
    const thamChieu = userRef(dauVao.userId);
    const duLieu = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const duLieu = (await giaoDich.get(thamChieu)).data();
      requireThat(duLieu, 'not-found', 'Không tìm thấy tài khoản.');
      requireDelete(nguoiThaoTac, cauHinh, { ...duLieu, id: thamChieu.id });
      requireThat(['active','blocked','deleting'].includes(duLieu.status), 'failed-precondition', 'Tài khoản chưa thể xóa.');
      giaoDich.update(thamChieu, {status:'deleting'});
      return duLieu;
    });
    const [attempts, requests] = await Promise.all([
      coSoDuLieu.collection('exam_attempts').where('userId', '==', thamChieu.id).get(),
      coSoDuLieu.collection('admin_requests').where('targetUid', '==', thamChieu.id).get(),
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
      const maLoi = codeRef ? await giaoDich.get(codeRef) : null;
      giaoDich.delete(coSoDuLieu.doc(`usernames/${usernameKey(duLieu.username)}`));
      giaoDich.delete(thamChieu);
      if (maLoi?.exists && maLoi.data().uid === thamChieu.id) giaoDich.delete(codeRef);
    });
    return { deleted: true };
  }

  async function updateUser(maNguoiDung, dauVao) {
    const thamChieu = userRef(dauVao.userId);
    requireThat(!dauVao.password, 'failed-precondition',
      'Hãy cấp lại mật khẩu từ yêu cầu đã được duyệt.');
    requireThat(typeof dauVao.name === 'string' && dauVao.name.trim().length > 0 && dauVao.name.length <= 100 &&
      (!dauVao.password || (typeof dauVao.password === 'string' && dauVao.password.length >= 6 && dauVao.password.length <= 128)) &&
      !Object.hasOwn(dauVao, 'role') && !Object.hasOwn(dauVao, 'createdBy') && !Object.hasOwn(dauVao, 'username') &&
      (!Object.hasOwn(dauVao, 'unit') || typeof dauVao.unit === 'string') &&
      (!Object.hasOwn(dauVao, 'userCodeSuffix') || typeof dauVao.userCodeSuffix === 'string'),
    'invalid-argument', 'Thông tin cập nhật không hợp lệ.');
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const dich = (await giaoDich.get(thamChieu)).data();
      requireThat(dich, 'not-found', 'Không tìm thấy tài khoản.');
      requireUpdate(nguoiThaoTac, cauHinh, { ...dich, id: thamChieu.id });
      requireThat(dich?.status === 'active', 'failed-precondition', 'Tài khoản chưa hoạt động.');
      const isRootActor = isRoot(nguoiThaoTac, cauHinh);
      requireThat(!(Object.hasOwn(dauVao, 'unit') || Object.hasOwn(dauVao, 'userCodeSuffix')) ||
        (dich.role === 'user' && (isRootActor
          ? Object.hasOwn(dauVao, 'unit') && !Object.hasOwn(dauVao, 'userCodeSuffix')
          : Object.hasOwn(dauVao, 'userCodeSuffix') && !Object.hasOwn(dauVao, 'unit'))),
      'permission-denied', 'Quản lý tổng chỉ đổi phần mã đơn vị; quản lý phụ trách chỉ đổi phần đuôi.');

      const oldSuffix = userCodeSuffix(dich, thamChieu.id);
      const nextUnit = Object.hasOwn(dauVao, 'unit') ? validateUnit(dauVao.unit) : dich.unit;
      const nextSuffix = Object.hasOwn(dauVao, 'userCodeSuffix')
        ? dauVao.userCodeSuffix.trim() : oldSuffix;
      const codeChanged = Object.hasOwn(dauVao, 'unit') || Object.hasOwn(dauVao, 'userCodeSuffix');
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
        updates.unit = nextUnit;
        updates.userCode = newCode;
        updates.userCodeSuffix = nextSuffix;
        giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {
          actorId: maNguoiDung, targetUid: thamChieu.id, action: isRootActor
            ? 'change_user_code_unit' : 'change_user_code_suffix',
          previousCode: oldCode, code: newCode, at: stamp(),
        });
      }
      giaoDich.update(thamChieu, updates);
    });
    return { updated: true };
  }

  // Callable này không yêu cầu đăng nhập: người dùng chưa đăng nhập vẫn phải
  // gửi được yêu cầu. Kết quả luôn giống nhau để không làm lộ tên tài khoản.
  async function requestPasswordReset(_uid, dauVao) {
    requireThat(typeof dauVao.username === 'string' &&
      /^[A-Za-z0-9_.@-]{3,64}$/.test(dauVao.username.trim()),
    'invalid-argument', 'Tên đăng nhập không hợp lệ.');
    const tenDangNhap = dauVao.username.trim();
    const usernameSnap = await coSoDuLieu.doc(`usernames/${usernameKey(tenDangNhap)}`).get();
    if (!usernameSnap.exists) return { submitted: true };
    const maNguoiDung = usernameSnap.data()?.uid;
    if (typeof maNguoiDung !== 'string') return { submitted: true };
    const targetRef = userRef(maNguoiDung);
    const dich = (await targetRef.get()).data();
    if (!['user', 'admin'].includes(dich?.role) || dich.status !== 'active' ||
      typeof dich.createdBy !== 'string') return { submitted: true };
    const manager = (await coSoDuLieu.doc(`users/${dich.createdBy}`).get()).data();
    if (!manager || !['admin', 'super_admin'].includes(manager.role) ||
      manager.status !== 'active') {
      return { submitted: true };
    }
    const thamChieuYeuCau = coSoDuLieu.doc(`password_reset_requests/${maNguoiDung}`);
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const hienTai = (await giaoDich.get(thamChieuYeuCau)).data();
      const latest = (await giaoDich.get(targetRef)).data();
      if (latest?.status !== 'active' || latest.createdBy !== dich.createdBy) return;
      if (hienTai && ['pending', 'approved_once', 'approved', 'processing'].includes(hienTai.status)) return;
      giaoDich.set(thamChieuYeuCau, {
      userId: maNguoiDung,
      managerId: dich.createdBy,
      name: dich.name || '',
      username: dich.username || tenDangNhap,
      status: 'pending',
      requestedAt: stamp(),
      updatedAt: stamp(),
      });
    });
    return { submitted: true };
  }

  async function resolvePasswordReset(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(dauVao.requestId) &&
      typeof dauVao.userId === 'string' &&
      typeof dauVao.password === 'string' && dauVao.password.length >= 6 &&
      dauVao.password.length <= 128, 'invalid-argument',
    'Thông tin cấp lại mật khẩu không hợp lệ.');
    const thamChieuYeuCau = coSoDuLieu.doc(`password_reset_requests/${dauVao.requestId}`);
    const targetRef = userRef(dauVao.userId);
    const dich = await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      const yeuCau = (await giaoDich.get(thamChieuYeuCau)).data();
      const nguoiDung = (await giaoDich.get(targetRef)).data();
      requireThat(yeuCau?.status === 'approved' && yeuCau.userId === dauVao.userId,
        'failed-precondition', 'Yêu cầu chưa được hai quản lý tổng duyệt.');
      requireThat(['user', 'admin'].includes(nguoiDung?.role) && nguoiDung.status === 'active',
        'failed-precondition', 'Tài khoản không còn hoạt động.');
      const roots = rootIds(cauHinh);
      requireThat(roots.includes(yeuCau.firstApprovedBy) && roots.includes(yeuCau.secondApprovedBy) &&
        yeuCau.firstApprovedBy !== yeuCau.secondApprovedBy,
      'failed-precondition', 'Thiếu xác nhận của hai quản lý tổng.');
      if (nguoiDung.role === 'admin') {
        requireThat(isRoot(nguoiThaoTac, cauHinh) && yeuCau.managerId === nguoiDung.createdBy &&
          nguoiDung.createdBy === nguoiThaoTac.id,
        'permission-denied', 'Chỉ quản lý tổng đã tạo tài khoản mới được cấp lại mật khẩu.');
      } else {
        requireUpdate(nguoiThaoTac, cauHinh, { ...nguoiDung, id: dauVao.userId });
        requireThat(!isRoot(nguoiThaoTac, cauHinh) && yeuCau.managerId === nguoiThaoTac.id &&
          yeuCau.managerId === nguoiDung.createdBy,
        'permission-denied', 'Chỉ quản lý phụ trách mới được cấp lại mật khẩu.');
      }
      giaoDich.update(thamChieuYeuCau, {status: 'processing', resolvingBy: maNguoiDung});
      return nguoiDung;
    });
    try {
      await xacThuc.updateUser(dauVao.userId, { password: dauVao.password });
      await xacThuc.revokeRefreshTokens(dauVao.userId);
      await coSoDuLieu.runTransaction(async (giaoDich) => {
      const yeuCau = (await giaoDich.get(thamChieuYeuCau)).data();
      requireThat(yeuCau?.status === 'processing' && yeuCau.resolvingBy === maNguoiDung,
        'failed-precondition', 'Yêu cầu đang được xử lý.');
      giaoDich.update(thamChieuYeuCau, { status: 'completed', resolvedBy: maNguoiDung, resolvedAt: stamp() });
      });
    } catch (loi) {
      await coSoDuLieu.runTransaction(async (giaoDich) => {
        const yeuCau = (await giaoDich.get(thamChieuYeuCau)).data();
        if (yeuCau?.status === 'processing' && yeuCau.resolvingBy === maNguoiDung) {
          giaoDich.update(thamChieuYeuCau, {status: 'approved', resolvingBy: FieldValue.delete()});
        }
      });
      throw loi;
    }
    return { updated: true, username: dich.username || '' };
  }

  async function approvePasswordReset(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(dauVao.requestId),
    'invalid-argument', 'Yêu cầu cấp lại mật khẩu không hợp lệ.');
    const thamChieuYeuCau = coSoDuLieu.doc(`password_reset_requests/${dauVao.requestId}`);
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const { actor: nguoiThaoTac, config: cauHinh } = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(nguoiThaoTac, cauHinh);
      const yeuCau = (await giaoDich.get(thamChieuYeuCau)).data();
      requireThat(yeuCau?.status === 'pending' || yeuCau?.status === 'approved_once',
        'failed-precondition', 'Yêu cầu đã được duyệt đủ hoặc đã hoàn tất.');
      const dich = (await giaoDich.get(userRef(yeuCau.userId))).data();
      requireThat(['user', 'admin'].includes(dich?.role) &&
        dich.status === 'active' && dich.createdBy === yeuCau.managerId,
      'failed-precondition', 'Tài khoản không còn thuộc quản lý phụ trách.');
      const roots = rootIds(cauHinh);
      if (yeuCau.status === 'pending') {
        giaoDich.update(thamChieuYeuCau, {
          status: 'approved_once', firstApprovedBy: maNguoiDung, firstApprovedAt: stamp(),
        });
      } else {
        requireThat(yeuCau.firstApprovedBy && roots.includes(yeuCau.firstApprovedBy) &&
          yeuCau.firstApprovedBy !== maNguoiDung,
        'permission-denied', 'Quản lý tổng còn lại phải là người duyệt lần hai.');
        giaoDich.update(thamChieuYeuCau, {
          status: 'approved', secondApprovedBy: maNguoiDung, secondApprovedAt: stamp(),
        });
      }
    });
    return { approved: true };
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
  async function setUnit(maNguoiDung,dauVao) {
    const donVi=validateUnit(dauVao.unit);
    const thamChieu=userRef(dauVao.userId);
    await coSoDuLieu.runTransaction(async giaoDich=>{
      const {actor: nguoiThaoTac,config: cauHinh}=await nguCanh(giaoDich,maNguoiDung);requireRoot(nguoiThaoTac,cauHinh);
      const dich=(await giaoDich.get(thamChieu)).data();
      requireThat(dich?.role==='admin'&&['active','pending'].includes(dich.status),'failed-precondition','Chọn quản lý đang hoạt động hoặc chờ duyệt.');
      const reserve = await unitReservation(giaoDich, donVi, thamChieu.id);
      const oldRef = dich.unit ? coSoDuLieu.doc(`unit_codes/${userCodeKey(dich.unit)}`) : null;
      const cu = oldRef ? await giaoDich.get(oldRef) : null;
      const children=await giaoDich.get(coSoDuLieu.collection('users').where('createdBy','==',thamChieu.id));
      const learners=await giaoDich.get(coSoDuLieu.collection('users').where('role','==','user'));
      const writes = [];
      const unitChanged = userCodeKey(dich.unit || '') !== userCodeKey(donVi);
      const codes = new Set();
      for (const child of children.docs) {
        if (child.data().role !== 'user') continue;
        // Admin tổng đổi phần đơn vị; đuôi do quản lý phụ trách sở hữu luôn được giữ nguyên.
        const suffix = userCodeSuffix(child.data(), child.id);
        const khoa = userCodeKey(makeUserCode(donVi, suffix));
        requireThat(!codes.has(khoa), 'already-exists', 'Học viên có mã trùng nhau. Chưa thay đổi đơn vị.');
        codes.add(khoa);
        writes.push(await assignment(giaoDich, child.ref, child.data(), donVi, thamChieu.id, maNguoiDung, learners));
      }
      const requests=await giaoDich.get(coSoDuLieu.collection('admin_requests').where('targetUid','==',thamChieu.id));
      reserve();
      if (cu?.exists && cu.data().managerId === thamChieu.id &&
        userCodeKey(dich.unit) !== userCodeKey(donVi)) giaoDich.delete(oldRef);
      giaoDich.update(thamChieu,{unit: donVi,updatedAt:stamp(),updatedBy:maNguoiDung});
      for (const write of writes) write();
      for (const yeuCau of requests.docs) giaoDich.update(yeuCau.ref, {unit: donVi});
      giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {actorId:maNguoiDung,targetUid:thamChieu.id,action:'assign_unit',unit: donVi,at:stamp()});
    });
    return {updated:true};
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
      requireThat(manager?.role === 'admin' && manager.status === 'active',
        'failed-precondition', 'Quản lý mới chưa hoạt động.');
      requireThat(dich.createdBy === managerRef.id ||
        userCodeKey(manager.unit || '') !== userCodeKey(dich.unit || ''),
        'failed-precondition', 'Không thể chuyển học viên trong cùng đơn vị.');
      requireThat(rootIds(cauHinh).includes(manager.createdBy) &&
        rootIds(cauHinh).includes(manager.approvedBy) && manager.createdBy !== manager.approvedBy,
        'failed-precondition', 'Quản lý mới chưa được quản lý tổng phê duyệt.');
      const reserve = await unitReservation(giaoDich, manager.unit, managerRef.id);
      const write = await assignment(giaoDich, targetRef, dich, validateUnit(manager.unit), managerRef.id, maNguoiDung,
        undefined);
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
  return { setUnit, setStatus, importUsers, proposeAdmin, decideAdmin, deleteUser, updateUser,
    checkUsernames, reassignUser, setSubUnits, getSubUnits, requestPasswordReset, resolvePasswordReset,
    approvePasswordReset };
}
