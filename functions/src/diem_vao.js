// API: khai báo các Cloud Functions mà app học viên và web admin gọi.
// Thêm nghiệp vụ tài khoản, khóa học và thi trong các module tương ứng.
// Tên export bên dưới là tên API đã dùng trên client; giữ tên khi nâng cấp.
import { examHandlers } from './bai_kiem_tra.js';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { accountHandlers } from './tai_khoan.js';
import { courseHandlers } from './khoa_hoc.js';
import { PolicyError } from './quy_tac.js';
import { rootPasswordRecoveryHandlers } from './khoi_phuc_mat_khau_quan_tri_tong.js';
import { feedbackHandlers } from './phan_hoi.js';
import { maintenanceHandlers } from './bao_tri.js';
import { rootUsernameSyncTrigger } from './dong_bo_ten_dang_nhap_quan_tri_tong.js';

initializeApp();
const coSoDuLieu = getFirestore();
const handlers = { ...accountHandlers(coSoDuLieu, getAuth()) };
Object.assign(handlers, feedbackHandlers(coSoDuLieu));
Object.assign(handlers, maintenanceHandlers(coSoDuLieu));
Object.assign(handlers, rootPasswordRecoveryHandlers(coSoDuLieu, getAuth()));
for (const [ten, handler] of Object.entries(examHandlers(coSoDuLieu))) {
  handlers[`exam_${ten}`] = handler;
}
for (const [ten, handler] of Object.entries(courseHandlers(coSoDuLieu))) {
  handlers[`course_${ten}`] = handler;
}

// Kết nối vùng này với AppConfig.functionsRegion trong lib/app/cau_hinh_ung_dung.dart.
const callableOptions = {
  region: 'asia-southeast1',
  timeoutSeconds: 540,
  maxInstances: 10,
};

const adminSessionRef = (uid) => coSoDuLieu.doc(`admin_web_sessions/${uid}`);
const adminSessionLeaseMs = 2 * 60 * 1000;
const tokenHash = (token) => createHash('sha256').update(token).digest('hex');
const validSessionToken = (token) => typeof token === 'string' && /^[a-f0-9]{64}$/.test(token);

async function requireActiveAccountSession(uid, data, authTime) {
  const account = (await coSoDuLieu.doc(`users/${uid}`).get()).data();
  if (!['user', 'học viên', 'admin', 'super_admin'].includes(account?.role) ||
      account?.status !== 'active') {
    throw new HttpsError('unauthenticated', 'Tài khoản không còn hoạt động.');
  }

  const session = (await adminSessionRef(uid).get()).data();
  const presentedToken = data?._adminWebSession;
  if (!session && !presentedToken) return data; // Legacy clients have not claimed a session yet.
  const lastSeen = session?.lastSeenAt?.toMillis?.() ?? 0;
  if (!session || typeof presentedToken !== 'string' ||
      session.status === 'released' || session.authTime !== authTime ||
      Date.now() - lastSeen >= adminSessionLeaseMs ||
      tokenHash(presentedToken) !== session.tokenHash) {
    throw new HttpsError('unauthenticated',
      'Tài khoản đã được đăng nhập trên thiết bị khác. Vui lòng đăng nhập lại.');
  }
  const { _adminWebSession, ...businessData } = data ?? {};
  return businessData;
}

