import 'package:e09_elearning/app/chu_de_ung_dung.dart';
import 'package:e09_elearning/widgets/anh_bia_khoa_hoc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing course cover shows a book, news retains branding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [CourseCover(), CourseCover(brandFallback: true)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    final branding = tester.widget<Image>(find.byType(Image));
    expect((branding.image as AssetImage).assetName, AppTheme.appLogo);
    expect(tester.takeException(), isNull);
  });
}
