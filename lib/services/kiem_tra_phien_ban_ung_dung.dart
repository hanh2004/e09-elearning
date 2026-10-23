import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Nhắc cập nhật khi ba số phiên bản phát hành mới lớn hơn bản đang cài.
class AppReleaseChecker {
  AppReleaseChecker({this._client});

  static const _channel = MethodChannel('com.example.e09_elearning/app_info');
  final http.Client? _client;
  static final _manifestUri = Uri.parse(
    'https://e09-elearning-admin.web.app/app-release.json',
  );

  Future<bool> hasNewRelease() async {
    final installedVersion = await _installedVersionName();
    if (installedVersion == null) return false;

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            _manifestUri.replace(
              queryParameters: {
                'check': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      final publishedVersion = data is Map ? data['versionName'] : null;
      return publishedVersion is String &&
          _isNewerVersion(publishedVersion, installedVersion);
    } finally {
      if (_client == null) client.close();
    }
  }

  bool _isNewerVersion(String publishedVersion, String installedVersion) {
    final published = _versionParts(publishedVersion);
    final installed = _versionParts(installedVersion);
    if (published == null || installed == null) return false;

    for (var index = 0; index < 3; index++) {
      if (published[index] != installed[index]) {
        return published[index] > installed[index];
      }
    }
    // Build number thứ tư chỉ ghi nhận bản sửa nhỏ và không nhắc cập nhật.
    return false;
  }

  List<int>? _versionParts(String version) {
    final parts = version.trim().split('.');
    if (parts.length < 3) return null;
    final numbers = <int>[];
    for (final part in parts.take(3)) {
      final number = int.tryParse(part);
      if (number == null || number < 0) return null;
      numbers.add(number);
    }
    return numbers;
  }

  Future<String?> _installedVersionName() async {
    try {
      return await _channel.invokeMethod<String>('getVersionName');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