function callable(ten) {
  return onCall(callableOptions, async (yeuCau) => {
    if (!yeuCau.auth) {
      throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
    }
    const dauVao = await requireActiveAccountSession(
      yeuCau.auth.uid,
      yeuCau.data ?? {},
      yeuCau.auth.token.auth_time,
    );
    try {
      return await handlers[ten](yeuCau.auth.uid, dauVao);
    } catch (loi) {
      if (loi instanceof PolicyError) {
        throw new HttpsError(loi.code, loi.message);
      }
      // Không ghi log dữ liệu gửi lên, mật khẩu hoặc lỗi SDK có thông tin tài khoản.
      console.error(`Account operation ${ten} failed: ${loi.code ?? loi.name}`);
      throw new HttpsError(
        'unavailable',
        'Thao tác chưa hoàn tất. Thử lại với cùng dữ liệu; không tạo yêu cầu khác.',
      );
    }
  });
}
function recentAuthCallable(ten) {
  return onCall(callableOptions, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
    const dauVao = await requireActiveAccountSession(
      request.auth.uid,
      request.data ?? {},
      request.auth.token.auth_time,
    );
    const authTime = request.auth.token.auth_time;
    const now = Date.now() / 1000;
    if (!Number.isFinite(authTime) || authTime > now + 60 || now - authTime > 300) {
      throw new HttpsError('failed-precondition',
        'Vui lòng xác thực lại mật khẩu rồi gửi góp ý.');
    }
    try {
      return await handlers[ten](request.auth.uid, dauVao);
    } catch (error) {
      if (error instanceof PolicyError) throw new HttpsError(error.code, error.message);
      // Không ghi nội dung góp ý, tên tài khoản hay thông tin xác thực vào log.
      console.error(`Feedback submission failed: ${error.code ?? error.name}`);
      throw new HttpsError('unavailable', 'Chưa gửi được góp ý. Vui lòng thử lại.');
    }
  });
}
function publicCallable(ten) {
  return onCall(callableOptions, async (yeuCau) => {
    try {
      return await handlers[ten](null, yeuCau.data ?? {});
    } catch (loi) {
      if (loi instanceof PolicyError) {
        throw new HttpsError(loi.code, loi.message);
      }
      console.error(`Public account operation ${ten} failed: ${loi.code ?? loi.name}`);
      throw new HttpsError('unavailable', 'Không thể gửi yêu cầu. Vui lòng thử lại.');
    }
  });
}

export const adminSessionClaim = onCall(callableOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
  const uid = request.auth.uid;
  const authTime = request.auth.token.auth_time;
  if (!Number.isSafeInteger(authTime)) {
    throw new HttpsError('unauthenticated', 'Phiên đăng nhập không hợp lệ.');
  }
  const accountRef = coSoDuLieu.doc(`users/${uid}`);
  const token = request.data?.sessionToken;
  if (!validSessionToken(token)) {
    throw new HttpsError('invalid-argument', 'Mã phiên đăng nhập không hợp lệ.');
  }
  const takeOver = request.data?.takeOver === true;
  return coSoDuLieu.runTransaction(async (transaction) => {
    const reference = adminSessionRef(uid);
    const [current, account] = await Promise.all([
      transaction.get(reference),
      transaction.get(accountRef),
    ]);
    const profile = account.data();
    if (!['user', 'học viên', 'admin', 'super_admin'].includes(profile?.role) ||
        profile.status !== 'active') {
      throw new HttpsError('permission-denied', 'Tài khoản không hoạt động.');
    }
    const data = current.data();
    const lastSeen = data?.lastSeenAt?.toMillis?.() ?? 0;
    const active = current.exists && data?.status !== 'released' &&
      Date.now() - lastSeen < adminSessionLeaseMs;
    const hash = tokenHash(token);
    const matches = data?.tokenHash === hash;
    if (active && !matches && !takeOver) {
      return { claimed: false, occupied: true };
    }
    transaction.set(reference, {
      tokenHash: hash,
      authTime,
      status: 'active',
      lastSeenAt: new Date(),
      updatedAt: new Date(),
      sessionVersion: (data?.sessionVersion ?? 0) + 1,
    });
    // Storage Rules can read only two Firestore documents per request.
    // Mirror non-secret lease data on the protected account so Storage can
    // validate the same session while still checking system/access for roots.
    transaction.update(accountRef, {
      accountSession: { status: 'active', authTime, lastSeenAt: new Date() },
    });
    return { claimed: true, occupied: false };
  });
});

