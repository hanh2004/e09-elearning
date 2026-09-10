import React from 'react';
import { storage } from '../../services/storageService';
import { BarChart3, Trophy, Medal, Award, CheckCircle, Flame, Users, BookOpen } from 'lucide-react';

export const AdminReportScreen: React.FC = () => {
  const attempts = storage.getAttempts().filter((a) => a.status === 'completed');
  const users = storage.getUsers();
  const exams = storage.getExams();

  const totalCompleted = attempts.length;
  const passedCount = attempts.filter((a) => (a.bestScore || a.diemSo || 0) >= 5.0).length;
  const passRate = totalCompleted > 0 ? ((passedCount / totalCompleted) * 100).toFixed(1) : '0.0';

  // Group by student to build Leaderboard
  const studentMap = new Map<
    string,
    { name: string; username: string; className: string; school: string; highestScore: number; attemptsCount: number; examsSet: Set<string> }
  >();

  attempts.forEach((att) => {
    const u = users.find((usr) => usr.id === att.userId);
    const score = att.bestScore || att.diemSo || 0;

    const existing = studentMap.get(att.userId);
    if (!existing) {
      const set = new Set<string>();
      set.add(att.examId);
      studentMap.set(att.userId, {
        name: u?.name || att.userName || 'Học viên',
        username: u?.username || '',
        className: u?.className || '12A',
        school: u?.school || 'THPT',
        highestScore: score,
        attemptsCount: att.attemptCount || 1,
        examsSet: set,
      });
    } else {
      existing.attemptsCount += 1;
      existing.examsSet.add(att.examId);
      if (score > existing.highestScore) {
        existing.highestScore = score;
      }
    }
  });

  const leaderboard = Array.from(studentMap.values()).sort((a, b) => b.highestScore - a.highestScore);

  // Score distribution
  const excellent = attempts.filter((a) => (a.bestScore || a.diemSo || 0) >= 8.0).length;
  const good = attempts.filter((a) => (a.bestScore || a.diemSo || 0) >= 6.5 && (a.bestScore || a.diemSo || 0) < 8.0).length;
  const average = attempts.filter((a) => (a.bestScore || a.diemSo || 0) >= 5.0 && (a.bestScore || a.diemSo || 0) < 6.5).length;
  const belowAverage = attempts.filter((a) => (a.bestScore || a.diemSo || 0) < 5.0).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2.5">
          <BarChart3 className="w-6 h-6 text-[#6B0000]" />
          <span>Báo Cáo Điểm Số & Bảng Xếp Hạng Học Viên</span>
        </h1>
        <p className="text-sm text-slate-500 mt-1">
          Tổng hợp kết quả toàn diện, tỷ lệ đạt yêu cầu và vinh danh học viên có thành tích xuất sắc
        </p>
      </div>

      {/* Top 3 Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Tỷ lệ đạt yêu cầu</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <CheckCircle className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black text-emerald-600">{passRate}%</div>
          <div className="text-xs text-slate-500 mt-1">
            {passedCount} trên tổng số {totalCompleted} bài nộp
          </div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Tổng số đề thi</span>
            <div className="w-8 h-8 rounded-lg bg-red-50 text-[#6B0000] flex items-center justify-center">
              <BookOpen className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{exams.length}</div>
          <div className="text-xs text-slate-500 mt-1">
            {exams.filter((e) => e.isOpen).length} đề đang mở làm bài
          </div>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Học viên tham gia</span>
            <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center">
              <Users className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900">{leaderboard.length}</div>
          <div className="text-xs text-slate-500 mt-1">Thí sinh đã có ít nhất 1 bài nộp</div>
        </div>
      </div>

      {/* Score Distribution Visual Progress */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs">
        <h2 className="text-sm font-bold uppercase tracking-wider text-slate-700 mb-4">
          Phân bố phổ điểm kiểm tra
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div className="p-4 rounded-xl bg-emerald-50/70 border border-emerald-200">
            <div className="text-xs font-bold text-emerald-900">Xuất sắc (8.0 - 10.0)</div>
            <div className="text-2xl font-black text-emerald-700 mt-1">{excellent}</div>
            <div className="text-[11px] text-emerald-800 mt-0.5">
              {totalCompleted > 0 ? ((excellent / totalCompleted) * 100).toFixed(0) : 0}% tổng bài
            </div>
          </div>

          <div className="p-4 rounded-xl bg-blue-50/70 border border-blue-200">
            <div className="text-xs font-bold text-blue-900">Khá (6.5 - 7.9)</div>
            <div className="text-2xl font-black text-blue-700 mt-1">{good}</div>
            <div className="text-[11px] text-blue-800 mt-0.5">
              {totalCompleted > 0 ? ((good / totalCompleted) * 100).toFixed(0) : 0}% tổng bài
            </div>
          </div>

          <div className="p-4 rounded-xl bg-amber-50/70 border border-amber-200">
            <div className="text-xs font-bold text-amber-900">Trung bình (5.0 - 6.4)</div>
            <div className="text-2xl font-black text-amber-700 mt-1">{average}</div>
            <div className="text-[11px] text-amber-800 mt-0.5">
              {totalCompleted > 0 ? ((average / totalCompleted) * 100).toFixed(0) : 0}% tổng bài
            </div>
          </div>

          <div className="p-4 rounded-xl bg-red-50/70 border border-red-200">
            <div className="text-xs font-bold text-red-900">Dưới trung bình (&lt; 5.0)</div>
            <div className="text-2xl font-black text-red-700 mt-1">{belowAverage}</div>
            <div className="text-[11px] text-red-800 mt-0.5">
              {totalCompleted > 0 ? ((belowAverage / totalCompleted) * 100).toFixed(0) : 0}% tổng bài
            </div>
          </div>
        </div>
      </div>

      {/* Leaderboard Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-amber-500" />
            <h2 className="font-bold text-slate-900 text-base">Bảng Xếp Hạng Thành Tích Cao Nhất</h2>
          </div>
          <span className="text-xs text-slate-500 font-medium">Sắp xếp theo điểm thi cao nhất</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-500 text-xs font-semibold uppercase tracking-wider border-b border-slate-200">
              <tr>
                <th className="py-3 px-4 w-16 text-center">Hạng</th>
                <th className="py-3 px-4">Học viên</th>
                <th className="py-3 px-4">Lớp / Trường</th>
                <th className="py-3 px-4 text-center">Số đề đã thi</th>
                <th className="py-3 px-4 text-right">Điểm cao nhất</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {leaderboard.map((student, idx) => {
                const rank = idx + 1;

                return (
                  <tr key={idx} className="hover:bg-slate-50/70 transition-colors">
                    {/* Rank Badge */}
                    <td className="py-3 px-4 text-center">
                      {rank === 1 ? (
                        <span className="w-7 h-7 rounded-full bg-amber-100 text-amber-800 font-bold inline-flex items-center justify-center ring-2 ring-amber-400">
                          1
                        </span>
                      ) : rank === 2 ? (
                        <span className="w-7 h-7 rounded-full bg-slate-200 text-slate-800 font-bold inline-flex items-center justify-center ring-2 ring-slate-300">
                          2
                        </span>
                      ) : rank === 3 ? (
                        <span className="w-7 h-7 rounded-full bg-amber-700/20 text-amber-900 font-bold inline-flex items-center justify-center ring-2 ring-amber-600">
                          3
                        </span>
                      ) : (
                        <span className="text-slate-400 font-semibold">{rank}</span>
                      )}
                    </td>

                    {/* Student Info */}
                    <td className="py-3 px-4">
                      <div className="font-bold text-slate-900">{student.name}</div>
                      <div className="text-xs text-slate-400 font-mono">@{student.username}</div>
                    </td>

                    {/* Class & School */}
                    <td className="py-3 px-4 text-xs text-slate-600">
                      <div className="font-medium text-slate-800">{student.className}</div>
                      <div className="text-slate-400 truncate max-w-[180px]">{student.school}</div>
                    </td>

                    {/* Exams completed */}
                    <td className="py-3 px-4 text-center text-xs text-slate-700 font-semibold">
                      {student.examsSet.size} đề
                    </td>

                    {/* Highest Score */}
                    <td className="py-3 px-4 text-right">
                      <span className="text-base font-black text-[#6B0000]">
                        {student.highestScore.toFixed(1)}{' '}
                        <span className="text-xs font-normal text-slate-400">/ 10</span>
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
