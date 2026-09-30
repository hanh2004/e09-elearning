import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:e09_elearning/app/chu_de_ung_dung.dart';
import 'package:e09_elearning/widgets/giao_dien_quan_tri.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_khoa_hoc.dart';
import 'package:e09_elearning/screens/admin/quan_ly_thong_bao.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tin_tuc.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';

void main() {
  for (final width in [760.0, 1440.0]) {
    testWidgets(
      'all secondary admin pages retain navigation and red headers at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AccountSession.current = const AccountIdentity(
          id: 'root',
          role: 'super_admin',
        );
        addTearDown(() => AccountSession.current = null);
        final db = FakeFirebaseFirestore();
        final learning = LearningService(db: db);
        final pages = <Widget>[
          AdminAccountScreen(service: FirestoreService(firestore: db)),
          AdminCoursesScreen(service: learning),
          AdminNewsScreen(service: learning),
          AdminNotificationsScreen(service: learning),
        ];
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AdminUi.theme,
            navigatorKey: navigator,
            home: pages.first,
          ),
        );
        await tester.pumpAndSettle();
        for (final page in pages.skip(1)) {
          navigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => page),
          );
          await tester.pumpAndSettle();
          if (width >= 1000) {
            expect(find.text('Trang chủ'), findsWidgets);
          } else {
            expect(find.byTooltip('Trang chủ'), findsOneWidget);
          }
          expect(find.byType(NavigationRail), findsNothing);
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(bar.backgroundColor, AppTheme.red);
          expect(bar.foregroundColor, Colors.white);
          expect((bar.title! as Text).style?.color, Colors.white);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
