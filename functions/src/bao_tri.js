// API: bật/tắt chế độ cập nhật và ghi mốc để buộc phiên cũ đăng nhập lại.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requireRoot, requireThat } from './quy_tac.js';

export function maintenanceHandlers(coSoDuLieu, dongHo = () => Date.now()) {
  const trangThaiRef = coSoDuLieu.doc('system/app_status');

  async function setMode(maNguoiDung, dauVao) {
    requireThat(typeof dauVao.maintenance === 'boolean', 'invalid-argument',
      'Trạng thái cập nhật không hợp lệ.');
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const [cauHinh, taiKhoan, trangThaiHienTai] = await Promise.all([
        giaoDich.get(coSoDuLieu.doc('system/access')),
        giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}`)),
        giaoDich.get(trangThaiRef),
      ]);
      requireRoot({ ...taiKhoan.data(), id: maNguoiDung }, cauHinh.data());
      const batLanDau = dauVao.maintenance && trangThaiHienTai.data()?.maintenance !== true;
      const thoiDiem = Timestamp.fromMillis(dongHo());
      giaoDich.set(trangThaiRef, {
        maintenance: dauVao.maintenance,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: maNguoiDung,
        // App dùng mốc này để buộc đăng nhập lại nếu bỏ lỡ cả đợt bảo trì.
        lastMaintenanceAt: dauVao.maintenance && batLanDau
          ? thoiDiem
          : trangThaiHienTai.data()?.lastMaintenanceAt ?? trangThaiHienTai.data()?.maintenanceStartedAt ?? null,
        maintenanceStartedAt: FieldValue.delete(),
      }, {merge:true});
    });
    return { maintenance: dauVao.maintenance };
  }

  return { setMode };
}
