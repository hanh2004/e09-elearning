import React, { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { ExamAttempt } from '../../types';
import { Search, History, Calendar, CheckCircle, XCircle, Award, ArrowRight } from 'lucide-react';

interface UserExamHistoryScreenProps {
  onSelectExamAttempt?: (attempt: ExamAttempt) => void;
}

export const UserExamHistoryScreen: React.FC<UserExamHistoryScreenProps> = () => {
  const { currentUser } = useAuth();
  const [attempts, setAttempts] = useState<ExamAttempt[]>([]);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (currentUser) {
      const load = () => {
        setAttempts(storage.getAttempts(currentUser.id).filter((a) => a.status === 'completed'));
      };
      load();
      return storage.subscribe(load);
    }
  }, [currentUser]);

  // Group attempts by examId to find best score and total attempts count
  const groupedMap = new Map<string, { latest: ExamAttempt; bestScore: number; count: number }>();
  attempts.forEach((att) => {
    const existing = groupedMap.get(att.examId);
    const score = att.bestScore || att.diemSo || 0;
    if (!existing) {
      groupedMap.set(att.examId, {
        latest: att,
        bestScore: score,
        count: att.attemptCount || 1,
      });
    } else {
      existing.count += 1;
      if (score > existing.bestScore) {
        existing.bestScore = score;
        existing.latest = att;
      }
    }
  });

  const groupedList = Array.from(groupedMap.values());

  const filteredItems = groupedList.filter((item) =>
    item.latest.examTitle.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Page Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2.5">
          <History className="w-6 h-6 text-[#6B0000]" />
          <span>Lịch sử bài thi của bạn</span>
        </h1>
        <p className="text-xs sm:text-sm text-slate-500 mt-1">
          Theo dõi kết quả, điểm số cao nhất và số lượt đã nộp bài của từng đề thi
        </p>
      </div>

      {/* Search Input */}
      <div className="relative w-full max-w-md mb-6">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Tìm kiếm bài làm theo tên đề thi..."
          className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] focus:border-transparent transition-all shadow-xs"
        />
      </div>

      {/* Attempts List */}
      {filteredItems.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center">
          <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto mb-3">
            <History className="w-6 h-6" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Chưa có lịch sử làm bài</h3>
          <p className="text-xs text-slate-500 mt-1">
            {searchQuery ? 'Không tìm thấy bài thi phù hợp với từ khóa.' : 'Hãy bắt đầu làm một bài thi ở trang chủ để xem lịch sử tại đây!'}
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredItems.map(({ latest, bestScore, count }) => {
            const isPassed = bestScore >= 5.0;
            const completedDate = latest.completedAt ? new Date(latest.completedAt) : null;
            const dateStr = completedDate
              ? `${completedDate.getHours().toString().padStart(2, '0')}:${completedDate
                  .getMinutes()
                  .toString()
                  .padStart(2, '0')} ${completedDate.getDate()}/${
                  completedDate.getMonth() + 1
                }/${completedDate.getFullYear()}`
              : 'N/A';

            return (
              <div
                key={latest.id}
                className="bg-white rounded-2xl border border-slate-200/80 p-5 sm:p-6 shadow-xs hover:shadow-md transition-all flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
              >
                <div className="space-y-2 flex-1">
                  <div className="flex items-center gap-2.5">
                    <h3 className="font-bold text-slate-900 text-base leading-snug">
                      {latest.examTitle}
                    </h3>
                    <span
                      className={`text-[11px] font-bold px-2.5 py-0.5 rounded-md inline-flex items-center gap-1 ${
                        isPassed
                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          : 'bg-red-50 text-red-700 border border-red-200'
                      }`}
                    >
                      {isPassed ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                      <span>{isPassed ? 'Đạt' : 'Chưa đạt'}</span>
                    </span>
                  </div>

                  <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
                    <span className="flex items-center gap-1">
                      <Calendar className="w-3.5 h-3.5 text-slate-400" />
                      <span>{dateStr}</span>
                    </span>
                    <span>•</span>
                    <span>Đã làm {count} lần</span>
                    {latest.correctAnswers !== undefined && latest.totalQuestions !== undefined && (
                      <>
                        <span>•</span>
                        <span>
                          Số câu đúng lần gần nhất: {latest.correctAnswers}/{latest.totalQuestions}
                        </span>
                      </>
                    )}
                  </div>
                </div>

                <div className="flex items-center justify-between sm:justify-end w-full sm:w-auto gap-4 pt-3 sm:pt-0 border-t sm:border-t-0 border-slate-100">
                  <div className="text-left sm:text-right">
                    <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                      Điểm cao nhất
                    </div>
                    <div className="text-2xl font-black text-[#6B0000]">
                      {bestScore.toFixed(1)}{' '}
                      <span className="text-xs font-semibold text-slate-400">/ 10</span>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
