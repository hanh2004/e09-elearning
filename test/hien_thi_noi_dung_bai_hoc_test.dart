import 'package:e09_elearning/widgets/hien_thi_noi_dung_bai_hoc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('escaped image parentheses do not enter the download token', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonContentRenderer(
            content: r'![Ảnh 1]\(https://example.org/image.jpeg?alt=media\&token=abc\)',
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://example.org/image.jpeg?alt=media&token=abc',
    );
  });
  testWidgets('renders Firebase image URLs from nested markdown links', (
    tester,
  ) async {
    const url =
        'https://firebasestorage.googleapis.com/v0/b/e09-elearning.firebasestorage.app/o/news%2F1789609580821000.jpeg?alt=media&token=abc123';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonContentRenderer(
            content: '![Ảnh 1]([https://example.org/wrapped](https://firebasestorage.googleapis.com/v0/b/e09-elearning.firebasestorage.app/o/news%2F1789609580821000.jpeg?alt=media\\&token=abc123))',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, url);
    expect(
      (image.image as NetworkImage).webHtmlElementStrategy,
      WebHtmlElementStrategy.fallback,
    );
    expect(find.text('Ảnh 1'), findsOneWidget);
  });

  testWidgets('normalizes HTML escaped query separators in image URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonContentRenderer(
            content: '![Ảnh 1](https://example.org/image.jpg?alt=media&amp;token=abc)',
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://example.org/image.jpg?alt=media&token=abc',
    );
  });
}
