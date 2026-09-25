// API THI: cấp phiên làm bài, trộn câu hỏi, lưu câu trả lời và chấm điểm trên server.
// prepareQuestions/normalizeQuestion xử lý câu hỏi; examHandlers chứa các API thi.
import { createHash, randomInt } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requireThat, requireRoot } from './policy.js';

const khoa = (maNguoiDung, maBaiThi) => createHash('sha256').update(JSON.stringify([maNguoiDung, maBaiThi])).digest('hex');
const ma = (giaTri) => typeof giaTri === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(giaTri);
const miliGiay = (giaTri) => giaTri?.toMillis?.() ?? null;

function shuffled(items) {
  const ketQua = [...items];
  for (let i = ketQua.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [ketQua[i], ketQua[j]] = [ketQua[j], ketQua[i]];
  }
  return ketQua;
}

export function prepareQuestions(cacCauHoi, policy) {
  const ketQua = cacCauHoi.map(q => {
    if (!policy.shuffleAnswers) return {...q, options:[...q.options]};
    const indices = shuffled(q.options.map((_, i) => i));
    return {...q, options:indices.map(i => q.options[i]), correctIndex:indices.indexOf(q.correctIndex)};
  });
  return policy.shuffleQuestions ? shuffled(ketQua) : ketQua;
}

export function normalizeQuestion(raw, questionId) {
  const title = raw.questionText ?? raw.noi_dung ?? raw.content;
  const options = raw.options ?? raw.ds_lua_chon ?? raw.answers;
  requireThat(typeof title === 'string' && title.trim() && Array.isArray(options) && options.length >= 2 && options.length <= 20,
    'failed-precondition', 'Đề có câu hỏi chưa hợp lệ.');
  const cacGiaTri = options.map((option) => typeof option === 'string' ? option : option.noi_dung ?? option.noiDung ?? '');
  const correct = options.flatMap((option, index) =>
    index === raw.correctAnswerIndex || index === raw.correctIndex || option?.dap_an_dung === true || option?.dapAnDung === true ? [index] : []);
  requireThat(cacGiaTri.every((giaTri) => typeof giaTri === 'string' && giaTri.trim()) && correct.length === 1 &&
    (!raw.loai_cau_hoi || raw.loai_cau_hoi === 'SINGLE_CHOICE'), 'failed-precondition', 'Đề phải có một đáp án đúng cho mỗi câu.');
  return { id: questionId, title, options: cacGiaTri, correctIndex: correct[0], explanation: String(raw.explanation ?? raw.loi_giai ?? '') };
}

function lamSachDapAn(dauVao, cacCauHoi) {
  requireThat(dauVao && typeof dauVao === 'object' && !Array.isArray(dauVao), 'invalid-argument', 'Đáp án không hợp lệ.');
  const allowed = new Map(cacCauHoi.map((q) => [q.id, q]));
  for (const [qid, giaTri] of Object.entries(dauVao)) {
    requireThat(allowed.has(qid) && Number.isInteger(giaTri) && giaTri >= 0 && giaTri < allowed.get(qid).options.length,
      'invalid-argument', 'Lựa chọn không hợp lệ.');
  }
  return { ...dauVao };
}

export function gradeRun(luotThi, cacDapAn) {
  const correctAnswers = luotThi.questions.filter((q) => cacDapAn[q.id] === q.correctIndex).length;
  const diem = Math.round(correctAnswers * 10000 / luotThi.questions.length) / 1000;
  return { score: diem, correctAnswers, totalQuestions: luotThi.questions.length, passed: diem >= luotThi.passScore,
    ...(luotThi.showSolutions ? { review: luotThi.questions.map((q) => ({ id:q.id, title:q.title, options:q.options,
      selectedIndex: cacDapAn[q.id] ?? null, correctIndex:q.correctIndex, explanation:q.explanation })) } : {}) };
}

