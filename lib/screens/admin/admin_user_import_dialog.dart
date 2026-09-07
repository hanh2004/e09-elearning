import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_import.dart';
import '../../services/firestore_service.dart';
import '../../services/user_excel_import.dart';
import '../../services/workbook_picker.dart';
import '../../services/workbook_picker_error.dart';

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
  State<AdminUserImportDialog> createState() => _AdminUserImportDialogState();
}

class _AdminUserImportDialogState extends State<AdminUserImportDialog> {
  UserImportPreview? _preview;
  UserImportPreview? _localPreview;
  bool _existingChecked = false;
  bool _busy = false;
  String? _message;

  Future<void> _downloadTemplate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await rootBundle.load(UserExcelImport.templateAsset);
      await FilePicker.saveFile(
        dialogTitle: 'Lưu mẫu nhập User',
        fileName: 'users_import.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Không tải được file mẫu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _preview = null;
      _localPreview = null;
      _existingChecked = false;
      _message = null;
    });
    var stage = 'pick';
    try {
      final bytes = await (widget.pickWorkbook ?? pickWorkbookFile)();
      if (bytes == null) return;
      stage = 'decode';
      final preview = (widget.decodeWorkbook ?? UserExcelImport().parse)(bytes);
      if (!mounted) return;
      setState(() {
        _localPreview = preview;
        _preview = preview;
      });
      // File errors must be shown locally, even when Firebase is unavailable.
      if (preview.canImport) await _checkExisting();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is WorkbookPickerException
              ? error.message
              : stage == 'decode'
              ? 'Không đọc được nội dung Excel. Chọn file .xlsx không mã hóa và đúng 3 cột.'
              : error is MissingPluginException || error is UnimplementedError
              ? 'Bộ chọn file chưa được khởi tạo. Dừng ứng dụng rồi chạy lại Flutter (không chỉ hot reload); trên web hãy tải lại trang.'
              : 'Không mở hoặc đọc được file từ máy (mã: ${error.runtimeType}). Hãy gửi mã lỗi này để kiểm tra; trên web thử mở bằng Chrome hoặc Edge.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkExisting() async {
    final local = _localPreview;
    if (local == null || !local.canImport) return;
    try {
      final usernames = await widget.service
          .checkUsernames(local.rows.map((row) => row.username).toList())
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _preview = local.checkExisting(usernames);
        _existingChecked = true;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      String detail;
      if (error is FirebaseException) {
        detail = switch (error.code) {
          'permission-denied' => 'Firebase từ chối quyền đọc danh sách tài khoản (permission-denied).',
          'unauthenticated' =>
            'Firebase yêu cầu phiên xác thực hợp lệ (unauthenticated).',
          'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
            'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.',
          _ => 'Firebase chưa kiểm tra được danh sách tài khoản. Vui lòng thử lại.',
        };
      } else if (error is TimeoutException) {
        detail = 'Firebase không phản hồi kịp. Kiểm tra mạng rồi thử lại.';
      } else {
        detail = 'Chưa kiểm tra được danh sách tài khoản trên Firebase. Vui lòng thử lại.';
      }
      setState(() {
        _existingChecked = false;
        _message =
            'Đã đọc file Excel. $detail Chưa cho phép nhập khi chưa kiểm tra trùng tài khoản.';
      });
    }
  }

  Future<void> _retryCheck() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _checkExisting();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || !_existingChecked || preview == null || !preview.canImport) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.service.importUsers(preview.rows);
      if (mounted) Navigator.pop(context, preview.rows.length);
    } catch (_) {
      if (mounted) {
        setState(() {
          _preview = null;
          _localPreview = null;
          _existingChecked = false;
          _message = 'Chưa xác nhận được kết quả nhập (có thể tên đã tồn tại hoặc lỗi kết nối). Chọn lại file để kiểm tra trước khi thử lại. Không ghi đè tài khoản cũ.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Nhập User từ Excel'),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(context).height * .58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ tạo User mới. Tối đa 200 dòng / 2 MB. Không ghi đè tài khoản đã có. Mật khẩu không hiển thị trong bản xem trước.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('Tải mẫu Excel'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _chooseFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Chọn file .xlsx'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: preview == null
                    ? SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _message ?? 'Điền sheet Users theo mẫu: Họ và tên | Tên đăng nhập | Mật khẩu. Đặt các ô ở định dạng Text để giữ số 0 đầu. Không thêm cột vai trò.',
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          if (_message != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _message!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (!_existingChecked &&
                              _localPreview?.canImport == true)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _retryCheck,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Kiểm tra lại Firebase'),
                              ),
                            ),
                          if (preview.rows.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                '${preview.rows.length} User • ${preview.rows.where((row) => row.errors.isNotEmpty).length} dòng lỗi',
                              ),
                            ),
                          for (final error in preview.errors)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                error,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          for (final row in preview.rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                row.errors.isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: row.errors.isEmpty
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text('Dòng ${row.rowNumber}: ${row.name}'),
                              subtitle: Text(
                                'TK: ${row.username} • Mật khẩu: ••••••${row.errors.isEmpty ? '' : '\n${row.errors.join('\n')}'}',
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
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: !_busy && _existingChecked && preview?.canImport == true
                ? _import
                : null,
            child: Text('Xác nhận thêm ${preview?.rows.length ?? 0} User'),
          ),
        ],
      ),
    );
  }
}
