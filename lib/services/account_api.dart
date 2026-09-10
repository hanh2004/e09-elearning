import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

typedef AccountCall = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class AccountApi {
  AccountApi({this.transport});
  final AccountCall? transport;
  bool get hasTransport => transport != null;
  final Map<String, String> _operations = {};

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> data,
  ) async {
    if (transport != null) return transport!(method, data);
    final result =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              method,
              options: HttpsCallableOptions(
                timeout: const Duration(minutes: 9),
              ),
            )
            .call<Map<String, dynamic>>(data);
    return result.data;
  }

  Future<Map<String, dynamic>> idempotent(
    String method,
    Map<String, dynamic> data,
  ) {
    final digest = '$method:${sha256.convert(utf8.encode(jsonEncode(data)))}';
    final operationId = _operations.putIfAbsent(digest, () {
      final random = Random.secure();
      return List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    return call(method, {...data, 'operationId': operationId});
  }
}
