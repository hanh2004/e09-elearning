import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/learning_service.dart';
import '../services/image_upload_service.dart';

class LearningList extends StatelessWidget {
  const LearningList({super.key, required this.stream, required this.builder});
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
  builder;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Không tải được dữ liệu. Kiểm tra kết nối và quyền truy cập.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return builder(snapshot.data!.docs);
        },
      );
}

Future<bool> editLearningRecord(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  required Future<void> Function(Map<String, String>) save,
  Set<String> optional = const {},
  Set<String> urls = const {},
  Map<String, int> maxLengths = const {},
  String? imageFolder,
  String initialImage = '',
  String? note,
}) async {
  var imageUrl = initialImage;
  final controllers = {
    for (final e in fields.entries) e.key: TextEditingController(text: e.value),
  };
  final form = GlobalKey<FormState>();
  var busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(note),
                    ),
                  if (imageFolder != null) ...[
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        height: 100,
                        errorBuilder: (_, _, _) => const Icon(Icons.image),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        busy
                            ? 'Đang xử lý…'
                            : 'Chọn ảnh từ thiết bị (tối đa 5 MB)',
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              try {
                                final uploaded =
                                    await ImageUploadService.pickAndUpload(
                                      imageFolder,
                                    );
                                if (context.mounted && uploaded != null) {
                                  setState(() => imageUrl = uploaded);
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  setState(
                                    () => error = 'Không tải được ảnh. Chọn JPG, PNG hoặc WebP tối đa 5 MB và kiểm tra kết nối.',
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => busy = false);
                                }
                              }
                            },
                    ),
                  ],
                  for (final entry in controllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: entry.value,
                        enabled: !busy,
                        obscureText: entry.key.toLowerCase().contains(
                          'mật khẩu',
                        ),
                        minLines: 1,
                        maxLines: entry.key.toLowerCase().contains('mật khẩu')
                            ? 1
                            : entry.key.contains('Nội dung')
                            ? 8
                            : 2,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value!.trim();
                          if (!optional.contains(entry.key) && text.isEmpty) {
                            return 'Vui lòng nhập thông tin';
                          }
                          final limit = maxLengths[entry.key] ?? 20000;
                          if (text.length > limit) {
                            return 'Tối đa $limit ký tự.';
                          }
                          if (urls.contains(entry.key)) {
                            return LearningPolicy.validateUrl(text);
                          }
                          return null;
                        },
                      ),
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await save({
                        if (imageFolder != null) 'imageUrl': imageUrl,
                        for (final e in controllers.entries)
                          e.key: e.key.toLowerCase().contains('mật khẩu')
                              ? e.value.text
                              : e.value.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (context.mounted) {
                        setState(() {
                          busy = false;
                          error = 'Không lưu được. Kiểm tra dữ liệu và quyền truy cập.';
                        });
                      }
                    }
                  },
            child: Text(busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    ),
  );
  // Controllers are disposed after the dialog route finishes its exit animation.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result == true;
}
