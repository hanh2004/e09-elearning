// CẤP LẠI MẬT KHẨU: gửi yêu cầu công khai để quản lý hiện tại xử lý.
// Tất cả quyền và trạng thái yêu cầu được kiểm tra phía máy chủ.
import { FieldValue } from 'firebase-admin/firestore';
import { randomUUID } from 'node:crypto';
import { PolicyError, requireRoot, requireThat, requireUpdate, rootIds, usernameKey } from './quy_tac.js';

function hasBothApprovals(request, config) {
  const roots = rootIds(config);
  return roots.includes(request.firstApprovedBy) &&
    roots.includes(request.secondApprovedBy) &&
    request.firstApprovedBy !== request.secondApprovedBy;
}

export function createPasswordResetHandlers({ coSoDuLieu, xacThuc, userRef, nguCanh, stamp }) {
  async function requestPasswordReset(_uid, dauVao) {
    // APK cũ vẫn gửi codeSuffix. Nhận trường này để giữ tương thích nhưng
    // chỉ tra username và quyền quản lý từ hồ sơ trên máy chủ.
    requireThat(dauVao && Object.keys(dauVao).every(key => ['username', 'codeSuffix'].includes(key)) &&
      (dauVao.codeSuffix === undefined ||
        (typeof dauVao.codeSuffix === 'string' && dauVao.codeSuffix.length <= 128)),
    'invalid-argument', 'Thông tin yêu cầu không hợp lệ.');
    requireThat(typeof dauVao.username === 'string' &&
      /^[A-Za-z0-9_.@-]{3,64}$/.test(dauVao.username.trim()),
    'invalid-argument', 'Tên đăng nhập không hợp lệ.');
    const username = dauVao.username.trim();
    const usernameMatches = profile => typeof profile.username === 'string' &&
      usernameKey(profile.username) === usernameKey(username);
    const usernameRef = coSoDuLieu.doc(`usernames/${usernameKey(username)}`);
    const usernameSnapshot = await usernameRef.get();
    if (!usernameSnapshot.exists) return { matched: false, submitted: false };

    const userId = usernameSnapshot.data()?.uid;
    if (typeof userId !== 'string') return { matched: false, submitted: false };

    const targetRef = userRef(userId);
    const target = (await targetRef.get()).data();
    if (!['user', 'admin'].includes(target?.role) || target.status !== 'active' ||
      typeof target.createdBy !== 'string') return { matched: false, submitted: false };

    if (!usernameMatches(target)) return { matched: false, submitted: false };

    const manager = (await userRef(target.createdBy).get()).data();
    if (!manager || !['admin', 'super_admin'].includes(manager.role) ||
      manager.status !== 'active') return { matched: false, submitted: false };

    const requestRef = coSoDuLieu.doc(`password_reset_requests/${userId}`);
    const matched = await coSoDuLieu.runTransaction(async (transaction) => {
      const currentRequest = (await transaction.get(requestRef)).data();
      const currentUser = (await transaction.get(targetRef)).data();
      if (!['user', 'admin'].includes(currentUser?.role) ||
        currentUser.status !== 'active' || currentUser.createdBy !== target.createdBy ||
        !usernameMatches(currentUser)) return false;
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

  async function approvePasswordReset(adminId, input) {
    requireThat(typeof input?.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(input.requestId),
    'invalid-argument', 'Yêu cầu cấp lại mật khẩu không hợp lệ.');
    const requestRef = coSoDuLieu.doc(`password_reset_requests/${input.requestId}`);
    const status = await coSoDuLieu.runTransaction(async (transaction) => {
      const { actor, config } = await nguCanh(transaction, adminId);
      requireRoot(actor, config);
      const request = (await transaction.get(requestRef)).data();
      requireThat(request?.type !== 'root_recovery' &&
        ['pending', 'approved_once', 'approved'].includes(request?.status) &&
        typeof request.userId === 'string' && request.userId.length > 0 &&
        request.userId.length <= 128 && !request.userId.includes('/'),
      'failed-precondition', 'Yêu cầu không còn chờ đồng ý cấp lại mật khẩu.');
      const user = (await transaction.get(userRef(request.userId))).data();
      requireThat(user?.role === 'admin' && user.status === 'active' &&
        request.managerId === user.createdBy,
      'failed-precondition', 'Tài khoản admin phụ không còn hoạt động hoặc đã thay đổi quản lý.');
      if (request.status === 'approved') {
        requireThat(hasBothApprovals(request, config),
          'failed-precondition', 'Yêu cầu thiếu xác nhận của hai quản lý tổng.');
        return 'approved';
      }
      if (request.status === 'pending') {
        transaction.update(requestRef, {
          status: 'approved_once', userRole: 'admin',
          firstApprovedBy: adminId, firstApprovedAt: stamp(),
          secondApprovedBy: FieldValue.delete(), secondApprovedAt: FieldValue.delete(),
          updatedAt: stamp(),
        });
        return 'approved_once';
      }
      requireThat(rootIds(config).includes(request.firstApprovedBy),
        'failed-precondition', 'Lượt đồng ý đầu tiên không hợp lệ.');
      // Gửi lại cùng lượt đồng ý không tính thành hai người đồng ý.
      if (request.firstApprovedBy === adminId) return 'approved_once';
      transaction.update(requestRef, {
        status: 'approved', userRole: 'admin',
        secondApprovedBy: adminId, secondApprovedAt: stamp(), updatedAt: stamp(),
      });
      return 'approved';
    });
    return { approved: true, status };
  }

  async function resolvePasswordReset(adminId, input) {
    requireThat(typeof input?.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(input.requestId) &&
      typeof input.userId === 'string' && input.userId.length > 0 &&
      input.userId.length <= 128 && !input.userId.includes('/') &&
      typeof input.password === 'string' && input.password.length >= 6 &&
      input.password.length <= 128,
    'invalid-argument', 'Thông tin cấp lại mật khẩu không hợp lệ.');

    const requestRef = coSoDuLieu.doc(`password_reset_requests/${input.requestId}`);
    const targetRef = userRef(input.userId);
    const resolvingToken = randomUUID();
    const claim = await coSoDuLieu.runTransaction(async (transaction) => {
      const { actor, config } = await nguCanh(transaction, adminId);
      const request = (await transaction.get(requestRef)).data();
      const user = (await transaction.get(targetRef)).data();

      requireThat(request?.type !== 'root_recovery' &&
        ['pending', 'approved_once', 'approved'].includes(request?.status) &&
        request.userId === input.userId,
      'failed-precondition', 'Yêu cầu đang được xử lý hoặc đã hoàn tất.');
      requireThat(['user', 'admin'].includes(user?.role) && user.status === 'active',
        'failed-precondition', 'Tài khoản không còn hoạt động.');
      requireThat(request.managerId === user.createdBy,
        'failed-precondition', 'Tài khoản đã được chuyển cho quản lý khác.');

      if (user.role === 'admin') {
        requireRoot(actor, config);
        requireThat(request.status === 'approved' && hasBothApprovals(request, config),
          'failed-precondition', 'Cả hai quản lý tổng phải đồng ý trước khi nhập mật khẩu mới.');
      } else {
        requireUpdate(actor, config, { ...user, id: input.userId });
        requireThat(request.managerId === actor.id,
          'permission-denied', 'Chỉ quản lý hiện tại mới được cấp lại mật khẩu.');
      }

      transaction.update(requestRef, {
        status: 'processing', resolvingBy: adminId, resolvingToken, updatedAt: stamp(),
        processingIssue: FieldValue.delete(),
      });
      return { user, previousStatus: request.status };
    });

    let passwordUpdated = false;
    try {
      await xacThuc.updateUser(input.userId, { password: input.password });
      passwordUpdated = true;
      await xacThuc.revokeRefreshTokens(input.userId);
      await coSoDuLieu.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        requireThat(request?.status === 'processing' && request.resolvingBy === adminId &&
          request.resolvingToken === resolvingToken,
          'failed-precondition', 'Yêu cầu đang được xử lý.');
        transaction.update(requestRef, {
          status: 'completed',
          resolvedBy: adminId,
          resolvedAt: stamp(),
          resolvingBy: FieldValue.delete(), resolvingToken: FieldValue.delete(),
          processingIssue: FieldValue.delete(),
          updatedAt: stamp(),
        });
      });
    } catch (error) {
      // Khi Auth đã đổi mật khẩu (hoặc kết quả gọi Auth chưa rõ), không mở
      // lại yêu cầu để admin tổng khác ghi đè mật khẩu vừa cấp.
      const rejectedBeforeUpdate = !passwordUpdated && [
        'auth/invalid-password', 'auth/invalid-argument', 'auth/invalid-uid',
        'auth/user-not-found',
      ].includes(error?.code);
      if (!rejectedBeforeUpdate) {
        console.error('Password reset claim remains locked', {
          requestId: input.requestId, code: error?.code || 'unknown', passwordUpdated,
        });
        try {
          await coSoDuLieu.runTransaction(async (transaction) => {
            const request = (await transaction.get(requestRef)).data();
            if (request?.status === 'processing' && request.resolvingBy === adminId &&
              request.resolvingToken === resolvingToken) {
              transaction.update(requestRef, {
                processingIssue: passwordUpdated ? 'password_updated' : 'result_unknown',
                updatedAt: stamp(),
              });
            }
          });
        } catch (recordError) {
          console.error('Could not record locked password reset state', {
            requestId: input.requestId, code: recordError?.code || 'unknown',
          });
        }
        throw new PolicyError('unavailable', passwordUpdated
          ? 'Mật khẩu đã được cập nhật nhưng chưa hoàn tất xác nhận. Yêu cầu đã khóa; liên hệ người phụ trách hệ thống kiểm tra.'
          : 'Chưa xác nhận được kết quả cập nhật mật khẩu. Yêu cầu đã khóa; liên hệ người phụ trách hệ thống kiểm tra.');
      }
      await coSoDuLieu.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        if (request?.status === 'processing' && request.resolvingBy === adminId &&
          request.resolvingToken === resolvingToken) {
          transaction.update(requestRef, {
            status: claim.previousStatus, resolvingBy: FieldValue.delete(),
            resolvingToken: FieldValue.delete(), processingIssue: FieldValue.delete(),
            updatedAt: stamp(),
          });
        }
      });
      throw error;
    }

    return { updated: true, username: claim.user.username || '' };
  }

  return { requestPasswordReset, approvePasswordReset, resolvePasswordReset };
}
