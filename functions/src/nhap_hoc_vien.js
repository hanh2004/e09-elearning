// API TÀI KHOẢN / NHẬP USER: giữ chỗ dữ liệu, tạo Auth và kích hoạt an toàn.
// Tạo hồ sơ theo nhóm nhỏ để hỗ trợ đủ 200 dòng và có thể tiếp tục sau lỗi.
import { FieldValue } from 'firebase-admin/firestore';
import {
  fingerprint,
  isRoot,
  PolicyError,
  requireThat,
  usernameKey,
  validateRows,
} from './quy_tac.js';

const IMPORT_PROFILE_CHUNK_SIZE = 50;

export function createImportUsersHandler({
  coSoDuLieu,
  xacThuc,
  stamp,
  nguCanh,
  unitReservation,
  userRef,
  ensureAuth,
}) {
  return async function importUsers(maNguoiDung, dauVao) {
    const cacDong = validateRows(dauVao.rows);
    requireThat(typeof dauVao.operationId === 'string' && /^[a-f0-9]{32}$/.test(dauVao.operationId),
      'invalid-argument', 'Thiếu mã thao tác.');
    const opRef = coSoDuLieu.doc(`account_operations/${maNguoiDung}_${dauVao.operationId}`);
    const digest = fingerprint(cacDong.map(({serialNumber, ...row}) => row));
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
      const refs = cacDong.map((r) => coSoDuLieu.doc(`usernames/${usernameKey(r.username)}`));
      for (let i = 0; i < refs.length; i++) {
        const sttPrefix = cacDong[i].serialNumber
          ? `STT ${cacDong[i].serialNumber}: ` : '';
        requireThat(!(await giaoDich.get(refs[i])).exists, 'already-exists',
          `${sttPrefix}Tên đăng nhập đã được sử dụng hoặc đang chờ xử lý.`);
      }
      const ids = cacDong.map(() => coSoDuLieu.collection('users').doc().id);
      for (const dong of cacDong) {
        if (dong.subUnit) requireThat(allowedSubUnits.has(dong.subUnit),
          'permission-denied', 'Trực thuộc không thuộc quản lý đang tạo học viên.');
      }
      // Giữ tên đăng nhập để hai lượt nhập không lấy trùng.
      // Chỉ ghi metadata ở bước này; hồ sơ được tạo theo nhóm nhỏ bên dưới.
      reserveUnit();
      for (let i = 0; i < cacDong.length; i++) {
        giaoDich.create(refs[i], { uid: ids[i], username: cacDong[i].username });
      }
      // Không lưu mật khẩu trong nhật ký thao tác; lần thử lại dùng cùng dữ liệu.
      const giaTri = {
        ids, digest, status: 'provisioning', createdBy: maNguoiDung,
        chunked: true, unit: donVi.trim(),
      };
      giaoDich.create(opRef, { ...giaTri, createdAt: stamp() });
      return giaTri;
    });
    if (op.status === 'completed') return { count: op.ids.length };
    if (op.chunked) {
      // Mỗi nhóm hồ sơ được ghi nguyên tử riêng và có thể chạy lại an toàn.
      for (let batDau = 0; batDau < cacDong.length; batDau += IMPORT_PROFILE_CHUNK_SIZE) {
        const ketThuc = Math.min(batDau + IMPORT_PROFILE_CHUNK_SIZE, cacDong.length);
        const trangThai = await coSoDuLieu.runTransaction(async (giaoDich) => {
          await nguCanh(giaoDich, maNguoiDung);
          const thaoTac = (await giaoDich.get(opRef)).data();
          requireThat(thaoTac?.digest === digest,
            'failed-precondition', 'Mã thao tác không khớp dữ liệu đang nhập.');
          if (thaoTac.status === 'completed') return 'completed';
          requireThat(thaoTac.status === 'provisioning',
            'failed-precondition', 'Lượt nhập không còn ở trạng thái có thể tiếp tục.');
          const cacTaiKhoan = [];
          for (let i = batDau; i < ketThuc; i++) {
            const ma = op.ids[i];
            const [hoSo, tenDangNhap] = await Promise.all([
              giaoDich.get(userRef(ma)),
              giaoDich.get(coSoDuLieu.doc(`usernames/${usernameKey(cacDong[i].username)}`)),
            ]);
            requireThat(tenDangNhap.exists && tenDangNhap.data().uid === ma,
            'failed-precondition', 'Không tìm thấy phần giữ chỗ của lượt nhập. Hãy liên hệ quản trị hệ thống.');
            if (hoSo.exists) {
              requireThat(hoSo.data().status === 'provisioning' &&
                hoSo.data().provisioningOperationId === opRef.id,
              'failed-precondition', 'Tài khoản đã được thay đổi trong lúc nhập.');
              continue;
            }
            cacTaiKhoan.push({ index: i, id: ma });
          }
          for (const taiKhoan of cacTaiKhoan) {
            const i = taiKhoan.index;
            const dong = cacDong[i];
            giaoDich.create(userRef(taiKhoan.id), {
              name: dong.name,
              username: dong.username,
              role: 'user',
              unit: op.unit,
              ...(dong.subUnit ? { subUnit: dong.subUnit } : {}),
              status: 'provisioning',
              provisioningOperationId: opRef.id,
              createdBy: maNguoiDung,
              unitNeedsConfirmation: true,
              unitAssignmentVersion: 0,
              createdAt: stamp(),
            });
          }
          return 'provisioning';
        });
        if (trangThai === 'completed') return { count: op.ids.length };
      }
    }
    // Auth được tạo trước; Rules vẫn chặn các hồ sơ cho tới lần kích hoạt cuối.
    for (let i = 0; i < cacDong.length; i++) {
      const dong = cacDong[i];
      const ma = op.ids[i];
      try {
        await ensureAuth(ma, dong);
        await xacThuc.updateUser(ma, { disabled: false });
      } catch (error) {
        const sttPrefix = dong.serialNumber ? `STT ${dong.serialNumber}: ` : '';
        throw new PolicyError('unavailable',
          `${sttPrefix}Đã dừng nhập tại tài khoản này do lỗi tạo tài khoản. Hãy kiểm tra dòng này rồi thử lại.`);
      }
    }
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      await nguCanh(giaoDich, maNguoiDung);
      const hienTai = (await giaoDich.get(opRef)).data();
      if (hienTai.status === 'completed') return;
      for (const ma of op.ids) {
        const hoSo = (await giaoDich.get(userRef(ma))).data();
        requireThat(hoSo?.status === 'provisioning' &&
          (!op.chunked || hoSo.provisioningOperationId === opRef.id),
          'failed-precondition', 'Tài khoản đang được xử lý bởi thao tác khác.');
      }
      for (const ma of op.ids) giaoDich.update(userRef(ma), {
        status: 'active', provisioningOperationId: FieldValue.delete(),
      });
      giaoDich.update(opRef, { status: 'completed', completedAt: stamp() });
    });
    return { count: op.ids.length };
  };
}
