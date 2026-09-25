part of 'user_courses_screen.dart';

/// Màn hình chương học tách khỏi thư viện khóa học để dễ bảo trì.
class CourseChaptersScreen extends StatelessWidget {
  const CourseChaptersScreen({
    super.key,
    required this.uid,
    required this.course,
    required this.service,
  });

  final String uid;
  final LessonDoc course;
  final LearningService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Nội dung chương học')),
    bottomNavigationBar: const LearnerNavigation(selectedIndex: 1),
    body: CourseChapterList(uid: uid, course: course, service: service),
  );
}

class CourseChapterList extends StatefulWidget {
  const CourseChapterList({
    super.key,
    required this.uid,
    required this.course,
    required this.service,
  });

  final String uid;
  final LessonDoc course;
  final LearningService service;

  @override
  State<CourseChapterList> createState() => _TrangThaiDanhSachChuong();
}

class _TrangThaiDanhSachChuong extends State<CourseChapterList> {
  late final lessons = widget.service.lessons(widget.course.id);
  late final progress = widget.service.progress(widget.uid, widget.course.id);

  void open(BuildContext context, List<LessonDoc> records, int index) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LessonReaderScreen(
            uid: widget.uid,
            courseId: widget.course.id,
            lessonId: records[index].id,
            lesson: records[index].data(),
            service: widget.service,
            siblings: records,
            courseData: widget.course.data(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => LearningList(
    stream: lessons,
    builder: (allDocs) {
      final courseData = widget.course.data();
      final explicitCourseMode =
          courseData['learningMode'] == 'study_only' ||
          courseData['learningMode'] == 'study_exam';
      final records = allDocs
          .where(
            (record) => explicitCourseMode
                ? !CourseForm.hasExam(courseData)
                : !LessonForm.hasExam(record.data()),
          )
          .toList();
      return _progress(records);
    },
  );

  Widget _progress(List<LessonDoc> records) => LearningList(
    stream: progress,
    builder: (progressDocs) {
      final completed = progressDocs
          .where((record) => record.data()['completed'] == true)
          .map((record) => record.data()['lessonId'])
          .toSet();
      final completion = LearningPolicy.completion(
        records.map((record) => record.id),
        completed.cast<String>(),
      );
      final chapters = <String, List<LessonDoc>>{};
      for (final record in records) {
        final name = (record.data()['chapter'] as String? ?? '').trim();
        (chapters[name.isEmpty ? 'Bài học' : name] ??= []).add(record);
      }
      final nextIndex = records.indexWhere(
        (record) => !completed.contains(record.id),
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              const Text(
                'Tiến độ học chuyên đề',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${(completion * 100).round()}% Hoàn thành',
                style: const TextStyle(color: AppTheme.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: completion),
          const SizedBox(height: 16),
          if (records.isEmpty) const Text('Chưa có bài học.'),
          if (records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () =>
                    open(context, records, nextIndex < 0 ? 0 : nextIndex),
                icon: const Icon(Icons.play_arrow),
                label: Text(completion == 1 ? 'Ôn tập lại' : 'Tiếp tục học'),
              ),
            ),
          for (final entry in chapters.entries)
            _chapterCard(entry, chapters.length, records, completed, nextIndex),
        ],
      );
    },
  );

  Widget _chapterCard(
    MapEntry<String, List<LessonDoc>> chapter,
    int chapterCount,
    List<LessonDoc> records,
    Set<Object?> completed,
    int nextIndex,
  ) {
    final lessons = chapter.value;
    final doneCount = lessons
        .where((lesson) => completed.contains(lesson.id))
        .length;
    final first = lessons.first.data();
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        key: PageStorageKey('${widget.course.id}-${chapter.key}'),
        initiallyExpanded:
            lessons.any((lesson) => records.indexOf(lesson) == nextIndex) ||
            chapterCount == 1,
        leading: CourseCover(
          url:
              first['coverUrl'] ??
              (first['type'] == 'image' ? first['url'] ?? '' : ''),
          width: 46,
          height: 46,
        ),
        title: Text(
          chapter.key,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('$doneCount/${lessons.length} bài đã học'),
        children: [
          for (final lesson in lessons) _lessonTile(lesson, records, completed),
        ],
      ),
    );
  }

  Widget _lessonTile(
    LessonDoc lesson,
    List<LessonDoc> records,
    Set<Object?> completed,
  ) {
    final data = lesson.data();
    final done = completed.contains(lesson.id);
    final courseMode = widget.course.data()['learningMode'] == 'study_only';
    final seconds = (data['minimumStudySeconds'] as num? ?? 300).toInt();
    return ListTile(
      leading: CourseCover(
        url:
            data['coverUrl'] ??
            (data['type'] == 'image' ? data['url'] ?? '' : ''),
        width: 40,
        height: 44,
      ),
      trailing: Icon(
        done ? Icons.check_circle_outline : Icons.play_circle_outline,
        color: done ? Colors.green : AppTheme.red,
        size: 18,
      ),
      title: Text(data['title'] ?? '', style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${courseMode ? CourseForm.studyOnlyLabel : LessonForm.modeLabel(data)} • ${done ? 'Đã học' : '$seconds giây • Chưa học'}',
      ),
      onTap: () => open(context, records, records.indexOf(lesson)),
    );
  }
}
