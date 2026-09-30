// CẤP LẠI MẬT KHẨU: gửi yêu cầu công khai để quản lý hiện tại xử lý.
// Tất cả quyền và trạng thái yêu cầu được kiểm tra phía máy chủ.
import { FieldValue } from 'firebase-admin/firestore';
import { isRoot, requireThat, requireUpdate, usernameKey } from './quy_tac.js';

export function createPasswordResetHandlers({ coSoDuLieu, xacThuc, userRef, nguCanh, stamp }) {
  async function requestPasswordReset(_uid, dauVao) {
    requireThat(dauVao && Object.keys(dauVao).every((key) =>
      ['username', 'codeSuffix'].includes(key)),
    'invalid-argument', 'Thông tin yêu cầu không hợp lệ.');
    requireThat(typeof dauVao.username === 'string' &&
      /^[A-Za-z0-9_.@-]{3,64}$/.test(dauVao.username.trim()),
    'invalid-argument', 'Tên đăng nhập không hợp lệ.');
    requireThat(typeof dauVao.codeSuffix === 'string' &&
      dauVao.codeSuffix.trim().length > 0 && dauVao.codeSuffix.trim().length <= 100,
    'invalid-argument', 'Mã đuôi không hợp lệ.');

    const username = dauVao.username.trim();
    const codeSuffix = dauVao.codeSuffix.trim().normalize('NFC').toLowerCase();
    const khopMaDuoi = (profile) => {
      // Học viên dùng phần sau dấu gạch trong mã người dùng; admin phụ dùng
      // mã đơn vị được gán vì hồ sơ admin không có userCode riêng.
      const fullCode = typeof profile.userCode === 'string' ? profile.userCode.trim() : '';
      const unitPrefix = typeof profile.unit === 'string' ? `${profile.unit.trim()}-` : '';
      const expectedSuffix = profile.role === 'admin'
        ? profile.unit
        : typeof profile.userCodeSuffix === 'string' && profile.userCodeSuffix.trim()
          ? profile.userCodeSuffix
          : unitPrefix && fullCode.startsWith(unitPrefix)
            ? fullCode.substring(unitPrefix.length)
            : '';
      return typeof expectedSuffix === 'string' && expectedSuffix.trim().length > 0 &&
        expectedSuffix.trim().normalize('NFC').toLowerCase() === codeSuffix;
    };
    const usernameRef = coSoDuLieu.doc(`usernames/${usernameKey(username)}`);
    const usernameSnapshot = await usernameRef.get();
    if (!usernameSnapshot.exists) return { matched: false, submitted: false };

    const userId = usernameSnapshot.data()?.uid;
    if (typeof userId !== 'string') return { matched: false, submitted: false };

    const targetRef = userRef(userId);
    const target = (await targetRef.get()).data();
    if (!['user', 'admin'].includes(target?.role) || target.status !== 'active' ||
      typeof target.createdBy !== 'string') return { matched: false, submitted: false };

    if (!khopMaDuoi(target)) return { matched: false, submitted: false };

    const manager = (await userRef(target.createdBy).get()).data();
    if (!manager || !['admin', 'super_admin'].includes(manager.role) ||
      manager.status !== 'active') return { matched: false, submitted: false };

    const requestRef = coSoDuLieu.doc(`password_reset_requests/${userId}`);
    const matched = await coSoDuLieu.runTransaction(async (transaction) => {
      const currentRequest = (await transaction.get(requestRef)).data();
      const currentUser = (await transaction.get(targetRef)).data();
      if (!['user', 'admin'].includes(currentUser?.role) ||
        currentUser.status !== 'active' || currentUser.createdBy !== target.createdBy ||
        !khopMaDuoi(currentUser)) return false;
      const currentManager = (await transaction.get(userRef(currentUser.createdBy))).data();
      if (!currentManager || !['admin', 'super_admin'].includes(currentManager.role) ||
        currentManager.status !== 'active') return false;
      if (currentRequest && ['pending', 'approved_once', 'approved', 'processing']
        .includes(currentRequest.status)) {
        transaction.update(requestRef, {
          managerId: currentUser.createdBy,
          userRole: currentUser.role,
          updatedAt: stamp(),
        });
        return true;
      }

      transaction.set(requestRef, {
        userId,
        managerId: currentUser.createdBy,
        userRole: currentUser.role,
        name: currentUser.name || '',
        username: currentUser.username || username,
        status: 'pending',
        requestedAt: stamp(),
        updatedAt: stamp(),
      });
      return true;
    });

    return { matched, submitted: matched };
  }

  async function resolvePasswordReset(adminId, input) {
    requireThat(typeof input.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(input.requestId) &&
      typeof input.userId === 'string' &&
      typeof input.password === 'string' && input.password.length >= 6 &&
      input.password.length <= 128,
    'invalid-argument', 'Thông tin cấp lại mật khẩu không hợp lệ.');

    const requestRef = coSoDuLieu.doc(`password_reset_requests/${input.requestId}`);
    const targetRef = userRef(input.userId);
    const target = await coSoDuLieu.runTransaction(async (transaction) => {
      const { actor, config } = await nguCanh(transaction, adminId);
      const request = (await transaction.get(requestRef)).data();
      const user = (await transaction.get(targetRef)).data();

      requireThat(['pending', 'approved_once', 'approved'].includes(request?.status) &&
        request.userId === input.userId,
      'failed-precondition', 'Yêu cầu không còn chờ cấp lại mật khẩu.');
      requireThat(['user', 'admin'].includes(user?.role) && user.status === 'active',
        'failed-precondition', 'Tài khoản không còn hoạt động.');
      requireThat(request.managerId === user.createdBy,
        'failed-precondition', 'Tài khoản đã được chuyển cho quản lý khác.');

      if (user.role === 'admin') {
        requireThat(isRoot(actor, config),
          'permission-denied', 'Chỉ admin tổng được cấp lại mật khẩu cho tài khoản admin.');
      } else {
        requireUpdate(actor, config, { ...user, id: input.userId });
        requireThat(request.managerId === actor.id,
          'permission-denied', 'Chỉ quản lý hiện tại mới được cấp lại mật khẩu.');
      }

      transaction.update(requestRef, { status: 'processing', resolvingBy: adminId });
      return user;
    });

    try {
      await xacThuc.updateUser(input.userId, { password: input.password });
      await xacThuc.revokeRefreshTokens(input.userId);
      await coSoDuLieu.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        requireThat(request?.status === 'processing' && request.resolvingBy === adminId,
          'failed-precondition', 'Yêu cầu đang được xử lý.');
        transaction.update(requestRef, {
          status: 'completed',
          resolvedBy: adminId,
          resolvedAt: stamp(),
        });
      });
    } catch (error) {
      await coSoDuLieu.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        if (request?.status === 'processing' && request.resolvingBy === adminId) {
          transaction.update(requestRef, {
            status: 'pending',
            resolvingBy: FieldValue.delete(),
          });
        }
      });
      throw error;
    }

    return { updated: true, username: target.username || '' };
  }

  return { requestPasswordReset, resolvePasswordReset };
}