export function examHandlers(coSoDuLieu, dongHo = () => Date.now()) {
  async function yeuCauDaHoc(giaoDich, maNguoiDung, dauVao, {allowEnded = false} = {}) {
    requireThat(ma(dauVao.courseId) && ma(dauVao.lessonId), 'failed-precondition',
      'Vui lòng mở nội dung học trong mục Kiểm tra và học xong trước khi làm bài.');
    const khoaHoc = (await giaoDich.get(coSoDuLieu.doc(`courses/${dauVao.courseId}`))).data();
    const baiHoc = (await giaoDich.get(coSoDuLieu.doc(`courses/${dauVao.courseId}/lessons/${dauVao.lessonId}`))).data();
    const tienDo = (await giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}/learning/${dauVao.courseId}_${dauVao.lessonId}`))).data();
    requireThat(khoaHoc?.published === true && khoaHoc?.deleting !== true &&
      (miliGiay(khoaHoc.startsAt) == null || miliGiay(khoaHoc.startsAt) <= dongHo()) &&
      (allowEnded || miliGiay(khoaHoc.endsAt) == null || miliGiay(khoaHoc.endsAt) > dongHo()),
      'failed-precondition', 'Nội dung học chưa mở hoặc đã kết thúc.');
    requireThat(khoaHoc.learningMode !== 'study_only', 'failed-precondition', 'Khóa học này chỉ dùng để học.');
    const kiemTraTheoKhoa = khoaHoc?.learningMode === 'study_exam';
    let cacBanGhiHoanThanh;
    if (kiemTraTheoKhoa) {
      requireThat(baiHoc && khoaHoc.examId === dauVao.examId, 'failed-precondition', 'Bài kiểm tra không thuộc khóa học này.');
      const cacBaiHoc = await giaoDich.get(coSoDuLieu.collection(`courses/${dauVao.courseId}/lessons`));
      const cacMauTin = await giaoDich.get(coSoDuLieu.collection(`users/${maNguoiDung}/learning`).where('courseId', '==', dauVao.courseId));
      const cacMaDaHoanThanh = new Set(cacMauTin.docs
        .filter((banGhi) => banGhi.data().studyCompleted === true || banGhi.data().completed === true)
        .map((banGhi) => banGhi.data().lessonId));
      requireThat(!cacBaiHoc.empty && cacBaiHoc.docs.every((banGhi) => cacMaDaHoanThanh.has(banGhi.id)),
        'failed-precondition', 'Bạn cần học xong tất cả nội dung trong khóa trước khi làm bài kiểm tra.');
      cacBanGhiHoanThanh = cacBaiHoc.docs.map((lessonDoc) => ({
        ref: coSoDuLieu.doc(`users/${maNguoiDung}/learning/${dauVao.courseId}_${lessonDoc.id}`),
        data: cacMauTin.docs.find((banGhi) => banGhi.id === `${dauVao.courseId}_${lessonDoc.id}`)?.data() ?? {},
      }));
    } else {
      requireThat(baiHoc?.learningMode === 'study_exam' && baiHoc.examId === dauVao.examId,
        'failed-precondition', 'Bài kiểm tra không thuộc nội dung học này.');
      requireThat((tienDo?.studyCompleted === true || tienDo?.completed === true) && tienDo.courseId === dauVao.courseId &&
        tienDo.lessonId === dauVao.lessonId,
        'failed-precondition', 'Bạn cần học xong nội dung trước khi làm bài kiểm tra.');
      cacBanGhiHoanThanh = [{ref: coSoDuLieu.doc(`users/${maNguoiDung}/learning/${dauVao.courseId}_${dauVao.lessonId}`), data: tienDo}];
    }
    return {courseTitle: khoaHoc.title ?? 'Khóa học', courseEndsAt:miliGiay(khoaHoc.endsAt), courseExam: kiemTraTheoKhoa, completionRecords: cacBanGhiHoanThanh};
  }
  async function hocVien(giaoDich, maNguoiDung) {
    const hoSo = (await giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}`))).data();
    requireThat(hoSo?.status === 'active' && hoSo.role === 'user', 'permission-denied', 'Cần đăng nhập học viên đang hoạt động.');
    return hoSo;
  }
  function luotThiCongKhai(luotThi) {
    return { status:luotThi.status, serverNow:dongHo(), runId:luotThi.id, examId:luotThi.examId, courseId:luotThi.courseId, lessonId:luotThi.lessonId, title:luotThi.title, endsAt:miliGiay(luotThi.endsAt), revision:luotThi.revision,
      selectedAnswers:luotThi.selectedAnswers, questions:luotThi.questions.map(({correctIndex, explanation, ...cauHoi}) => cauHoi) };
  }
  function hoanTat(giaoDich, thamChieuPhien, phien, thamChieuRieng, luotThi, cacDapAn, expired, duLieuHoc) {
    const lucHoanThanh = expired
      ? Timestamp.fromMillis(Math.min(miliGiay(luotThi.endsAt), duLieuHoc.courseEndsAt ?? Infinity))
      : FieldValue.serverTimestamp();
    const nguCanh = {courseId:luotThi.courseId, lessonId:luotThi.lessonId, courseTitle:luotThi.courseTitle ?? duLieuHoc.courseTitle};
    const ketQua = { ...gradeRun(luotThi, cacDapAn), ...nguCanh, passScore:luotThi.passScore, status:'completed', runId:luotThi.id, examId:luotThi.examId, title:luotThi.title, expired };
    const diemCaoNhatCu = phien.bestScore ?? -1;
    const laDiemCaoNhat = ketQua.score >= diemCaoNhatCu;
    const nguCanhDiemCaoNhat = laDiemCaoNhat ? nguCanh : {
      courseId: phien.bestCourseId ?? nguCanh.courseId,
      lessonId: phien.bestLessonId ?? nguCanh.lessonId,
      courseTitle: phien.bestCourseTitle ?? nguCanh.courseTitle,
    };
    for (const mauTin of duLieuHoc.completionRecords) {
      if (mauTin.data.completed === true && mauTin.data.completedExamId === luotThi.examId) continue;
      giaoDich.update(mauTin.ref, {completed:true, examCompleted:true, completedExamId:luotThi.examId,
        studyCompleted:true, studyCompletedAt:mauTin.data.studyCompletedAt ?? mauTin.data.completedAt ?? FieldValue.serverTimestamp(),
        completedAt: lucHoanThanh, updatedAt:FieldValue.serverTimestamp()});
    }
    giaoDich.update(thamChieuRieng, {status:'completed', selectedAnswers:cacDapAn, result: ketQua, completedAt: lucHoanThanh});
    giaoDich.set(thamChieuPhien.collection('runs').doc(luotThi.id), {...ketQua, completedAt: lucHoanThanh, userId:luotThi.userId});
    const soLuotHoanThanh = (phien.completedCount ?? 0) + 1;
    giaoDich.update(thamChieuPhien, {activeRunId:null, completedCount: soLuotHoanThanh, bestScore:Math.max(diemCaoNhatCu, ketQua.score),
      ...(laDiemCaoNhat ? {bestCourseId:nguCanh.courseId, bestLessonId:nguCanh.lessonId, bestCourseTitle:nguCanh.courseTitle} : {})});
    const tongHop = {...nguCanhDiemCaoNhat, userId:luotThi.userId, examId:luotThi.examId, examTitle:luotThi.title, status:'completed', attemptCount:soLuotHoanThanh,
      lastAttemptAt:FieldValue.serverTimestamp()};
    if (laDiemCaoNhat) Object.assign(tongHop, {bestScore:ketQua.score, diemSo:ketQua.score,
      passed:ketQua.passed,passScore:luotThi.passScore,
      correctAnswers:ketQua.correctAnswers, totalQuestions:ketQua.totalQuestions, completedAt: lucHoanThanh,
      answers:luotThi.questions.map((q) => ({ma_cau_hoi:q.id, ma_lua_chon:String(cacDapAn[q.id] ?? ''), tra_loi_dung:cacDapAn[q.id] === q.correctIndex}))});
    giaoDich.set(coSoDuLieu.doc(`exam_attempts/secure_${thamChieuPhien.id}`), tongHop, {merge:true});
    return ketQua;
  }
  async function list(maNguoiDung) {
    return coSoDuLieu.runTransaction(async (giaoDich) => {
      await hocVien(giaoDich, maNguoiDung);
      const [cacBaiThi, cacPhien, legacy] = await Promise.all([giaoDich.get(coSoDuLieu.collection('exams')), giaoDich.get(coSoDuLieu.collection('exam_sessions').where('userId','==',maNguoiDung)), giaoDich.get(coSoDuLieu.collection('exam_attempts').where('userId','==',maNguoiDung))]);
      const cacSoLuot = new Map(cacPhien.docs.map((banGhi) => [banGhi.data().examId, banGhi.data()]));
      return {exams:cacBaiThi.docs.filter(banGhi => banGhi.data().deleting !== true).map((banGhi) => { const e = banGhi.data(); const s = cacSoLuot.get(banGhi.id);
        const soLuotCuDaDung = legacy.docs.filter(d => d.data().examId === banGhi.id).reduce((soLuong,d) => soLuong +
          (d.data().attemptCount ?? (d.data().status === 'completed' ? 1 : 0)) + (d.data().status === 'in_progress' ? 1 : 0),0);
        return {id:banGhi.id, title:e.title ?? 'Bài thi', durationMinutes:e.durationMinutes ?? (parseInt(e.duration,10) || 45),
          isOpen:e.isOpen === true, closesAt:miliGiay(e.closesAt), opensAt:miliGiay(e.opensAt), maxAttempts:e.maxAttempts ?? null,
          usedAttempts:s ? s.issuedCount+s.legacyUsed : soLuotCuDaDung, active:s?.activeRunId != null}; })};
    });
  }
  async function batDau(maNguoiDung, dauVao) {
    requireThat(ma(dauVao.examId), 'invalid-argument', 'Mã đề không hợp lệ.');
    const thamChieuPhien = coSoDuLieu.doc(`exam_sessions/${khoa(maNguoiDung,dauVao.examId)}`);
    return coSoDuLieu.runTransaction(async (giaoDich) => {
      await hocVien(giaoDich, maNguoiDung);
      const phien = (await giaoDich.get(thamChieuPhien)).data();
      const duLieuHoc = await yeuCauDaHoc(giaoDich, maNguoiDung, dauVao);
      if (phien?.activeRunId) {
        const thamChieuRieng = coSoDuLieu.doc(`exam_private_runs/${phien.activeRunId}`);
        const luotThi = (await giaoDich.get(thamChieuRieng)).data();
        requireThat(luotThi && luotThi.userId === maNguoiDung, 'failed-precondition', 'Lượt thi không hợp lệ.');
        requireThat(luotThi.courseId === dauVao.courseId && (duLieuHoc.courseExam || luotThi.lessonId === dauVao.lessonId),
          'failed-precondition', 'Hãy hoàn tất lượt kiểm tra đang làm trong nội dung đã mở trước đó.');
        if (miliGiay(luotThi.endsAt) <= dongHo()) return hoanTat(giaoDich, thamChieuPhien, phien, thamChieuRieng, luotThi, luotThi.selectedAnswers, true, duLieuHoc);
        return luotThiCongKhai(luotThi);
      }
      const thamChieuBaiThi = coSoDuLieu.doc(`exams/${dauVao.examId}`);
      const baiThi = (await giaoDich.get(thamChieuBaiThi)).data();
      requireThat(baiThi?.isOpen === true && baiThi.deleting !== true && (miliGiay(baiThi.opensAt) == null || miliGiay(baiThi.opensAt) <= dongHo()) &&
        (miliGiay(baiThi.closesAt) == null || miliGiay(baiThi.closesAt) > dongHo()), 'failed-precondition', 'Bài thi hiện chưa mở hoặc đã đóng.');
      let soLuotCuDaDung = phien?.legacyUsed ?? 0;
      if (!phien) {
        const cu = await giaoDich.get(coSoDuLieu.collection('exam_attempts').where('userId','==',maNguoiDung));
        soLuotCuDaDung = cu.docs.filter((d) => d.data().examId === dauVao.examId).reduce((soLuong,d) => soLuong +
          (d.data().attemptCount ?? (d.data().status === 'completed' ? 1 : 0)) + (d.data().status === 'in_progress' ? 1 : 0),0);
      }
      const soLuotDaCap = phien?.issuedCount ?? 0;
      requireThat(baiThi.maxAttempts == null || soLuotDaCap + soLuotCuDaDung < baiThi.maxAttempts, 'resource-exhausted', 'Bạn đã hết lượt thi.');
      const questionDocs = await giaoDich.get(thamChieuBaiThi.collection('questions').orderBy('__name__'));
      const source = questionDocs.empty && Array.isArray(baiThi.questions) ? baiThi.questions.map((raw,i) => ({raw,id:String(i)})) : questionDocs.docs.map((d) => ({raw:d.data(),id:d.id}));
      requireThat(source.length > 0 && source.length <= 200, 'failed-precondition', 'Đề cần có 1–200 câu hỏi.');
      const cacCauHoi = prepareQuestions(source.map((q) => normalizeQuestion(q.raw,q.id)), baiThi);
      requireThat(Buffer.byteLength(JSON.stringify(cacCauHoi),'utf8') < 800000, 'failed-precondition', 'Nội dung đề quá lớn. Hãy chia thành nhiều đề.');
      const thoiLuong = baiThi.durationMinutes ?? (parseInt(baiThi.duration, 10) || 45);
      requireThat(Number.isInteger(thoiLuong) && thoiLuong > 0 && thoiLuong <= 1440, 'failed-precondition', 'Thời gian đề không hợp lệ.');
      requireThat(baiThi.passScore == null || (Number.isFinite(baiThi.passScore) && baiThi.passScore >= 0 && baiThi.passScore <= 10),
        'failed-precondition', 'Điểm đạt cần nằm trong khoảng 0–10.');
      const maLuotThi = `${thamChieuPhien.id}_${soLuotDaCap+1}`;
      const hanKhoaHoc = duLieuHoc.courseEndsAt;
      const luotThi = {id:maLuotThi, userId:maNguoiDung, examId:dauVao.examId, courseId:dauVao.courseId, lessonId:dauVao.lessonId, courseTitle:duLieuHoc.courseTitle, title:baiThi.title ?? 'Bài thi', status:'in_progress', questions: cacCauHoi,
        passScore:typeof baiThi.passScore === 'number' ? baiThi.passScore : 5, showSolutions:baiThi.showSolutions === true,
        endsAt:Timestamp.fromMillis(Math.min(dongHo()+thoiLuong*60000,miliGiay(baiThi.closesAt) ?? Infinity, hanKhoaHoc ?? Infinity)), selectedAnswers:{}, revision:0};
      giaoDich.set(thamChieuPhien,{userId:maNguoiDung,examId:dauVao.examId,issuedCount:soLuotDaCap+1,legacyUsed: soLuotCuDaDung,activeRunId:maLuotThi,completedCount:phien?.completedCount ?? 0,bestScore:phien?.bestScore ?? -1});
      giaoDich.create(coSoDuLieu.doc(`exam_private_runs/${maLuotThi}`),luotThi);
      return luotThiCongKhai(luotThi);
    });
  }
  async function capNhat(maNguoiDung, dauVao, submitting) {
    requireThat(ma(dauVao.runId), 'invalid-argument', 'Mã lượt thi không hợp lệ.');
    return coSoDuLieu.runTransaction(async (giaoDich) => {
      await hocVien(giaoDich,maNguoiDung);
      const thamChieuRieng = coSoDuLieu.doc(`exam_private_runs/${dauVao.runId}`);
      const luotThi = (await giaoDich.get(thamChieuRieng)).data();
      requireThat(luotThi?.userId === maNguoiDung, 'permission-denied', 'Không có quyền với lượt thi.');
      if (luotThi.status === 'completed') return luotThi.result;
      // Lượt thi đã cấp có thể hết hạn đúng lúc khóa học đóng.
      // Chấm bằng đáp án đã lưu trên máy chủ, không nhận sửa muộn.
      const duLieuHoc = await yeuCauDaHoc(giaoDich, maNguoiDung, luotThi, {allowEnded:true});
      const thamChieuPhien = coSoDuLieu.doc(`exam_sessions/${khoa(maNguoiDung,luotThi.examId)}`);
      const phien = (await giaoDich.get(thamChieuPhien)).data();
      requireThat(phien?.activeRunId === dauVao.runId, 'failed-precondition', 'Lượt thi đã thay đổi.');
      const hanChot = Math.min(miliGiay(luotThi.endsAt), duLieuHoc.courseEndsAt ?? Infinity);
      if (hanChot <= dongHo()) return hoanTat(giaoDich,thamChieuPhien,phien,thamChieuRieng,luotThi,luotThi.selectedAnswers,true,duLieuHoc);
      requireThat(dauVao.revision === luotThi.revision, 'aborted', 'Bài làm đã thay đổi trên thiết bị khác. Hãy tải lại bài.');
      const cacDapAn = lamSachDapAn(dauVao.selectedAnswers,luotThi.questions);
      if (submitting) return hoanTat(giaoDich,thamChieuPhien,phien,thamChieuRieng,luotThi,cacDapAn,false,duLieuHoc);
      giaoDich.update(thamChieuRieng,{selectedAnswers:cacDapAn,revision:luotThi.revision+1});
      return {status:'in_progress',revision:luotThi.revision+1};
    });
  }
  async function lichSu(maNguoiDung) {
    await coSoDuLieu.runTransaction((giaoDich) => hocVien(giaoDich,maNguoiDung));
    const cacPhien = await coSoDuLieu.collection('exam_sessions').where('userId','==',maNguoiDung).get();
    const cacLuotThi = await Promise.all(cacPhien.docs.map((d) => d.ref.collection('runs').orderBy('completedAt','desc').limit(100).get()));
    const cacKhoaHoc = new Map();
    const docKhoaHoc = (maKhoaHoc) => {
      if (!cacKhoaHoc.has(maKhoaHoc)) cacKhoaHoc.set(maKhoaHoc, coSoDuLieu.doc(`courses/${maKhoaHoc}`).get().then(banGhi => banGhi.data()));
      return cacKhoaHoc.get(maKhoaHoc);
    };
    const cacKetQua = await Promise.all(cacLuotThi.flatMap((s) => s.docs).map(async (banGhi) => {
      const duLieu = banGhi.data();
      if (duLieu.status !== 'completed') return null;
      // Kết quả cũ thiếu mã khóa; chỉ khôi phục từ lượt thi gốc của nó.
      const banGoc = duLieu.courseId ? duLieu : (await coSoDuLieu.doc(`exam_private_runs/${banGhi.id}`).get()).data();
      const maKhoaHoc = banGoc?.courseId;
      if (!ma(maKhoaHoc)) return null;
      const khoaHoc = await docKhoaHoc(maKhoaHoc);
      const lucKetThuc = miliGiay(khoaHoc?.endsAt);
      // Giữ kết quả từ lúc nộp; chỉ hiện trong lịch sử khi khóa học kết thúc.
      if (lucKetThuc == null || lucKetThuc > dongHo()) return null;
      return {...duLieu, courseId: maKhoaHoc, lessonId:banGoc.lessonId,
        courseTitle:duLieu.courseTitle ?? banGoc.courseTitle ?? khoaHoc?.title ?? 'Khóa học',
        courseEndedAt:lucKetThuc,
        completedAt:miliGiay(duLieu.completedAt)};
    }));
    return {runs:cacKetQua.filter(Boolean).sort((a,b) => b.completedAt-a.completedAt)};
  }
  async function xoaBaiThi(maNguoiDung,dauVao) {
    requireThat(ma(dauVao.examId),'invalid-argument','Mã đề không hợp lệ.');
    const thamChieu=coSoDuLieu.doc(`exams/${dauVao.examId}`);
    await coSoDuLieu.runTransaction(async(giaoDich)=>{
      const cauHinh=(await giaoDich.get(coSoDuLieu.doc('system/access'))).data();
      const nguoiThaoTac={...(await giaoDich.get(coSoDuLieu.doc(`users/${maNguoiDung}`))).data(),id:maNguoiDung};
      requireRoot(nguoiThaoTac,cauHinh);
      if(!(await giaoDich.get(thamChieu)).exists)return;
      giaoDich.update(thamChieu,{isOpen:false,deleting:true});
    });
    const cacLuotThiRieng=await coSoDuLieu.collection('exam_private_runs').where('examId','==',dauVao.examId).get();
    for(const luotThi of cacLuotThiRieng.docs)await luotThi.ref.delete();
    const cacPhien=await coSoDuLieu.collection('exam_sessions').where('examId','==',dauVao.examId).get();
    for(const phien of cacPhien.docs)await coSoDuLieu.recursiveDelete(phien.ref);
    const cacTongHop=await coSoDuLieu.collection('exam_attempts').where('examId','==',dauVao.examId).get();
    for(const tongHop of cacTongHop.docs)await coSoDuLieu.recursiveDelete(tongHop.ref);
    await coSoDuLieu.recursiveDelete(thamChieu);
    return {deleted:true};
  }
  return {deleteExam: xoaBaiThi,list,start: batDau,save:(maNguoiDung,dauVao) => capNhat(maNguoiDung,dauVao,false),submit:(maNguoiDung,dauVao) => capNhat(maNguoiDung,dauVao,true),history: lichSu};
}
