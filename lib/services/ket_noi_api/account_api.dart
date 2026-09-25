// XỬ LÝ DỮ LIỆU / API: Gọi API quản lý tài khoản; dùng mã thao tác để thử lại không tạo tài khoản trùng.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../../app/app_config.dart';

typedef AccountCall = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class AccountApi {
  AccountApi({this.transport, this.useBackend = false});
  final bool useBackend;
  final AccountCall? transport;
  bool get hasTransport => transport != null || useBackend;
  final Map<String, String> _cacThaoTac = {};

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
            .call<Map<String, dynamic>>(duLieu);
    return ketQua.data;
  }

  Future<Map<String, dynamic>> idempotent(
    String method,
    Map<String, dynamic> duLieu,
  ) {
    final digest = '$method:${sha256.convert(utf8.encode(jsonEncode(duLieu)))}';
    final operationId = _cacThaoTac.putIfAbsent(digest, () {
      final random = Random.secure();
      return List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    return call(method, {...duLieu, 'operationId': operationId});
  }
}
