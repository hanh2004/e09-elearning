import React, { useState } from 'react';
import { storage } from '../../services/storageService';
import { Exam } from '../../types';
import {
  BookOpen,
  Plus,
  Search,
  Clock,
  HelpCircle,
  ToggleLeft,
  ToggleRight,
  Trash2,
  Edit2,
  Calendar,
  AlertTriangle,
  RotateCcw,
  Check,
} from 'lucide-react';

interface AdminExamScreenProps {
  onOpenQuestions: (examId: string) => void;
}

export const AdminExamScreen: React.FC<AdminExamScreenProps> = ({ onOpenQuestions }) => {
  const exams = storage.getExams();
  const [searchQuery, setSearchQuery] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingExam, setEditingExam] = useState<Exam | null>(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Form State
  const [title, setTitle] = useState('');
  const [durationMinutes, setDurationMinutes] = useState(45);
  const [isOpen, setIsOpen] = useState(true);
  const [unlimitedAttempts, setUnlimitedAttempts] = useState(true);
  const [maxAttempts, setMaxAttempts] = useState(3);
  const [hasAutoClose, setHasAutoClose] = useState(false);
  const [closesAt, setClosesAt] = useState('');
  const [description, setDescription] = useState('');

  const openCreateModal = () => {
    setEditingExam(null);
    setTitle('');
    setDurationMinutes(45);
    setIsOpen(true);
    setUnlimitedAttempts(true);
    setMaxAttempts(3);
    setHasAutoClose(false);
    setClosesAt('');
    setDescription('');
    setShowModal(true);
  };

  const openEditModal = (exam: Exam) => {
    setEditingExam(exam);
    setTitle(exam.title);
    setDurationMinutes(exam.durationMinutes);
    setIsOpen(exam.isOpen);
    setUnlimitedAttempts(exam.maxAttempts == null);
    setMaxAttempts(exam.maxAttempts ?? 3);
    setHasAutoClose(Boolean(exam.closesAt));
    setClosesAt(exam.closesAt ? exam.closesAt.slice(0, 16) : '');
    setDescription(exam.description || '');
    setShowModal(true);
  };

  const handleSaveExam = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const examData: Exam = {
      id: editingExam ? editingExam.id : `exam_${Date.now()}`,
      title: title.trim(),
      duration: `${durationMinutes} phút`,
      durationMinutes: Number(durationMinutes),
      isOpen,
      maxAttempts: unlimitedAttempts ? null : Number(maxAttempts),
      closesAt: hasAutoClose && closesAt ? new Date(closesAt).toISOString() : null,
      description: description.trim(),
      createdAt: editingExam ? editingExam.createdAt : new Date().toISOString(),
    };

    storage.saveExam(examData);
    setShowModal(false);
  };

  const handleDeleteExam = (id: string) => {
    storage.deleteExam(id);
    setDeleteConfirmId(null);
  };

  const filteredExams = exams.filter((e) =>
    e.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (e.description && e.description.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Quản lý Đề thi</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            Tạo mới, chỉnh sửa thời gian làm bài, số lần thi và ngân hàng câu hỏi
          </p>
        </div>

        <button
          onClick={openCreateModal}
          className="py-2.5 px-4 bg-[#6B0000] hover:bg-[#520000] text-white text-sm font-semibold rounded-xl flex items-center gap-2 shadow-xs transition-colors cursor-pointer self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>Thêm đề thi mới</span>
        </button>
      </div>

      {/* Search Input */}
      <div className="relative w-full max-w-md">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Tìm kiếm theo tên đề thi..."
          className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] focus:border-transparent transition-all shadow-xs"
        />
      </div>

      {/* Exams Grid */}
      {filteredExams.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center">
          <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto mb-3">
            <BookOpen className="w-6 h-6" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Không có đề thi nào</h3>
          <p className="text-xs text-slate-500 mt-1">Bấm nút "Thêm đề thi mới" để bắt đầu soạn đề.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
          {filteredExams.map((exam) => {
            const qs = storage.getQuestions(exam.id);
            const isAutoClosed = exam.closesAt ? new Date(exam.closesAt).getTime() < Date.now() : false;

            return (
              <div
                key={exam.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:border-slate-300 p-5 sm:p-6 flex flex-col justify-between transition-all"
              >
                <div>
                  {/* Top Badges & Actions */}
                  <div className="flex items-center justify-between gap-2 mb-3">
                    <button
                      onClick={() => storage.toggleExamStatus(exam.id)}
                      className={`inline-flex items-center gap-1.5 text-xs font-bold px-2.5 py-1 rounded-lg border transition-colors cursor-pointer ${
                        exam.isOpen && !isAutoClosed
                          ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                          : 'bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200'
                      }`}
                    >
                      <span
                        className={`w-2 h-2 rounded-full ${
                          exam.isOpen && !isAutoClosed ? 'bg-emerald-500' : 'bg-slate-400'
                        }`}
                      />
                      <span>{exam.isOpen && !isAutoClosed ? 'Đang mở (Bấm để đóng)' : 'Đang đóng (Bấm để mở)'}</span>
                    </button>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => openEditModal(exam)}
                        className="p-1.5 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
                        title="Chỉnh sửa đề thi"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setDeleteConfirmId(exam.id)}
                        className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
                        title="Xóa đề thi"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>

                  {/* Title */}
                  <h3 className="text-base font-bold text-slate-900 leading-snug mb-1.5">
                    {exam.title}
                  </h3>

                  {exam.description && (
                    <p className="text-xs text-slate-500 line-clamp-2 mb-4 leading-relaxed">
                      {exam.description}
                    </p>
                  )}

                  {/* Metadata pills */}
                  <div className="grid grid-cols-2 gap-2 text-xs text-slate-600 py-3 border-y border-slate-100 mb-4">
                    <div className="flex items-center gap-1.5">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>{exam.durationMinutes} phút</span>
                    </div>

                    <div className="flex items-center gap-1.5">
                      <HelpCircle className="w-3.5 h-3.5 text-slate-400" />
                      <span className="font-semibold text-slate-800">{qs.length} câu hỏi</span>
                    </div>

                    <div className="flex items-center gap-1.5 col-span-2">
                      <RotateCcw className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Số lần thi:{' '}
                        {exam.maxAttempts ? `${exam.maxAttempts} lần/học viên` : 'Không giới hạn'}
                      </span>
                    </div>

                    {exam.closesAt && (
                      <div className="flex items-center gap-1.5 col-span-2 text-[11px] text-amber-700">
                        <Calendar className="w-3 h-3" />
                        <span>Tự động đóng: {new Date(exam.closesAt).toLocaleString('vi-VN')}</span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Footer Buttons */}
                <div className="flex items-center gap-2 pt-1">
                  <button
                    onClick={() => onOpenQuestions(exam.id)}
                    className="flex-1 py-2 px-3 bg-[#6B0000] hover:bg-[#520000] text-white text-xs font-semibold rounded-xl flex items-center justify-center gap-1.5 shadow-xs transition-colors cursor-pointer"
                  >
                    <BookOpen className="w-3.5 h-3.5" />
                    <span>Quản lý Ngân hàng Câu hỏi ({qs.length})</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal: Create or Edit Exam */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
            <h2 className="text-lg font-bold text-slate-900 mb-4">
              {editingExam ? 'Chỉnh sửa đề thi' : 'Tạo đề thi mới'}
            </h2>

            <form onSubmit={handleSaveExam} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Tên đề thi *
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Ví dụ: Kiểm tra 1 tiết Toán 12"
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Thời gian làm bài (phút) *
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="300"
                    value={durationMinutes}
                    onChange={(e) => setDurationMinutes(Number(e.target.value))}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                    required
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Trạng thái mở đề
                  </label>
                  <select
                    value={isOpen ? 'true' : 'false'}
                    onChange={(e) => setIsOpen(e.target.value === 'true')}
                    className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  >
                    <option value="true">Mở cho học viên làm</option>
                    <option value="false">Đóng (Tạm khóa)</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Giới hạn số lần làm bài
                </label>
                <div className="flex items-center gap-4 text-xs">
                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="radio"
                      checked={unlimitedAttempts}
                      onChange={() => setUnlimitedAttempts(true)}
                    />
                    <span>Không giới hạn</span>
                  </label>
                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="radio"
                      checked={!unlimitedAttempts}
                      onChange={() => setUnlimitedAttempts(false)}
                    />
                    <span>Giới hạn số lần</span>
                  </label>
                </div>

                {!unlimitedAttempts && (
                  <div className="mt-2">
                    <input
                      type="number"
                      min="1"
                      max="10"
                      value={maxAttempts}
                      onChange={(e) => setMaxAttempts(Number(e.target.value))}
                      placeholder="Số lần tối đa (ví dụ: 3)"
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                    />
                  </div>
                )}
              </div>

              <div>
                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 cursor-pointer mb-1.5">
                  <input
                    type="checkbox"
                    checked={hasAutoClose}
                    onChange={(e) => setHasAutoClose(e.target.checked)}
                  />
                  <span>Tự động đóng đề theo thời gian hẹn</span>
                </label>

                {hasAutoClose && (
                  <input
                    type="datetime-local"
                    value={closesAt}
                    onChange={(e) => setClosesAt(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  />
                )}
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Mô tả đề thi (Tùy chọn)
                </label>
                <textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Ghi chú thêm về phạm vi kiến thức, đối tượng học sinh..."
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="py-2.5 px-4 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  className="py-2.5 px-5 bg-[#6B0000] hover:bg-[#520000] text-white rounded-xl text-xs font-bold shadow-xs cursor-pointer"
                >
                  {editingExam ? 'Cập nhật đề thi' : 'Tạo đề thi'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteConfirmId && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl">
            <div className="w-12 h-12 rounded-full bg-red-50 text-red-600 flex items-center justify-center mx-auto mb-3">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <h3 className="text-base font-bold text-center text-slate-900 mb-1">
              Xác nhận xóa đề thi?
            </h3>
            <p className="text-xs text-slate-500 text-center mb-5">
              Hành động này sẽ xóa toàn bộ câu hỏi và lịch sử làm bài của đề thi này. Dữ liệu không thể khôi phục.
            </p>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setDeleteConfirmId(null)}
                className="flex-1 py-2 px-3 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Hủy
              </button>
              <button
                onClick={() => handleDeleteExam(deleteConfirmId)}
                className="flex-1 py-2 px-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-xs font-semibold cursor-pointer"
              >
                Xác nhận xóa
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
