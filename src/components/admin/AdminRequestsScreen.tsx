import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { AdminRequest } from '../../types';
import { UserCheck, CheckCircle2, XCircle, Clock, Shield, AlertTriangle } from 'lucide-react';

export const AdminRequestsScreen: React.FC = () => {
  const { currentUser, isRoot } = useAuth();
  const requests = storage.getRequests();
  const [filter, setFilter] = useState<'all' | 'pending' | 'decided'>('pending');
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  const handleDecide = (reqId: string, approve: boolean) => {
    if (!currentUser) return;
    storage.decideAdminRequest(reqId, approve, currentUser.id);
    setActionSuccess(
      approve
        ? 'Đã phê duyệt và kích hoạt tài khoản Admin phụ thành công!'
        : 'Đã từ chối yêu cầu bổ nhiệm.'
    );
    setTimeout(() => setActionSuccess(null), 3000);
  };

  const filteredRequests = requests.filter((r) => {
    if (filter === 'pending') return r.status === 'pending';
    if (filter === 'decided') return r.status !== 'pending';
    return true;
  });

  if (!isRoot) {
    return (
      <div className="p-8 text-center bg-white rounded-2xl border border-slate-200">
        <AlertTriangle className="w-8 h-8 text-amber-500 mx-auto mb-2" />
        <h2 className="text-base font-bold text-slate-800">Không có quyền truy cập</h2>
        <p className="text-xs text-slate-500 mt-1">Chỉ Admin Tổng (Root) mới có quyền phê duyệt Admin phụ.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2.5">
          <UserCheck className="w-6 h-6 text-[#6B0000]" />
          <span>Duyệt Yêu Cầu Bổ Nhiệm Admin Phụ</span>
        </h1>
        <p className="text-sm text-slate-500 mt-1">
          Cơ chế xác thực chéo giữa hai Root Admin nhằm bảo đảm an toàn hệ thống phân quyền E-09
        </p>
      </div>

      {actionSuccess && (
        <div className="p-3.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs sm:text-sm flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{actionSuccess}</span>
        </div>
      )}

      {/* Filter Tabs */}
      <div className="flex items-center gap-2 bg-white p-1 rounded-xl border border-slate-200 w-fit">
        <button
          onClick={() => setFilter('pending')}
          className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
            filter === 'pending' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          Chờ duyệt ({requests.filter((r) => r.status === 'pending').length})
        </button>
        <button
          onClick={() => setFilter('decided')}
          className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
            filter === 'decided' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          Đã xử lý ({requests.filter((r) => r.status !== 'pending').length})
        </button>
        <button
          onClick={() => setFilter('all')}
          className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
            filter === 'all' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          Tất cả ({requests.length})
        </button>
      </div>

      {/* Requests List */}
      {filteredRequests.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center">
          <CheckCircle2 className="w-10 h-10 text-emerald-500 mx-auto mb-2" />
          <h3 className="text-base font-bold text-slate-800">Không có yêu cầu nào</h3>
          <p className="text-xs text-slate-500 mt-1">Tất cả các đề xuất phân quyền đã được giải quyết xong.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredRequests.map((req) => {
            const isPending = req.status === 'pending';
            const dateStr = new Date(req.createdAt).toLocaleDateString('vi-VN', {
              hour: '2-digit',
              minute: '2-digit',
              day: '2-digit',
              month: '2-digit',
              year: 'numeric',
            });

            return (
              <div
                key={req.id}
                className="bg-white rounded-2xl border border-slate-200 p-5 sm:p-6 shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
              >
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2.5">
                    <h3 className="font-bold text-slate-900 text-base">{req.name}</h3>
                    <span className="font-mono text-xs text-slate-500 bg-slate-100 px-2 py-0.5 rounded">
                      @{req.username}
                    </span>
                    <span
                      className={`text-[11px] font-bold px-2 py-0.5 rounded-md ${
                        req.status === 'pending'
                          ? 'bg-amber-100 text-amber-800'
                          : req.status === 'approved'
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {req.status === 'pending'
                        ? 'Chờ duyệt'
                        : req.status === 'approved'
                        ? 'Đã phê duyệt'
                        : 'Đã từ chối'}
                    </span>
                  </div>

                  <div className="text-xs text-slate-500 flex items-center gap-2">
                    <Clock className="w-3.5 h-3.5" />
                    <span>Thời gian gửi: {dateStr}</span>
                    <span>•</span>
                    <span>Người đề xuất: {req.createdByName || req.createdBy}</span>
                  </div>
                </div>

                {isPending ? (
                  <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
                    <button
                      onClick={() => handleDecide(req.id, false)}
                      className="py-2 px-3.5 bg-slate-100 hover:bg-red-50 hover:text-red-700 text-slate-700 rounded-xl text-xs font-semibold transition-colors cursor-pointer"
                    >
                      Từ chối
                    </button>
                    <button
                      onClick={() => handleDecide(req.id, true)}
                      className="py-2 px-4 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-xs transition-colors cursor-pointer"
                    >
                      Phê duyệt & Kích hoạt
                    </button>
                  </div>
                ) : (
                  <div className="text-xs font-semibold text-slate-400">
                    {req.status === 'approved' ? 'Tài khoản đã hoạt động' : 'Yêu cầu bị từ chối'}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
