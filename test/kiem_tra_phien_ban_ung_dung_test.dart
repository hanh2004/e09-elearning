import 'dart:async';
import 'dart:convert';

import 'package:e09_elearning/services/kiem_tra_phien_ban_ung_dung.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _ReleaseClient extends http.BaseClient {
  _ReleaseClient(this.response);

  final Future<http.StreamedResponse> Function(http.BaseRequest) response;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response(request);

  @override
  void close() => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.e09_elearning/app_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (_) async => '1.0.4');
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final version in ['1.0.5', '1.1.0', '2.0.0']) {
    test('detects newer release $version and closes its own client', () async {
      final client = _ReleaseClient((request) async {
        expect(request.headers['Cache-Control'], 'no-cache');
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'versionName': version}))),
          200,
        );
      });
      final checker = AppReleaseChecker();

      expect(
        await http.runWithClient(checker.hasNewRelease, () => client),
        isTrue,
      );
      expect(client.closed, isTrue);
    });
  }

  test('closes its own client when the manifest is invalid', () async {
    final client = _ReleaseClient(
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('<html>error</html>')),
        200,
      ),
    );
    await expectLater(
      http.runWithClient(AppReleaseChecker().hasNewRelease, () => client),
      throwsFormatException,
    );
    expect(client.closed, isTrue);
  });

  test('closes its own client on a network failure', () async {
    final client = _ReleaseClient(
      (_) async => throw http.ClientException('offline'),
    );
    await expectLater(
      http.runWithClient(AppReleaseChecker().hasNewRelease, () => client),
      throwsA(isA<http.ClientException>()),
    );
    expect(client.closed, isTrue);
  });

  test('leaves an injected client open for its owner', () async {
    final client = _ReleaseClient(
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('{"versionName":"1.0.4.10"}')),
        200,
      ),
    );
    final checker = AppReleaseChecker(client: client);
    expect(await checker.hasNewRelease(), isFalse);
    expect(await checker.hasNewRelease(), isFalse);
    expect(client.closed, isFalse);
    client.close();
  });

  test(
    'does not create a client when the installed version is unavailable',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      var created = false;
      final result = await http.runWithClient(
        AppReleaseChecker().hasNewRelease,
        () {
          created = true;
          throw StateError('No request expected');
        },
      );
      expect(result, isFalse);
      expect(created, isFalse);
    },
  );
}
