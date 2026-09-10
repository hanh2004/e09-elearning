import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import {
  Settings,
  AlertTriangle,
  RotateCcw,
  Shield,
  User,
  CheckCircle2,
  Lock,
  LogOut,
  Power,
} from 'lucide-react';

export const AdminSettingsScreen: React.FC = () => {
  const { currentUser, isRoot, logout } = useAuth();
  const status = storage.getStatus();
  const [maintenance, setMaintenance] = useState(status.maintenance);
  const [resetConfirm, setResetConfirm] = useState(false);
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  const handleToggleMaintenance = (enabled: boolean) => {
    if (!currentUser) return;
    setMaintenance(enabled);
    storage.setMaintenanceMode(enabled, currentUser.id);
    setToastMsg(
      enabled
        ? 'Đã BẬT chế độ bảo trì hệ thống! Cổng học viên hiện tạm khóa.'
        : 'Đã TẮT chế độ bảo trì hệ thống! Học viên có thể truy cập bình thường.'
    );
    setTimeout(() => setToastMsg(null), 3500);
  };

  const handleResetDefaults = () => {
    storage.resetToDefaults();
    setResetConfirm(false);
    setToastMsg('Đã thiết lập lại toàn bộ dữ liệu hệ thống về cấu hình mẫu mặc định!');
    setTimeout(() => setToastMsg(null), 3500);
  };

  return (
    <div className="max-w-4xl space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2.5">
          <Settings className="w-6 h-6 text-[#6B0000]" />
          <span>Cài Đặt Hệ Thống E-09</span>
        </h1>
        <p className="text-sm text-slate-500 mt-1">
          Quản lý trạng thái vận hành, bảo trì máy chủ và thông tin quản trị viên
        </p>
      </div>

      {toastMsg && (
        <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs sm:text-sm flex items-center gap-2.5 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span>{toastMsg}</span>
        </div>
      )}

      {/* Maintenance Mode Card */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <Power className={`w-5 h-5 ${maintenance ? 'text-amber-600' : 'text-slate-400'}`} />
              <h2 className="font-bold text-slate-900 text-base">Chế độ Bảo trì Hệ thống</h2>
            </div>
            <p className="text-xs sm:text-sm text-slate-500 max-w-xl leading-relaxed">
              Khi bật chế độ bảo trì, học viên tạm thời không thể đăng nhập hoặc làm bài thi. Quản trị viên (Admin) vẫn có toàn quyền truy cập để chuẩn bị đề thi và cập nhật dữ liệu.
            </p>
          </div>

          <div className="flex items-center gap-3 self-start sm:self-auto">
            <button
              onClick={() => handleToggleMaintenance(!maintenance)}
              className={`relative inline-flex h-7 w-12 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                maintenance ? 'bg-amber-600' : 'bg-slate-300'
              }`}
            >
              <span
                className={`pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out ${
                  maintenance ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
            <span className="text-xs font-bold text-slate-700 min-w-[60px]">
              {maintenance ? 'Đang Bật' : 'Đang Tắt'}
            </span>
          </div>
        </div>

        {maintenance && (
          <div className="mt-4 p-3.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-xs flex items-start gap-2.5">
            <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
            <div>
              <strong>Lưu ý:</strong> Thông báo bảo trì đang hiển thị tại màn hình đăng nhập của học viên. Sau khi chuẩn bị xong đề thi, hãy tắt chế độ này để học sinh bắt đầu làm bài.
            </div>
          </div>
        )}
      </div>

      {/* Current Admin Account Card */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs">
        <h2 className="font-bold text-slate-900 text-base mb-4 flex items-center gap-2">
          <User className="w-4 h-4 text-[#6B0000]" />
          <span>Thông tin tài khoản Quản trị</span>
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs text-slate-600">
          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200">
            <div className="text-slate-400 font-medium">Họ và tên</div>
            <div className="font-bold text-slate-800 text-sm mt-0.5">{currentUser?.name}</div>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200">
            <div className="text-slate-400 font-medium">Tên đăng nhập</div>
            <div className="font-bold text-slate-800 text-sm font-mono mt-0.5">
              @{currentUser?.username}
            </div>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200">
            <div className="text-slate-400 font-medium">Cấp bậc phân quyền</div>
            <div className="font-bold text-slate-800 text-sm mt-0.5">
              {isRoot ? 'Admin Tổng (Super Admin - Root)' : 'Admin Phụ / Giáo viên bộ môn'}
            </div>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200">
            <div className="text-slate-400 font-medium">Đơn vị công tác</div>
            <div className="font-bold text-slate-800 text-sm mt-0.5">
              {currentUser?.school || 'Sở GD&ĐT / THPT'}
            </div>
          </div>
        </div>
      </div>

      {/* Danger Zone: Reset Data */}
      <div className="bg-white rounded-2xl border border-red-200 p-6 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="font-bold text-red-700 text-base flex items-center gap-2">
              <RotateCcw className="w-4 h-4" />
              <span>Khôi phục Dữ liệu Mẫu Ban đầu</span>
            </h2>
            <p className="text-xs text-slate-500 mt-1 max-w-lg">
              Thiết lập lại danh sách đề thi, ngân hàng câu hỏi và các tài khoản mẫu về trạng thái chuẩn gốc của hệ thống.
            </p>
          </div>

          <button
            onClick={() => setResetConfirm(true)}
            className="py-2 px-4 bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 text-xs font-semibold rounded-xl transition-colors cursor-pointer self-start sm:self-auto"
          >
            Khôi phục mặc định
          </button>
        </div>
      </div>

      {/* Reset Confirmation Modal */}
      {resetConfirm && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl">
            <div className="w-12 h-12 rounded-full bg-red-50 text-red-600 flex items-center justify-center mx-auto mb-3">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <h3 className="text-base font-bold text-center text-slate-900 mb-1">
              Khôi phục dữ liệu mẫu?
            </h3>
            <p className="text-xs text-slate-500 text-center mb-5">
              Toàn bộ bài thi mới tạo và lịch sử làm bài sẽ được đặt lại về bộ dữ liệu khởi tạo ban đầu.
            </p>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setResetConfirm(false)}
                className="flex-1 py-2 px-3 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Hủy
              </button>
              <button
                onClick={handleResetDefaults}
                className="flex-1 py-2 px-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-xs font-semibold cursor-pointer"
              >
                Xác nhận khôi phục
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
