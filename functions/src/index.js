import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { accountHandlers } from './accounts.js';
import { PolicyError } from './policy.js';

initializeApp();
const handlers = accountHandlers(getFirestore(), getAuth());
const callable = (name) => onCall({ region: 'asia-southeast1', timeoutSeconds: 540,
  maxInstances: 10 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Cần đăng nhập.');
  try { return await handlers[name](request.auth.uid, request.data ?? {}); }
  catch (error) {
    if (error instanceof PolicyError) throw new HttpsError(error.code, error.message);
    // Never log payloads, passwords or raw SDK errors containing account data.
    console.error(`Account operation ${name} failed: ${error.code ?? error.name}`);
    throw new HttpsError('unavailable', 'Thao tác chưa hoàn tất. Thử lại với cùng dữ liệu; không tạo yêu cầu khác.');
  }
});
export const accountImportUsers = callable('importUsers');
export const accountProposeAdmin = callable('proposeAdmin');
export const accountDecideAdmin = callable('decideAdmin');
export const accountDeleteUser = callable('deleteUser');
export const accountUpdateUser = callable('updateUser');
export const accountCheckUsernames = callable('checkUsernames');
