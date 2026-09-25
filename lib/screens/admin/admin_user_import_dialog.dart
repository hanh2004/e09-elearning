// WEB ADMIN: Hộp thoại đọc file Excel, xem trước và nhập học viên mới.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_import.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../services/tep/user_excel_import.dart';
import '../../services/tep/workbook_picker.dart';
import '../../services/tep/workbook_picker_error.dart';

/// Hộp thoại đọc file Excel, xem trước và nhập học viên mới.
class AdminUserImportDialog extends StatefulWidget {
  const AdminUserImportDialog({
    super.key,
    required this.service,
    this.pickWorkbook,
    this.decodeWorkbook,
  });

  final FirestoreService service;
  final Future<Uint8List?> Function()? pickWorkbook;
  final UserImportPreview Function(Uint8List)? decodeWorkbook;

  @override
  State<AdminUserImportDialog> createState() => _TrangThaiNhapHocVien();
}

class _TrangThaiNhapHocVien extends State<AdminUserImportDialog> {
  UserImportPreview? _xemTruoc;
  UserImportPreview? _xemTruocCucBo;
  bool _daKiemTraTonTai = false;
  bool _dangXuLy = false;
  String? _thongDiep;

  Future<void> _taiTepMau() async {
    setState(() {
      _dangXuLy = true;
      _thongDiep = null;
    });
    try {
      final duLieu = await rootBundle.load(UserExcelImport.templateAsset);
      await FilePicker.saveFile(
        dialogTitle: 'Lưu mẫu nhập học viên',
        fileName: 'users_import.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: duLieu.buffer.asUint8List(
          duLieu.offsetInBytes,
          duLieu.lengthInBytes,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _thongDiep = 'Không tải được file mẫu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _chonTep() async {
    setState(() {
      _dangXuLy = true;
      _xemTruoc = null;
      _xemTruocCucBo = null;
      _daKiemTraTonTai = false;
      _thongDiep = null;
    });
    var stage = 'pick';
    try {
      final duLieuByte = await (widget.pickWorkbook ?? pickWorkbookFile)();
      if (duLieuByte == null) return;
      stage = 'decode';
      final preview = (widget.decodeWorkbook ?? UserExcelImport().parse)(
        duLieuByte,
      );
      if (!mounted) return;
      setState(() {
        _xemTruocCucBo = preview;
        _xemTruoc = preview;
      });
      // Lỗi file phải hiện ngay trên màn hình, kể cả khi Firebase đang lỗi.
      if (preview.canImport) await _kiemTraTonTai();
    } catch (loi) {
      if (mounted) {
        setState(
          () => _thongDiep = loi is WorkbookPickerException
              ? loi.message
              : stage == 'decode'
              ? 'Không đọc được nội dung Excel. Chọn file .xlsx không mã hóa và đúng 3 cột.'
              : loi is MissingPluginException || loi is UnimplementedError
              ? 'Bộ chọn file chưa được khởi tạo. Dừng ứng dụng rồi chạy lại Flutter (không chỉ hot reload); trên web hãy tải lại trang.'
              : 'Không mở hoặc đọc được file từ máy (mã: ${loi.runtimeType}). Hãy gửi mã lỗi này để kiểm tra; trên web thử mở bằng Chrome hoặc Edge.',
        );
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _kiemTraTonTai() async {
    final local = _xemTruocCucBo;
    if (local == null || !local.canImport) return;
    try {
      final usernames = await widget.service
          .checkUsernames(local.rows.map((dong) => dong.username).toList())
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _xemTruoc = local.checkExisting(usernames);
        _daKiemTraTonTai = true;
        _thongDiep = null;
      });
    } catch (loi) {
      if (!mounted) return;
      String detail;
      if (loi is FirebaseException) {
        detail = switch (loi.code) {
          'permission-denied' => 'Firebase từ chối quyền đọc danh sách tài khoản (permission-denied).',
          'unauthenticated' =>
            'Firebase yêu cầu phiên xác thực hợp lệ (unauthenticated).',
          'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
            'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.',
          _ => 'Firebase chưa kiểm tra được danh sách tài khoản. Vui lòng thử lại.',
        };
      } else if (loi is TimeoutException) {
        detail = 'Firebase không phản hồi kịp. Kiểm tra mạng rồi thử lại.';
      } else {
        detail = 'Chưa kiểm tra được danh sách tài khoản trên Firebase. Vui lòng thử lại.';
      }
      setState(() {
        _daKiemTraTonTai = false;
        _thongDiep =
            'Đã đọc file Excel. $detail Chưa cho phép nhập khi chưa kiểm tra trùng tài khoản.';
      });
    }
  }

  Future<void> _thuKiemTraLai() async {
    if (_dangXuLy) return;
    setState(() => _dangXuLy = true);
    try {
      await _kiemTraTonTai();
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _nhapDuLieu() async {
    final preview = _xemTruoc;
    if (_dangXuLy ||
        !_daKiemTraTonTai ||
        preview == null ||
        !preview.canImport) {
      return;
    }
    setState(() {
      _dangXuLy = true;
      _thongDiep = null;
    });
    try {
      await widget.service.importUsers(preview.rows);
      if (mounted) Navigator.pop(context, preview.rows.length);
    } catch (_) {
      if (mounted) {
        setState(() {
          _xemTruoc = null;
          _xemTruocCucBo = null;
          _daKiemTraTonTai = false;
          _thongDiep = 'Chưa xác nhận được kết quả nhập (có thể tên đã tồn tại hoặc lỗi kết nối). Chọn lại file để kiểm tra trước khi thử lại. Không ghi đè tài khoản cũ.';
        });
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _xemTruoc;
    return PopScope(
      canPop: !_dangXuLy,
      child: AlertDialog(
        title: const Text('Nhập học viên từ Excel'),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(context).height * .58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ tạo học viên mới. Tối đa 200 dòng / 2 MB. Không ghi đè tài khoản đã có. Mật khẩu không hiển thị trong bản xem trước.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _dangXuLy ? null : _taiTepMau,
                    icon: const Icon(Icons.download),
                    label: const Text('Tải mẫu Excel'),
                  ),
                  FilledButton.icon(
                    onPressed: _dangXuLy ? null : _chonTep,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Chọn file .xlsx'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_dangXuLy) const LinearProgressIndicator(),
              Expanded(
                child: preview == null
                    ? SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _thongDiep ?? 'Điền 4 cột theo mẫu. Mã người dùng là phần đuôi, có thể để trống để dùng tên đăng nhập. Các cột đã định dạng Text để giữ số 0 đầu.',
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          if (_thongDiep != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _thongDiep!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (!_daKiemTraTonTai &&
                              _xemTruocCucBo?.canImport == true)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _dangXuLy ? null : _thuKiemTraLai,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Kiểm tra lại Firebase'),
                              ),
                            ),
                          if (preview.rows.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                '${preview.rows.length} học viên • ${preview.rows.where((dong) => dong.errors.isNotEmpty).length} dòng lỗi',
                              ),
                            ),
                          for (final loi in preview.errors)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                loi,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          for (final dong in preview.rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                dong.errors.isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: dong.errors.isEmpty
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text(
                                'Dòng ${dong.rowNumber}: ${dong.name}',
                              ),
                              subtitle: Text(
                                'TK: ${dong.username} • Đuôi mã: ${dong.userCodeSuffix ?? dong.username}\nMật khẩu: ••••••${dong.errors.isEmpty ? '' : '\n${dong.errors.join('\n')}'}',
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _dangXuLy ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed:
                !_dangXuLy && _daKiemTraTonTai && preview?.canImport == true
                ? _nhapDuLieu
                : null,
            child: Text('Xác nhận thêm ${preview?.rows.length ?? 0} học viên'),
          ),
        ],
      ),
    );
  }
}
