// API QUẢN LÝ KHÓA HỌC: xóa khóa học và dữ liệu con bằng Admin SDK.
// Dùng backend để không bị giới hạn bởi truy vấn collection-group trên client.

import { requireRoot, requireThat } from './policy.js';

const maHopLe = (giaTri) =>
  typeof giaTri === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(giaTri);

export function courseHandlers(coSoDuLieu) {
  async function xoaKhoaHoc(maNguoiDung, dauVao) {
    requireThat(maHopLe(dauVao.courseId), 'invalid-argument', 'Mã khóa học không hợp lệ.');

    const thamChieuNguoiThaoTac = coSoDuLieu.doc(`users/${maNguoiDung}`);
    const thamChieuKhoaHoc = coSoDuLieu.doc(`courses/${dauVao.courseId}`);
    const [duLieuNguoiThaoTac, duLieuCauHinh, duLieuKhoaHoc] = await Promise.all([
      thamChieuNguoiThaoTac.get(),
      coSoDuLieu.doc('system/access').get(),
      thamChieuKhoaHoc.get(),
    ]);
    const nguoiThaoTac = { ...(duLieuNguoiThaoTac.data() ?? {}), id: maNguoiDung };
    requireRoot(nguoiThaoTac, duLieuCauHinh.data());
    requireThat(duLieuKhoaHoc.exists, 'not-found', 'Không tìm thấy khóa học.');

    const [cacBaiHoc, reviews, baiThiCuaKhoa] = await Promise.all([
      thamChieuKhoaHoc.collection('lessons').get(),
      thamChieuKhoaHoc.collection('reviews').get(),
      coSoDuLieu.collection('exams').where('courseId', '==', dauVao.courseId).get(),
    ]);
    const cacThamChieuBaiThi = new Map(baiThiCuaKhoa.docs.map((banGhi) => [banGhi.id, banGhi.ref]));
    const maLienKet = duLieuKhoaHoc.data()?.examId;
    if (maHopLe(maLienKet) && !cacThamChieuBaiThi.has(maLienKet)) {
      const duLieuLienKet = await coSoDuLieu.doc(`exams/${maLienKet}`).get();
      requireThat(!duLieuLienKet.exists || duLieuLienKet.data()?.courseId === dauVao.courseId,
        'failed-precondition', 'Bài thi đang thuộc khóa học khác.');
      if (duLieuLienKet.exists) cacThamChieuBaiThi.set(maLienKet, duLieuLienKet.ref);
    }
    // Chặn lượt thi mới trước khi xóa kết quả liên quan.
    await thamChieuKhoaHoc.update({ deleting: true });
    for (const thamChieuBaiThi of cacThamChieuBaiThi.values()) {
      await thamChieuBaiThi.update({ isOpen: false, deleting: true });
    }
    for (const [maBaiThi, thamChieuBaiThi] of cacThamChieuBaiThi) {
      const [cacLuotThiRieng, cacPhien, cacTongHop] = await Promise.all([
        coSoDuLieu.collection('exam_private_runs').where('examId', '==', maBaiThi).get(),
        coSoDuLieu.collection('exam_sessions').where('examId', '==', maBaiThi).get(),
        coSoDuLieu.collection('exam_attempts').where('examId', '==', maBaiThi).get(),
      ]);
      for (const banGhi of cacLuotThiRieng.docs) await coSoDuLieu.recursiveDelete(banGhi.ref);
      for (const banGhi of cacPhien.docs) await coSoDuLieu.recursiveDelete(banGhi.ref);
      for (const banGhi of cacTongHop.docs) await coSoDuLieu.recursiveDelete(banGhi.ref);
      await coSoDuLieu.recursiveDelete(thamChieuBaiThi);
    }
    const boGhi = coSoDuLieu.bulkWriter();
    for (const banGhi of cacBaiHoc.docs) boGhi.delete(banGhi.ref);
    for (const banGhi of reviews.docs) boGhi.delete(banGhi.ref);
    await xoaTienDoKhoaHoc(coSoDuLieu, boGhi, dauVao.courseId);
    boGhi.delete(thamChieuKhoaHoc);
    await boGhi.close();
    return { deleted: true };
  }

  async function xoaBaiHoc(maNguoiDung, dauVao) {
    requireThat(maHopLe(dauVao.courseId) && maHopLe(dauVao.lessonId), 'invalid-argument', 'Mã bài học không hợp lệ.');

    const thamChieuNguoiThaoTac = coSoDuLieu.doc(`users/${maNguoiDung}`);
    const thamChieuKhoaHoc = coSoDuLieu.doc(`courses/${dauVao.courseId}`);
    const thamChieuBaiHoc = thamChieuKhoaHoc.collection('lessons').doc(dauVao.lessonId);
    const [duLieuNguoiThaoTac, duLieuCauHinh, duLieuKhoaHoc, duLieuBaiHoc] = await Promise.all([
      thamChieuNguoiThaoTac.get(),
      coSoDuLieu.doc('system/access').get(),
      thamChieuKhoaHoc.get(),
      thamChieuBaiHoc.get(),
    ]);
    const nguoiThaoTac = { ...(duLieuNguoiThaoTac.data() ?? {}), id: maNguoiDung };
    requireRoot(nguoiThaoTac, duLieuCauHinh.data());
    requireThat(duLieuKhoaHoc.exists, 'not-found', 'Không tìm thấy khóa học.');
    requireThat(duLieuBaiHoc.exists, 'not-found', 'Không tìm thấy bài học.');

    const boGhi = coSoDuLieu.bulkWriter();
    await xoaTienDoKhoaHoc(coSoDuLieu, boGhi, dauVao.courseId, dauVao.lessonId);
    boGhi.delete(thamChieuBaiHoc);
    await boGhi.close();
    return { deleted: true };
  }

  return { deleteCourse: xoaKhoaHoc, deleteLesson: xoaBaiHoc };
}

async function xoaTienDoKhoaHoc(coSoDuLieu, boGhi, maKhoaHoc, maBaiHoc = null) {
  let truyVan = coSoDuLieu.collectionGroup('learning')
    .where('courseId', '==', maKhoaHoc);
  if (maBaiHoc != null) truyVan = truyVan.where('lessonId', '==', maBaiHoc);

  // Quét trực tiếp collection-group theo courseId, thay vì đọc toàn bộ users
  // rồi tuần tự chạy một truy vấn con cho từng tài khoản.
  for await (const banGhi of truyVan.stream()) {
    boGhi.delete(banGhi.ref);
  }
}
