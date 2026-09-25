// XỬ LÝ DỮ LIỆU / API: Chọn file Excel trong trình duyệt bằng API web.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'workbook_picker_error.dart';

/// Mở ngay trong lần bấm của người dùng, không cần đăng ký plugin.
Future<Uint8List?> pickWorkbookFile() {
  final ketQua = Completer<Uint8List?>();
  final dauVao = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx'
    ..multiple = false
    ..setAttribute('data-workbook-picker', 'true')
    ..style.display = 'none';
  var reading = false;
  late final JSFunction onChange;
  late final JSFunction onCancel;

  void cleanup() {
    dauVao.removeEventListener('change', onChange);
    dauVao.removeEventListener('cancel', onCancel);
    dauVao.remove();
  }

  onChange = ((web.Event event) {
    if (reading || ketQua.isCompleted) return;
    reading = true;
    unawaited(() async {
      try {
        final tep = dauVao.files?.item(0);
        if (tep == null) {
          ketQua.complete(null);
        } else {
          validateWorkbookFile(tep.name, tep.size);
          final buffer = await tep.arrayBuffer().toDart;
          ketQua.complete(buffer.toDart.asUint8List());
        }
      } catch (loi, stack) {
        ketQua.completeError(loi, stack);
      } finally {
        cleanup();
      }
    }());
  }).toJS;
  onCancel = ((web.Event event) {
    if (reading || ketQua.isCompleted) return;
    ketQua.complete(null);
    cleanup();
  }).toJS;
  dauVao.addEventListener('change', onChange);
  dauVao.addEventListener('cancel', onCancel);
  try {
    final thanNoiDung = web.document.body;
    if (thanNoiDung == null) throw StateError('document-body-unavailable');
    thanNoiDung.appendChild(dauVao);
    // Giữ ô chọn file cho tới khi chọn hoặc hủy xong.
    dauVao.click();
  } catch (loi, stack) {
    cleanup();
    ketQua.completeError(loi, stack);
  }
  return ketQua.future;
}
