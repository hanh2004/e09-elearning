import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/models/mo_hinh_cau_hoi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported or ungradable questions are rejected', () {
    final valid = {
      'questionText': 'Q',
      'options': ['A', 'B'],
      'correctAnswerIndex': 0,
    };
    expect(CauHoiModel.fromMap(valid, 'q').isValidForExam, true);
    expect(
      CauHoiModel.fromMap({
        ...valid,
        'loai_cau_hoi': 'MULTIPLE_CHOICE',
      }, 'q').isValidForExam,
      false,
    );
    expect(
      CauHoiModel.fromMap({
        ...valid,
        'correctAnswerIndex': -1,
      }, 'q').isValidForExam,
      false,
    );
  });
  test('republishing with edits keeps one notification', () async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    final ref = db.doc('courses/c');
    await service.saveContent('admin', ref, {
      'title': 'C',
      'published': true,
      'audience': 'all',
      'publishedAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 1)),
      ),
    });
    await service.saveContent('admin', ref, {
      'published': true,
      'title': 'Updated',
    });
    expect(
      (await db.collection('learning_notifications').get()).docs.length,
      1,
    );
  });
}
