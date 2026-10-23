import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new exam stores duration and attempt limit without an exam schedule',
    () async {
      final db = FakeFirebaseFirestore();
      await FirestoreService(firestore: db)
          .addExam(title: 'Giữa kỳ', durationMinutes: 45, maxAttempts: 2);

      final data = (await db.collection('exams').get()).docs.single.data();
      expect(data['durationMinutes'], 45);
      expect(data['duration'], '45 phút');
      expect(data['maxAttempts'], 2);
      expect(data.containsKey('isOpen'), isFalse);
      expect(data.containsKey('opensAt'), isFalse);
      expect(data.containsKey('closesAt'), isFalse);
    },
  );
}
