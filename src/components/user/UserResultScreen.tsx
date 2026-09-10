import React, { useEffect } from 'react';
import { ExamAttempt, Question, Exam } from '../../types';
import confetti from 'canvas-confetti';
import { CheckCircle2, XCircle, Award, RotateCcw, Home, History, Check, X, BookOpen } from 'lucide-react';

interface UserResultScreenProps {
  attempt: ExamAttempt;
  questions: Question[];
  exam: Exam;
  onRetake: () => void;
  onGoHome: () => void;
  onGoHistory: () => void;
}

export const UserResultScreen: React.FC<UserResultScreenProps> = ({
  attempt,
  questions,
  exam,
  onRetake,
  onGoHome,
  onGoHistory,
}) => {
  const score = attempt.diemSo ?? 0;
  const isPassed = score >= 5.0;
  const correctCount = attempt.correctAnswers ?? 0;
  const totalCount = attempt.totalQuestions ?? questions.length;
  const wrongCount = totalCount - correctCount;

  // Trigger confetti if passed
  useEffect(() => {
    if (isPassed) {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
      });
    }
  }, [isPassed]);

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-8">
      {/* Result Hero Card */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-md p-6 sm:p-10 text-center mb-8 relative overflow-hidden">
        <div className="max-w-md mx-auto">
          <div
            className={`w-20 h-20 rounded-full mx-auto flex items-center justify-center mb-4 ring-8 ${
              isPassed
                ? 'bg-emerald-50 text-emerald-600 ring-emerald-50/50'
                : 'bg-red-50 text-red-600 ring-red-50/50'
            }`}
          >
            {isPassed ? <CheckCircle2 className="w-12 h-12" /> : <XCircle className="w-12 h-12" />}
          </div>

          <span
            className={`inline-block px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider mb-2 ${
              isPassed
                ? 'bg-emerald-100 text-emerald-800'
                : 'bg-red-100 text-red-800'
            }`}
          >
            {isPassed ? 'Đạt yêu cầu' : 'Chưa đạt yêu cầu'}
          </span>

          <h1 className="text-2xl font-bold text-slate-900 mb-1">{exam.title}</h1>
          <p className="text-xs text-slate-500 mb-6">
            Lượt làm bài #{attempt.attemptCount} • Hoàn thành lúc{' '}
            {new Date(attempt.completedAt || Date.now()).toLocaleTimeString('vi-VN')}
          </p>

          {/* Large Score Display */}
          <div className="p-5 rounded-2xl bg-slate-50 border border-slate-100 inline-block w-full mb-6">
            <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1">
              Điểm số của bạn
            </div>
            <div className="flex items-baseline justify-center gap-1.5">
              <span className={`text-5xl font-black ${isPassed ? 'text-[#6B0000]' : 'text-slate-800'}`}>
                {score.toFixed(1)}
              </span>
              <span className="text-xl font-bold text-slate-400">/ 10</span>
            </div>
          </div>

          {/* Detailed Score Stats */}
          <div className="grid grid-cols-3 gap-3 mb-8">
            <div className="p-3 bg-emerald-50 rounded-xl border border-emerald-100">
              <div className="text-xl font-bold text-emerald-700">{correctCount}</div>
              <div className="text-[11px] font-medium text-emerald-900">Số câu đúng</div>
            </div>

            <div className="p-3 bg-red-50 rounded-xl border border-red-100">
              <div className="text-xl font-bold text-red-700">{wrongCount}</div>
              <div className="text-[11px] font-medium text-red-900">Số câu sai</div>
            </div>

            <div className="p-3 bg-amber-50 rounded-xl border border-amber-100">
              <div className="text-xl font-bold text-amber-800">
                {attempt.bestScore !== undefined ? attempt.bestScore.toFixed(1) : score.toFixed(1)}
              </div>
              <div className="text-[11px] font-medium text-amber-900">Điểm cao nhất</div>
            </div>
          </div>

          {/* Primary Action Buttons */}
          <div className="flex flex-wrap items-center justify-center gap-3">
            <button
              onClick={onRetake}
              className="py-2.5 px-5 bg-[#6B0000] hover:bg-[#520000] text-white text-xs sm:text-sm font-semibold rounded-xl flex items-center gap-2 shadow-xs transition-colors cursor-pointer"
            >
              <RotateCcw className="w-4 h-4" />
              <span>Làm lại bài thi</span>
            </button>

            <button
              onClick={onGoHistory}
              className="py-2.5 px-4 bg-white border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs sm:text-sm font-semibold rounded-xl flex items-center gap-2 transition-colors cursor-pointer"
            >
              <History className="w-4 h-4" />
              <span>Xem lịch sử bài làm</span>
            </button>

            <button
              onClick={onGoHome}
              className="py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs sm:text-sm font-semibold rounded-xl flex items-center gap-2 transition-colors cursor-pointer"
            >
              <Home className="w-4 h-4" />
              <span>Về danh sách đề thi</span>
            </button>
          </div>
        </div>
      </div>

      {/* Question Details & Explanations Review */}
      <div className="space-y-4">
        <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2">
          <BookOpen className="w-5 h-5 text-[#6B0000]" />
          <span>Chi tiết từng câu hỏi & Lời giải</span>
        </h2>

        {questions.map((q, qIndex) => {
          const studentAnswer = attempt.selectedAnswers ? attempt.selectedAnswers[qIndex] : undefined;
          const isCorrect = studentAnswer === q.correctAnswerIndex;
          const isSkipped = studentAnswer === undefined;

          return (
            <div
              key={q.id || qIndex}
              className={`bg-white rounded-2xl border p-5 sm:p-6 transition-all ${
                isCorrect
                  ? 'border-emerald-200/80 shadow-xs'
                  : 'border-red-200/80 shadow-xs'
              }`}
            >
              {/* Question Header */}
              <div className="flex items-center justify-between gap-2 mb-3">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-600">
                  Câu {qIndex + 1}
                </span>

                <span
                  className={`text-xs font-bold px-2.5 py-1 rounded-md flex items-center gap-1 ${
                    isCorrect
                      ? 'bg-emerald-100 text-emerald-800'
                      : isSkipped
                      ? 'bg-slate-100 text-slate-700'
                      : 'bg-red-100 text-red-800'
                  }`}
                >
                  {isCorrect ? (
                    <>
                      <Check className="w-3.5 h-3.5" />
                      <span>Đúng (+{(10 / questions.length).toFixed(2)} đ)</span>
                    </>
                  ) : isSkipped ? (
                    <>
                      <X className="w-3.5 h-3.5" />
                      <span>Chưa chọn đáp án (0 đ)</span>
                    </>
                  ) : (
                    <>
                      <X className="w-3.5 h-3.5" />
                      <span>Sai (0 đ)</span>
                    </>
                  )}
                </span>
              </div>

              {/* Question Text */}
              <p className="font-semibold text-slate-900 text-sm sm:text-base leading-relaxed mb-4">
                {q.questionText}
              </p>

              {/* Options Breakdown */}
              <div className="space-y-2 mb-4">
                {q.options.map((opt, optIdx) => {
                  const isThisSelected = studentAnswer === optIdx;
                  const isThisCorrect = q.correctAnswerIndex === optIdx;
                  const letter = String.fromCharCode(65 + optIdx);

                  let bgBorder = 'border-slate-200 bg-white text-slate-700';
                  if (isThisCorrect) {
                    bgBorder = 'border-emerald-500 bg-emerald-50/70 text-emerald-950 font-medium ring-1 ring-emerald-400';
                  } else if (isThisSelected && !isThisCorrect) {
                    bgBorder = 'border-red-400 bg-red-50 text-red-950 line-through ring-1 ring-red-300';
                  }

                  return (
                    <div
                      key={optIdx}
                      className={`p-3 rounded-xl border text-sm flex items-center justify-between gap-3 ${bgBorder}`}
                    >
                      <div className="flex items-center gap-2.5">
                        <span className="w-6 h-6 rounded-md bg-white border border-slate-200 flex items-center justify-center font-bold text-xs shrink-0">
                          {letter}
                        </span>
                        <span>{opt}</span>
                      </div>

                      {isThisCorrect && (
                        <span className="text-xs font-bold text-emerald-700 flex items-center gap-1 shrink-0">
                          <Check className="w-4 h-4" />
                          <span>Đáp án đúng</span>
                        </span>
                      )}

                      {isThisSelected && !isThisCorrect && (
                        <span className="text-xs font-bold text-red-600 flex items-center gap-1 shrink-0">
                          <X className="w-4 h-4" />
                          <span>Bạn đã chọn sai</span>
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>

              {/* Explanation Note */}
              {q.explanation && (
                <div className="p-3.5 rounded-xl bg-amber-50/70 border border-amber-200/70 text-xs text-amber-950">
                  <span className="font-bold block mb-1">💡 Lời giải / Hướng dẫn chi tiết:</span>
                  <p className="leading-relaxed">{q.explanation}</p>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
