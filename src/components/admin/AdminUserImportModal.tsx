import React, { useState } from 'react';
import { UserProfile } from '../../types';
import { storage } from '../../services/storageService';
import { Upload, Download, CheckCircle, AlertTriangle, FileText, X } from 'lucide-react';

interface AdminUserImportModalProps {
  currentUserId: string;
  onClose: () => void;
  onSuccess: () => void;
}

interface ParsedUserRow {
  username: string;
  name: string;
  className?: string;
  school?: string;
  phoneNumber?: string;
  status: 'valid' | 'duplicate' | 'invalid';
  error?: string;
}

export const AdminUserImportModal: React.FC<AdminUserImportModalProps> = ({
  currentUserId,
  onClose,
  onSuccess,
}) => {
  const [rows, setRows] = useState<ParsedUserRow[]>([]);
  const [rawText, setRawText] = useState('');
  const [isImporting, setIsImporting] = useState(false);

  // Sample CSV template generator
  const downloadTemplate = () => {
    const csvContent =
      'username,name,className,school,phoneNumber\n' +
      'nguyenvana,Nguyễn Văn An,12A1,THPT Chuyên Lê Hồng Phong,0912345678\n' +
      'tranthib,Trần Thị Bình,12A2,THPT Chuyên Lê Hồng Phong,0923456789\n' +
      'lehoangc,Lê Hoàng Cường,12A1,THPT Chu Văn An,0934567890';

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'mau_danh_sach_hoc_vien.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleParse = (text: string) => {
    setRawText(text);
    const lines = text.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
    const existingUsers = storage.getUsers();
    const existingUsernames = new Set(existingUsers.map((u) => u.username.toLowerCase()));

    const parsed: ParsedUserRow[] = [];

    // Check if line 0 is a header
    const startIndex = lines[0] && lines[0].toLowerCase().includes('username') ? 1 : 0;

    for (let i = startIndex; i < lines.length; i++) {
      const parts = lines[i].split(',').map((p) => p.trim());
      const username = parts[0] || '';
      const name = parts[1] || '';
      const className = parts[2] || '';
      const school = parts[3] || '';
      const phoneNumber = parts[4] || '';

      if (!username || !name) {
        parsed.push({
          username,
          name,
          status: 'invalid',
          error: 'Thiếu tên đăng nhập hoặc họ tên',
        });
      } else if (existingUsernames.has(username.toLowerCase())) {
        parsed.push({
          username,
          name,
          className,
          school,
          phoneNumber,
          status: 'duplicate',
          error: 'Tên đăng nhập đã tồn tại trong hệ thống',
        });
      } else {
        parsed.push({
          username,
          name,
          className,
          school,
          phoneNumber,
          status: 'valid',
        });
      }
    }

    setRows(parsed);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (evt) => {
        const text = evt.target?.result as string;
        handleParse(text);
      };
      reader.readAsText(file);
    }
  };

  const validCount = rows.filter((r) => r.status === 'valid').length;

  const handleExecuteImport = () => {
    setIsImporting(true);
    const validRows = rows.filter((r) => r.status === 'valid');

    validRows.forEach((r) => {
      const newUser: UserProfile = {
        id: `user_imported_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        username: r.username.toLowerCase().trim(),
        name: r.name.trim(),
        role: 'user',
        status: 'active',
        createdBy: currentUserId,
        className: r.className || '12A',
        school: r.school || 'THPT',
        phoneNumber: r.phoneNumber || '',
        createdAt: new Date().toISOString(),
      };
      storage.saveUser(newUser);
    });

    setIsImporting(false);
    onSuccess();
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl max-h-[90vh] flex flex-col">
        {/* Modal Header */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-100">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
              <Upload className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-slate-900">Nhập danh sách học viên từ file</h2>
              <p className="text-xs text-slate-500">Hỗ trợ file CSV hoặc nhập bảng dữ liệu mẫu</p>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto py-4 space-y-4">
          {/* Instructions and Download Template */}
          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
            <div>
              <span className="font-bold text-slate-800 block">Định dạng cột chuẩn CSV:</span>
              <span className="text-slate-500 font-mono">username, name, className, school, phoneNumber</span>
            </div>
            <button
              onClick={downloadTemplate}
              className="py-1.5 px-3 bg-white border border-slate-300 hover:bg-slate-100 text-slate-700 font-semibold rounded-lg flex items-center gap-1.5 transition-colors cursor-pointer shrink-0"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Tải file mẫu (.csv)</span>
            </button>
          </div>

          {/* Upload Input & Paste Area */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
              Chọn file CSV từ máy tính:
            </label>
            <input
              type="file"
              accept=".csv, .txt"
              onChange={handleFileUpload}
              className="w-full text-xs text-slate-600 file:mr-3 file:py-2 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-semibold file:bg-[#6B0000] file:text-white hover:file:bg-[#520000] cursor-pointer"
            />
          </div>

          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-600 mb-1.5">
              Hoặc dán trực tiếp nội dung dữ liệu CSV vào đây:
            </label>
            <textarea
              rows={4}
              value={rawText}
              onChange={(e) => handleParse(e.target.value)}
              placeholder="nguyenvana,Nguyễn Văn An,12A1,THPT Chuyên,0912345678&#10;tranthib,Trần Thị Bình,12A2,THPT Chuyên,0923456789"
              className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-[#6B0000]"
            />
          </div>

          {/* Parsed Preview Table */}
          {rows.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-slate-800">
                  Xem trước dữ liệu ({validCount}/{rows.length} hợp lệ)
                </span>
              </div>
              <div className="border border-slate-200 rounded-xl overflow-hidden max-h-48 overflow-y-auto text-xs">
                <table className="w-full text-left">
                  <thead className="bg-slate-100 text-slate-600 sticky top-0 font-bold border-b border-slate-200">
                    <tr>
                      <th className="py-2 px-3">Tên đăng nhập</th>
                      <th className="py-2 px-3">Họ và tên</th>
                      <th className="py-2 px-3">Lớp</th>
                      <th className="py-2 px-3">Trạng thái</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {rows.map((r, i) => (
                      <tr key={i} className={r.status !== 'valid' ? 'bg-red-50/40' : ''}>
                        <td className="py-1.5 px-3 font-mono">{r.username || '(trống)'}</td>
                        <td className="py-1.5 px-3">{r.name || '(trống)'}</td>
                        <td className="py-1.5 px-3">{r.className || '-'}</td>
                        <td className="py-1.5 px-3">
                          {r.status === 'valid' ? (
                            <span className="text-emerald-700 font-semibold flex items-center gap-1">
                              <CheckCircle className="w-3 h-3" /> Hợp lệ
                            </span>
                          ) : (
                            <span className="text-red-600 flex items-center gap-1 font-medium">
                              <AlertTriangle className="w-3 h-3" /> {r.error}
                            </span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="flex items-center justify-between pt-4 border-t border-slate-100">
          <button
            onClick={onClose}
            className="py-2 px-4 bg-slate-100 text-slate-700 rounded-xl text-xs font-semibold cursor-pointer"
          >
            Đóng
          </button>
          <button
            onClick={handleExecuteImport}
            disabled={validCount === 0 || isImporting}
            className="py-2 px-5 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-xs transition-colors cursor-pointer"
          >
            <Upload className="w-3.5 h-3.5" />
            <span>Thêm {validCount} học viên vào hệ thống</span>
          </button>
        </div>
      </div>
    </div>
  );
};
