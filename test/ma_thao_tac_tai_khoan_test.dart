import 'dart:async';

import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retry keeps operation ID, a later successful operation gets a new ID',
    () async {
      final ids = <String>[];
      final api = AccountApi(
        transport: (_, data) async {
          ids.add(data['operationId'] as String);
          if (ids.length == 1) throw StateError('Temporary connection failure');
          return {'count': 1};
        },
      );
      const input = {'username': 'learner'};
      await expectLater(api.idempotent('import', input), throwsStateError);
      await api.idempotent('import', input);
      await api.idempotent('import', input);
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
      expect(input.containsKey('operationId'), isFalse);
    },
  );

  test(
    'overlapping requests share an ID until complete, then a new action gets a new ID',
    () async {
      final ids = <String>[];
      final replies = <Completer<Map<String, dynamic>>>[];
      final api = AccountApi(
        transport: (_, data) {
          ids.add(data['operationId'] as String);
          final reply = Completer<Map<String, dynamic>>();
          replies.add(reply);
          return reply.future;
        },
      );
      const input = {'username': 'learner'};
      final first = api.idempotent('import', input);
      final retry = api.idempotent('import', input);
      expect(ids[0], ids[1]);
      replies[0].complete({'count': 1});
      await first;
      final overlapping = api.idempotent('import', input);
      expect(ids[2], ids[0]);
      replies[1].complete({'count': 1});
      await retry;
      replies[2].complete({'count': 1});
      await overlapping;
      final next = api.idempotent('import', input);
      expect(ids[3], isNot(ids[0]));
      final nextRetry = api.idempotent('import', input);
      expect(ids[4], ids[3]);
      replies[3].complete({'count': 1});
      replies[4].complete({'count': 1});
      await Future.wait([next, nextRetry]);
    },
  );
}
