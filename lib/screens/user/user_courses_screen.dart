import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class UserCoursesScreen extends StatefulWidget {
  const UserCoursesScreen({super.key, required this.uid, this.service});
  final LearningService? service;
  final String uid;
  @override
  State<UserCoursesScreen> createState() => _UserCoursesScreenState();
}

class _UserCoursesScreenState extends State<UserCoursesScreen> {
  late final service = widget.service ?? LearningService();
  late final profile = service.db
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  String search = '';
  String? subject;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thư viện học tập')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không tải được hồ sơ học viên.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final classId = snapshot.data!.data()?['classId'] as String? ?? '';
        return LearningList(
          stream: service.courses(classId: classId),
          builder: (docs) {
            final subjects =
                docs
                    .map((d) => d.data()['subject'] as String? ?? '')
                    .toSet()
                    .toList()
                  ..sort();
            final filtered = docs
                .where(
                  (d) =>
                      (subject == null || d.data()['subject'] == subject) &&
                      '${d.data()['title']} ${d.data()['subject']}'
                          .toLowerCase()
                          .contains(search),
                )
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Tìm kiếm khóa học',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setState(() => search = v.toLowerCase()),
                      ),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: subjects.contains(subject) ? subject : null,
                        hint: const Text('Tất cả môn học'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Tất cả môn học'),
                          ),
                          for (final s in subjects)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(() => subject = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Chưa có khóa học phù hợp.'))
                      : ListView(
                          children: [
                            for (final doc in filtered)
                              Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9E9E5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.auto_stories_outlined,
                                      color: Color(0xFFB51F24),
                                    ),
                                  ),
                                  title: Text(doc.data()['title'] ?? ''),
                                  subtitle: Text(
                                    '${doc.data()['subject']}\n${doc.data()['description'] ?? ''}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => UserLessonsScreen(
                                        uid: widget.uid,
                                        course: doc,
                                        service: service,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class UserLessonsScreen extends StatefulWidget {
  const UserLessonsScreen({
    super.key,
    required this.uid,
    required this.course,
    this.service,
  });
  final LearningService? service;
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  @override
  State<UserLessonsScreen> createState() => _UserLessonsScreenState();
}

class _UserLessonsScreenState extends State<UserLessonsScreen> {
  late final service = widget.service ?? LearningService();
  late final lessons = service.lessons(widget.course.id);
  late final progress = service.progress(widget.uid, widget.course.id);
  bool favoritesOnly = false;
  String? selectedChapter;
  final pending = <String>{};
  Future<bool> mark(String id, bool completed, bool favorite) async {
    if (pending.contains(id)) return false;
    setState(() => pending.add(id));
    try {
      await service.markLesson(
        widget.uid,
        widget.course.id,
        id,
        completed: completed,
        favorite: favorite,
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được tiến độ. Hãy thử lại.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  void open(
    String id,
    Map<String, dynamic> lesson,
    bool completed,
    bool favorite,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, setReaderState) => Scaffold(
            appBar: AppBar(title: Text(lesson['title'] ?? 'Bài học')),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  lesson['chapter'] ?? '',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  lesson['content'] ?? '',
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                if (lesson['type'] == 'image' &&
                    (lesson['url'] as String? ?? '').isNotEmpty)
                  Image.network(
                    lesson['url'],
                    errorBuilder: (_, error, stack) =>
                        const Text('Không tải được hình ảnh.'),
                  ),
                if ((lesson['url'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Tài liệu ${lesson['type']}'),
                  SelectableText(lesson['url']),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: lesson['url']),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép liên kết tài liệu.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép liên kết để mở tài liệu'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  onPressed: pending.contains(id)
                      ? null
                      : () async {
                          final saving = mark(id, !completed, favorite);
                          setReaderState(() {});
                          final success = await saving;
                          if (context.mounted) {
                            setReaderState(() {
                              if (success) completed = !completed;
                            });
                          }
                        },
                  icon: Icon(completed ? Icons.check_circle : Icons.check),
                  label: Text(
                    completed
                        ? 'Đã học • Đánh dấu chưa học'
                        : 'Hoàn thành bài học',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.course.data()['title'] ?? 'Bài học')),
    body: LearningList(
      stream: lessons,
      builder: (docs) => LearningList(
        stream: progress,
        builder: (records) {
          final states = {
            for (final d in records) d.data()['lessonId']: d.data(),
          };
          final completed = records
              .where((d) => d.data()['completed'] == true)
              .map((d) => d.data()['lessonId'] as String);
          final ratio = LearningPolicy.completion(
            docs.map((d) => d.id),
            completed,
          );
          final chapters = docs
              .map((d) => (d.data()['chapter'] as String? ?? '').trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
          final activeChapter = chapters.contains(selectedChapter)
              ? selectedChapter
              : null;
          final visible = docs
              .where(
                (d) =>
                    (!favoritesOnly || states[d.id]?['favorite'] == true) &&
                    (activeChapter == null ||
                        (d.data()['chapter'] as String? ?? '').trim() ==
                            activeChapter),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      widget.course.data()['description'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Hoàn thành ${(ratio * 100).round()}%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: ratio),
                    if (docs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed: () {
                            final nextIndex = docs.indexWhere(
                              (d) => states[d.id]?['completed'] != true,
                            );
                            final next = docs[nextIndex < 0 ? 0 : nextIndex];
                            open(
                              next.id,
                              next.data(),
                              states[next.id]?['completed'] == true,
                              states[next.id]?['favorite'] == true,
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            ratio == 1 ? 'Ôn tập lại' : 'Tiếp tục học',
                          ),
                        ),
                      ),
                    SwitchListTile(
                      title: const Text('Chỉ xem bài yêu thích'),
                      value: favoritesOnly,
                      onChanged: (v) => setState(() => favoritesOnly = v),
                    ),
                    if (chapters.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Tất cả chương'),
                              selected: activeChapter == null,
                              onSelected: (_) =>
                                  setState(() => selectedChapter = null),
                            ),
                            for (final chapter in chapters)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  label: Text(chapter),
                                  selected: activeChapter == chapter,
                                  onSelected: (_) =>
                                      setState(() => selectedChapter = chapter),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('Chưa có bài học.'))
                    : ListView(
                        children: [
                          for (final doc in visible)
                            Card(
                              child: ListTile(
                                onTap: () => open(
                                  doc.id,
                                  doc.data(),
                                  states[doc.id]?['completed'] == true,
                                  states[doc.id]?['favorite'] == true,
                                ),
                                leading: Checkbox(
                                  value: states[doc.id]?['completed'] == true,
                                  onChanged: pending.contains(doc.id)
                                      ? null
                                      : (v) => mark(
                                          doc.id,
                                          v!,
                                          states[doc.id]?['favorite'] == true,
                                        ),
                                ),
                                title: Text(doc.data()['title'] ?? ''),
                                subtitle: Text(
                                  '${doc.data()['chapter']} • ${doc.data()['type']}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Yêu thích',
                                  onPressed: pending.contains(doc.id)
                                      ? null
                                      : () => mark(
                                          doc.id,
                                          states[doc.id]?['completed'] == true,
                                          states[doc.id]?['favorite'] != true,
                                        ),
                                  icon: Icon(
                                    states[doc.id]?['favorite'] == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
