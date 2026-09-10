import React, { useState } from 'react';
import { storage } from '../../services/storageService';
import { Question, Exam } from '../../types';
import {
  ArrowLeft,
  Plus,
  Edit2,
  Trash2,
  CheckCircle2,
  HelpCircle,
  BookOpen,
  Check,
  AlertTriangle,
} from 'lucide-react';

interface AdminQuestionBankScreenProps {
  examId: string;
  onBack: () => void;
}

export const AdminQuestionBankScreen: React.FC<AdminQuestionBankScreenProps> = ({ examId, onBack }) => {
  const exam = storage.getExamById(examId);
  const questions = storage.getQuestions(examId);

  const [showModal, setShowModal] = useState(false);
  const [editingQuestion, setEditingQuestion] = useState<Question | null>(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Question Form State
  const [questionText, setQuestionText] = useState('');
  const [optA, setOptA] = useState('');
  const [optB, setOptB] = useState('');
  const [optC, setOptC] = useState('');
  const [optD, setOptD] = useState('');
  const [correctIndex, setCorrectIndex] = useState(0);
  const [explanation, setExplanation] = useState('');

  const openCreateModal = () => {
    setEditingQuestion(null);
    setQuestionText('');
    setOptA('');
    setOptB('');
    setOptC('');
    setOptD('');
    setCorrectIndex(0);
    setExplanation('');
    setShowModal(true);
  };

  const openEditModal = (q: Question) => {
    setEditingQuestion(q);
    setQuestionText(q.questionText);
    setOptA(q.options[0] || '');
    setOptB(q.options[1] || '');
    setOptC(q.options[2] || '');
    setOptD(q.options[3] || '');
    setCorrectIndex(q.correctAnswerIndex);
    setExplanation(q.explanation || '');
    setShowModal(true);
  };

  const handleSaveQuestion = (e: React.FormEvent) => {
    e.preventDefault();
    if (!questionText.trim() || !optA.trim() || !optB.trim() || !optC.trim() || !optD.trim()) {
      return;
    }

    const newQ: Question = {
      id: editingQuestion ? editingQuestion.id : `q_${Date.now()}`,
      examId,
      questionText: questionText.trim(),
      options: [optA.trim(), optB.trim(), optC.trim(), optD.trim()],
      correctAnswerIndex: correctIndex,
      explanation: explanation.trim(),
    };

    storage.saveQuestion(newQ);
    setShowModal(false);
  };

  const handleDelete = (id: string) => {
    storage.deleteQuestion(id);
    setDeleteConfirmId(null);
  };

  if (!exam) {
    return (
      <div className="p-8 text-center">
        <p className="text-slate-600 mb-4">Không tìm thấy thông tin bài thi này.</p>
        <button
          onClick={onBack}
          className="px-4 py-2 bg-[#6B0000] text-white rounded-xl text-xs font-semibold"
        >
          Quay lại danh sách đề thi
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header with Back Button */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="p-2 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
            title="Quay lại danh sách đề thi"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B0000] bg-red-50 px-2 py-0.5 rounded-md">
                Ngân hàng câu hỏi
              </span>
              <span className="text-xs text-slate-400">•</span>
              <span className="text-xs font-semibold text-slate-600">{questions.length} câu hỏi</span>
            </div>
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 mt-0.5">{exam.title}</h1>
          </div>
        </div>

        <button
          onClick={openCreateModal}
          className="py-2.5 px-4 bg-[#6B0000] hover:bg-[#520000] text-white text-sm font-semibold rounded-xl flex items-center gap-2 shadow-xs transition-colors cursor-pointer self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>Thêm câu hỏi mới</span>
        </button>
      </div>

      {/* Questions List */}
      {questions.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center">
          <div className="w-12 h-12 rounded-full bg-red-50 text-[#6B0000] flex items-center justify-center mx-auto mb-3">
            <HelpCircle className="w-6 h-6" />
          </div>
          <h3 className="text-base font-bold text-slate-800">Chưa có câu hỏi nào trong đề thi này</h3>
          <p className="text-xs text-slate-500 mt-1 mb-4">
            Bắt đầu thêm câu hỏi trắc nghiệm kèm 4 lựa chọn và đáp án đúng.
          </p>
          <button
            onClick={openCreateModal}
            className="py-2 px-4 bg-[#6B0000] text-white rounded-xl text-xs font-semibold cursor-pointer"
          >
            Thêm câu hỏi đầu tiên
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {questions.map((q, idx) => (
            <div
              key={q.id}
              className="bg-white rounded-2xl border border-slate-200/80 p-5 sm:p-6 shadow-xs hover:border-slate-300 transition-all"
            >
              {/* Question Index & Controls */}
              <div className="flex items-center justify-between gap-2 mb-3">
                <span className="text-xs font-bold uppercase tracking-wider text-slate-600 bg-slate-100 px-2.5 py-1 rounded-md">
                  Câu hỏi #{idx + 1}
                </span>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => openEditModal(q)}
                    className="p-1.5 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
                    title="Chỉnh sửa câu hỏi"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => setDeleteConfirmId(q.id)}
                    className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
                    title="Xóa câu hỏi"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Question Prompt */}
              <p className="font-semibold text-slate-900 text-sm sm:text-base leading-relaxed mb-4">
                {q.questionText}
              </p>

              {/* 4 Choices */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 mb-3">
                {q.options.map((opt, optIdx) => {
                  const isCorrect = q.correctAnswerIndex === optIdx;
                  const letter = String.fromCharCode(65 + optIdx);

                  return (
                    <div
                      key={optIdx}
                      className={`p-3 rounded-xl border text-xs sm:text-sm flex items-center justify-between gap-2.5 ${
                        isCorrect
                          ? 'border-emerald-500 bg-emerald-50/60 font-semibold text-emerald-950 ring-1 ring-emerald-400'
                          : 'border-slate-200 bg-white text-slate-700'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <span
                          className={`w-6 h-6 rounded-md flex items-center justify-center font-bold text-xs ${
                            isCorrect ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {letter}
                        </span>
                        <span>{opt}</span>
                      </div>

                      {isCorrect && (
                        <span className="text-[11px] font-bold text-emerald-700 flex items-center gap-1 shrink-0">
                          <Check className="w-3.5 h-3.5" />
                          <span>Đáp án đúng</span>
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>

              {/* Explanation note */}
              {q.explanation && (
                <div className="p-3 rounded-xl bg-amber-50/70 border border-amber-200/60 text-xs text-amber-950 mt-2">
                  <span className="font-bold block mb-0.5">💡 Lời giải / Hướng dẫn:</span>
                  <p>{q.explanation}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Modal: Create or Edit Question */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-bold text-slate-900 mb-4">
              {editingQuestion ? 'Chỉnh sửa câu hỏi' : 'Thêm câu hỏi mới'}
            </h2>

            <form onSubmit={handleSaveQuestion} className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Nội dung câu hỏi *
                </label>
                <textarea
                  rows={3}
                  value={questionText}
                  onChange={(e) => setQuestionText(e.target.value)}
                  placeholder="Nhập đề bài hoặc câu hỏi..."
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-2">
                  4 Phương án lựa chọn (Chọn nút tròn để chỉ định đáp án đúng) *
                </label>

                <div className="space-y-2.5">
                  {[
                    { label: 'A', value: optA, setter: setOptA, idx: 0 },
                    { label: 'B', value: optB, setter: setOptB, idx: 1 },
                    { label: 'C', value: optC, setter: setOptC, idx: 2 },
                    { label: 'D', value: optD, setter: setOptD, idx: 3 },
                  ].map(({ label, value, setter, idx }) => (
                    <div
                      key={label}
                      className={`flex items-center gap-2.5 p-2 rounded-xl border ${
                        correctIndex === idx
                          ? 'border-emerald-500 bg-emerald-50/50'
                          : 'border-slate-200 bg-slate-50'
                      }`}
                    >
                      <label className="flex items-center gap-1.5 cursor-pointer pl-1 shrink-0">
                        <input
                          type="radio"
                          name="correctOption"
                          checked={correctIndex === idx}
                          onChange={() => setCorrectIndex(idx)}
                          className="text-emerald-600 focus:ring-emerald-500"
                        />
                        <span className="font-bold text-xs text-slate-700">{label}:</span>
                      </label>
                      <input
                        type="text"
                        value={value}
                        onChange={(e) => setter(e.target.value)}
                        placeholder={`Nội dung lựa chọn ${label}`}
                        className="flex-1 px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs sm:text-sm focus:outline-none focus:ring-1 focus:ring-[#6B0000]"
                        required
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Lời giải / Giải thích chi tiết (Tùy chọn)
                </label>
                <textarea
                  rows={2}
                  value={explanation}
                  onChange={(e) => setExplanation(e.target.value)}
                  placeholder="Giải thích vì sao đáp án này là đúng..."
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
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
                  {editingQuestion ? 'Lưu thay đổi' : 'Thêm câu hỏi'}
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
              Xác nhận xóa câu hỏi này?
            </h3>
            <p className="text-xs text-slate-500 text-center mb-5">
              Câu hỏi sẽ bị xóa vĩnh viễn khỏi ngân hàng câu hỏi của bài thi.
            </p>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setDeleteConfirmId(null)}
                className="flex-1 py-2 px-3 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Hủy
              </button>
              <button
                onClick={() => handleDelete(deleteConfirmId)}
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
