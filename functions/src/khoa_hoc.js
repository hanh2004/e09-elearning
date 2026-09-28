// API QUẢN LÝ KHÓA HỌC: xóa khóa học và dữ liệu con bằng Admin SDK.
// Dùng backend để không bị giới hạn bởi truy vấn collection-group trên client.

import { requireRoot, requireThat } from './quy_tac.js';
import { randomUUID } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';

const maHopLe = (giaTri) =>
  typeof giaTri === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(giaTri);
// Callable Cloud Functions cho phép chạy tối đa 540 giây; giữ khóa lâu hơn
// giới hạn đó để tránh cho thao tác thứ hai giành khóa khi thao tác đầu còn sống.
const THOI_HAN_KHOA_XOA_MS = 10 * 60 * 1000;

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
      await xoaDuLieuBaiThi(coSoDuLieu, maBaiThi, thamChieuBaiThi);
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

    const maBaiThi = duLieuBaiHoc.data()?.examId;
    let thamChieuBaiThi;
    let baiThiTonTai = false;
    let baiThiDuocDungNoiKhac = false;
    if (maHopLe(maBaiThi)) {
      thamChieuBaiThi = coSoDuLieu.doc(`exams/${maBaiThi}`);
      const [duLieuBaiThi, cacKhoaHocLienKet, cacBaiHocLienKet] = await Promise.all([
        thamChieuBaiThi.get(),
        coSoDuLieu.collection('courses').where('examId', '==', maBaiThi).get(),
        coSoDuLieu.collectionGroup('lessons').where('examId', '==', maBaiThi).get(),
      ]);
      baiThiTonTai = duLieuBaiThi.exists;
      const duLieuBaiThiData = duLieuBaiThi.data();
      requireThat(!duLieuBaiThiData?.courseId || duLieuBaiThiData.courseId === dauVao.courseId,
        'failed-precondition', 'Đề thi đang thuộc khóa học khác.');
      baiThiDuocDungNoiKhac = !cacKhoaHocLienKet.empty || cacBaiHocLienKet.docs.some((banGhi) =>
        banGhi.ref.path !== thamChieuBaiHoc.path);
    }

    // Khóa bài học bằng transaction trước khi dò lượt thi đang chạy. examStart
    // cũng đọc tài liệu này trong transaction, nên lượt thi chỉ có thể bắt đầu
    // trước khóa (và sẽ được phát hiện) hoặc bị từ chối sau khóa.
    const maTacVuXoa = randomUUID();
    await coSoDuLieu.runTransaction(async (giaoDich) => {
      const banGhiBaiHoc = await giaoDich.get(thamChieuBaiHoc);
      requireThat(banGhiBaiHoc.exists, 'not-found', 'Không tìm thấy bài học.');
      const duLieuHienTai = banGhiBaiHoc.data();
      const khoaConHieuLuc = Number.isFinite(duLieuHienTai.deletingLeaseUntil) &&
        duLieuHienTai.deletingLeaseUntil > Date.now();
      requireThat(!khoaConHieuLuc, 'failed-precondition',
        'Bài học đang được một thao tác xóa khác xử lý.');
      giaoDich.update(thamChieuBaiHoc, {
        deleting: true,
        deletingOperationId: maTacVuXoa,
        deletingLeaseUntil: Date.now() + THOI_HAN_KHOA_XOA_MS,
      });
    });

    // Nếu lượt thi còn hoạt động qua bài học dùng chung, mở khóa để học viên
    // có thể nộp bài; mọi lỗi trước khi bắt đầu dọn dữ liệu cũng được mở khóa.
    const moKhoaBaiHoc = async (giuTrangThaiDangXoa = false) => coSoDuLieu.runTransaction(async (giaoDich) => {
      const banGhiBaiHoc = await giaoDich.get(thamChieuBaiHoc);
      if (!banGhiBaiHoc.exists || banGhiBaiHoc.data()?.deletingOperationId !== maTacVuXoa) return;
      giaoDich.update(thamChieuBaiHoc, {
        deleting: giuTrangThaiDangXoa,
        deletingOperationId: FieldValue.delete(),
        deletingLeaseUntil: FieldValue.delete(),
      });
    });
    try {
      if (baiThiDuocDungNoiKhac) {
        const cacLuotThi = await coSoDuLieu.collection('exam_private_runs')
          .where('examId', '==', maBaiThi).get();
        const coLuotDangLamTuBaiNay = cacLuotThi.docs.some((banGhi) => {
          const luotThi = banGhi.data();
          return luotThi.status === 'in_progress' && luotThi.courseId === dauVao.courseId &&
            luotThi.lessonId === dauVao.lessonId;
        });
        requireThat(!coLuotDangLamTuBaiNay, 'failed-precondition',
          'Có học viên đang làm đề qua bài học này. Hãy hoàn tất lượt thi rồi thử xóa lại.');
      }
    } catch (loi) {
      await moKhoaBaiHoc();
      throw loi;
    }

    try {
      if (thamChieuBaiThi && baiThiTonTai && !baiThiDuocDungNoiKhac) {
        await thamChieuBaiThi.update({ isOpen: false, deleting: true });
      }
      if (thamChieuBaiThi && !baiThiDuocDungNoiKhac) {
        await xoaDuLieuBaiThi(coSoDuLieu, maBaiThi, thamChieuBaiThi);
      }
      const boGhi = coSoDuLieu.bulkWriter();
      await xoaTienDoKhoaHoc(coSoDuLieu, boGhi, dauVao.courseId, dauVao.lessonId);
      boGhi.delete(thamChieuBaiHoc);
      await boGhi.close();
      return { deleted: true };
    } catch (loi) {
      // Giữ trạng thái deleting để chặn thi vào dữ liệu đang dọn dở, nhưng
      // bỏ chủ sở hữu khóa để lần gọi xóa sau có thể tiếp tục dọn.
      await moKhoaBaiHoc(true);
      throw loi;
    }
  }

  return { deleteCourse: xoaKhoaHoc, deleteLesson: xoaBaiHoc };
}