export const adminSessionHeartbeat = onCall(callableOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
  const token = request.data?.sessionToken;
  if (!validSessionToken(token)) {
    throw new HttpsError('invalid-argument', 'Mã phiên đăng nhập không hợp lệ.');
  }
  const reference = adminSessionRef(request.auth.uid);
  const accountRef = coSoDuLieu.doc(`users/${request.auth.uid}`);
  return coSoDuLieu.runTransaction(async (transaction) => {
    const current = await transaction.get(reference);
    if (!current.exists || current.data()?.status === 'released' ||
        current.data()?.authTime !== request.auth.token.auth_time ||
        current.data()?.tokenHash !== tokenHash(token)) {
      return { active: false };
    }
    transaction.update(reference, { lastSeenAt: new Date() });
    transaction.update(accountRef, {
      accountSession: {
        status: 'active',
        authTime: request.auth.token.auth_time,
        lastSeenAt: new Date(),
      },
    });
    return { active: true };
  });
});

export const adminSessionRelease = onCall(callableOptions, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
  const token = request.data?.sessionToken;
  if (!validSessionToken(token)) {
    return { released: false };
  }
  const reference = adminSessionRef(request.auth.uid);
  const accountRef = coSoDuLieu.doc(`users/${request.auth.uid}`);
  return coSoDuLieu.runTransaction(async (transaction) => {
    const current = await transaction.get(reference);
    if (!current.exists || current.data()?.status === 'released' ||
        current.data()?.authTime !== request.auth.token.auth_time ||
        current.data()?.tokenHash !== tokenHash(token)) {
      return { released: false };
    }
    transaction.update(reference, {
      tokenHash: null,
      status: 'released',
      releasedAt: new Date(),
      updatedAt: new Date(),
    });
    transaction.update(accountRef, {
      accountSession: {
        status: 'released',
        authTime: request.auth.token.auth_time,
        lastSeenAt: new Date(),
      },
    });
    return { released: true };
  });
});

export const accountImportUsers = callable('importUsers');
export const accountProposeAdmin = callable('proposeAdmin');
export const accountDecideAdmin = callable('decideAdmin');
export const accountDeleteUser = callable('deleteUser');
export const accountRequestAdminDeletion = callable('requestAdminDeletion');
export const accountDecideAdminDeletion = callable('decideAdminDeletion');
export const accountUpdateUser = callable('updateUser');
export const accountCheckUsernames = callable('checkUsernames');

export const examList = callable('exam_list');
export const examStart = callable('exam_start');
export const examSave = callable('exam_save');
export const examSubmit = callable('exam_submit');
export const examHeartbeat = callable('exam_heartbeat');
export const examExpireRuns = onSchedule({
  schedule: 'every 1 minutes',
  region: 'asia-southeast1',
  timeoutSeconds: 540,
  maxInstances: 1,
}, async () => {
  const result = await handlers.exam_expireRuns();
  if (result.failed) throw new Error(`Could not finalize ${result.failed} expired exams`);
});
export const examHistory = callable('exam_history');
export const maintenanceSet = callable('setMode');

export const accountSetStatus = callable('setStatus');
export const accountSetUnit = callable('setUnit');
export const accountSetSubUnits = callable('setSubUnits');
export const accountGetSubUnits = callable('getSubUnits');
export const accountReassignUser = callable('reassignUser');
export const accountRequestPasswordReset = publicCallable('requestPasswordReset');
export const accountApprovePasswordReset = callable('approvePasswordReset');
export const accountResolvePasswordReset = callable('resolvePasswordReset');
export const feedbackSubmit = recentAuthCallable('submitFeedback');
export const feedbackDelete = callable('deleteFeedback');
export const rootPasswordResetRequest = publicCallable('requestRootPasswordReset');
export const rootPasswordResetStatus = publicCallable('rootPasswordResetStatus');
export const rootPasswordResetFinish = publicCallable('finishRootPasswordReset');
export const rootPasswordResetApprove = callable('approveRootPasswordReset');
export const rootUsernameSync = rootUsernameSyncTrigger(coSoDuLieu, getAuth());
export const examDelete = callable('exam_deleteExam');
export const courseDelete = callable('course_deleteCourse');
export const courseDeleteLesson = callable('course_deleteLesson');
