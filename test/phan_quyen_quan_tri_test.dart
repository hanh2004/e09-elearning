import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/duyet_yeu_cau.dart';
import 'package:e09_elearning/screens/admin/quan_ly_bai_kiem_tra.dart';
import 'package:e09_elearning/screens/admin/ngan_hang_cau_hoi.dart';
import 'package:e09_elearning/models/tham_so_ngan_hang_cau_hoi.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/tai_khoan/xac_thuc_tai_khoan.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e09_elearning/screens/admin/quan_ly_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';

void main() {
  tearDown(() => AccountSession.current = null);
  testWidgets('limited admin can list courses without authoring controls', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Course',
      'subject': 'Subject',
      'published': true,
    });
    AccountSession.current = const AccountIdentity(id: 'a', role: 'admin');
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCoursesScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Course'), findsOneWidget);
    expect(find.text('Tạo khóa học'), findsNothing);
    expect(find.byTooltip('Sửa khóa học'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('limited admin deletes only Users they created', () {
    const admin = AccountIdentity(id: 'a1', role: 'admin');
    const root = AccountIdentity(id: 'r1', role: 'super_admin');
    const own = {'role': 'user', 'status': 'active', 'createdBy': 'a1'};
    expect(admin.canDelete('u1', own), isTrue);
    expect(
      admin.canDelete('u1', {'role': 'user', 'status': 'active'}),
      isFalse,
    );
    expect(
      admin.canDelete('u2', {
        'role': 'user',
        'status': 'active',
        'createdBy': 'other',
      }),
      isFalse,
    );
    expect(admin.canEdit('u1', own), isTrue);
    expect(
      admin.canEdit('u2', {
        'role': 'user',
        'status': 'active',
        'createdBy': 'other',
      }),
      isFalse,
    );
    expect(admin.canEdit('a2', {'role': 'admin', 'status': 'active'}), isFalse);
    expect(
      admin.canDelete('a2', {'role': 'admin', 'status': 'active'}),
      isFalse,
    );
    expect(root.canDelete('a2', {'role': 'admin', 'status': 'active'}), isTrue);
    expect(
      root.canDelete('r2', {'role': 'super_admin', 'status': 'active'}),
      isFalse,
    );
    expect(
      root.canEdit('r2', {'role': 'super_admin', 'status': 'active'}),
      isFalse,
    );
    expect(
      root.canEdit('r1', {'role': 'super_admin', 'status': 'active'}),
      isFalse,
    );
  });

  test('login mapping matches backend SHA-256 mapping', () {
    expect(accountLoginEmail(' Admintong1 '), accountLoginEmail('admintong1'));
    expect(
      accountLoginEmail('admintong1'),
      matches(RegExp(r'^[a-f0-9]{64}@accounts\.invalid$')),
    );
  });

  test(
    'deleting a User permanently removes profile, username and attempts',
    () async {
      AccountSession.current = const AccountIdentity(
        id: 'root',
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      const userId = 'user1';
      const username = 'student01';
      final usernameId = accountLoginEmail(username).split('@').first;
      await db.collection('users').doc(userId).set({
        'name': 'Student',
        'username': username,
        'role': 'user',
        'status': 'active',
        'createdBy': 'root',
      });
      await db.collection('usernames').doc(usernameId).set({
        'uid': userId,
        'username': username,
      });
      await db.collection('exam_attempts').doc('attempt1').set({
        'userId': userId,
        'examId': 'exam1',
      });

      await db.doc('users/user1/learning/c_l').set({'completed': true});
      await db.doc('exam_attempts/attempt1/runs/1').set({'score': 8});
      await FirestoreService(firestore: db).deleteUser(userId);
      expect((await db.doc('users/user1/learning/c_l').get()).exists, isFalse);
      expect(
        (await db.doc('exam_attempts/attempt1/runs/1').get()).exists,
        isFalse,
      );

      expect((await db.collection('users').doc(userId).get()).exists, isFalse);
      expect(
        (await db.collection('usernames').doc(usernameId).get()).exists,
        isFalse,
      );
      expect(
        (await db
                .collection('exam_attempts')
                .where('userId', isEqualTo: userId)
                .get())
            .docs,
        isEmpty,
      );
    },
  );

  testWidgets(
    'limited admin sees all Users and creator labels but no admin governance',
    (tester) async {
      AccountSession.current = const AccountIdentity(
        id: 'limited',
        role: 'admin',
      );
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('own').set({
        'name': 'Own User',
        'username': 'own01',
        'role': 'user',
        'status': 'active',
        'createdBy': 'limited',
      });
      await db.collection('users').doc('other').set({
        'name': 'Other User',
        'username': 'other01',
        'role': 'user',
        'status': 'active',
        'createdBy': 'someoneElse',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAccountScreen(service: FirestoreService(firestore: db)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Own User'), findsOneWidget);
      expect(find.text('Other User'), findsOneWidget);
      expect(find.textContaining('Quản lý: limited'), findsOneWidget);
      expect(find.textContaining('Quản lý: someoneElse'), findsOneWidget);
      expect(find.text('Đề xuất Quản lý'), findsNothing);
      expect(find.text('Duyệt Quản lý'), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Nhập học viên từ Excel'), findsOneWidget);
    },
  );

  testWidgets('limited admin cannot create exams or questions in UI', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'limited',
      role: 'admin',
    );
    final db = FakeFirebaseFirestore();
    await db.collection('exams').doc('exam1').set({
      'title': 'Test exam',
      'duration': '30 phút',
      'isOpen': true,
    });
    await db.collection('exams').doc('exam1').collection('questions').add({
      'questionText': 'Câu hỏi thử',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 0,
    });
    final service = FirestoreService(firestore: db);
    await tester.pumpWidget(
      MaterialApp(home: AdminExamScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài thi mới'), findsNothing);
    expect(find.text('Chỉ quản lý tổng được tạo bài thi'), findsNothing);
    expect(find.text('Quản lý Kiểm tra'), findsOneWidget);
    expect(find.text('Xem câu hỏi'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.text('Đang mở'));
    await tester.pumpAndSettle();
    expect((await db.collection('exams').doc('exam1').get())['isOpen'], isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminQuestionBankScreen(
          service: service,
          args: const QuestionBankArguments(
            examId: 'exam1',
            examTitle: 'Test exam',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  for (final own in [true, false]) {
    testWidgets('approval screen only enables the other root: own=$own', (
      tester,
    ) async {
      AccountSession.current = const AccountIdentity(
        id: 'root1',
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      await db.collection('admin_requests').doc('r').set({
        'createdBy': own ? 'root1' : 'root2',
        'name': 'Pending admin',
        'username': 'pending01',
        'status': 'pending',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: AdminRequestsScreen(service: FirestoreService(firestore: db)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Duyệt'), own ? findsNothing : findsOneWidget);
      expect(find.text('Từ chối'), own ? findsNothing : findsOneWidget);
    });
  }
}