async function xoaTienDoKhoaHoc(coSoDuLieu, boGhi, maKhoaHoc, maBaiHoc = null) {
  let truyVan = coSoDuLieu.collectionGroup('learning')
    .where('courseId', '==', maKhoaHoc);
  if (maBaiHoc != null) truyVan = truyVan.where('lessonId', '==', maBaiHoc);

  try {
    // Dùng truy vấn collection-group trước để xóa nhanh trên hệ thống lớn.
    for await (const banGhi of truyVan.stream()) {
      boGhi.delete(banGhi.ref);
    }
  } catch (loi) {
    // Chỉ mục collection-group có thể chưa được triển khai ở một môi trường
    // cũ. Quét từng collection learning của học viên để thao tác xóa vẫn chạy.
    if (!['failed-precondition', 'FAILED_PRECONDITION', 9].includes(loi?.code)) {
      throw loi;
    }
    const cacNguoiDung = await coSoDuLieu.collection('users').get();
    for (let batDau = 0; batDau < cacNguoiDung.docs.length; batDau += 20) {
      const cacTienDo = await Promise.all(
        cacNguoiDung.docs.slice(batDau, batDau + 20).map((nguoiDung) => {
          let truyVanHocVien = nguoiDung.ref.collection('learning')
            .where('courseId', '==', maKhoaHoc);
          if (maBaiHoc != null) {
            truyVanHocVien = truyVanHocVien.where('lessonId', '==', maBaiHoc);
          }
          return truyVanHocVien.get();
        }),
      );
      for (const ketQua of cacTienDo) {
        for (const banGhi of ketQua.docs) boGhi.delete(banGhi.ref);
      }
    }
  }
}

async function xoaDuLieuBaiThi(coSoDuLieu, maBaiThi, thamChieuBaiThi) {
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
