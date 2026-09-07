import { createHash } from 'node:crypto';

export class PolicyError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
export function requireThat(condition, code, message) {
  if (!condition) throw new PolicyError(code, message);
}
export const usernameKey = (name) => createHash('sha256')
  .update(name.trim().toLowerCase()).digest('hex');
export const loginEmail = (name) => `${usernameKey(name)}@accounts.invalid`;
export const fingerprint = (data) => createHash('sha256')
  .update(JSON.stringify(data)).digest('hex');

export function rootIds(config) {
  const ids = config?.rootUids;
  requireThat(Array.isArray(ids) && ids.length === 2 && new Set(ids).size === 2,
    'failed-precondition', 'Chưa cấu hình đúng hai admin tổng.');
  return ids;
}
export function isRoot(actor, config) {
  return actor?.status === 'active' && actor.role === 'super_admin' &&
    rootIds(config).includes(actor.id);
}
export function requireRoot(actor, config) {
  requireThat(isRoot(actor, config), 'permission-denied', 'Chỉ admin tổng được thực hiện.');
}
export function requireAdmin(actor, config) {
  requireThat(isRoot(actor, config) || (actor?.status === 'active' &&
    actor.role === 'admin' && rootIds(config).includes(actor.createdBy) &&
    rootIds(config).includes(actor.approvedBy) && actor.createdBy !== actor.approvedBy),
  'permission-denied', 'Tài khoản không có quyền quản trị đã được duyệt.');
}
export function requireDelete(actor, config, target) {
  requireAdmin(actor, config);
  requireThat(!rootIds(config).includes(target.id), 'permission-denied',
    'Không được xóa hai admin tổng.');
  requireThat(isRoot(actor, config) ||
    (target.role === 'user' && target.createdBy === actor.id),
  'permission-denied', 'Admin phụ chỉ được xóa User do chính mình tạo.');
}
export function requireUpdate(actor, config, target) {
  requireAdmin(actor, config);
  requireThat(!rootIds(config).includes(target.id) && target.role !== 'super_admin',
    'permission-denied', 'Admin tổng được cố định và không sửa trong ứng dụng.');
  requireThat(isRoot(actor, config) ||
    (target.role === 'user' && target.createdBy === actor.id),
  'permission-denied', 'Admin phụ chỉ được sửa User do chính mình tạo.');
}
export function requireDecision(actor, config, request) {
  requireRoot(actor, config);
  requireThat(rootIds(config).includes(request.createdBy) && request.createdBy !== actor.id,
    'permission-denied', 'Admin tổng gửi yêu cầu không được tự duyệt hoặc từ chối.');
}
export function validateRows(rows) {
  requireThat(Array.isArray(rows) && rows.length > 0 && rows.length <= 200,
    'invalid-argument', 'Chỉ nhận từ 1 đến 200 User.');
  const seen = new Set();
  return rows.map((row) => {
    requireThat(row && typeof row.name === 'string' && row.name.trim().length > 0 &&
      row.name.trim().length <= 100 && typeof row.username === 'string' &&
      /^[A-Za-z0-9_.@-]{3,64}$/.test(row.username) && typeof row.password === 'string' &&
      row.password.length >= 6 && row.password.length <= 128 &&
      !Object.hasOwn(row, 'role') && !Object.hasOwn(row, 'createdBy'),
    'invalid-argument', 'Dữ liệu tài khoản không hợp lệ. Không được truyền vai trò hoặc người tạo.');
    const key = usernameKey(row.username);
    requireThat(!seen.has(key), 'invalid-argument', 'Tên đăng nhập trùng trong danh sách.');
    seen.add(key);
    return { name: row.name.trim(), username: row.username.trim(), password: row.password };
  });
}
