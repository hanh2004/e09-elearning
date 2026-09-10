import React, { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { Exam, ExamAttempt } from '../../types';
import { Clock, BookOpen, Search, CheckCircle, AlertCircle, Play, RotateCcw, Award, Flame, Calendar } from 'lucide-react';

interface UserHomeScreenProps {
  onStartExam: (exam: Exam) => void;
}

export const UserHomeScreen: React.FC<UserHomeScreenProps> = ({ onStartExam }) => {
  const { currentUser } = useAuth();
  const [exams, setExams] = useState<Exam[]>([]);
  const [attempts, setAttempts] = useState<ExamAttempt[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'open' | 'completed'>('all');

  useEffect(() => {
    const loadData = () => {
      setExams(storage.getExams());
      if (currentUser) {
        setAttempts(storage.getAttempts(currentUser.id));
      }
    };
    loadData();
    const unsubscribe = storage.subscribe(loadData);
    return unsubscribe;
  }, [currentUser]);

  // Calculations for stats
  const completedAttempts = attempts.filter((a) => a.status === 'completed');
  const userExamIdsWithAttempt = new Set(completedAttempts.map((a) => a.examId));
  const openExamsCount = exams.filter((e) => e.isOpen).length;

  const totalScore = completedAttempts.reduce((sum, a) => sum + (a.bestScore || a.diemSo || 0), 0);
  const averageScore = completedAttempts.length > 0 ? (totalScore / completedAttempts.length).toFixed(1) : '0.0';

  // Filter exams
  const filteredExams = exams.filter((exam) => {
    const matchSearch = exam.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (exam.description && exam.description.toLowerCase().includes(searchQuery.toLowerCase()));

    if (!matchSearch) return false;

    if (filterType === 'open') {
      return exam.isOpen;
    }
    if (filterType === 'completed') {
      return userExamIdsWithAttempt.has(exam.id);
    }
    return true;
  });

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Welcome Banner */}
      <div className="relative overflow-hidden bg-gradient-to-r from-[#6B0000] via-[#851414] to-red-950 text-white rounded-2xl p-6 sm:p-8 shadow-lg shadow-red-950/15 mb-8">
        <div className="relative z-10 max-w-2xl">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/15 backdrop-blur-xs text-xs font-semibold tracking-wide text-red-100 mb-3">
            <Flame className="w-3.5 h-3.5 text-amber-300" />
            <span>Kỳ thi học kỳ & Đánh giá năng lực 2025</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-white mb-2">
            Chào {currentUser?.name || 'bạn'}, sẵn sàng làm bài thi hôm nay!
          </h1>
          <p className="text-red-100/90 text-sm sm:text-base leading-relaxed">
            Lựa chọn đề thi bên dưới để bắt đầu làm bài. Hệ thống tự động tính giờ và chấm điểm trực tiếp ngay sau khi nộp bài.
          </p>
        </div>
        <div className="absolute -right-10 -bottom-10 w-64 h-64 bg-white/5 rounded-full blur-2xl pointer-events-none" />
      </div>

      {/* Quick Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="bg-white rounded-xl p-5 border border-slate-200 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-red-50 text-[#6B0000] flex items-center justify-center font-bold">
            <BookOpen className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-slate-900">{openExamsCount}</div>
            <div className="text-xs text-slate-500 font-medium">Đề thi đang mở</div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-5 border border-slate-200 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold">
            <CheckCircle className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-slate-900">{userExamIdsWithAttempt.size}</div>
            <div className="text-xs text-slate-500 font-medium">Đề đã hoàn thành</div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-5 border border-slate-200 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold">
            <Award className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-slate-900">{averageScore} <span className="text-sm font-normal text-slate-400">/ 10</span></div>
            <div className="text-xs text-slate-500 font-medium">Điểm trung bình</div>
          </div>
        </div>
      </div>

      {/* Search & Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-6">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm kiếm tên bài thi..."
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] focus:border-transparent transition-all shadow-xs"
          />
        </div>

        {/* Filter Chips */}
        <div className="flex items-center gap-1.5 w-full sm:w-auto overflow-x-auto pb-1 sm:pb-0">
          <button
            onClick={() => setFilterType('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-colors cursor-pointer ${
              filterType === 'all'
                ? 'bg-[#6B0000] text-white shadow-xs'
                : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
            }`}
          >
            Tất cả đề ({exams.length})
          </button>
          <button
            onClick={() => setFilterType('open')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-colors cursor-pointer ${
              filterType === 'open'
                ? 'bg-[#6B0000] text-white shadow-xs'
                : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
            }`}
          >
            Đang mở ({openExamsCount})
          </button>
          <button
            onClick={() => setFilterType('completed')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-colors cursor-pointer ${
              filterType === 'completed'
                ? 'bg-[#6B0000] text-white shadow-xs'
                : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
            }`}
          >
            Đã làm ({userExamIdsWithAttempt.size})
          </button>
        </div>
      </div>

      {/* Exam List Grid */}
      {filteredExams.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-slate-200 p-8">
          <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto mb-3">
            <BookOpen className="w-6 h-6" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Không tìm thấy bài thi phù hợp</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
            Vui lòng thử tìm kiếm với từ khóa khác hoặc thay đổi bộ lọc trạng thái.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredExams.map((exam) => {
            const questions = storage.getQuestions(exam.id);
            const userAttempt = attempts.find((a) => a.examId === exam.id && a.status === 'completed');
            const attemptCount = userAttempt ? userAttempt.attemptCount : 0;
            const maxAttempts = exam.maxAttempts;
            const canAttempt = exam.isOpen && (maxAttempts == null || attemptCount < maxAttempts);

            const hasExpired = exam.closesAt ? new Date(exam.closesAt).getTime() < Date.now() : false;

            return (
              <div
                key={exam.id}
                className="bg-white rounded-2xl border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow flex flex-col justify-between overflow-hidden group"
              >
                <div className="p-5 sm:p-6">
                  {/* Status header */}
                  <div className="flex items-center justify-between gap-2 mb-3">
                    <span
                      className={`text-[11px] font-bold px-2.5 py-1 rounded-md inline-flex items-center gap-1 ${
                        hasExpired
                          ? 'bg-slate-100 text-slate-600'
                          : exam.isOpen
                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200/60'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      <span className={`w-1.5 h-1.5 rounded-full ${exam.isOpen && !hasExpired ? 'bg-emerald-500' : 'bg-slate-400'}`} />
                      {hasExpired ? 'Đã hết hạn' : exam.isOpen ? 'Đang mở' : 'Đã đóng'}
                    </span>

                    {userAttempt && (
                      <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-amber-50 text-amber-800 border border-amber-200">
                        Điểm cao nhất: {userAttempt.bestScore?.toFixed(1) ?? 'N/A'}
                      </span>
                    )}
                  </div>

                  {/* Title */}
                  <h3 className="font-bold text-slate-900 text-base group-hover:text-[#6B0000] transition-colors line-clamp-2 leading-snug mb-2">
                    {exam.title}
                  </h3>

                  {exam.description && (
                    <p className="text-xs text-slate-500 line-clamp-2 mb-4 leading-relaxed">
                      {exam.description}
                    </p>
                  )}

                  {/* Badges / Metrics */}
                  <div className="grid grid-cols-2 gap-2 text-xs text-slate-600 pt-2 border-t border-slate-100">
                    <div className="flex items-center gap-1.5">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>{exam.durationMinutes} phút</span>
                    </div>

                    <div className="flex items-center gap-1.5">
                      <BookOpen className="w-3.5 h-3.5 text-slate-400" />
                      <span>{questions.length} câu hỏi</span>
                    </div>

                    <div className="flex items-center gap-1.5 col-span-2">
                      <RotateCcw className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Lượt làm: {attemptCount} / {maxAttempts ? `${maxAttempts} lần` : 'Không giới hạn'}
                      </span>
                    </div>

                    {exam.closesAt && (
                      <div className="flex items-center gap-1.5 col-span-2 text-[11px] text-amber-700">
                        <Calendar className="w-3 h-3" />
                        <span>Tự đóng: {new Date(exam.closesAt).toLocaleDateString('vi-VN')}</span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Footer Action */}
                <div className="p-4 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
                  {canAttempt ? (
                    <button
                      onClick={() => onStartExam(exam)}
                      className="w-full py-2.5 px-4 bg-[#6B0000] hover:bg-[#520000] text-white text-xs sm:text-sm font-semibold rounded-xl flex items-center justify-center gap-2 shadow-xs transition-all cursor-pointer"
                    >
                      {userAttempt ? (
                        <>
                          <RotateCcw className="w-4 h-4" />
                          <span>Làm lại bài thi</span>
                        </>
                      ) : (
                        <>
                          <Play className="w-4 h-4 fill-current" />
                          <span>Bắt đầu làm bài</span>
                        </>
                      )}
                    </button>
                  ) : (
                    <div className="w-full text-center py-2 text-xs font-semibold text-slate-400 bg-slate-100 rounded-xl flex items-center justify-center gap-1.5">
                      <AlertCircle className="w-4 h-4" />
                      <span>
                        {!exam.isOpen
                          ? 'Đề thi hiện đã đóng'
                          : hasExpired
                          ? 'Đã hết hạn làm bài'
                          : 'Đã hết số lượt làm bài'}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
