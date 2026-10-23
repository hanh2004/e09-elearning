// Danh sách chương và bài học bên trong một khóa học của học viên.
// Đây là màn hình tách riêng thuộc thư viện cac_khoa_hoc.dart.
part of 'cac_khoa_hoc.dart';

/// Màn hình danh sách bài học tách khỏi thư viện khóa học để dễ bảo trì.
class CourseChaptersScreen extends StatelessWidget {
  const CourseChaptersScreen({
    super.key,
    required this.uid,
    required this.course,
    required this.service,
    this.examService,
  });

  final String uid;
  final LessonDoc course;
  final LearningService service;
  final SecureExamService? examService;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Bài học')),
    bottomNavigationBar: const LearnerNavigation(selectedIndex: 1),
    body: CourseChapterList(
      uid: uid,
      course: course,
      service: service,
      examService: examService,
    ),
  );
}

class CourseChapterList extends StatefulWidget {
  const CourseChapterList({
    super.key,
    required this.uid,
    required this.course,
    required this.service,
    this.examService,
    this.includeExamLessons = false,
  });

  final String uid;
  final LessonDoc course;
  final LearningService service;
  final SecureExamService? examService;
  final bool includeExamLessons;

  @override
  State<CourseChapterList> createState() => _TrangThaiDanhSachChuong();
}

class _TrangThaiDanhSachChuong extends State<CourseChapterList> {
  late final lessons = widget.service.lessons(widget.course.id);
  late final progress = widget.service.progress(widget.uid, widget.course.id);
  late final Future<String?> courseExamTitle = _loadCourseExamTitle();

