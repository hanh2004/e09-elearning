import React, { useState, useEffect, useRef } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { Exam, Question, ExamAttempt } from '../../types';
import { Clock, AlertTriangle, ArrowLeft, ArrowRight, CheckCircle2, Flag, Send, HelpCircle, ShieldAlert } from 'lucide-react';

interface UserExamScreenProps {
  exam: Exam;
  onExit: () => void;
  onFinish: (attempt: ExamAttempt, questions: Question[]) => void;
}

export const UserExamScreen: React.FC<UserExamScreenProps> = ({ exam, onExit, onFinish }) => {
  const { currentUser } = useAuth();
  const [questions, setQuestions] = useState<Question[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedAnswers, setSelectedAnswers] = useState<Record<number, number>>({});
  const [flaggedQuestions, setFlaggedQuestions] = useState<Set<number>>(new Set());
  const [timeLeftSeconds, setTimeLeftSeconds] = useState(exam.durationMinutes * 60);
  const [showSubmitModal, setShowSubmitModal] = useState(false);
  const [showExitModal, setShowExitModal] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Load questions
  useEffect(() => {
    const qs = storage.getQuestions(exam.id);
    setQuestions(qs);
  }, [exam.id]);

  // Countdown timer
  useEffect(() => {
    if (timeLeftSeconds <= 0) {
      handleFinalSubmit();
      return;
    }
    const timer = setInterval(() => {
      setTimeLeftSeconds((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          handleFinalSubmit();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [timeLeftSeconds]);

  const formatTime = (secs: number) => {
    const mins = Math.floor(secs / 60);
    const s = secs % 60;
    return `${mins.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const handleSelectOption = (qIndex: number, optIndex: number) => {
    setSelectedAnswers((prev) => ({ ...prev, [qIndex]: optIndex }));
  };

  const toggleFlagQuestion = (qIndex: number) => {
    setFlaggedQuestions((prev) => {
      const next = new Set(prev);
      if (next.has(qIndex)) {
        next.delete(qIndex);
      } else {
        next.add(qIndex);
      }
      return next;
    });
  };

  const answeredCount = Object.keys(selectedAnswers).length;
  const totalCount = questions.length;
  const isTimeCritical = timeLeftSeconds <= 300; // < 5 mins

  const handleFinalSubmit = () => {
    if (isSubmitting) return;
    setIsSubmitting(true);

    if (!currentUser || questions.length === 0) {
      onExit();
      return;
    }

    // Grade the exam
    let correctCount = 0;
    questions.forEach((q, idx) => {
      if (selectedAnswers[idx] === q.correctAnswerIndex) {
        correctCount++;
      }
    });

    const calculatedScore = Number(((correctCount / questions.length) * 10).toFixed(2));

    // Get previous attempts to compute best score & attempt count
    const existingAttempts = storage.getAttempts(currentUser.id).filter((a) => a.examId === exam.id);
    const prevAttemptsCount = existingAttempts.reduce((max, a) => Math.max(max, a.attemptCount || 0), 0);
    const prevBestScore = existingAttempts.reduce((best, a) => Math.max(best, a.bestScore || 0), 0);

    const newBestScore = Math.max(prevBestScore, calculatedScore);

    const now = new Date();
    const attempt: ExamAttempt = {
      id: `att_${Date.now()}`,
      examId: exam.id,
      examTitle: exam.title,
      userId: currentUser.id,
      userName: currentUser.name,
      startedAt: new Date(now.getTime() - (exam.durationMinutes * 60 - timeLeftSeconds) * 1000).toISOString(),
      endsAt: now.toISOString(),
      completedAt: now.toISOString(),
      bestCompletedAt: now.toISOString(),
      lastAttemptAt: now.toISOString(),
      status: 'completed',
      attemptCount: prevAttemptsCount + 1,
      diemSo: calculatedScore,
      bestScore: newBestScore,
      correctAnswers: correctCount,
      totalQuestions: questions.length,
      selectedAnswers,
    };

    storage.saveAttempt(attempt);
    onFinish(attempt, questions);
  };

  if (questions.length === 0) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl p-8 max-w-md w-full text-center border border-slate-200">
          <div className="w-12 h-12 rounded-full bg-red-50 text-[#6B0000] flex items-center justify-center mx-auto mb-4">
            <HelpCircle className="w-6 h-6" />
          </div>
          <h2 className="text-lg font-bold text-slate-900 mb-2">Đề thi chưa có câu hỏi</h2>
          <p className="text-sm text-slate-500 mb-6">
            Đề thi này đang được giáo viên biên soạn câu hỏi. Vui lòng quay lại sau!
          </p>
          <button
            onClick={onExit}
            className="w-full py-2.5 px-4 bg-[#6B0000] text-white rounded-xl text-sm font-semibold cursor-pointer"
          >
            Quay lại trang chủ
          </button>
        </div>
      </div>
    );
  }

  const currentQ = questions[currentIndex];

  return (
    <div className="min-h-screen bg-slate-100 flex flex-col">
      {/* Exam Sticky Header */}
      <header className="sticky top-0 z-30 bg-white border-b border-slate-200 shadow-xs px-4 sm:px-6 py-3">
        <div className="max-w-7xl mx-auto flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setShowExitModal(true)}
              className="p-1.5 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
              title="Thoát bài thi"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div>
              <h1 className="font-bold text-slate-900 text-sm sm:text-base line-clamp-1">
                {exam.title}
              </h1>
              <div className="text-xs text-slate-500">
                Câu hỏi {currentIndex + 1} / {questions.length} • Đã làm {answeredCount}/{totalCount} câu
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Countdown Badge */}
            <div
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-mono text-sm sm:text-base font-bold transition-colors ${
                isTimeCritical
                  ? 'bg-red-500 text-white animate-pulse'
                  : 'bg-red-50 text-[#6B0000] border border-red-200'
              }`}
            >
              <Clock className="w-4 h-4" />
              <span>{formatTime(timeLeftSeconds)}</span>
            </div>

            {/* Submit Button */}
            <button
              onClick={() => setShowSubmitModal(true)}
              className="py-1.5 px-4 bg-[#6B0000] hover:bg-[#520000] text-white text-xs sm:text-sm font-bold rounded-xl flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
            >
              <Send className="w-3.5 h-3.5" />
              <span>Nộp bài</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Question Content (8 cols on desktop) */}
        <div className="lg:col-span-8 flex flex-col justify-between">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-5 sm:p-7 mb-4">
            {/* Question Header */}
            <div className="flex items-center justify-between gap-2 mb-4 pb-3 border-b border-slate-100">
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B0000] bg-red-50 px-2.5 py-1 rounded-md">
                Câu {currentIndex + 1} / {questions.length}
              </span>

              <button
                onClick={() => toggleFlagQuestion(currentIndex)}
                className={`flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1 rounded-md transition-colors cursor-pointer ${
                  flaggedQuestions.has(currentIndex)
                    ? 'bg-amber-100 text-amber-800'
                    : 'text-slate-500 hover:bg-slate-100'
                }`}
              >
                <Flag className={`w-3.5 h-3.5 ${flaggedQuestions.has(currentIndex) ? 'fill-current' : ''}`} />
                <span>{flaggedQuestions.has(currentIndex) ? 'Đã đánh dấu xem lại' : 'Đánh dấu xem lại'}</span>
              </button>
            </div>

            {/* Question Text */}
            <p className="text-base sm:text-lg font-medium text-slate-900 leading-relaxed mb-6">
              {currentQ.questionText}
            </p>

            {/* Options List */}
            <div className="space-y-3">
              {currentQ.options.map((option, optIdx) => {
                const isSelected = selectedAnswers[currentIndex] === optIdx;
                const letter = String.fromCharCode(65 + optIdx);

                return (
                  <button
                    key={optIdx}
                    type="button"
                    onClick={() => handleSelectOption(currentIndex, optIdx)}
                    className={`w-full text-left p-4 rounded-xl border transition-all flex items-start gap-3 cursor-pointer ${
                      isSelected
                        ? 'border-[#6B0000] bg-red-50/50 shadow-xs ring-1 ring-[#6B0000]'
                        : 'border-slate-200 bg-white hover:border-slate-300 hover:bg-slate-50/50'
                    }`}
                  >
                    <div
                      className={`w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs shrink-0 transition-colors ${
                        isSelected
                          ? 'bg-[#6B0000] text-white'
                          : 'bg-slate-100 text-slate-700'
                      }`}
                    >
                      {letter}
                    </div>
                    <span className="text-sm sm:text-base text-slate-800 pt-0.5 leading-snug">
                      {option}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Previous / Next Navigation Buttons */}
          <div className="flex items-center justify-between gap-3">
            <button
              onClick={() => setCurrentIndex((prev) => Math.max(0, prev - 1))}
              disabled={currentIndex === 0}
              className="py-2.5 px-4 bg-white border border-slate-200 rounded-xl text-sm font-semibold text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Câu trước</span>
            </button>

            {currentIndex < questions.length - 1 ? (
              <button
                onClick={() => setCurrentIndex((prev) => Math.min(questions.length - 1, prev + 1))}
                className="py-2.5 px-5 bg-[#6B0000] hover:bg-[#520000] text-white rounded-xl text-sm font-semibold flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
              >
                <span>Câu tiếp theo</span>
                <ArrowRight className="w-4 h-4" />
              </button>
            ) : (
              <button
                onClick={() => setShowSubmitModal(true)}
                className="py-2.5 px-5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-bold flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Hoàn tất & Nộp bài</span>
              </button>
            )}
          </div>
        </div>

        {/* Question Palette Sidebar (4 cols on desktop) */}
        <div className="lg:col-span-4">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-5 sticky top-20">
            <h3 className="font-bold text-slate-900 text-sm mb-3 flex items-center justify-between">
              <span>Danh sách câu hỏi</span>
              <span className="text-xs text-slate-500 font-normal">
                {answeredCount}/{totalCount} câu
              </span>
            </h3>

            {/* Progress Bar */}
            <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden mb-4">
              <div
                className="h-full bg-[#6B0000] transition-all duration-300"
                style={{ width: `${(answeredCount / totalCount) * 100}%` }}
              />
            </div>

            {/* Question Number Grid */}
            <div className="grid grid-cols-5 sm:grid-cols-6 lg:grid-cols-5 gap-2 mb-5">
              {questions.map((_, idx) => {
                const isAnswered = selectedAnswers[idx] !== undefined;
                const isCurrent = currentIndex === idx;
                const isFlagged = flaggedQuestions.has(idx);

                return (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => setCurrentIndex(idx)}
                    className={`relative h-10 rounded-xl font-bold text-xs flex items-center justify-center transition-all cursor-pointer ${
                      isCurrent
                        ? 'ring-2 ring-[#6B0000] ring-offset-2'
                        : ''
                    } ${
                      isAnswered
                        ? 'bg-[#6B0000] text-white shadow-xs'
                        : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                    }`}
                  >
                    <span>{idx + 1}</span>
                    {isFlagged && (
                      <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-amber-400 rounded-full ring-2 ring-white" />
                    )}
                  </button>
                );
              })}
            </div>

            {/* Palette Legend */}
            <div className="space-y-1.5 text-xs text-slate-600 pt-3 border-t border-slate-100">
              <div className="flex items-center gap-2">
                <span className="w-3.5 h-3.5 rounded bg-[#6B0000]" />
                <span>Đã chọn đáp án ({answeredCount})</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3.5 h-3.5 rounded bg-slate-100 border border-slate-300" />
                <span>Chưa trả lời ({totalCount - answeredCount})</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3.5 h-3.5 rounded bg-amber-400" />
                <span>Đánh dấu xem lại ({flaggedQuestions.size})</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Submit Confirmation Modal */}
      {showSubmitModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
            <div className="w-12 h-12 rounded-full bg-red-50 text-[#6B0000] flex items-center justify-center mx-auto mb-4">
              <Send className="w-6 h-6" />
            </div>

            <h3 className="text-lg font-bold text-center text-slate-900 mb-1">
              Xác nhận nộp bài thi?
            </h3>

            <div className="my-4 p-4 rounded-xl bg-slate-50 border border-slate-200 text-sm space-y-2">
              <div className="flex justify-between">
                <span className="text-slate-500">Tổng số câu hỏi:</span>
                <span className="font-bold text-slate-800">{totalCount} câu</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Đã trả lời:</span>
                <span className="font-bold text-emerald-700">{answeredCount} câu</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Chưa trả lời:</span>
                <span className="font-bold text-red-600">{totalCount - answeredCount} câu</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Thời gian còn lại:</span>
                <span className="font-bold text-slate-800">{formatTime(timeLeftSeconds)}</span>
              </div>
            </div>

            {totalCount - answeredCount > 0 && (
              <div className="mb-4 p-3 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-xs flex items-start gap-2">
                <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                <span>
                  Bạn vẫn còn <strong>{totalCount - answeredCount}</strong> câu chưa chọn đáp án. Các câu chưa làm sẽ không được tính điểm.
                </span>
              </div>
            )}

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setShowSubmitModal(false)}
                className="flex-1 py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-sm font-semibold transition-colors cursor-pointer"
              >
                Tiếp tục làm bài
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowSubmitModal(false);
                  handleFinalSubmit();
                }}
                disabled={isSubmitting}
                className="flex-1 py-2.5 px-4 bg-[#6B0000] hover:bg-[#520000] text-white rounded-xl text-sm font-bold shadow-xs transition-colors cursor-pointer"
              >
                {isSubmitting ? 'Đang nộp...' : 'Nộp bài ngay'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Exit Exam Modal */}
      {showExitModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl">
            <div className="w-12 h-12 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center mx-auto mb-3">
              <ShieldAlert className="w-6 h-6" />
            </div>
            <h3 className="text-base font-bold text-center text-slate-900 mb-2">
              Bạn có muốn rời khỏi bài thi?
            </h3>
            <p className="text-xs text-slate-500 text-center mb-5">
              Bài làm chưa nộp sẽ không được lưu điểm chính thức. Bạn chắc chắn muốn thoát về trang chủ?
            </p>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setShowExitModal(false)}
                className="flex-1 py-2 px-3 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Ở lại làm tiếp
              </button>
              <button
                onClick={onExit}
                className="flex-1 py-2 px-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-xs font-semibold cursor-pointer"
              >
                Thoát bài thi
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
