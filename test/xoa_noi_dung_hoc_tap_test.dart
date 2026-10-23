import 'package:cloud_functions/cloud_functions.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final code in ['not-found', 'unimplemented']) {
    test('deletes directly only when the endpoint is absent ($code)', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('courses/course').set({'title': 'Khóa học'});
      var calls = 0;
      final service = LearningService(
        db: db,
        api: AccountApi(
          transport: (_, _) async {
            calls++;
            throw FirebaseFunctionsException(code: code, message: 'Absent');
          },
        ),
      );

      await service.deleteCourse('course');

      expect(calls, 1);
      expect((await db.doc('courses/course').get()).exists, isFalse);
    });
  }

  test(
    'does not retry an absent endpoint after direct deletion fails',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('courses/course').set({'examId': 'exam'});
      var calls = 0;
      final service = LearningService(
        db: db,
        api: AccountApi(
          transport: (_, _) async {
            calls++;
            throw FirebaseFunctionsException(
              code: 'not-found',
              message: 'Absent',
            );
          },
        ),
      );

      await expectLater(service.deleteCourse('course'), throwsStateError);

      expect(calls, 1);
      expect((await db.doc('courses/course').get()).exists, isTrue);
    },
  );

  test('preserves data when the backend result is uncertain', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/course').set({'title': 'Khóa học'});
    final error = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Unavailable',
    );
    var calls = 0;
    final service = LearningService(
      db: db,
      api: AccountApi(
        transport: (_, _) async {
          calls++;
          throw error;
        },
      ),
    );

    await expectLater(service.deleteCourse('course'), throwsA(same(error)));

    expect(calls, 1);
    expect((await db.doc('courses/course').get()).exists, isTrue);
  });
}
