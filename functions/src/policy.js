// QUY TẮC API: xác định quyền admin, kiểm tra dữ liệu và chuẩn hóa tên tài khoản.
// Các hàm require... ném PolicyError khi thao tác không được phép.
import { createHash } from 'node:crypto';

export class PolicyError extends Error {
  constructor(maLoi, thongDiep) { super(thongDiep); this.code = maLoi; }
}
export function requireThat(condition, maLoi, thongDiep) {
  if (!condition) throw new PolicyError(maLoi, thongDiep);
}
export const usernameKey = (ten) => createHash('sha256')
  .update(ten.trim().toLowerCase()).digest('hex');
export const loginEmail = (ten) => `${usernameKey(ten)}@accounts.invalid`;
export const fingerprint = (duLieu) => createHash('sha256')
  .update(JSON.stringify(duLieu)).digest('hex');
export const userCodeKey = (maLoi) => createHash('sha256')
  .update(maLoi.trim().normalize('NFC').toLowerCase()).digest('hex');
export function validateUnit(donVi) {
  const giaTri = typeof donVi === 'string' ? donVi.trim().normalize('NFC') : '';
  requireThat(giaTri.length > 0 && giaTri.length <= 100,
    'invalid-argument', 'Nhập mã đơn vị, tối đa 100 ký tự.');
  return giaTri;
}
export function validateSubUnit(giaTri) {
  const text = typeof giaTri === 'string' ? giaTri.trim().normalize('NFC') : '';
  requireThat(text.length > 0 && text.length <= 100,
    'invalid-argument', 'Nhập tên trực thuộc, tối đa 100 ký tự.');
  return text;
}
export function userCodeSuffix(nguoiDung, fallback) {
  if (typeof nguoiDung.userCodeSuffix === 'string' && nguoiDung.userCodeSuffix.trim()) {
    return nguoiDung.userCodeSuffix.trim();
  }
  const prefix = `${nguoiDung.unit || ''}-`;
  if (typeof nguoiDung.userCode === 'string' && nguoiDung.userCode.startsWith(prefix)) {
    return nguoiDung.userCode.substring(prefix.length);
  }
  return nguoiDung.username || fallback;
}
export function makeUserCode(donVi, suffix) {
  const unitText = typeof donVi === 'string' ? donVi.trim() : '';
  const codeText = typeof suffix === 'string' ? suffix.trim() : '';
  requireThat(unitText.length > 0 && unitText.length <= 100,
    'failed-precondition', 'Quản lý chưa được phân mã đơn vị.');
  requireThat(/^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$/.test(codeText),
    'invalid-argument', 'Mã người dùng gồm 1–64 ký tự không dấu, số, _, ., @ hoặc -.');
  return `${unitText}-${codeText}`;
}

export function rootIds(cauHinh) {
  const ids = cauHinh?.rootUids;
  requireThat(Array.isArray(ids) && ids.length === 2 && new Set(ids).size === 2,
    'failed-precondition', 'Chưa cấu hình đúng hai quản lý tổng.');
  return ids;
}
export function isRoot(nguoiThaoTac, cauHinh) {
  return nguoiThaoTac?.status === 'active' && nguoiThaoTac.role === 'super_admin' &&
    rootIds(cauHinh).includes(nguoiThaoTac.id);
}
export function requireRoot(nguoiThaoTac, cauHinh) {
  requireThat(isRoot(nguoiThaoTac, cauHinh), 'permission-denied', 'Chỉ quản lý tổng được thực hiện.');
}
export function requireAdmin(nguoiThaoTac, cauHinh) {
  requireThat(isRoot(nguoiThaoTac, cauHinh) || (nguoiThaoTac?.status === 'active' &&
    nguoiThaoTac.role === 'admin' && rootIds(cauHinh).includes(nguoiThaoTac.createdBy) &&
    rootIds(cauHinh).includes(nguoiThaoTac.approvedBy) && nguoiThaoTac.createdBy !== nguoiThaoTac.approvedBy),
  'permission-denied', 'Tài khoản không có quyền quản trị đã được duyệt.');
}
export function requireDelete(nguoiThaoTac, cauHinh, dich) {
  requireAdmin(nguoiThaoTac, cauHinh);
  requireThat(!rootIds(cauHinh).includes(dich.id), 'permission-denied',
    'Không được xóa hai quản lý tổng.');
  requireThat(isRoot(nguoiThaoTac, cauHinh) ||
    (dich.role === 'user' && dich.createdBy === nguoiThaoTac.id),
  'permission-denied', 'Quản lý chỉ được xóa học viên do chính mình tạo.');
}
export function requireUpdate(nguoiThaoTac, cauHinh, dich) {
  requireAdmin(nguoiThaoTac, cauHinh);
  requireThat(!rootIds(cauHinh).includes(dich.id) && dich.role !== 'super_admin',
    'permission-denied', 'Quản lý tổng được cố định và không sửa trong ứng dụng.');
  requireThat(isRoot(nguoiThaoTac, cauHinh) ||
    (dich.role === 'user' && dich.createdBy === nguoiThaoTac.id),
  'permission-denied', 'Quản lý chỉ được sửa học viên do chính mình tạo.');
}
export function requireDecision(nguoiThaoTac, cauHinh, yeuCau) {
  requireRoot(nguoiThaoTac, cauHinh);
  requireThat(rootIds(cauHinh).includes(yeuCau.createdBy) && yeuCau.createdBy !== nguoiThaoTac.id,
    'permission-denied', 'Quản lý tổng gửi yêu cầu không được tự duyệt hoặc từ chối.');
}
export function validateRows(cacDong) {
  requireThat(Array.isArray(cacDong) && cacDong.length > 0 && cacDong.length <= 200,
    'invalid-argument', 'Chỉ nhận từ 1 đến 200 User.');
  const seen = new Set();
  return cacDong.map((dong) => {
    requireThat(dong && typeof dong.name === 'string' && dong.name.trim().length > 0 &&
      dong.name.trim().length <= 100 && typeof dong.username === 'string' &&
      /^[A-Za-z0-9_.@-]{3,64}$/.test(dong.username) && typeof dong.password === 'string' &&
      dong.password.length >= 6 && dong.password.length <= 128 &&
      (dong.code === undefined || (typeof dong.code === 'string' &&
        /^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$/.test(dong.code.trim()))) &&
      (dong.subUnit === undefined || (typeof dong.subUnit === 'string' &&
        dong.subUnit.trim().length > 0 && dong.subUnit.trim().length <= 100)) &&
      !Object.hasOwn(dong, 'role') && !Object.hasOwn(dong, 'createdBy'),
    'invalid-argument', 'Dữ liệu tài khoản không hợp lệ. Không được truyền vai trò hoặc người tạo.');
    const khoa = usernameKey(dong.username);
    requireThat(!seen.has(khoa), 'invalid-argument', 'Tên đăng nhập trùng trong danh sách.');
    seen.add(khoa);
    return { name: dong.name.trim(), username: dong.username.trim(), password: dong.password,
      ...(dong.code === undefined ? {} : { code: dong.code.trim() }),
      ...(dong.subUnit === undefined ? {} : { subUnit: dong.subUnit.trim().normalize('NFC') }) };
  });
}
