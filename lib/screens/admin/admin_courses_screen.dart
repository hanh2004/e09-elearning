import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/account_identity.dart';
import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key, this.service});
  final LearningService? service;
  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.courses();
  String search = '';
  Future<void> edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (AccountSession.current?.isRoot != true) return;
    final data = doc?.data() ?? {};
    await editLearningRecord(
      context,
      title: doc == null ? 'Tạo khóa học' : 'Sửa khóa học',
      fields: {
        'Tên khóa học': data['title'] ?? '',
        'Môn học': data['subject'] ?? '',
        'Mô tả': data['description'] ?? '',
      },
      optional: {'Mô tả'},
      note: 'Sau khi xuất bản, tất cả học viên đều được học.',
      save: (values) async {
        await service.saveContent(
          AccountSession.current!.id,
          doc?.reference ?? service.db.collection('courses').doc(),
          {
            'title': values['Tên khóa học'],
            'subject': values['Môn học'],
            'description': values['Mô tả'],
            'audience': 'all',
            'published': data['published'] == true,
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Môn học và khóa học')),
    floatingActionButton: AccountSession.current?.isRoot != true
        ? null
        : FloatingActionButton.extended(
            onPressed: edit,
            icon: const Icon(Icons.add),
            label: const Text('Tạo khóa học'),
          ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Tìm theo tên hoặc môn học',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => search = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: LearningList(
            stream: stream,
            builder: (docs) {
              final filtered = docs
                  .where(
                    (doc) => '${doc.data()['title']} ${doc.data()['subject']}'
                        .toLowerCase()
                        .contains(search),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('Chưa có khóa học phù hợp.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final d = doc.data();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Text(d['title'] ?? ''),
                      subtitle: Text(
                        '${d['subject']} • ${d['published'] == true ? 'Đã xuất bản • Tất cả học viên' : 'Bản nháp'}',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AdminLessonsScreen(course: doc),
                        ),
                      ),
                      trailing: AccountSession.current?.isRoot != true
                          ? null
                          : IconButton(
                              tooltip: 'Sửa khóa học',
                              icon: const Icon(Icons.edit),
                              onPressed: () => edit(doc),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class AdminLessonsScreen extends StatefulWidget {
  const AdminLessonsScreen({super.key, required this.course});
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  @override
  State<AdminLessonsScreen> createState() => _AdminLessonsScreenState();
}

class _AdminLessonsScreenState extends State<AdminLessonsScreen> {
  final service = LearningService();
  late final stream = service.lessons(widget.course.id);
  late bool published = widget.course.data()['published'] == true;
  bool busy = false;
  Future<void> publish() async {
    if (AccountSession.current?.isRoot != true) return;
    setState(() => busy = true);
    try {
      await service.saveContent(
        AccountSession.current!.id,
        widget.course.reference,
        {'published': !published, 'audience': 'all'},
      );
      if (mounted) setState(() => published = !published);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đổi được trạng thái khóa học.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (AccountSession.current?.isRoot != true) return;
    final d = doc?.data() ?? {};
    await editLearningRecord(
      context,
      title: doc == null ? 'Thêm bài học' : 'Sửa bài học',
      fields: {
        'Tên bài học': d['title'] ?? '',
        'Chương': d['chapter'] ?? '',
        'Thứ tự': '${d['order'] ?? 1}',
        'Nội dung': d['content'] ?? '',
      },
      optional: {'Nội dung'},
      imageFolder: 'lessons/${widget.course.id}',
      initialImage: d['type'] == 'image' ? (d['url'] ?? '') : '',
      save: (v) async {
        final order = int.tryParse(v['Thứ tự']!);
        final imageUrl = v['imageUrl'] ?? '';
        final type = imageUrl.isNotEmpty ? 'image' : (d['type'] ?? 'text');
        if (order == null || order < 0) {
          throw ArgumentError('Dữ liệu không hợp lệ');
        }
        if (type == 'text' && v['Nội dung']!.isEmpty) {
          throw ArgumentError('Thiếu nội dung');
        }
        await service.saveContent(
          AccountSession.current!.id,
          doc?.reference ?? widget.course.reference.collection('lessons').doc(),
          {
            'title': v['Tên bài học'],
            'chapter': v['Chương'],
            'order': order,
            'content': v['Nội dung'],
            'type': type,
            'url': imageUrl.isNotEmpty ? imageUrl : (d['url'] ?? ''),
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.course.data()['title'] ?? 'Bài học'),
      actions: [
        if (AccountSession.current?.isRoot == true)
          TextButton(
            onPressed: busy ? null : publish,
            child: Text(published ? 'Chuyển về nháp' : 'Xuất bản'),
          ),
      ],
    ),
    floatingActionButton: AccountSession.current?.isRoot != true
        ? null
        : FloatingActionButton.extended(
            onPressed: edit,
            icon: const Icon(Icons.add),
            label: const Text('Thêm bài học'),
          ),
    body: LearningList(
      stream: stream,
      builder: (docs) => docs.isEmpty
          ? const Center(
              child: Text('Thêm bài học trước khi xuất bản khóa học.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final doc in docs)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${doc.data()['order']}. ${doc.data()['title']}',
                      ),
                      subtitle: Text(
                        '${doc.data()['chapter']} • ${doc.data()['type']}',
                      ),
                      trailing: AccountSession.current?.isRoot == true
                          ? const Icon(Icons.edit)
                          : null,
                      onTap: AccountSession.current?.isRoot == true
                          ? () => edit(doc)
                          : null,
                    ),
                  ),
              ],
            ),
    ),
  );
}
