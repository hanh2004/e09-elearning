import 'package:e09_elearning/models/user_import.dart';
import 'package:e09_elearning/screens/admin/admin_account_screen.dart';
import 'package:e09_elearning/screens/admin/admin_user_import_dialog.dart';
import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/services/account_api.dart';
import 'package:e09_elearning/models/account_identity.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class RetryLookupService extends FirestoreService {
  RetryLookupService() : super(firestore: FakeFirebaseFirestore());
  int calls = 0;

  @override
  Future<List<String>> checkUsernames(List<String> names) async {
    calls++;
    if (calls == 1) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return [];
  }
}

void main() {
  setUp(
    () => AccountSession.current = const AccountIdentity(
      id: 'root1',
      role: 'super_admin',
    ),
  );
  tearDown(() => AccountSession.current = null);
  testWidgets('canceling file selection does not decode or query Firebase', (
    tester,
  ) async {
    final service = RetryLookupService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserImportDialog(
            service: service,
            pickWorkbook: () async => null,
            decodeWorkbook: (_) => throw StateError('must-not-decode'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chọn file .xlsx'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.textContaining('Không mở hoặc đọc'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Chọn file .xlsx'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('unexpected picker error exposes type but no sensitive payload', (
    tester,
  ) async {
    final service = RetryLookupService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserImportDialog(
            service: service,
            pickWorkbook: () async => throw StateError('private-file-data'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chọn file .xlsx'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mã: StateError'), findsOneWidget);
    expect(find.textContaining('private-file-data'), findsNothing);
    expect(service.calls, 0);
  });

  testWidgets(
    'missing picker plugin gives restart guidance before reading file',
    (tester) async {
      final service = RetryLookupService();
      var decoded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUserImportDialog(
              service: service,
              pickWorkbook: () async => throw MissingPluginException(),
              decodeWorkbook: (_) {
                decoded = true;
                return const UserImportPreview();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn file .xlsx'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bộ chọn file chưa được khởi tạo'),
        findsOneWidget,
      );
      expect(decoded, isFalse);
      expect(service.calls, 0);
    },
  );

  testWidgets(
    'Firebase failure keeps local preview and blocks import until retry succeeds',
    (tester) async {
      final service = RetryLookupService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUserImportDialog(
              service: service,
              pickWorkbook: () async => Uint8List.fromList([1]),
              decodeWorkbook: (_) => const UserImportPreview(
                rows: [
                  UserImportRow(
                    rowNumber: 2,
                    name: 'An',
                    username: 'user01',
                    password: 'secret01',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn file .xlsx'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã đọc file Excel.'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsOneWidget);
      expect(find.text('Dòng 2: An'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận thêm 1 User'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Kiểm tra lại Firebase'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận thêm 1 User'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('invalid workbook shows local errors without querying Firebase', (
    tester,
  ) async {
    final service = RetryLookupService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserImportDialog(
            service: service,
            pickWorkbook: () async => Uint8List.fromList([1]),
            decodeWorkbook: (_) =>
                const UserImportPreview(errors: ['File không hợp lệ.']),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chọn file .xlsx'));
    await tester.pumpAndSettle();
    expect(find.text('File không hợp lệ.'), findsOneWidget);
    expect(service.calls, 0);
  });

  testWidgets('adding accounts cannot assign admin directly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAccountScreen(
          service: FirestoreService(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nhập User từ Excel'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    expect(find.text('Giáo viên'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Vai trò: User (Học viên)'), findsOneWidget);
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'import at width $width requires confirmation and masks passwords',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        var writes = 0;
        final api = AccountApi(
          transport: (method, payload) async {
            if (method == 'accountCheckUsernames') {
              return {'existing': <String>[]};
            }
            if (method == 'accountImportUsers') {
              writes++;
              return {'count': 1};
            }
            throw StateError('Unexpected API');
          },
        );
        var completed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    completed =
                        await showDialog<int>(
                          context: context,
                          builder: (_) => AdminUserImportDialog(
                            service: FirestoreService(
                              firestore: db,
                              accounts: api,
                            ),
                            pickWorkbook: () async => Uint8List.fromList([1]),
                            decodeWorkbook: (_) => const UserImportPreview(
                              rows: [
                                UserImportRow(
                                  rowNumber: 2,
                                  name: 'Nguyễn An',
                                  username: 'user01',
                                  password: 'PrivatePassword!',
                                ),
                              ],
                            ),
                          ),
                        ) ??
                        0;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn file .xlsx'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nguyễn An'), findsOneWidget);
        expect(find.textContaining('PrivatePassword!'), findsNothing);
        expect((await db.collection('users').get()).docs, isEmpty);
        await tester.tap(find.text('Xác nhận thêm 1 User'));
        await tester.pumpAndSettle();
        expect(completed, 1);
        expect(writes, 1);
        expect((await db.collection('users').get()).docs, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invalid preview cannot be imported and cancel writes nothing', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserImportDialog(
            service: FirestoreService(firestore: db),
            pickWorkbook: () async => Uint8List.fromList([1]),
            decodeWorkbook: (_) => const UserImportPreview(
              rows: [
                UserImportRow(
                  rowNumber: 2,
                  name: '',
                  username: 'user01',
                  password: 'secret',
                  errors: ['Thiếu họ và tên.'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chọn file .xlsx'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận thêm 1 User'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect((await db.collection('users').get()).docs, isEmpty);
  });
}
