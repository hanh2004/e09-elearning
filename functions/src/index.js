// API: khai báo các Cloud Functions mà app học viên và web admin gọi.
// Thêm nghiệp vụ tài khoản, khóa học và thi trong các module tương ứng.
// Tên export bên dưới là tên API đã dùng trên client; giữ tên khi nâng cấp.
import { examHandlers } from './exams.js';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { accountHandlers } from './accounts.js';
import { courseHandlers } from './courses.js';
import { PolicyError } from './policy.js';
import { rootPasswordRecoveryHandlers } from './root_password_recovery.js';
import { feedbackHandlers } from './feedback.js';
import { rootUsernameSyncTrigger } from './root_username_sync.js';

initializeApp();
const coSoDuLieu = getFirestore();
const handlers = { ...accountHandlers(coSoDuLieu, getAuth()) };
Object.assign(handlers, feedbackHandlers(coSoDuLieu));
Object.assign(handlers, rootPasswordRecoveryHandlers(coSoDuLieu, getAuth()));
for (const [ten, handler] of Object.entries(examHandlers(coSoDuLieu))) {
  handlers[`exam_${ten}`] = handler;
}
for (const [ten, handler] of Object.entries(courseHandlers(coSoDuLieu))) {
  handlers[`course_${ten}`] = handler;
}

// Kết nối vùng này với AppConfig.functionsRegion trong lib/app/app_config.dart.
const callableOptions = {
  region: 'asia-southeast1',
  timeoutSeconds: 540,
  maxInstances: 10,
};

function callable(ten) {
  return onCall(callableOptions, async (yeuCau) => {
    if (!yeuCau.auth) {
      throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
    }
    try {
      return await handlers[ten](yeuCau.auth.uid, yeuCau.data ?? {});
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
    const authTime = request.auth.token.auth_time;
    const now = Date.now() / 1000;
    if (!Number.isFinite(authTime) || authTime > now + 60 || now - authTime > 300) {
      throw new HttpsError('failed-precondition',
        'Vui lòng xác thực lại mật khẩu rồi gửi góp ý.');
    }
    try {
      return await handlers[ten](request.auth.uid, request.data ?? {});
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
export const accountImportUsers = callable('importUsers');
export const accountProposeAdmin = callable('proposeAdmin');
export const accountDecideAdmin = callable('decideAdmin');
export const accountDeleteUser = callable('deleteUser');
export const accountUpdateUser = callable('updateUser');
export const accountCheckUsernames = callable('checkUsernames');

export const examList = callable('exam_list');
export const examStart = callable('exam_start');
export const examSave = callable('exam_save');
export const examSubmit = callable('exam_submit');
export const examHistory = callable('exam_history');

export const accountSetStatus = callable('setStatus');
export const accountSetUnit = callable('setUnit');
export const accountSetSubUnits = callable('setSubUnits');
export const accountGetSubUnits = callable('getSubUnits');
export const accountReassignUser = callable('reassignUser');
export const accountRequestPasswordReset = publicCallable('requestPasswordReset');
export const accountApprovePasswordReset = callable('approvePasswordReset');
export const accountResolvePasswordReset = callable('resolvePasswordReset');
export const feedbackSubmit = recentAuthCallable('submitFeedback');
export const rootPasswordResetRequest = publicCallable('requestRootPasswordReset');
export const rootPasswordResetStatus = publicCallable('rootPasswordResetStatus');
export const rootPasswordResetFinish = publicCallable('finishRootPasswordReset');
export const rootPasswordResetApprove = callable('approveRootPasswordReset');
export const rootUsernameSync = rootUsernameSyncTrigger(coSoDuLieu, getAuth());
export const examDelete = callable('exam_deleteExam');
export const courseDelete = callable('course_deleteCourse');
export const courseDeleteLesson = callable('course_deleteLesson');
