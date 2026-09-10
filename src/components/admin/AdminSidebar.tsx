import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { AdminTab } from '../../types';
import {
  GraduationCap,
  LayoutDashboard,
  BookOpen,
  Users,
  UserCheck,
  TrendingUp,
  BarChart3,
  Settings,
  LogOut,
  ArrowLeftRight,
  Shield,
  Menu,
  X,
} from 'lucide-react';

interface AdminSidebarProps {
  currentTab: AdminTab;
  onSelectTab: (tab: AdminTab) => void;
  pendingRequestsCount?: number;
  mobileOpen: boolean;
  setMobileOpen: (open: boolean) => void;
}

export const AdminSidebar: React.FC<AdminSidebarProps> = ({
  currentTab,
  onSelectTab,
  pendingRequestsCount = 0,
  mobileOpen,
  setMobileOpen,
}) => {
  const { currentUser, isRoot, logout, setActivePortal } = useAuth();

  const navItems: { id: AdminTab; label: string; icon: React.FC<{ className?: string }>; badge?: number; superAdminOnly?: boolean }[] = [
    { id: 'dashboard', label: 'Bảng tổng quan', icon: LayoutDashboard },
    { id: 'exams', label: 'Quản lý Bài thi', icon: BookOpen },
    { id: 'accounts', label: 'Quản lý Tài khoản', icon: Users },
    {
      id: 'requests',
      label: 'Duyệt Admin phụ',
      icon: UserCheck,
      badge: pendingRequestsCount,
      superAdminOnly: true,
    },
    { id: 'progress', label: 'Theo dõi Tiến độ', icon: TrendingUp },
    { id: 'reports', label: 'Báo cáo & Xếp hạng', icon: BarChart3 },
    { id: 'settings', label: 'Cài đặt hệ thống', icon: Settings },
  ];

  return (
    <>
      {/* Mobile Backdrop */}
      {mobileOpen && (
        <div
          onClick={() => setMobileOpen(false)}
          className="fixed inset-0 z-40 bg-slate-900/50 backdrop-blur-xs lg:hidden"
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 w-72 bg-slate-900 text-slate-300 flex flex-col justify-between border-r border-slate-800 transition-transform duration-300 lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div>
          {/* Brand Header */}
          <div className="h-16 px-6 flex items-center justify-between border-b border-slate-800">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-[#6B0000] text-white flex items-center justify-center font-black shadow-md shadow-red-950/40">
                <GraduationCap className="w-5 h-5" />
              </div>
              <div>
                <div className="font-bold text-white text-base leading-none">E-09 Admin</div>
                <div className="text-[11px] text-slate-400 mt-1">Cổng Quản Trị Hệ Thống</div>
              </div>
            </div>

            <button
              onClick={() => setMobileOpen(false)}
              className="lg:hidden text-slate-400 hover:text-white p-1 rounded-lg"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Current Admin Identity Card */}
          <div className="p-4 mx-4 my-4 rounded-xl bg-slate-800/80 border border-slate-700/60">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-[#6B0000] text-white font-bold flex items-center justify-center text-sm ring-2 ring-red-900/40">
                {currentUser?.name ? currentUser.name[0].toUpperCase() : 'A'}
              </div>
              <div className="overflow-hidden">
                <div className="text-xs font-bold text-white truncate">{currentUser?.name}</div>
                <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                  <Shield className="w-3 h-3 text-red-400" />
                  <span>{isRoot ? 'Admin Tổng (Root)' : 'Admin Phụ / Giáo viên'}</span>
                </div>
              </div>
            </div>

            {/* Switch to Student Portal */}
            <button
              onClick={() => setActivePortal('user')}
              className="w-full mt-3 py-1.5 px-2.5 rounded-lg bg-slate-700/80 hover:bg-slate-700 text-[11px] font-semibold text-slate-200 hover:text-white flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
            >
              <ArrowLeftRight className="w-3 h-3 text-amber-400" />
              <span>Xem giao diện Học viên</span>
            </button>
          </div>

          {/* Navigation Links */}
          <nav className="px-3 space-y-1">
            {navItems.map((item) => {
              if (item.superAdminOnly && !isRoot) return null;
              const Icon = item.icon;
              const isActive = currentTab === item.id;

              return (
                <button
                  key={item.id}
                  onClick={() => {
                    onSelectTab(item.id);
                    setMobileOpen(false);
                  }}
                  className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-medium transition-colors cursor-pointer ${
                    isActive
                      ? 'bg-[#6B0000] text-white font-semibold shadow-xs'
                      : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <Icon className="w-4 h-4" />
                    <span>{item.label}</span>
                  </div>

                  {item.badge !== undefined && item.badge > 0 && (
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500 text-slate-950">
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>
        </div>

        {/* Footer actions */}
        <div className="p-4 border-t border-slate-800">
          <button
            onClick={() => logout()}
            className="w-full py-2 px-3 rounded-xl text-xs font-semibold text-slate-400 hover:text-red-400 hover:bg-red-950/30 flex items-center gap-2 transition-colors cursor-pointer"
          >
            <LogOut className="w-4 h-4" />
            <span>Đăng xuất tài khoản</span>
          </button>
        </div>
      </aside>
    </>
  );
};
