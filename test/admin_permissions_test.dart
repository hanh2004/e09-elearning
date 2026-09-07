import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_account_screen.dart';
import 'package:e09_elearning/screens/admin/admin_requests_screen.dart';
import 'package:e09_elearning/screens/admin/admin_exam_screen.dart';
import 'package:e09_elearning/screens/admin/admin_question_bank_screen.dart';
import 'package:e09_elearning/models/question_bank_arguments.dart';
import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/services/account_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);
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

      await FirestoreService(firestore: db).deleteUser(userId);

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
      expect(find.textContaining('Tạo bởi: limited'), findsOneWidget);
      expect(find.textContaining('Tạo bởi: someoneElse'), findsOneWidget);
      expect(find.text('Đề xuất Admin phụ'), findsNothing);
      expect(find.text('Duyệt Admin phụ'), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Nhập User từ Excel'), findsOneWidget);
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
    final createExam = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Chỉ Admin tổng được tạo bài thi'),
    );
    expect(createExam.onPressed, isNull);
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
      expect(find.text('Đồng ý'), own ? findsNothing : findsOneWidget);
      expect(find.text('Từ chối'), own ? findsNothing : findsOneWidget);
    });
  }
}
