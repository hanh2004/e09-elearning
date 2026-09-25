// GIAO DIỆN DÙNG CHUNG: Soạn nội dung bài học, nút định dạng và nhập nội dung từ Word.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../services/tep/image_upload_service.dart';

class LessonRichEditor extends StatelessWidget {
  const LessonRichEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.label = 'Nội dung bài học',
    this.imageFolder,
    this.imageService,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? imageFolder;
  final ImageUploadService? imageService;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _NutCongCu(
            icon: Icons.title,
            label: 'Tiêu đề',
            enabled: enabled,
            onPressed: () => _chenDong('# Tiêu đề bài học'),
          ),
          _NutCongCu(
            icon: Icons.subtitles,
            label: 'Mục',
            enabled: enabled,
            onPressed: () => _chenDong('## Mục nội dung'),
          ),
          _NutCongCu(
            icon: Icons.format_bold,
            label: 'Đậm',
            enabled: enabled,
            onPressed: _inDamVungChon,
          ),
          _NutCongCu(
            icon: Icons.format_list_bulleted,
            label: 'Gạch đầu dòng',
            enabled: enabled,
            onPressed: () => _chenDong('- Nội dung cần nhớ'),
          ),
          _NutCongCu(
            icon: Icons.format_list_numbered,
            label: 'Đánh số',
            enabled: enabled,
            onPressed: () => _chenDong('1. Bước thực hiện'),
          ),
          _NutCongCu(
            icon: Icons.priority_high,
            label: 'Ghi chú',
            enabled: enabled,
            onPressed: () => _chenDong('> Lưu ý quan trọng'),
          ),
          OutlinedButton.icon(
            onPressed: enabled ? () => _nhapDocx(context) : null,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Nhập từ Word'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        enabled: enabled,
        minLines: 12,
        maxLines: 18,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
          helperText: imageFolder == null
              ? 'Dùng các nút phía trên hoặc nhập file .docx. Học viên sẽ xem theo giao diện bài học hiện tại.'
              : 'Dùng các nút phía trên hoặc nhập file .docx. Ảnh chèn trong Word sẽ được tải lên và giữ vị trí trong nội dung.',
        ),
        validator: (giaTri) {
          final vanBan = giaTri?.trim() ?? '';
          if (vanBan.isEmpty) return 'Vui lòng nhập nội dung bài học.';
          if (vanBan.length > 50000) return 'Nội dung tối đa 50.000 ký tự.';
          return null;
        },
      ),
    ],
  );

  void _chenDong(String vanBan) {
    final giaTri = controller.value;
    final source = giaTri.text;
    final selection = giaTri.selection;
    final offset = selection.isValid ? selection.start : source.length;
    final prefix = offset > 0 && !source.substring(0, offset).endsWith('\n')
        ? '\n'
        : '';
    final suffix = source.substring(offset).startsWith('\n') ? '' : '\n';
    final tiepTheo = source.replaceRange(
      offset,
      offset,
      '$prefix$vanBan$suffix',
    );
    final caret = offset + prefix.length + vanBan.length + suffix.length;
    controller.value = TextEditingValue(
      text: tiepTheo,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _inDamVungChon() {
    final giaTri = controller.value;
    final selection = giaTri.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _chenDong('**Nội dung in đậm**');
      return;
    }
    final daChon = selection.textInside(giaTri.text);
    final tiepTheo = giaTri.text.replaceRange(
      selection.start,
      selection.end,
      '**$daChon**',
    );
    controller.value = TextEditingValue(
      text: tiepTheo,
      selection: TextSelection.collapsed(offset: selection.end + 4),
    );
  }

  Future<void> _nhapDocx(BuildContext context) async {
    try {
      final tep = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      if (tep == null) return;
      final vanBan = await _doiDocxSangVanBanDinhDang(
        await tep.readAsBytes(),
        imageFolder: imageFolder,
        imageService: imageService,
      );
      if (vanBan.trim().isEmpty) {
        throw const FormatException('File Word không có nội dung văn bản.');
      }
      controller.text = vanBan;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nhập nội dung và ảnh từ Word.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không đọc được file Word. Hãy chọn file .docx.'),
          ),
        );
      }
    }
  }
}

Future<String> _doiDocxSangVanBanDinhDang(
  List<int> duLieuByte, {
  String? imageFolder,
  ImageUploadService? imageService,
}) async {
  final archive = ZipDecoder().decodeBytes(duLieuByte);
  final document = archive.findFile('word/document.xml');
  if (document == null) return '';
  final raw = document.content;
  final xmlText = utf8.decode(raw is List<int> ? raw : List<int>.from(raw));
  final xml = XmlDocument.parse(xmlText);
  final relationships = <String, String>{};
  final relsFile = archive.findFile('word/_rels/document.xml.rels');
  if (relsFile != null) {
    final rels = XmlDocument.parse(
      utf8.decode(
        relsFile.content is List<int>
            ? relsFile.content as List<int>
            : List<int>.from(relsFile.content),
      ),
    );
    for (final relation in rels.findAllElements('Relationship')) {
      final ma = relation.getAttribute('Id');
      final target = relation.getAttribute('Target');
      if (ma != null && target != null) relationships[ma] = target;
    }
  }
  final uploader = imageService ?? ImageUploadService();
  final uploaded = <String, String>{};
  Future<String?> imageUrl(String relationId) async {
    if (imageFolder == null) return null;
    final target = relationships[relationId];
    if (target == null) return null;
    final duongDan = target.startsWith('/')
        ? target.substring(1)
        : 'word/${target.replaceAll('..\\', '').replaceAll('../', '')}';
    final imageFile = archive.findFile(duongDan);
    if (imageFile == null) return null;
    if (uploaded.containsKey(relationId)) return uploaded[relationId];
    final ten = duongDan.split('/').last;
    final daChon = SelectedUploadImage(
      bytes: Uint8List.fromList(
        imageFile.content is List<int>
            ? imageFile.content as List<int>
            : List<int>.from(imageFile.content),
      ),
      name: ten,
    );
    final duongDanUrl = await uploader.upload(imageFolder, daChon);
    uploaded[relationId] = duongDanUrl;
    return duongDanUrl;
  }

  final paragraphs = <String>[];
  for (final paragraph in xml.findAllElements('w:p')) {
    final buffer = StringBuffer();
    var imageNumber = 0;
    for (final node in paragraph.descendantElements) {
      if (node.name.local == 't') {
        buffer.write(node.innerText);
      } else if (node.name.local == 'blip') {
        final relationId = node.attributes
            .where((attribute) => attribute.name.local == 'embed')
            .firstOrNull
            ?.value;
        if (relationId == null) continue;
        final duongDanUrl = await imageUrl(relationId);
        if (duongDanUrl != null) {
          imageNumber++;
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write('![Ảnh $imageNumber]($duongDanUrl)');
          buffer.write('\n');
        }
      }
    }
    final dongVanBan = buffer.toString().trim();
    if (dongVanBan.isNotEmpty) paragraphs.add(dongVanBan);
  }
  return paragraphs.join('\n\n');
}

class _NutCongCu extends StatelessWidget {
  const _NutCongCu({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
