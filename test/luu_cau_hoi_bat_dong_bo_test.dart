import 'dart:async';

import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/models/tham_so_ngan_hang_cau_hoi.dart';
import 'package:e09_elearning/screens/admin/ngan_hang_cau_hoi.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingQuestions extends FirestoreService {
  _PendingQuestions(FakeFirebaseFirestore db) : super(firestore: db);

  final pending = Completer<void>();
  var batchCalls = 0;

  @override
  Future<void> addQuestion(
    String examId, {
    required String questionText,
    required List<String> options,
    required int correctAnswerIndex,
    String explanation = '',
    String? questionId,
  }) => pending.future;

  @override
  Future<void> addQuestions(
    String examId,
    List<Map<String, dynamic>> questions,
  ) {
    batchCalls++;
    return pending.future;
  }
}

Future<_PendingQuestions> _openBank(
  WidgetTester tester, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final db = FakeFirebaseFirestore();
  await db.doc('exams/e').set({'title': 'Đề', 'durationMinutes': 45});
  final service = _PendingQuestions(db);
  AccountSession.current = const AccountIdentity(
    id: 'root',
    role: 'super_admin',
  );
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: AdminQuestionBankScreen(
        args: const QuestionBankArguments(examId: 'e', examTitle: 'Đề'),
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<void> _openQuestion(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  for (final field in find.byType(TextField).evaluate().toList()) {
    await tester.enterText(find.byWidget(field.widget), 'Nội dung');
  }
  await tester.tap(find.text('Lưu'));
  await tester.pump();
}

void main() {
  tearDown(() => AccountSession.current = null);

  testWidgets('rapid bulk save sends one batch and keeps dialog during save', (
    tester,
  ) async {
    final service = await _openBank(tester);
    await tester.tap(find.text('Nhập nhiều câu hỏi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Danh sách câu hỏi'),
      'Câu hỏi: Nội dung?\nA. Một\nB. Hai\nC. Ba\nD. Bốn\nĐáp án: A',
    );
    await tester.pump();
    final save = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Lưu 1 câu hỏi'),
        )
        .onPressed!;
    save();
    save();
    await tester.pump();
    final calls = service.batchCalls;
    unawaited(
      Navigator.of(tester.element(find.byType(AlertDialog))).maybePop(),
    );
    await tester.pumpAndSettle();
    final stayedOpen = find.text('Đang lưu…').evaluate().isNotEmpty;
    service.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(stayedOpen, isTrue);
    expect(find.text('Lưu 1 câu hỏi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single question stays open on back while save is pending', (
    tester,
  ) async {
    final service = await _openBank(tester);
    await _openQuestion(tester);
    unawaited(
      Navigator.of(tester.element(find.byType(AlertDialog))).maybePop(),
    );
    await tester.pumpAndSettle();
    final stayedOpen = find.text('Thêm câu hỏi mới').evaluate().isNotEmpty;
    service.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(stayedOpen, isTrue);
    expect(find.text('Lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question save closes only its own dialog under a newer dialog', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final service = await _openBank(tester, navigatorKey: navigator);
    await _openQuestion(tester);
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Thông tin mới')),
      ),
    );
    await tester.pumpAndSettle();
    service.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Thông tin mới'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Thêm câu hỏi mới'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
