import React, { useState } from 'react';
import { storage } from '../../services/storageService';
import { Exam, ExamAttempt, UserProfile } from '../../types';
import { TrendingUp, Users, CheckCircle, Clock, Search, X, Award, ChevronRight } from 'lucide-react';

export const AdminProgressScreen: React.FC = () => {
  const exams = storage.getExams();
  const allAttempts = storage.getAttempts().filter((a) => a.status === 'completed');
  const allUsers = storage.getUsers();

  const [selectedExamId, setSelectedExamId] = useState<string | null>(null);
  const [studentSearch, setStudentSearch] = useState('');

  // Selected Exam stats drilldown
  const selectedExam = selectedExamId ? storage.getExamById(selectedExamId) : null;
  const examAttempts = selectedExamId ? allAttempts.filter((a) => a.examId === selectedExamId) : [];

  // Group attempts by student for this exam
  const studentMap = new Map<string, { user: UserProfile | undefined; bestScore: number; count: number; lastDate: string }>();
  examAttempts.forEach((att) => {
    const existing = studentMap.get(att.userId);
    const score = att.bestScore || att.diemSo || 0;
    const date = att.completedAt || att.lastAttemptAt || '';

    if (!existing) {
      const u = allUsers.find((usr) => usr.id === att.userId);
      studentMap.set(att.userId, {
        user: u,
        bestScore: score,
        count: att.attemptCount || 1,
        lastDate: date,
      });
    } else {
      existing.count = Math.max(existing.count, att.attemptCount || 1);
      if (score > existing.bestScore) {
        existing.bestScore = score;
      }
      if (date > existing.lastDate) {
        existing.lastDate = date;
      }
    }
  });

  const studentList = Array.from(studentMap.entries()).map(([userId, data]) => ({
    userId,
    ...data,
  }));

  const filteredStudents = studentList.filter((s) => {
    const name = s.user?.name || '';
    const username = s.user?.username || '';
    const className = s.user?.className || '';
    const q = studentSearch.toLowerCase();
    return name.toLowerCase().includes(q) || username.toLowerCase().includes(q) || className.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2.5">
          <TrendingUp className="w-6 h-6 text-[#6B0000]" />
          <span>Theo Dõi Tiến Độ Thi Cử Của Học Viên</span>
        </h1>
        <p className="text-sm text-slate-500 mt-1">
          Xem tỷ lệ tham gia, điểm số và số lần thi của từng học viên theo từng đề thi cụ thể
        </p>
      </div>

      {/* Progress Exam Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {exams.map((exam) => {
          const thisExamAttempts = allAttempts.filter((a) => a.examId === exam.id);
          const distinctStudents = new Set(thisExamAttempts.map((a) => a.userId));
          const studentCount = distinctStudents.size;

          const totalBestScores = Array.from(distinctStudents).reduce((sum, uId) => {
            const userAtts = thisExamAttempts.filter((a) => a.userId === uId);
            const userBest = Math.max(...userAtts.map((a) => a.bestScore || a.diemSo || 0));
            return sum + userBest;
          }, 0);

          const avgScore = studentCount > 0 ? (totalBestScores / studentCount).toFixed(1) : '0.0';

          return (
            <div
              key={exam.id}
              className="bg-white rounded-2xl border border-slate-200 p-5 sm:p-6 shadow-xs hover:border-slate-300 transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <span
                    className={`text-[11px] font-bold px-2 py-0.5 rounded ${
                      exam.isOpen ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {exam.isOpen ? 'Đang mở' : 'Đã đóng'}
                  </span>
                  <span className="text-xs text-slate-500">{exam.durationMinutes} phút</span>
                </div>

                <h3 className="font-bold text-slate-900 text-base leading-snug mb-4 line-clamp-2">
                  {exam.title}
                </h3>

                <div className="grid grid-cols-2 gap-3 py-3 border-y border-slate-100 text-xs mb-4">
                  <div>
                    <div className="text-slate-400 font-medium">Thí sinh đã thi</div>
                    <div className="text-lg font-bold text-slate-900 mt-0.5">
                      {studentCount} <span className="text-xs font-normal text-slate-500">học viên</span>
                    </div>
                  </div>

                  <div>
                    <div className="text-slate-400 font-medium">Điểm trung bình</div>
                    <div className="text-lg font-bold text-[#6B0000] mt-0.5">
                      {avgScore} <span className="text-xs font-normal text-slate-400">/ 10</span>
                    </div>
                  </div>
                </div>
              </div>

              <button
                onClick={() => {
                  setSelectedExamId(exam.id);
                  setStudentSearch('');
                }}
                className="w-full py-2 px-3 bg-slate-100 hover:bg-[#6B0000] hover:text-white text-slate-700 text-xs font-semibold rounded-xl flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
              >
                <span>Xem danh sách kết quả học viên ({studentCount})</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          );
        })}
      </div>

      {/* Drilldown Modal for Selected Exam */}
      {selectedExam && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-6 shadow-2xl max-h-[90vh] flex flex-col">
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div>
                <span className="text-xs font-bold uppercase tracking-wider text-[#6B0000]">
                  Tiến độ thi chi tiết
                </span>
                <h2 className="text-lg font-bold text-slate-900">{selectedExam.title}</h2>
              </div>
              <button
                onClick={() => setSelectedExamId(null)}
                className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Search filter in modal */}
            <div className="py-3">
              <div className="relative">
                <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={studentSearch}
                  onChange={(e) => setStudentSearch(e.target.value)}
                  placeholder="Tìm học viên theo tên, lớp..."
                  className="w-full pl-9 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                />
              </div>
            </div>

            {/* Student Table */}
            <div className="flex-1 overflow-y-auto border border-slate-200 rounded-xl">
              {filteredStudents.length === 0 ? (
                <div className="p-8 text-center text-xs text-slate-500">
                  Chưa có dữ liệu bài làm của học viên cho đề thi này.
                </div>
              ) : (
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-100 text-slate-600 font-bold sticky top-0 border-b border-slate-200">
                    <tr>
                      <th className="py-2.5 px-3">Học viên</th>
                      <th className="py-2.5 px-3">Lớp</th>
                      <th className="py-2.5 px-3">Số lần thi</th>
                      <th className="py-2.5 px-3">Thời gian gần nhất</th>
                      <th className="py-2.5 px-3 text-right">Điểm cao nhất</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredStudents.map((item) => {
                      const isPassed = item.bestScore >= 5.0;
                      const dateStr = item.lastDate
                        ? new Date(item.lastDate).toLocaleDateString('vi-VN', {
                            hour: '2-digit',
                            minute: '2-digit',
                            day: '2-digit',
                            month: '2-digit',
                          })
                        : '-';

                      return (
                        <tr key={item.userId} className="hover:bg-slate-50">
                          <td className="py-2.5 px-3">
                            <div className="font-bold text-slate-800">
                              {item.user?.name || item.userId}
                            </div>
                            <div className="text-[11px] text-slate-400">
                              @{item.user?.username || '-'}
                            </div>
                          </td>
                          <td className="py-2.5 px-3 text-slate-600">
                            {item.user?.className || '-'}
                          </td>
                          <td className="py-2.5 px-3 text-slate-600">{item.count} lần</td>
                          <td className="py-2.5 px-3 text-slate-500">{dateStr}</td>
                          <td className="py-2.5 px-3 text-right">
                            <span
                              className={`inline-block px-2.5 py-1 rounded-md font-bold text-xs ${
                                isPassed
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : 'bg-red-50 text-red-700 border border-red-200'
                              }`}
                            >
                              {item.bestScore.toFixed(1)} đ
                            </span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>

            {/* Modal Footer */}
            <div className="pt-4 flex justify-end">
              <button
                onClick={() => setSelectedExamId(null)}
                className="py-2 px-4 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