  Future<String?> _loadCourseExamTitle() async {
    final courseData = widget.course.data();
    final examId = (courseData['examId'] ?? '').toString().trim();
    final fallback = (courseData['examTitle'] ?? 'Bài kiểm tra cuối khóa')
        .toString();
    if (!widget.includeExamLessons ||
        !CourseForm.hasExam(courseData) ||
        examId.isEmpty) {
      return fallback;
    }

    final examService = widget.examService;
    try {
      final response = await (examService ?? SecureExamService()).call(
        'examList',
      );
      final exams = response['exams'];
      if (exams is Iterable) {
        for (final exam in exams) {
          if (exam is Map && exam['id'] == examId) {
            final title = exam['title']?.toString().trim() ?? '';
            if (title.isNotEmpty) return title;
          }
        }
      }
    } catch (_) {
      // Keep the course visible if this title lookup is temporarily unavailable.
    }
    return fallback;
  }

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
            examService: widget.examService,
            courseData: widget.course.data(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => LearningList(
    stream: lessons,
    errorTitle: 'Tải nội dung khóa học',
    builder: (allDocs) {
      final courseData = widget.course.data();
      final records = LearningPolicy.sortLessons(allDocs);
      final explicitCourseMode =
          courseData['learningMode'] == 'study_only' ||
          courseData['learningMode'] == 'study_exam';
      final visibleRecords = widget.includeExamLessons
          ? records
          : records
                .where(
                  (record) => explicitCourseMode
                      ? !CourseForm.hasExam(courseData)
                      : !LearningPolicy.requiresExam(courseData, record.data()),
                )
                .toList();
      return _progress(visibleRecords);
    },
  );

  Widget _progress(List<LessonDoc> records) => LearningList(
    stream: progress,
    errorTitle: 'Tải tiến độ nội dung khóa học',
    builder: (progressDocs) {
      final completed = progressDocs
          .where((record) => LearningPolicy.hasCompletedStudy(record.data()))
          .map((record) => record.data()['lessonId']?.toString())
          .whereType<String>()
          .toSet();
      final courseData = widget.course.data();
      final courseExamId = (courseData['examId'] ?? '').toString().trim();
      final hasCourseExam =
          widget.includeExamLessons && CourseForm.hasExam(courseData);
      final examCompletedLessonIds = progressDocs
          .where((record) {
            final data = record.data();
            return data['completed'] == true &&
                data['examCompleted'] == true &&
                data['completedExamId'] == courseExamId;
          })
          .map((record) => record.data()['lessonId']?.toString())
          .whereType<String>()
          .toSet();
      final examCompleted =
          hasCourseExam &&
          courseExamId.isNotEmpty &&
          records.isNotEmpty &&
          records.every((record) => examCompletedLessonIds.contains(record.id));
      final examUnlocked =
          records.isNotEmpty &&
          records.every((record) => completed.contains(record.id));
      final totalSteps = records.length + (hasCourseExam ? 1 : 0);
      final completedSteps =
          records.where((record) => completed.contains(record.id)).length +
          (examCompleted ? 1 : 0);
      final displayedCompletion = totalSteps == 0
          ? 0.0
          : completedSteps / totalSteps;
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
                'Tiến độ học tập',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${(displayedCompletion * 100).round()}% Hoàn thành',
                style: const TextStyle(color: AppTheme.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: displayedCompletion),
          const SizedBox(height: 16),
          if (records.isEmpty) const Text('Chưa có bài học.'),
          if (records.isNotEmpty && (nextIndex >= 0 || !hasCourseExam))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => open(
                  context,
                  records,
                  nextIndex >= 0 ? nextIndex : records.length - 1,
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(nextIndex < 0 ? 'Ôn tập lại' : 'Tiếp tục học'),
              ),
            ),
          for (final lesson in records)
            Card(child: _lessonTile(lesson, records, completed, nextIndex)),
          if (hasCourseExam && records.isNotEmpty)
            FutureBuilder<String?>(
              future: courseExamTitle,
              builder: (context, snapshot) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.assignment_outlined,
                    color: AppTheme.red,
                  ),
                  title: Text(snapshot.data ?? 'Bài kiểm tra cuối khóa'),
                  subtitle: Text(
                    examCompleted
                        ? 'Đã hoàn thành'
                        : examUnlocked
                        ? 'Chưa làm bài kiểm tra'
                        : 'Hoàn thành các bài học để mở khóa',
                  ),
                  trailing: Icon(
                    examCompleted
                        ? Icons.check_circle_outline
                        : examUnlocked && courseExamId.isNotEmpty
                        ? Icons.chevron_right
                        : Icons.lock_outline,
                    color: examCompleted ? Colors.green : null,
                  ),
                  onTap: !examUnlocked || courseExamId.isEmpty
                      ? null
                      : () => open(context, records, records.length - 1),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _lessonTile(
    LessonDoc lesson,
    List<LessonDoc> records,
    Set<Object?> completed,
    int nextIndex,
  ) {
    final data = lesson.data();
    final index = records.indexOf(lesson);
    final done = completed.contains(lesson.id);
    final unlocked = done || index <= nextIndex;
    final courseMode = widget.course.data()['learningMode'] == 'study_only';
    final seconds = (data['minimumStudySeconds'] as num? ?? 300).toInt();
    final order = data['order'] ?? records.indexOf(lesson) + 1;
    return ListTile(
      leading: CourseCover(
        url:
            data['coverUrl'] ??
            (data['type'] == 'image' ? data['url'] ?? '' : ''),
        width: 40,
        height: 44,
      ),
      trailing: Icon(
        !unlocked
            ? Icons.lock_outline
            : done
            ? Icons.check_circle_outline
            : Icons.play_circle_outline,
        color: !unlocked
            ? Colors.blueGrey
            : done
            ? Colors.green
            : AppTheme.red,
        size: 18,
      ),
      title: Text(
        data['title'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        'Bài $order • ${courseMode ? CourseForm.studyOnlyLabel : LessonForm.modeLabel(data)} • ${!unlocked
            ? 'Hoàn thành bài trước để mở khóa'
            : done
            ? 'Đã học'
            : '$seconds giây • Chưa học'}',
      ),
      onTap: unlocked ? () => open(context, records, index) : null,
    );
  }
}
