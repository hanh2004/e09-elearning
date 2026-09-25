// Khôi phục mật khẩu admin tổng bằng một lần duyệt từ admin tổng còn lại.
// Mã khôi phục ngẫu nhiên chỉ tồn tại trong phiên trình duyệt gửi yêu cầu;
// Firestore chỉ lưu SHA-256 của mã, không lưu mật khẩu mới hay mã thô.
import { createHash } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { isRoot, requireThat, rootIds, usernameKey } from './policy.js';

const hashProof = (proof) => createHash('sha256').update(proof).digest('hex');
const validProof = (proof) => typeof proof === 'string' && /^[A-Za-z0-9_-]{43}$/.test(proof);
const validUsername = (username) => typeof username === 'string' &&
  /^[A-Za-z0-9_.@-]{3,64}$/.test(username.trim());

export function rootPasswordRecoveryHandlers(db, auth) {
  const userRef = (uid) => db.doc(`users/${uid}`);
  const resetRef = (uid) => db.doc(`password_reset_requests/${uid}`);

  async function findRoot(username) {
    const usernameSnap = await db.doc(`usernames/${usernameKey(username)}`).get();
    if (!usernameSnap.exists || typeof usernameSnap.data()?.uid !== 'string') return null;
    const uid = usernameSnap.data().uid;
    const [profileSnap, accessSnap] = await Promise.all([
      userRef(uid).get(), db.doc('system/access').get(),
    ]);
    const profile = profileSnap.data();
    const roots = rootIds(accessSnap.data());
    if (!roots.includes(uid) || !isRoot({ ...profile, id: uid }, accessSnap.data())) return null;
    return { uid, profile };
  }

  async function requestRootPasswordReset(_uid, input) {
    requireThat(input && Object.keys(input).every((key) => ['username', 'proof'].includes(key)) &&
      validUsername(input.username) && validProof(input.proof),
    'invalid-argument', 'Thông tin yêu cầu không hợp lệ.');
    const root = await findRoot(input.username.trim());
    // Trả cùng kết quả nếu tên đăng nhập không phải admin tổng, tránh dò tài khoản.
    if (!root) return { submitted: true };

    const requestRef = resetRef(root.uid);
    const limitRef = db.doc(`root_password_reset_limits/${root.uid}`);
    const proofHash = hashProof(input.proof);
    const now = Date.now();
    const expiresAt = Timestamp.fromMillis(now + 30 * 60 * 1000);
    await db.runTransaction(async (transaction) => {
      const [accessSnap, profileSnap, requestSnap, limitSnap] = await Promise.all([
        transaction.get(db.doc('system/access')),
        transaction.get(userRef(root.uid)),
        transaction.get(requestRef),
        transaction.get(limitRef),
      ]);
      const config = accessSnap.data();
      const profile = profileSnap.data();
      if (!isRoot({ ...profile, id: root.uid }, config)) return;

      const current = requestSnap.data() ?? {};
      const currentExpiry = current.expiresAt?.toMillis?.() ?? 0;
      if (current.proofHash === proofHash && currentExpiry > now &&
        ['pending', 'approved', 'processing'].includes(current.status)) return;

      const limit = limitSnap.data() ?? {};
      const lastAt = limit.lastAt?.toMillis?.() ?? 0;
      const dayStart = limit.dayStart?.toMillis?.() ?? 0;
      const count = now - dayStart < 86_400_000 ? limit.count ?? 0 : 0;
      requireThat(now - lastAt >= 60_000, 'resource-exhausted',
        'Vui lòng đợi một phút trước khi gửi yêu cầu mới.');
      requireThat(count < 5, 'resource-exhausted',
        'Đã đạt giới hạn yêu cầu khôi phục trong ngày.');

      transaction.set(requestRef, {
        type: 'root_recovery',
        userId: root.uid,
        managerId: root.uid,
        name: profile.name || '',
        username: profile.username || input.username.trim(),
        status: 'pending',
        proofHash,
        requestedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
      });
      transaction.set(limitRef, {
        lastAt: FieldValue.serverTimestamp(),
        dayStart: count === 0 ? Timestamp.fromMillis(now) : limit.dayStart,
        count: count + 1,
      });
    });
    return { submitted: true };
  }

  async function rootPasswordResetStatus(_uid, input) {
    requireThat(input && Object.keys(input).every((key) => ['username', 'proof'].includes(key)) &&
      validUsername(input.username) && validProof(input.proof),
    'invalid-argument', 'Thông tin yêu cầu không hợp lệ.');
    const root = await findRoot(input.username.trim());
    if (!root) return { status: 'not_found' };
    const request = (await resetRef(root.uid).get()).data();
    if (request?.type !== 'root_recovery' || request.proofHash !== hashProof(input.proof)) {
      return { status: 'not_found' };
    }
    if ((request.expiresAt?.toMillis?.() ?? 0) <= Date.now()) return { status: 'expired' };
    return { status: request.status };
  }

  async function approveRootPasswordReset(actorUid, input) {
    requireThat(typeof input?.requestId === 'string' &&
      /^[A-Za-z0-9_=-]{1,128}$/.test(input.requestId),
    'invalid-argument', 'Yêu cầu khôi phục không hợp lệ.');
    const requestRef = resetRef(input.requestId);
    await db.runTransaction(async (transaction) => {
      const accessSnap = await transaction.get(db.doc('system/access'));
      const actorSnap = await transaction.get(userRef(actorUid));
      const requestSnap = await transaction.get(requestRef);
      const request = requestSnap.data();
      const config = accessSnap.data();
      const actor = { ...actorSnap.data(), id: actorUid };
      requireThat(isRoot(actor, config), 'permission-denied', 'Chỉ admin tổng được duyệt.');
      requireThat(request?.type === 'root_recovery' && request.status === 'pending',
        'failed-precondition', 'Yêu cầu không còn chờ duyệt.');
      requireThat((request.expiresAt?.toMillis?.() ?? 0) > Date.now(),
        'deadline-exceeded', 'Yêu cầu đã hết hạn. Admin cần gửi yêu cầu mới.');
      const roots = rootIds(config);
      requireThat(roots.includes(request.userId) && request.userId !== actorUid,
        'permission-denied', 'Admin tổng chỉ được duyệt yêu cầu của admin tổng còn lại.');
      const targetSnap = await transaction.get(userRef(request.userId));
      requireThat(isRoot({ ...targetSnap.data(), id: request.userId }, config),
        'failed-precondition', 'Tài khoản yêu cầu không còn là admin tổng hoạt động.');
      transaction.update(requestRef, {
        status: 'approved',
        approvedBy: actorUid,
        approvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { approved: true };
  }

  async function finishRootPasswordReset(_uid, input) {
    requireThat(input && Object.keys(input).every((key) =>
      ['username', 'proof', 'password'].includes(key)) &&
      validUsername(input.username) && validProof(input.proof) &&
      typeof input.password === 'string' && input.password.length >= 8 &&
      input.password.length <= 128,
    'invalid-argument', 'Mật khẩu mới phải dài từ 8 đến 128 ký tự.');
    const root = await findRoot(input.username.trim());
    requireThat(root, 'failed-precondition', 'Yêu cầu không hợp lệ hoặc đã hết hạn.');
    const requestRef = resetRef(root.uid);
    const proofHash = hashProof(input.proof);
    const now = Date.now();
    const state = await db.runTransaction(async (transaction) => {
      const [accessSnap, profileSnap, requestSnap] = await Promise.all([
        transaction.get(db.doc('system/access')),
        transaction.get(userRef(root.uid)),
        transaction.get(requestRef),
      ]);
      const config = accessSnap.data();
      const profile = { ...profileSnap.data(), id: root.uid };
      const request = requestSnap.data();
      requireThat(isRoot(profile, config) && request?.type === 'root_recovery' &&
        request.proofHash === proofHash,
      'failed-precondition', 'Yêu cầu không hợp lệ hoặc đã hết hạn.');
      if (request.status === 'completed') return 'completed';
      requireThat(request.status === 'approved' &&
        rootsIncludeOtherApprover(config, root.uid, request.approvedBy) &&
        (request.expiresAt?.toMillis?.() ?? 0) > now,
      'failed-precondition', 'Yêu cầu chưa được admin tổng còn lại duyệt hoặc đã hết hạn.');
      transaction.update(requestRef, {
        status: 'processing',
        processingAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return 'processing';
    });
    if (state === 'completed') return { updated: true };
    try {
      await auth.updateUser(root.uid, { password: input.password });
      await auth.revokeRefreshTokens(root.uid);
      await db.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        requireThat(request?.status === 'processing' && request.proofHash === proofHash,
          'failed-precondition', 'Yêu cầu đã thay đổi trạng thái.');
        transaction.update(requestRef, {
          status: 'completed',
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      await db.runTransaction(async (transaction) => {
        const request = (await transaction.get(requestRef)).data();
        if (request?.status === 'processing' && request.proofHash === proofHash) {
          transaction.update(requestRef, {
            status: 'approved',
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });
      throw error;
    }
    return { updated: true };
  }

  return {
    requestRootPasswordReset,
    rootPasswordResetStatus,
    approveRootPasswordReset,
    finishRootPasswordReset,
  };
}

function rootsIncludeOtherApprover(config, targetUid, approverUid) {
  const roots = rootIds(config);
  return roots.includes(targetUid) && roots.includes(approverUid) && targetUid !== approverUid;
}
