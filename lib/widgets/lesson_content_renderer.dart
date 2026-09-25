// GIAO DIỆN DÙNG CHUNG: Hiển thị nội dung bài học: tiêu đề, đoạn văn, danh sách và ghi chú.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

class LessonContentRenderer extends StatelessWidget {
  const LessonContentRenderer({
    super.key,
    required this.content,
    this.textStyle,
  });

  final String content;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ?? const TextStyle(fontSize: 17, height: 1.6);
    final cacDongVanBan = content
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((dongVanBan) => dongVanBan.trimRight())
        .toList();
    final children = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectableText.rich(
            TextSpan(
              style: baseStyle,
              children: _cacDoanVanBan(paragraph.join(' '), baseStyle),
            ),
          ),
        ),
      );
      paragraph.clear();
    }

    for (final dongVanBan in cacDongVanBan) {
      final trimmed = dongVanBan.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      final anh = _docDongAnh(trimmed);
      if (anh != null) {
        flushParagraph();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    anh.$2,
                    // Nguồn ảnh có thể thiếu CORS. Trên web, dùng phần tử ảnh
                    // HTML khi trình duyệt chặn cách tải ảnh dạng byte.
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 100,
                      color: const Color(0xFFF1F3F6),
                      alignment: Alignment.center,
                      child: const Text('Không tải được ảnh nội dung.'),
                    ),
                  ),
                ),
                if (anh.$1.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      anh.$1,
                      style: baseStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: SelectableText(
              trimmed.substring(3).trim(),
              style: baseStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF12275A),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        flushParagraph();
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: SelectableText(
              trimmed.substring(2).trim(),
              style: baseStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF12275A),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        children.add(
          _DongDauDong(text: trimmed.substring(2).trim(), style: baseStyle),
        );
      } else if (_danhSo.hasMatch(trimmed)) {
        flushParagraph();
        final match = _danhSo.firstMatch(trimmed)!;
        children.add(
          _DongDauDong(
            marker: '${match.group(1)}.',
            text: trimmed.substring(match.end).trim(),
            style: baseStyle,
          ),
        );
      } else if (trimmed.startsWith('> ')) {
        flushParagraph();
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3C9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3C662)),
            ),
            child: SelectableText.rich(
              TextSpan(
                style: baseStyle.copyWith(color: const Color(0xFF705200)),
                children: _cacDoanVanBan(
                  trimmed.substring(2).trim(),
                  baseStyle,
                ),
              ),
            ),
          ),
        );
      } else {
        paragraph.add(trimmed);
      }
    }
    flushParagraph();

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

final _danhSo = RegExp(r'^(\d+)[\.\)]\s+');
final _dongAnh = RegExp(r'^!\[([^\]]*)\]\s*\\?\((.*)\\?\)$');
final _duongDanAnh = RegExp(r'https?://[^\s\]\)]+');

(String, String)? _docDongAnh(String dongVanBan) {
  final match = _dongAnh.firstMatch(
    dongVanBan.replaceAll(r'\(', '(').replaceAll(r'\)', ')'),
  );
  if (match == null) return null;
  final urls = _duongDanAnh
      .allMatches(match.group(2)!)
      .map((match) => match.group(0)!)
      .toList();
  if (urls.isEmpty) return null;
  final duongDanUrl = urls.last
      .replaceAll(r'\&', '&')
      .replaceAll(r'\?', '?')
      .replaceAll(r'\=', '=')
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .replaceAll('&#x26;', '&')
      .replaceAll('<', '')
      .replaceAll('>', '');
  return (match.group(1)!, duongDanUrl);
}

List<TextSpan> _cacDoanVanBan(String vanBan, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  var viTri = 0;
  while (viTri < vanBan.length) {
    final batDau = vanBan.indexOf('**', viTri);
    if (batDau < 0) {
      spans.add(TextSpan(text: vanBan.substring(viTri)));
      break;
    }
    final ketThuc = vanBan.indexOf('**', batDau + 2);
    if (ketThuc < 0) {
      spans.add(TextSpan(text: vanBan.substring(viTri)));
      break;
    }
    if (batDau > viTri) {
      spans.add(TextSpan(text: vanBan.substring(viTri, batDau)));
    }
    spans.add(
      TextSpan(
        text: vanBan.substring(batDau + 2, ketThuc),
        style: baseStyle.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    viTri = ketThuc + 2;
  }
  return spans;
}

class _DongDauDong extends StatelessWidget {
  const _DongDauDong({
    required this.text,
    required this.style,
    this.marker = '•',
  });

  final String marker;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            marker,
            style: style.copyWith(
              color: const Color(0xFFB51F24),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: SelectableText.rich(
            TextSpan(style: style, children: _cacDoanVanBan(text, style)),
          ),
        ),
      ],
    ),
  );
}
