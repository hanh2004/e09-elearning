import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tai_khoan.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/widgets/giao_dien_quan_tri.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('account unit and search combine and reset at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AccountSession.current = const AccountIdentity(
        id: 'admin',
        role: 'admin',
      );
      addTearDown(() => AccountSession.current = null);
      final db = FakeFirebaseFirestore();
      await db.doc('users/root').set({
        'name': 'Quản lý tổng',
        'username': 'root',
        'role': 'super_admin',
        'status': 'active',
        'unit': 'E09',
      });
      await db.doc('users/a').set({
        'name': 'Nguyễn An',
        'username': 'an01',
        'role': 'user',
        'status': 'active',
        'unit': 'D1',
        'subUnit': 'C1',
      });
      await db.doc('users/b').set({
        'name': 'Trần Bình',
        'username': 'binh02',
        'role': 'user',
        'status': 'active',
        'unit': 'D2',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminUi.theme,
          home: AdminAccountScreen(service: FirestoreService(firestore: db)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quản lý tổng'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D1').last);
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(find.text('Trần Bình'), findsNothing);
      await tester.enterText(find.byType(TextField), 'C1-D1');
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn An'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'binh02');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy tài khoản nào'), findsOneWidget);
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(find.text('Trần Bình'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
