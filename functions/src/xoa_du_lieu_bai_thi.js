// Dùng chung khi xóa đề trực tiếp hoặc xóa khóa học/bài học chứa đề.
export async function xoaDuLieuBaiThi(coSoDuLieu, maBaiThi, thamChieuBaiThi) {
  // Xóa lượt thi trước để một lần nộp đồng thời không tạo kết quả sau khi quét.
  for (const ten of ['exam_private_runs', 'exam_sessions', 'exam_attempts']) {
    const nhom = await coSoDuLieu.collection(ten).where('examId', '==', maBaiThi).get();
    for (const banGhi of nhom.docs) await coSoDuLieu.recursiveDelete(banGhi.ref);
  }
  await coSoDuLieu.recursiveDelete(thamChieuBaiThi);
}
