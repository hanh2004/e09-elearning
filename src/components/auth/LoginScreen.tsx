import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { GraduationCap, Lock, User, Eye, EyeOff, AlertTriangle, ShieldCheck, ArrowRight } from 'lucide-react';

export const LoginScreen: React.FC = () => {
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const systemStatus = storage.getStatus();

  const handleLogin = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setErrorMessage(null);
    setLoading(true);

    try {
      const result = await login(username, password);
      if (!result.success) {
        setErrorMessage(result.error || 'Đăng nhập thất bại.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Lỗi kết nối máy chủ.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickLogin = (user: string, pass: string) => {
    setUsername(user);
    setPassword(pass);
    setErrorMessage(null);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-100 via-stone-100 to-rose-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-[#6B0000] text-white shadow-xl shadow-red-950/20 mb-4 ring-4 ring-red-100">
            <GraduationCap className="w-9 h-9" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
            Hệ Thống Thi & Kiểm Tra E-09
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Nền tảng kiểm tra trực tuyến và quản lý học tập tích hợp
          </p>
        </div>

        {/* Maintenance Banner */}
        {systemStatus.maintenance && (
          <div className="mb-4 bg-amber-50 border border-amber-200 rounded-xl p-3.5 flex items-start gap-3 text-amber-900 text-xs sm:text-sm">
            <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div>
              <span className="font-semibold block">Hệ thống đang bảo trì cập nhật:</span>
              Cổng học viên tạm khóa đăng nhập. Tài khoản Quản trị viên (Admin) vẫn có thể đăng nhập bình thường để chuẩn bị dữ liệu.
            </div>
          </div>
        )}

        {/* Login Card */}
        <div className="bg-white rounded-2xl shadow-xl shadow-slate-200/60 border border-slate-200/80 p-6 sm:p-8">
          <h2 className="text-lg font-semibold text-slate-800 mb-5">Đăng nhập tài khoản</h2>

          {errorMessage && (
            <div className="mb-5 p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 text-sm flex items-start gap-2.5">
              <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
              <span>{errorMessage}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5">
                Tên đăng nhập
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <User className="w-4 h-4" />
                </div>
                <input
                  id="username-input"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Ví dụ: admintong1 hoặc hocsinh1"
                  className="w-full pl-10 pr-3.5 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] focus:border-transparent transition-all"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5">
                Mật khẩu
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  id="password-input"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Nhập mật khẩu"
                  className="w-full pl-10 pr-10 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] focus:border-transparent transition-all"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-600"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full mt-2 py-3 px-4 bg-[#6B0000] hover:bg-[#520000] text-white font-medium rounded-xl text-sm shadow-md shadow-red-950/20 flex items-center justify-center gap-2 transition-all disabled:opacity-70 cursor-pointer"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>Đăng nhập hệ thống</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Test Accounts Pill Selector */}
          <div className="mt-7 pt-5 border-t border-slate-100">
            <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-3 font-medium">
              <ShieldCheck className="w-3.5 h-3.5 text-[#6B0000]" />
              <span>Tài khoản thử nghiệm nhanh (Mật khẩu: 123456):</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => handleQuickLogin('admintong1', '123456')}
                className="text-left px-2.5 py-2 rounded-lg border border-slate-200 bg-slate-50 hover:bg-red-50 hover:border-red-200 transition-colors cursor-pointer"
              >
                <div className="text-[11px] font-bold text-[#6B0000]">Admin Tổng</div>
                <div className="text-[11px] text-slate-600 truncate">admintong1</div>
              </button>

              <button
                type="button"
                onClick={() => handleQuickLogin('gv_toan', '123456')}
                className="text-left px-2.5 py-2 rounded-lg border border-slate-200 bg-slate-50 hover:bg-red-50 hover:border-red-200 transition-colors cursor-pointer"
              >
                <div className="text-[11px] font-bold text-slate-800">Admin Phụ / GV</div>
                <div className="text-[11px] text-slate-600 truncate">gv_toan</div>
              </button>

              <button
                type="button"
                onClick={() => handleQuickLogin('hocsinh1', '123456')}
                className="text-left px-2.5 py-2 rounded-lg border border-slate-200 bg-slate-50 hover:bg-red-50 hover:border-red-200 transition-colors cursor-pointer"
              >
                <div className="text-[11px] font-bold text-emerald-800">Học viên</div>
                <div className="text-[11px] text-slate-600 truncate">hocsinh1</div>
              </button>
            </div>
          </div>
        </div>

        {/* Footer info */}
        <p className="text-center text-xs text-slate-400 mt-6">
          E-09 E-Learning Platform • Phiên bản Web React chuẩn hóa từ Flutter
        </p>
      </div>
    </div>
  );
};
