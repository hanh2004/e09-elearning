import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { storage } from '../../services/storageService';
import { UserProfile, UserRole } from '../../types';
import { AdminUserImportModal } from './AdminUserImportModal';
import {
  Users,
  Search,
  Plus,
  Upload,
  UserCheck,
  Shield,
  Trash2,
  Edit2,
  Key,
  School,
  Phone,
  AlertTriangle,
  UserPlus,
} from 'lucide-react';

export const AdminAccountScreen: React.FC = () => {
  const { currentUser, isRoot, canDeleteUser, canEditUser } = useAuth();
  const users = storage.getUsers();

  const [filterRole, setFilterRole] = useState<'all' | 'user' | 'admin'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [showImportModal, setShowImportModal] = useState(false);

  // Add/Edit User Modal
  const [showUserModal, setShowUserModal] = useState(false);
  const [editingUser, setEditingUser] = useState<UserProfile | null>(null);

  // Form State
  const [username, setUsername] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [school, setSchool] = useState('');
  const [className, setClassName] = useState('');
  const [assignedRole, setAssignedRole] = useState<UserRole>('user');
  const [formError, setFormError] = useState<string | null>(null);

  // Propose Admin Modal (Super Admin proposal flow)
  const [showProposeModal, setShowProposeModal] = useState(false);
  const [proposeUsername, setProposeUsername] = useState('');
  const [proposeName, setProposeName] = useState('');
  const [proposeSuccessMsg, setProposeSuccessMsg] = useState<string | null>(null);

  // Delete Confirm
  const [deleteTarget, setDeleteTarget] = useState<UserProfile | null>(null);

  const openCreateStudent = () => {
    setEditingUser(null);
    setUsername('');
    setName('');
    setPassword('123456');
    setPhoneNumber('');
    setSchool('THPT Chuyên Lê Hồng Phong');
    setClassName('12A1');
    setAssignedRole('user');
    setFormError(null);
    setShowUserModal(true);
  };

  const openEditModal = (u: UserProfile) => {
    setEditingUser(u);
    setUsername(u.username);
    setName(u.name);
    setPassword('');
    setPhoneNumber(u.phoneNumber || '');
    setSchool(u.school || '');
    setClassName(u.className || '');
    setAssignedRole(u.role);
    setFormError(null);
    setShowUserModal(true);
  };

  const handleSaveUser = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const cleanUsername = username.trim().toLowerCase();
    const cleanName = name.trim();

    if (!cleanUsername || !cleanName) {
      setFormError('Vui lòng nhập đầy đủ tên đăng nhập và họ tên!');
      return;
    }

    // Check duplicate username if creating
    if (!editingUser) {
      const exists = storage.getUserByUsername(cleanUsername);
      if (exists) {
        setFormError('Tên đăng nhập này đã tồn tại trong hệ thống!');
        return;
      }
    }

    const userData: UserProfile = {
      id: editingUser ? editingUser.id : `user_${Date.now()}`,
      username: cleanUsername,
      name: cleanName,
      role: assignedRole,
      status: 'active',
      createdBy: editingUser ? editingUser.createdBy : currentUser?.id,
      phoneNumber: phoneNumber.trim(),
      school: school.trim(),
      className: className.trim(),
      createdAt: editingUser ? editingUser.createdAt : new Date().toISOString(),
    };

    storage.saveUser(userData);
    setShowUserModal(false);
  };

  const handleProposeAdmin = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) return;

    // Check if target username already exists
    const exists = storage.getUserByUsername(proposeUsername.trim().toLowerCase());
    if (exists) {
      setFormError('Tên đăng nhập này đã tồn tại!');
      return;
    }

    storage.saveRequest({
      id: `req_${Date.now()}`,
      username: proposeUsername.trim().toLowerCase(),
      name: proposeName.trim(),
      status: 'pending',
      createdBy: currentUser.id,
      createdByName: currentUser.name,
      createdAt: new Date().toISOString(),
    });

    setProposeSuccessMsg('Đã gửi đề xuất bổ nhiệm Admin phụ! Chờ Admin Tổng còn lại phê duyệt.');
    setTimeout(() => {
      setShowProposeModal(false);
      setProposeUsername('');
      setProposeName('');
      setProposeSuccessMsg(null);
    }, 2000);
  };

  const handleDeleteUser = () => {
    if (deleteTarget) {
      storage.deleteUser(deleteTarget.id);
      setDeleteTarget(null);
    }
  };

  // Filter users
  const filteredUsers = users.filter((u) => {
    if (filterRole === 'user' && u.role !== 'user') return false;
    if (filterRole === 'admin' && u.role === 'user') return false;

    const match =
      u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (u.className && u.className.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (u.school && u.school.toLowerCase().includes(searchQuery.toLowerCase()));

    return match;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Quản lý Tài khoản</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            Quản lý danh sách học viên, phân quyền Admin và nhập dữ liệu từ Excel/CSV
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {isRoot && (
            <button
              onClick={() => setShowProposeModal(true)}
              className="py-2 px-3.5 bg-slate-800 hover:bg-slate-900 text-white text-xs font-semibold rounded-xl flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
            >
              <UserCheck className="w-4 h-4 text-amber-400" />
              <span>Đề xuất Admin phụ</span>
            </button>
          )}

          <button
            onClick={() => setShowImportModal(true)}
            className="py-2 px-3.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold rounded-xl flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
          >
            <Upload className="w-4 h-4" />
            <span>Nhập Excel / CSV</span>
          </button>

          <button
            onClick={openCreateStudent}
            className="py-2 px-4 bg-[#6B0000] hover:bg-[#520000] text-white text-xs font-semibold rounded-xl flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Thêm học viên</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm theo tên, username, lớp..."
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] shadow-xs"
          />
        </div>

        {/* Role Tabs */}
        <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-slate-200 shadow-xs self-start sm:self-auto">
          <button
            onClick={() => setFilterRole('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
              filterRole === 'all' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Tất cả ({users.length})
          </button>
          <button
            onClick={() => setFilterRole('user')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
              filterRole === 'user' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Học viên ({users.filter((u) => u.role === 'user').length})
          </button>
          <button
            onClick={() => setFilterRole('admin')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
              filterRole === 'admin' ? 'bg-[#6B0000] text-white' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Quản trị viên ({users.filter((u) => u.role !== 'user').length})
          </button>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-500 font-semibold border-b border-slate-200 text-xs uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Tài khoản & Họ tên</th>
                <th className="py-3 px-4">Vai trò</th>
                <th className="py-3 px-4">Lớp / Trường</th>
                <th className="py-3 px-4">Số điện thoại</th>
                <th className="py-3 px-4">Người tạo</th>
                <th className="py-3 px-4 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredUsers.map((u) => {
                const canDel = canDeleteUser(u);
                const canEdit = canEditUser(u);
                const creator = u.createdBy ? storage.getUserById(u.createdBy) : null;

                return (
                  <tr key={u.id} className="hover:bg-slate-50/60 transition-colors">
                    {/* User Identity */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div
                          className={`w-9 h-9 rounded-xl flex items-center justify-center font-bold text-xs shrink-0 ${
                            u.role === 'super_admin'
                              ? 'bg-purple-100 text-purple-800'
                              : u.role === 'admin'
                              ? 'bg-blue-100 text-blue-800'
                              : 'bg-emerald-100 text-emerald-800'
                          }`}
                        >
                          {u.name[0].toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-slate-900 leading-tight">{u.name}</div>
                          <div className="text-xs text-slate-500 font-mono mt-0.5">@{u.username}</div>
                        </div>
                      </div>
                    </td>

                    {/* Role Badge */}
                    <td className="py-3.5 px-4">
                      <span
                        className={`text-[11px] font-bold px-2.5 py-1 rounded-md inline-flex items-center gap-1 ${
                          u.role === 'super_admin'
                            ? 'bg-purple-50 text-purple-700 border border-purple-200'
                            : u.role === 'admin'
                            ? 'bg-blue-50 text-blue-700 border border-blue-200'
                            : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                        }`}
                      >
                        <Shield className="w-3 h-3" />
                        <span>
                          {u.role === 'super_admin'
                            ? 'Admin Tổng'
                            : u.role === 'admin'
                            ? 'Admin Phụ / GV'
                            : 'Học viên'}
                        </span>
                      </span>
                    </td>

                    {/* Class & School */}
                    <td className="py-3.5 px-4 text-xs text-slate-600">
                      <div className="font-medium text-slate-800">{u.className || '-'}</div>
                      <div className="text-slate-500 truncate max-w-[160px]">{u.school || '-'}</div>
                    </td>

                    {/* Phone */}
                    <td className="py-3.5 px-4 text-xs text-slate-600 font-mono">
                      {u.phoneNumber || '-'}
                    </td>

                    {/* Created By */}
                    <td className="py-3.5 px-4 text-xs text-slate-500">
                      {creator ? (
                        <span title={`UID: ${creator.id}`}>{creator.name}</span>
                      ) : (
                        <span className="text-slate-400 italic">Hệ thống gốc</span>
                      )}
                    </td>

                    {/* Actions */}
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-1">
                        {canEdit && (
                          <button
                            onClick={() => openEditModal(u)}
                            className="p-1.5 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
                            title="Sửa thông tin"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                        )}

                        {canDel && (
                          <button
                            onClick={() => setDeleteTarget(u)}
                            className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
                            title="Xóa tài khoản"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal: Create or Edit User */}
      {showUserModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl">
            <h2 className="text-lg font-bold text-slate-900 mb-4">
              {editingUser ? 'Chỉnh sửa tài khoản' : 'Thêm tài khoản mới'}
            </h2>

            {formError && (
              <div className="mb-4 p-3 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs">
                {formError}
              </div>
            )}

            <form onSubmit={handleSaveUser} className="space-y-3.5">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Tên đăng nhập (Username) *
                </label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  disabled={Boolean(editingUser)}
                  placeholder="Ví dụ: nguyenvana"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000] disabled:opacity-60"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Họ và tên *
                </label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Ví dụ: Nguyễn Văn An"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  required
                />
              </div>

              {!editingUser && (
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Mật khẩu khởi tạo
                  </label>
                  <input
                    type="text"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Mặc định: 123456"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  />
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Lớp
                  </label>
                  <input
                    type="text"
                    value={className}
                    onChange={(e) => setClassName(e.target.value)}
                    placeholder="12A1"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Số điện thoại
                  </label>
                  <input
                    type="tel"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    placeholder="09xx xxx xxx"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                  Trường học
                </label>
                <input
                  type="text"
                  value={school}
                  onChange={(e) => setSchool(e.target.value)}
                  placeholder="THPT Chuyên..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                />
              </div>

              {isRoot && (
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Vai trò tài khoản
                  </label>
                  <select
                    value={assignedRole}
                    onChange={(e) => setAssignedRole(e.target.value as UserRole)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                  >
                    <option value="user">Học viên</option>
                    <option value="admin">Admin Phụ / Giáo viên</option>
                  </select>
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowUserModal(false)}
                  className="py-2 px-4 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  className="py-2 px-5 bg-[#6B0000] hover:bg-[#520000] text-white rounded-xl text-xs font-bold cursor-pointer"
                >
                  {editingUser ? 'Cập nhật' : 'Tạo tài khoản'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Propose Sub-Admin (Super Admin workflow) */}
      {showProposeModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl">
            <div className="flex items-center gap-2.5 mb-3">
              <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center">
                <UserCheck className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-base font-bold text-slate-900">Đề xuất Bổ nhiệm Admin Phụ</h2>
                <p className="text-xs text-slate-500">Quy trình xác thực 2-Root Admin</p>
              </div>
            </div>

            <p className="text-xs text-slate-600 mb-4 bg-slate-50 p-3 rounded-xl border border-slate-200">
              Theo quy định bảo mật hệ thống E-09, yêu cầu bổ nhiệm Admin phụ mới sẽ được gửi tới Admin Tổng đối tác để phê duyệt trước khi tài khoản có hiệu lực.
            </p>

            {proposeSuccessMsg ? (
              <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-semibold text-center">
                {proposeSuccessMsg}
              </div>
            ) : (
              <form onSubmit={handleProposeAdmin} className="space-y-3.5">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Tên đăng nhập (Username) *
                  </label>
                  <input
                    type="text"
                    value={proposeUsername}
                    onChange={(e) => setProposeUsername(e.target.value)}
                    placeholder="Ví dụ: gv_hoa"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                    required
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1">
                    Họ và tên Giáo viên / Cán bộ *
                  </label>
                  <input
                    type="text"
                    value={proposeName}
                    onChange={(e) => setProposeName(e.target.value)}
                    placeholder="Ví dụ: Cô Lê Thị Hoa (GV Hóa học)"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
                    required
                  />
                </div>

                <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowProposeModal(false)}
                    className="py-2 px-4 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
                  >
                    Hủy
                  </button>
                  <button
                    type="submit"
                    className="py-2 px-5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl text-xs font-bold cursor-pointer"
                  >
                    Gửi đề xuất
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* Delete User Modal */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl">
            <div className="w-12 h-12 rounded-full bg-red-50 text-red-600 flex items-center justify-center mx-auto mb-3">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <h3 className="text-base font-bold text-center text-slate-900 mb-1">
              Xóa tài khoản @{deleteTarget.username}?
            </h3>
            <p className="text-xs text-slate-500 text-center mb-5">
              Họ tên: <strong>{deleteTarget.name}</strong>. Hành động này sẽ vô hiệu hóa tài khoản và toàn bộ lịch sử thi cử liên quan.
            </p>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setDeleteTarget(null)}
                className="flex-1 py-2 px-3 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
              >
                Hủy
              </button>
              <button
                onClick={handleDeleteUser}
                className="flex-1 py-2 px-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-xs font-semibold cursor-pointer"
              >
                Xác nhận xóa
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Batch Import CSV Modal */}
      {showImportModal && currentUser && (
        <AdminUserImportModal
          currentUserId={currentUser.id}
          onClose={() => setShowImportModal(false)}
          onSuccess={() => setShowImportModal(false)}
        />
      )}
    </div>
  );
};
