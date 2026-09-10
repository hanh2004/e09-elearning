import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { AdminTab, Exam, Question, UserProfile, ExamAttempt } from '../../types';
import {
  BookOpen,
  HelpCircle,
  Users,
  CheckCircle2,
  AlertTriangle,
  Plus,
  ArrowRight,
  Sparkles,
  TrendingUp,
  Clock,
  RotateCcw,
} from 'lucide-react';

interface AdminHomeScreenProps {
  onNavigateTab: (tab: AdminTab) => void;
  onOpenQuestions: (examId: string) => void;
}

export const AdminHomeScreen: React.FC<AdminHomeScreenProps> = ({ onNavigateTab, onOpenQuestions }) => {
  const { isRoot } = useAuth();
  const exams = storage.getExams();
  const questions = storage.getQuestions();
  const users = storage.getUsers();
  const attempts = storage.getAttempts();
  const systemStatus = storage.getStatus();

  const studentCount = users.filter((u) => u.role === 'user').length;
  const completedAttemptsCount = attempts.filter((a) => a.status === 'completed').length;
  const pendingRequests = storage.getRequests().filter((r) => r.status === 'pending');

  return (
    <div className="space-y-8">
      {/* Page Title & System Status Banner */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Bảng điều khiển Tổng quan</h1>
        <p className="text-sm text-slate-500 mt-1">
          Hệ thống theo dõi các kỳ thi, câu hỏi và tiến độ làm bài trực tuyến E-09
        </p>
      </div>

      {/* Maintenance Mode Alert Banner */}
      {systemStatus.maintenance && (
        <div className="bg-amber-50 border border-amber-300 rounded-2xl p-4 sm:p-5 flex items-start justify-between gap-4">
          <div className="flex items-start gap-3 text-amber-900">
            <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div>
              <span className="font-bold block text-sm sm:text-base">Hệ thống đang ở Chế độ Bảo trì:</span>
              <p className="text-xs sm:text-sm text-amber-800 mt-0.5">
                Cổng học viên hiện đang tạm khóa để chuẩn bị đề thi hoặc cập nhật dữ liệu. Bạn có thể tắt chế độ bảo trì trong mục Cài đặt hệ thống.
              </p>
            </div>
          </div>
          <button
            onClick={() => onNavigateTab('settings')}
            className="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white text-xs font-semibold rounded-xl whitespace-nowrap transition-colors cursor-pointer"
          >
            Quản lý bảo trì
          </button>
        </div>
      )}

      {/* Pending Request Alert (Super Admin Only) */}
      {isRoot && pendingRequests.length > 0 && (
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 sm:p-5 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center font-bold">
              {pendingRequests.length}
            </div>
            <div>
              <div className="text-sm font-bold text-rose-950">
                Có {pendingRequests.length} đề xuất bổ nhiệm Admin phụ đang chờ bạn phê duyệt
              </div>
              <div className="text-xs text-rose-700">
                Yêu cầu từ Admin Tổng đối tác cần xác nhận theo quy trình bảo mật phân quyền.
              </div>
            </div>
          </div>
          <button
            onClick={() => onNavigateTab('requests')}
            className="px-3 py-1.5 bg-[#6B0000] text-white text-xs font-semibold rounded-xl whitespace-nowrap transition-colors cursor-pointer"
          >
            Duyệt ngay
          </button>
        </div>
      )}

      {/* 4 Major Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Đề thi</span>
            <div className="w-10 h-10 rounded-xl bg-red-50 text-[#6B0000] flex items-center justify-center">
              <BookOpen className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{exams.length}</div>
          <div className="text-xs text-slate-500 mt-1">
            {exams.filter((e) => e.isOpen).length} đề đang mở làm bài
          </div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Ngân hàng câu hỏi</span>
            <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
              <HelpCircle className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{questions.length}</div>
          <div className="text-xs text-slate-500 mt-1">Câu hỏi trắc nghiệm đã biên soạn</div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Học viên hoạt động</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{studentCount}</div>
          <div className="text-xs text-slate-500 mt-1">Tài khoản học sinh chính thức</div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Lượt nộp bài thi</span>
            <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{completedAttemptsCount}</div>
          <div className="text-xs text-slate-500 mt-1">Bài nộp đã chấm điểm tự động</div>
        </div>
      </div>

      {/* Quick Action Shortcuts */}
      <div className="bg-white rounded-2xl border border-slate-200/80 p-6 shadow-xs">
        <h2 className="text-sm font-bold uppercase tracking-wider text-slate-600 mb-4">
          Thao tác nhanh
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <button
            onClick={() => onNavigateTab('exams')}
            className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 hover:bg-red-50 hover:border-red-200 text-left transition-all cursor-pointer group"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-lg bg-[#6B0000] text-white flex items-center justify-center">
                <Plus className="w-4 h-4" />
              </div>
              <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-[#6B0000] transition-colors" />
            </div>
            <div className="font-bold text-slate-800 text-sm">Tạo đề thi mới</div>
            <div className="text-xs text-slate-500 mt-0.5">Thiết lập thời gian & số lần thi</div>
          </button>

          <button
            onClick={() => onNavigateTab('accounts')}
            className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 hover:bg-emerald-50 hover:border-emerald-200 text-left transition-all cursor-pointer group"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-lg bg-emerald-600 text-white flex items-center justify-center">
                <Users className="w-4 h-4" />
              </div>
              <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-emerald-600 transition-colors" />
            </div>
            <div className="font-bold text-slate-800 text-sm">Quản lý tài khoản</div>
            <div className="text-xs text-slate-500 mt-0.5">Thêm học viên hoặc nhập từ Excel</div>
          </button>

          <button
            onClick={() => onNavigateTab('progress')}
            className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 hover:bg-blue-50 hover:border-blue-200 text-left transition-all cursor-pointer group"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-lg bg-blue-600 text-white flex items-center justify-center">
                <TrendingUp className="w-4 h-4" />
              </div>
              <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-blue-600 transition-colors" />
            </div>
            <div className="font-bold text-slate-800 text-sm">Theo dõi tiến độ</div>
            <div className="text-xs text-slate-500 mt-0.5">Xem chi tiết bài làm từng học sinh</div>
          </button>

          <button
            onClick={() => onNavigateTab('reports')}
            className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 hover:bg-amber-50 hover:border-amber-200 text-left transition-all cursor-pointer group"
          >
            <div className="flex items-center justify-between mb-2">
              <div className="w-8 h-8 rounded-lg bg-amber-600 text-white flex items-center justify-center">
                <Sparkles className="w-4 h-4" />
              </div>
              <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-amber-600 transition-colors" />
            </div>
            <div className="font-bold text-slate-800 text-sm">Bảng xếp hạng</div>
            <div className="text-xs text-slate-500 mt-0.5">Vinh danh top học viên đạt điểm cao</div>
          </button>
        </div>
      </div>

      {/* Recent Exams Table / Cards */}
      <div className="bg-white rounded-2xl border border-slate-200/80 p-6 shadow-xs">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="font-bold text-slate-900 text-base">Danh sách đề thi hiện hành</h2>
            <p className="text-xs text-slate-500">Bấm vào đề thi để quản lý ngân hàng câu hỏi</p>
          </div>
          <button
            onClick={() => onNavigateTab('exams')}
            className="text-xs font-semibold text-[#6B0000] hover:underline cursor-pointer"
          >
            Xem tất cả đề thi &rarr;
          </button>
        </div>

        <div className="space-y-3">
          {exams.slice(0, 4).map((exam) => {
            const examQs = storage.getQuestions(exam.id);

            return (
              <div
                key={exam.id}
                className="p-4 rounded-xl border border-slate-200 hover:border-slate-300 bg-white flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 transition-colors"
              >
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span
                      className={`w-2 h-2 rounded-full ${
                        exam.isOpen ? 'bg-emerald-500' : 'bg-slate-400'
                      }`}
                    />
                    <h3 className="font-bold text-slate-900 text-sm">{exam.title}</h3>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-slate-500">
                    <span className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5" />
                      {exam.durationMinutes} phút
                    </span>
                    <span>•</span>
                    <span>{examQs.length} câu hỏi</span>
                    <span>•</span>
                    <span>{exam.maxAttempts ? `${exam.maxAttempts} lượt` : 'Không giới hạn lượt'}</span>
                  </div>
                </div>

                <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
                  <button
                    onClick={() => onOpenQuestions(exam.id)}
                    className="py-1.5 px-3 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-semibold transition-colors cursor-pointer"
                  >
                    Ngân hàng câu hỏi ({examQs.length})
                  </button>
                  <button
                    onClick={() => storage.toggleExamStatus(exam.id)}
                    className={`py-1.5 px-3 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
                      exam.isOpen
                        ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {exam.isOpen ? 'Đang mở' : 'Đang đóng'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
