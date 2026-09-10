import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { UserTab } from '../../types';
import { GraduationCap, LayoutDashboard, History, User, LogOut, ArrowLeftRight, Shield } from 'lucide-react';

interface UserNavbarProps {
  currentTab: UserTab;
  onSelectTab: (tab: UserTab) => void;
}

export const UserNavbar: React.FC<UserNavbarProps> = ({ currentTab, onSelectTab }) => {
  const { currentUser, logout, isAdmin, setActivePortal } = useAuth();

  return (
    <header className="sticky top-0 z-40 bg-white border-b border-slate-200/80 shadow-xs">
      {/* Admin preview notice if an Admin is browsing Student Portal */}
      {isAdmin && (
        <div className="bg-[#6B0000] text-white px-4 py-1.5 text-xs flex items-center justify-between">
          <div className="flex items-center gap-2 font-medium">
            <Shield className="w-3.5 h-3.5" />
            <span>Bạn đang xem giao diện với quyền của Học viên ({currentUser?.role})</span>
          </div>
          <button
            onClick={() => setActivePortal('admin')}
            className="flex items-center gap-1 font-semibold underline hover:text-red-200 transition-colors cursor-pointer"
          >
            <ArrowLeftRight className="w-3 h-3" />
            <span>Về Cổng Quản trị (Admin Portal)</span>
          </button>
        </div>
      )}

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo & Portal Title */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#6B0000] text-white flex items-center justify-center shadow-md shadow-red-950/15">
              <GraduationCap className="w-6 h-6" />
            </div>
            <div>
              <div className="font-bold text-slate-900 text-base sm:text-lg leading-tight flex items-center gap-2">
                <span>E-09 E-Learning</span>
                <span className="text-[10px] font-semibold uppercase px-2 py-0.5 rounded-full bg-red-100 text-[#6B0000]">
                  Học viên
                </span>
              </div>
              <div className="text-xs text-slate-500 hidden sm:block">
                Cổng kiểm tra & ôn luyện trực tuyến
              </div>
            </div>
          </div>

          {/* Desktop Navigation Tabs */}
          <nav className="hidden md:flex items-center gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200/60">
            <button
              onClick={() => onSelectTab('home')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition-all cursor-pointer ${
                currentTab === 'home'
                  ? 'bg-white text-[#6B0000] shadow-xs font-semibold'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <LayoutDashboard className="w-4 h-4" />
              <span>Đề thi & Kiểm tra</span>
            </button>

            <button
              onClick={() => onSelectTab('history')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition-all cursor-pointer ${
                currentTab === 'history'
                  ? 'bg-white text-[#6B0000] shadow-xs font-semibold'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <History className="w-4 h-4" />
              <span>Lịch sử bài làm</span>
            </button>

            <button
              onClick={() => onSelectTab('profile')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition-all cursor-pointer ${
                currentTab === 'profile'
                  ? 'bg-white text-[#6B0000] shadow-xs font-semibold'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <User className="w-4 h-4" />
              <span>Hồ sơ</span>
            </button>
          </nav>

          {/* User Profile & Actions */}
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2.5 pl-2">
              <div className="w-9 h-9 rounded-full bg-slate-200 flex items-center justify-center text-slate-700 font-bold text-sm ring-2 ring-[#6B0000]/20">
                {currentUser?.name ? currentUser.name[0].toUpperCase() : 'U'}
              </div>
              <div className="hidden sm:block text-left">
                <div className="text-xs font-bold text-slate-800 leading-tight truncate max-w-[140px]">
                  {currentUser?.name || currentUser?.username}
                </div>
                <div className="text-[11px] text-slate-500">
                  {currentUser?.className ? `Lớp ${currentUser.className}` : 'Học viên'}
                </div>
              </div>
            </div>

            <button
              onClick={() => logout()}
              title="Đăng xuất"
              className="p-2 text-slate-500 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Mobile Sub-Navigation */}
        <div className="md:hidden flex items-center justify-around py-2 border-t border-slate-100 text-xs font-medium">
          <button
            onClick={() => onSelectTab('home')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-lg ${
              currentTab === 'home' ? 'text-[#6B0000] font-bold' : 'text-slate-600'
            }`}
          >
            <LayoutDashboard className="w-4 h-4" />
            <span>Đề thi</span>
          </button>
          <button
            onClick={() => onSelectTab('history')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-lg ${
              currentTab === 'history' ? 'text-[#6B0000] font-bold' : 'text-slate-600'
            }`}
          >
            <History className="w-4 h-4" />
            <span>Lịch sử</span>
          </button>
          <button
            onClick={() => onSelectTab('profile')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-lg ${
              currentTab === 'profile' ? 'text-[#6B0000] font-bold' : 'text-slate-600'
            }`}
          >
            <User className="w-4 h-4" />
            <span>Hồ sơ</span>
          </button>
        </div>
      </div>
    </header>
  );
};
