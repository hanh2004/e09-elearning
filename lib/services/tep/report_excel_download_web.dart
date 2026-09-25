// NỀN TẢNG: Tải tệp Excel trực tiếp xuống trình duyệt.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadReportExcel(Uint8List duLieuByte, String tenTep) async {
  final blob = web.Blob(
    [duLieuByte.toJS].toJS,
    web.BlobPropertyBag(
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final duongDanUrl = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = duongDanUrl
    ..download = tenTep
    ..style.display = 'none';
  final thanNoiDung = web.document.body;
  if (thanNoiDung == null) {
    web.URL.revokeObjectURL(duongDanUrl);
    throw StateError('document-body-unavailable');
  }
  thanNoiDung.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(duongDanUrl);
}
