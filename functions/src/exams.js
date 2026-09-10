import { createHash, randomInt } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requireThat, requireRoot } from './policy.js';

const key = (uid, examId) => createHash('sha256').update(JSON.stringify([uid, examId])).digest('hex');
const id = (value) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const millis = (value) => value?.toMillis?.() ?? null;

function shuffled(items) {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export function prepareQuestions(questions, policy) {
  const result = questions.map(q => {
    if (!policy.shuffleAnswers) return {...q, options:[...q.options]};
    const indices = shuffled(q.options.map((_, i) => i));
    return {...q, options:indices.map(i => q.options[i]), correctIndex:indices.indexOf(q.correctIndex)};
  });
  return policy.shuffleQuestions ? shuffled(result) : result;
}

export function normalizeQuestion(raw, questionId) {
  const title = raw.questionText ?? raw.noi_dung ?? raw.content;
  const options = raw.options ?? raw.ds_lua_chon ?? raw.answers;
  requireThat(typeof title === 'string' && title.trim() && Array.isArray(options) && options.length >= 2 && options.length <= 20,
    'failed-precondition', 'Đề có câu hỏi chưa hợp lệ.');
  const values = options.map((option) => typeof option === 'string' ? option : option.noi_dung ?? option.noiDung ?? '');
  const correct = options.flatMap((option, index) =>
    index === raw.correctAnswerIndex || index === raw.correctIndex || option?.dap_an_dung === true || option?.dapAnDung === true ? [index] : []);
  requireThat(values.every((value) => typeof value === 'string' && value.trim()) && correct.length === 1 &&
    (!raw.loai_cau_hoi || raw.loai_cau_hoi === 'SINGLE_CHOICE'), 'failed-precondition', 'Đề phải có một đáp án đúng cho mỗi câu.');
  return { id: questionId, title, options: values, correctIndex: correct[0], explanation: String(raw.explanation ?? raw.loi_giai ?? '') };
}

function cleanAnswers(input, questions) {
  requireThat(input && typeof input === 'object' && !Array.isArray(input), 'invalid-argument', 'Đáp án không hợp lệ.');
  const allowed = new Map(questions.map((q) => [q.id, q]));
  for (const [qid, value] of Object.entries(input)) {
    requireThat(allowed.has(qid) && Number.isInteger(value) && value >= 0 && value < allowed.get(qid).options.length,
      'invalid-argument', 'Lựa chọn không hợp lệ.');
  }
  return { ...input };
}

export function gradeRun(run, answers) {
  const correctAnswers = run.questions.filter((q) => answers[q.id] === q.correctIndex).length;
  const score = Math.round(correctAnswers * 10000 / run.questions.length) / 1000;
  return { score, correctAnswers, totalQuestions: run.questions.length, passed: score >= run.passScore,
    ...(run.showSolutions ? { review: run.questions.map((q) => ({ id:q.id, title:q.title, options:q.options,
      selectedIndex: answers[q.id] ?? null, correctIndex:q.correctIndex, explanation:q.explanation })) } : {}) };
}

export function examHandlers(db, clock = () => Date.now()) {
  async function student(tx, uid) {
    const profile = (await tx.get(db.doc(`users/${uid}`))).data();
    requireThat(profile?.status === 'active' && profile.role === 'user', 'permission-denied', 'Cần đăng nhập học viên đang hoạt động.');
    return profile;
  }
  function publicRun(run) {
    return { status:run.status, serverNow:clock(), runId:run.id, examId:run.examId, title:run.title, endsAt:millis(run.endsAt), revision:run.revision,
      selectedAnswers:run.selectedAnswers, questions:run.questions.map(({correctIndex, explanation, ...question}) => question) };
  }
  function complete(tx, sessionRef, session, privateRef, run, answers, expired) {
    const result = { ...gradeRun(run, answers), passScore:run.passScore, status:'completed', runId:run.id, examId:run.examId, title:run.title, expired };
    tx.update(privateRef, {status:'completed', selectedAnswers:answers, result, completedAt:FieldValue.serverTimestamp()});
    tx.set(sessionRef.collection('runs').doc(run.id), {...result, completedAt:FieldValue.serverTimestamp(), userId:run.userId});
    const completedCount = (session.completedCount ?? 0) + 1;
    tx.update(sessionRef, {activeRunId:null, completedCount, bestScore:Math.max(session.bestScore ?? -1, result.score)});
    const summary = {userId:run.userId, examId:run.examId, examTitle:run.title, status:'completed', attemptCount:completedCount,
      lastAttemptAt:FieldValue.serverTimestamp()};
    if (result.score >= (session.bestScore ?? -1)) Object.assign(summary, {bestScore:result.score, diemSo:result.score,
      passed:result.passed,passScore:run.passScore,
      correctAnswers:result.correctAnswers, totalQuestions:result.totalQuestions, completedAt:FieldValue.serverTimestamp(),
      answers:run.questions.map((q) => ({ma_cau_hoi:q.id, ma_lua_chon:String(answers[q.id] ?? ''), tra_loi_dung:answers[q.id] === q.correctIndex}))});
    tx.set(db.doc(`exam_attempts/secure_${sessionRef.id}`), summary, {merge:true});
    return result;
  }
  async function list(uid) {
    return db.runTransaction(async (tx) => {
      await student(tx, uid);
      const [exams, sessions, legacy] = await Promise.all([tx.get(db.collection('exams')), tx.get(db.collection('exam_sessions').where('userId','==',uid)), tx.get(db.collection('exam_attempts').where('userId','==',uid))]);
      const counts = new Map(sessions.docs.map((doc) => [doc.data().examId, doc.data()]));
      return {exams:exams.docs.filter(doc => doc.data().deleting !== true).map((doc) => { const e = doc.data(); const s = counts.get(doc.id);
        const legacyUsed = legacy.docs.filter(d => d.data().examId === doc.id).reduce((count,d) => count +
          (d.data().attemptCount ?? (d.data().status === 'completed' ? 1 : 0)) + (d.data().status === 'in_progress' ? 1 : 0),0);
        return {id:doc.id, title:e.title ?? 'Bài thi', durationMinutes:e.durationMinutes ?? (parseInt(e.duration,10) || 45),
          isOpen:e.isOpen === true, closesAt:millis(e.closesAt), opensAt:millis(e.opensAt), maxAttempts:e.maxAttempts ?? null,
          usedAttempts:s ? s.issuedCount+s.legacyUsed : legacyUsed, active:s?.activeRunId != null}; })};
    });
  }
  async function start(uid, input) {
    requireThat(id(input.examId), 'invalid-argument', 'Mã đề không hợp lệ.');
    const sessionRef = db.doc(`exam_sessions/${key(uid,input.examId)}`);
    return db.runTransaction(async (tx) => {
      await student(tx, uid);
      const session = (await tx.get(sessionRef)).data();
      if (session?.activeRunId) {
        const privateRef = db.doc(`exam_private_runs/${session.activeRunId}`);
        const run = (await tx.get(privateRef)).data();
        requireThat(run && run.userId === uid, 'failed-precondition', 'Lượt thi không hợp lệ.');
        if (millis(run.endsAt) <= clock()) return complete(tx, sessionRef, session, privateRef, run, run.selectedAnswers, true);
        return publicRun(run);
      }
      const examRef = db.doc(`exams/${input.examId}`);
      const exam = (await tx.get(examRef)).data();
      requireThat(exam?.isOpen === true && exam.deleting !== true && (millis(exam.opensAt) == null || millis(exam.opensAt) <= clock()) &&
        (millis(exam.closesAt) == null || millis(exam.closesAt) > clock()), 'failed-precondition', 'Bài thi hiện chưa mở hoặc đã đóng.');
      let legacyUsed = session?.legacyUsed ?? 0;
      if (!session) {
        const old = await tx.get(db.collection('exam_attempts').where('userId','==',uid));
        legacyUsed = old.docs.filter((d) => d.data().examId === input.examId).reduce((count,d) => count +
          (d.data().attemptCount ?? (d.data().status === 'completed' ? 1 : 0)) + (d.data().status === 'in_progress' ? 1 : 0),0);
      }
      const issuedCount = session?.issuedCount ?? 0;
      requireThat(exam.maxAttempts == null || issuedCount + legacyUsed < exam.maxAttempts, 'resource-exhausted', 'Bạn đã hết lượt thi.');
      const questionDocs = await tx.get(examRef.collection('questions').orderBy('__name__'));
      const source = questionDocs.empty && Array.isArray(exam.questions) ? exam.questions.map((raw,i) => ({raw,id:String(i)})) : questionDocs.docs.map((d) => ({raw:d.data(),id:d.id}));
      requireThat(source.length > 0 && source.length <= 200, 'failed-precondition', 'Đề cần có 1–200 câu hỏi.');
      const questions = prepareQuestions(source.map((q) => normalizeQuestion(q.raw,q.id)), exam);
      requireThat(Buffer.byteLength(JSON.stringify(questions),'utf8') < 800000, 'failed-precondition', 'Nội dung đề quá lớn. Hãy chia thành nhiều đề.');
      const duration = exam.durationMinutes ?? (parseInt(exam.duration, 10) || 45);
      requireThat(Number.isInteger(duration) && duration > 0 && duration <= 1440, 'failed-precondition', 'Thời gian đề không hợp lệ.');
      requireThat(exam.passScore == null || (Number.isFinite(exam.passScore) && exam.passScore >= 0 && exam.passScore <= 10),
        'failed-precondition', 'Điểm đạt cần nằm trong khoảng 0–10.');
      const runId = `${sessionRef.id}_${issuedCount+1}`;
      const run = {id:runId, userId:uid, examId:input.examId, title:exam.title ?? 'Bài thi', status:'in_progress', questions,
        passScore:typeof exam.passScore === 'number' ? exam.passScore : 5, showSolutions:exam.showSolutions === true,
        endsAt:Timestamp.fromMillis(Math.min(clock()+duration*60000,millis(exam.closesAt) ?? Infinity)), selectedAnswers:{}, revision:0};
      tx.set(sessionRef,{userId:uid,examId:input.examId,issuedCount:issuedCount+1,legacyUsed,activeRunId:runId,completedCount:session?.completedCount ?? 0,bestScore:session?.bestScore ?? -1});
      tx.create(db.doc(`exam_private_runs/${runId}`),run);
      return publicRun(run);
    });
  }
  async function update(uid, input, submitting) {
    requireThat(id(input.runId), 'invalid-argument', 'Mã lượt thi không hợp lệ.');
    return db.runTransaction(async (tx) => {
      await student(tx,uid);
      const privateRef = db.doc(`exam_private_runs/${input.runId}`);
      const run = (await tx.get(privateRef)).data();
      requireThat(run?.userId === uid, 'permission-denied', 'Không có quyền với lượt thi.');
      if (run.status === 'completed') return run.result;
      const sessionRef = db.doc(`exam_sessions/${key(uid,run.examId)}`);
      const session = (await tx.get(sessionRef)).data();
      requireThat(session?.activeRunId === input.runId, 'failed-precondition', 'Lượt thi đã thay đổi.');
      if (millis(run.endsAt) <= clock()) return complete(tx,sessionRef,session,privateRef,run,run.selectedAnswers,true);
      requireThat(input.revision === run.revision, 'aborted', 'Bài làm đã thay đổi trên thiết bị khác. Hãy tải lại bài.');
      const answers = cleanAnswers(input.selectedAnswers,run.questions);
      if (submitting) return complete(tx,sessionRef,session,privateRef,run,answers,false);
      tx.update(privateRef,{selectedAnswers:answers,revision:run.revision+1});
      return {status:'in_progress',revision:run.revision+1};
    });
  }
  async function history(uid) {
    await db.runTransaction((tx) => student(tx,uid));
    const sessions = await db.collection('exam_sessions').where('userId','==',uid).get();
    const runs = await Promise.all(sessions.docs.map((d) => d.ref.collection('runs').orderBy('completedAt','desc').limit(100).get()));
    return {runs:runs.flatMap((s) => s.docs.map((d) => ({...d.data(),completedAt:millis(d.data().completedAt)}))).sort((a,b) => b.completedAt-a.completedAt)};
  }
  async function deleteExam(uid,input) {
    requireThat(id(input.examId),'invalid-argument','Mã đề không hợp lệ.');
    const ref=db.doc(`exams/${input.examId}`);
    await db.runTransaction(async(tx)=>{
      const config=(await tx.get(db.doc('system/access'))).data();
      const actor={...(await tx.get(db.doc(`users/${uid}`))).data(),id:uid};
      requireRoot(actor,config);
      if(!(await tx.get(ref)).exists)return;
      tx.update(ref,{isOpen:false,deleting:true});
    });
    const privateRuns=await db.collection('exam_private_runs').where('examId','==',input.examId).get();
    for(const run of privateRuns.docs)await run.ref.delete();
    const sessions=await db.collection('exam_sessions').where('examId','==',input.examId).get();
    for(const session of sessions.docs)await db.recursiveDelete(session.ref);
    const summaries=await db.collection('exam_attempts').where('examId','==',input.examId).get();
    for(const summary of summaries.docs)await db.recursiveDelete(summary.ref);
    await db.recursiveDelete(ref);
    return {deleted:true};
  }
  return {deleteExam,list,start,save:(uid,input) => update(uid,input,false),submit:(uid,input) => update(uid,input,true),history};
}



