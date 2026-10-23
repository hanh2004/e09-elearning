// XỬ LÝ DỮ LIỆU / API: Gọi API quản lý tài khoản; dùng mã thao tác để thử lại không tạo tài khoản trùng.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../../app/cau_hinh_ung_dung.dart';
import '../tai_khoan/phien_dang_nhap_quan_tri_web.dart';

typedef AccountCall = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class AccountApi {
  AccountApi({this.transport, this.useBackend = false});
  final bool useBackend;
  final AccountCall? transport;
  bool get hasTransport => transport != null || useBackend;
  final Map<String, _AccountOperation> _cacThaoTac = {};

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> duLieu,
  ) async {
    if (transport != null) return transport!(method, duLieu);
    final ketQua =
        await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
            .httpsCallable(
              method,
              options: HttpsCallableOptions(
                timeout: const Duration(minutes: 9),
              ),
            )
            .call<Map<String, dynamic>>(AdminWebSession.addToken(duLieu));
    return ketQua.data;
  }

  Future<Map<String, dynamic>> idempotent(
    String method,
    Map<String, dynamic> duLieu,
  ) async {
    final digestData = method == 'accountImportUsers'
        ? {
            ...duLieu,
            'rows': (duLieu['rows'] as List).map((rawRow) {
              final row = Map<String, dynamic>.from(rawRow as Map);
              row.remove('serialNumber');
              return row;
            }).toList(),
          }
        : duLieu;
    final digest =
        '$method:${sha256.convert(utf8.encode(jsonEncode(digestData)))}';
    final operation = _cacThaoTac.putIfAbsent(digest, () {
      final random = Random.secure();
      final operationId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      return _AccountOperation(operationId);
    });
    operation.inFlight++;
    try {
      final result = await call(method, {
        ...duLieu,
        'operationId': operation.id,
      });
      operation.succeeded = true;
      return result;
    } finally {
      operation.inFlight--;
      // Retain failed operations for retry. Retire successful IDs only after
      // every overlapping call using that ID has completed.
      if (operation.inFlight == 0 &&
          operation.succeeded &&
          identical(_cacThaoTac[digest], operation)) {
        _cacThaoTac.remove(digest);
      }
    }
  }
}

class _AccountOperation {
  _AccountOperation(this.id);

  final String id;
  int inFlight = 0;
  bool succeeded = false;
}
