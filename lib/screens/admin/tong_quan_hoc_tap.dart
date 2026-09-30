// WEB ADMIN: Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/bo_loc_bao_cao_quan_tri.dart';

class _LessonDefinition {
  const _LessonDefinition(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class _CourseDefinition {
  const _CourseDefinition({
    required this.id,
    required this.title,
    required this.data,
    required this.lessons,
  });

  final String id;
  final String title;
  final Map<String, dynamic> data;
  final List<_LessonDefinition> lessons;

  bool get hasExam =>
      LearningPolicy.requiresExam(data, const {}) ||
      lessons.any((lesson) => LearningPolicy.requiresExam(data, lesson.data));
}

class _CourseProgress {
  const _CourseProgress({
    required this.course,
    required this.started,
    required this.completed,
    required this.contentComplete,
    required this.examComplete,
  });

  final _CourseDefinition course;
  final bool started;
  final bool completed;
  final bool contentComplete;
  final bool examComplete;
}

class _StudentProgress {
  const _StudentProgress({
    required this.id,
    required this.name,
    required this.classId,
    required this.unit,
    required this.subUnit,
    required this.courses,
  });

  final String id;
  final String name;
  final String classId;
  final String unit;
  final String subUnit;
  final List<_CourseProgress> courses;

  _StudentProgress withCourses(List<_CourseProgress> value) => _StudentProgress(
    id: id,
    name: name,
    classId: classId,
    unit: unit,
    subUnit: subUnit,
    courses: value,
  );
}

class _LearningReport {
  const _LearningReport({required this.courses, required this.students});

  final List<_CourseDefinition> courses;
  final List<_StudentProgress> students;
}

/// Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
class AdminLearningDashboard extends StatefulWidget {
  const AdminLearningDashboard({super.key, required this.reportData});
  final AdminReportData reportData;
  @override
  State<AdminLearningDashboard> createState() =>
      _TrangThaiTongQuanHocTapQuanTri();
}

class _TrangThaiTongQuanHocTapQuanTri extends State<AdminLearningDashboard> {
  static const _courseTypes = <(String, String)>[
    ('study_exam', 'Khóa học có kiểm tra'),
    ('study_only', 'Khóa học không kiểm tra'),
  ];

  final searchController = TextEditingController();
  AdminReportData? _reportInputs;
  Future<_LearningReport>? _report;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_LearningReport> _load(AdminReportData data) async {
    final cacHocVien = data.users
        .where((user) => user.data()['role'] == 'user')
        .toList();
    final courses = <_CourseDefinition>[];
    for (final course in data.visibleCourses) {
      final lessons = await course.reference.collection('lessons').get();
      courses.add(
        _CourseDefinition(
          id: course.id,
          title: (course.data()['title'] ?? 'Khóa học').toString(),
          data: course.data(),
          lessons: [
            for (final lesson in lessons.docs)
              _LessonDefinition(lesson.id, lesson.data()),
          ],
        ),
      );
    }

    final students = <_StudentProgress>[];
    for (final hocVien in cacHocVien) {
      final hoSo = hocVien.data();
      final records = (await hocVien.reference.collection('learning').get())
          .docs
          .map((record) => record.data())
          .toList();
      final courseProgress = <_CourseProgress>[];

      for (final course in courses.where(
        (course) => LearningPolicy.canRead(course.data, hoSo['classId'] ?? ''),
      )) {
        final progressByLesson = {
          for (final record in records)
            if (record['courseId'] == course.id && record['lessonId'] != null)
              record['lessonId'].toString(): record,
        };
        var started = false;
        var contentComplete = course.lessons.isNotEmpty;
        var examComplete = course.lessons.isNotEmpty;
        for (final lesson in course.lessons) {
          final progress = progressByLesson[lesson.id] ?? const {};
          final requiresExam = LearningPolicy.requiresExam(
            course.data,
            lesson.data,
          );
          final studyComplete = LearningPolicy.hasCompletedStudy(progress);
          final lessonComplete = requiresExam
              ? LearningPolicy.isLessonComplete(
                  progress,
                  course.data,
                  lesson.data,
                )
              : studyComplete;
          contentComplete = contentComplete && studyComplete;
          if (requiresExam) {
            examComplete = examComplete && lessonComplete;
          }
          started =
              started ||
              LearningPolicy.readDateTime(progress['startedAt']) != null ||
              studyComplete ||
              progress['examCompleted'] == true;
        }
        final completed = contentComplete && (!course.hasExam || examComplete);
        courseProgress.add(
          _CourseProgress(
            course: course,
            started: started,
            completed: completed,
            contentComplete: contentComplete,
            examComplete: course.hasExam && examComplete,
          ),
        );
      }

      students.add(
        _StudentProgress(
          id: hocVien.id,
          name: (hoSo['name'] ?? hoSo['username'] ?? '').toString(),
          classId: (hoSo['classId'] ?? '').toString(),
          unit: (hoSo['unit'] ?? '').toString(),
          subUnit: (hoSo['subUnit'] ?? '').toString(),
          courses: courseProgress,
        ),
      );
    }
    return _LearningReport(courses: courses, students: students);
  }

  Future<_LearningReport> _loadFor(AdminReportData data) {
    if (_report == null ||
        !(_reportInputs?.hasSameLearningInputs(data) ?? false)) {
      _reportInputs = data;
      _report = _load(data);
    }
    return _report!;
  }

  void _refresh(AdminReportData data) => setState(() {
    _reportInputs = null;
    _report = null;
  });

  Widget _summaryMetrics({required int inScope, required int notStarted}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 2 : 1;
          final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  value: '$inScope',
                  label: 'Học viên trong phạm vi',
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF1687F8),
                ),
              ),
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  value: '$notStarted',
                  label: 'Chưa bắt đầu khóa nào',
                  icon: Icons.person_outline,
                  color: const Color(0xFFFF7900),
                ),
              ),
            ],
          );
        },
      );

  Widget _filterBar({
    required List<String> units,
    required List<String> subUnits,
    required String? selectedUnit,
    required String? selectedSubUnit,
    required List<(String, String)> courses,
    required String? selectedCourse,
    required String? selectedCourseType,
  }) => AdminCard(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: AdminReportFilters(
        units: units,
        subUnits: subUnits,
        selectedUnit: selectedUnit,
        selectedSubUnit: selectedSubUnit,
        searchController: searchController,
        searchLabel: 'Tìm học viên, đơn vị, khóa học',
        onUnitChanged: (value) => setState(() {
          unitFilter = value;
          subUnitFilter = null;
        }),
        onSubUnitChanged: (value) => setState(() => subUnitFilter = value),
        onSearchChanged: (value) =>
            setState(() => search = value.toLowerCase()),
        courses: courses,
        selectedCourse: selectedCourse,
        onCourseChanged: (value) => setState(() => courseFilter = value),
        courseTypes: _courseTypes,
        selectedCourseType: selectedCourseType,
        onCourseTypeChanged: (value) => setState(() {
          courseTypeFilter = value;
          courseFilter = null;
        }),
        trailing: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chỉ học viên chưa hoàn thành khóa học'),
          value: incomplete,
          onChanged: (value) => setState(() => incomplete = value),
        ),
      ),
    ),
  );

  Widget _studentsTable(
    List<_StudentProgress> rows,
    Map<String, double> scoresByUser,
  ) => AdminCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4F1FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  color: Color(0xFF1687F8),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tiến độ học viên',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 900
                  ? 900.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.8),
                      2: FlexColumnWidth(3.2),
                      3: FlexColumnWidth(1.5),
                    },
                    border: const TableBorder(
                      horizontalInside: BorderSide(color: AdminUi.border),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F4F9),
                        ),
                        children: [
                          _tableCell(const Text('Học viên'), header: true),
                          _tableCell(const Text('Đơn vị'), header: true),
                          _tableCell(
                            const Text('Tiến độ khóa học'),
                            header: true,
                          ),
                          _tableCell(const Text('Kết quả thi'), header: true),
                        ],
                      ),
                      for (final row in rows)
                        _studentTableRow(row, scoresByUser),
                    ],
                  ),
                ),
              );
            },
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Không có học viên phù hợp bộ lọc.')),
            ),
        ],
      ),
    ),
  );

  Widget _tableCell(Widget child, {bool header = false}) => Container(
    constraints: BoxConstraints(minHeight: header ? 46 : 76),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: header ? const Color(0xFF687996) : AppTheme.navy,
        fontSize: header ? 14 : 15,
        fontWeight: header ? FontWeight.w700 : FontWeight.w500,
      ),
      child: child,
    ),
  );

  TableRow _studentTableRow(
    _StudentProgress row,
    Map<String, double> scoresByUser,
  ) {
    final name = row.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    const avatarColors = [
      Color(0xFFE1F0FF),
      Color(0xFFECE5FF),
      Color(0xFFD9F4E8),
      Color(0xFFFFE9DB),
    ];
    final avatarColor =
        avatarColors[(name.hashCode & 0x7fffffff) % avatarColors.length];
    final total = row.courses.length;
    final completed = row.courses.where((course) => course.completed).length;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final score = scoresByUser[row.id];
    final result = score == null
        ? 'Chưa thi'
        : 'Đã thi • ${score.toStringAsFixed(1)}';
    final unit = row.unit.trim();
    final subUnit = row.subUnit.trim();
    final unitLabel = [
      unit,
      subUnit,
    ].where((part) => part.isNotEmpty).join(' · ');

    return TableRow(
      children: [
        _tableCell(
          InkWell(
            onTap: () => _showStudentProgress(row),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF1687F8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF164078)),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new,
                  size: 15,
                  color: Color(0xFF7185A5),
                ),
              ],
            ),
          ),
        ),
        _tableCell(Text(unitLabel.isEmpty ? 'Chưa phân đơn vị' : unitLabel)),
        _tableCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$completed/$total khóa học'),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        color: const Color(0xFF1687F8),
                        backgroundColor: const Color(0xFFE4E8EF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 34,
                    child: Text('$percent%', textAlign: TextAlign.end),
                  ),
                ],
              ),
            ],
          ),
        ),
        _tableCell(
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: score == null
                    ? const Color(0xFFE9ECF1)
                    : const Color(0xFFE2F4EA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                result,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: score == null
                      ? const Color(0xFF535B67)
                      : const Color(0xFF247347),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showStudentProgress(_StudentProgress student) {
    final chuaHocBaiNao = student.courses.every((course) => !course.started);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.name.isEmpty ? 'Chi tiết học viên' : student.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 440),
          child: chuaHocBaiNao
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Học viên này chưa bắt đầu khóa học nào (chưa học bài nào).',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: student.courses.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final progress = student.courses[index];
                    final examRequired = progress.course.hasExam;
                    final color = progress.completed
                        ? const Color(0xFF159B43)
                        : progress.started
                        ? const Color(0xFFFF7900)
                        : const Color(0xFF7185A5);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                progress.course.title,
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              examRequired ? 'Có kiểm tra' : 'Không kiểm tra',
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          progress.completed
                              ? 'Khóa học đã hoàn thành.'
                              : progress.started
                              ? 'Khóa học chưa hoàn thành.'
                              : 'Chưa bắt đầu khóa học này.',
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          examRequired
                              ? progress.examComplete
                                    ? 'Kiểm tra: Đã hoàn thành.'
                                    : progress.contentComplete
                                    ? 'Cần hoàn thành bài kiểm tra để tính khóa học.'
                                    : 'Cần hoàn tất nội dung và bài kiểm tra.'
                              : 'Khóa học không yêu cầu kiểm tra.',
                          style: const TextStyle(
                            color: Color(0xFF60779A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String search = '';
  bool incomplete = false;
  String? unitFilter;
  String? subUnitFilter;
  String? courseTypeFilter;
  String? courseFilter;
  @override
  Widget build(BuildContext context) => _dungBang(widget.reportData);

  Widget _dungBang(AdminReportData data) => FutureBuilder<_LearningReport>(
    future: _loadFor(data),
    builder: (context, duLieuNhan) {
      if (duLieuNhan.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tải được thống kê.'),
              TextButton(
                onPressed: () => _refresh(data),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }
      if (!duLieuNhan.hasData) {
        return const AdminLoading();
      }

      final report = duLieuNhan.data!;
      final cacDonVi =
          report.students
              .map((student) => student.unit.trim())
              .where((unit) => unit.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final selectedUnit = cacDonVi.contains(unitFilter) ? unitFilter : null;
      final subUnits =
          report.students
              .where((student) => student.unit == selectedUnit)
              .map((student) => student.subUnit.trim())
              .where((subUnit) => subUnit.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final selectedSubUnit = subUnits.contains(subUnitFilter)
          ? subUnitFilter
          : null;
      final selectedCourseType =
          _courseTypes.any((option) => option.$1 == courseTypeFilter)
          ? courseTypeFilter
          : null;
      final availableCourses = report.courses.where((course) {
        if (selectedCourseType == 'study_exam') return course.hasExam;
        if (selectedCourseType == 'study_only') return !course.hasExam;
        return true;
      }).toList();
      final selectedCourse =
          availableCourses.any((course) => course.id == courseFilter)
          ? courseFilter
          : null;
      final selectedCourseDefinitions = selectedCourse == null
          ? availableCourses
          : availableCourses
                .where((course) => course.id == selectedCourse)
                .toList();
      final selectedCourseIds = {
        for (final course in selectedCourseDefinitions) course.id,
      };
      final courseOptions = [
        for (final course in availableCourses) (course.id, course.title),
      ];

      final scopeRows = report.students
          .map((student) {
            final studentCourses = student.courses
                .where(
                  (progress) => selectedCourseIds.contains(progress.course.id),
                )
                .toList();
            final searchText =
                '${student.name} ${student.classId} ${student.unit} ${student.subUnit} '
                        '${studentCourses.map((progress) => progress.course.title).join(' ')}'
                    .toLowerCase();
            if (studentCourses.isEmpty ||
                (selectedUnit != null && student.unit != selectedUnit) ||
                (selectedSubUnit != null &&
                    student.subUnit != selectedSubUnit) ||
                !searchText.contains(search)) {
              return null;
            }
            return student.withCourses(studentCourses);
          })
          .whereType<_StudentProgress>()
          .toList();

      final filteredRows = incomplete
          ? scopeRows
                .where(
                  (student) =>
                      student.courses.any((course) => !course.completed),
                )
                .toList()
          : scopeRows;
      final notStarted = scopeRows
          .where(
            (student) => student.courses.every((course) => !course.started),
          )
          .length;
      final selectedCourseTitle = selectedCourse == null
          ? null
          : availableCourses
                .firstWhere((course) => course.id == selectedCourse)
                .title;
      final courseScopeLabel =
          selectedCourseTitle ??
          switch (selectedCourseType) {
            'study_exam' => 'khóa học có kiểm tra',
            'study_only' => 'khóa học không kiểm tra',
            _ => 'tất cả khóa học',
          };

      final examCourseIds = {
        for (final exam in data.visibleExams)
          if ((exam.data()['courseId']?.toString().trim() ?? '').isNotEmpty)
            exam.id: exam.data()['courseId'].toString().trim(),
      };
      final scoresByUser = <String, double>{};
      for (final attempt in data.visibleAttempts) {
        final attemptData = attempt.data();
        final userId = attemptData['userId']?.toString();
        final score = attemptData['diemSo'];
        final rawCourseId = attemptData['courseId']?.toString().trim() ?? '';
        final courseId = rawCourseId.isNotEmpty
            ? rawCourseId
            : examCourseIds[attemptData['examId']?.toString()];
        if (userId != null &&
            score is num &&
            courseId != null &&
            selectedCourseIds.contains(courseId)) {
          final value = score.toDouble();
          scoresByUser.update(
            userId,
            (previous) => previous > value ? previous : value,
            ifAbsent: () => value,
          );
        }
      }
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          AdminPageHeading(
            title: 'Tổng quan học tập',
            subtitle:
                'Theo dõi mức độ hoàn thành khóa học và điều kiện kiểm tra.',
            action: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.red,
                minimumSize: const Size(144, 48),
                side: const BorderSide(color: AppTheme.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _refresh(data),
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _summaryMetrics(
              inScope: scopeRows.length,
              notStarted: notStarted,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _filterBar(
              units: cacDonVi,
              subUnits: subUnits,
              selectedUnit: selectedUnit,
              selectedSubUnit: selectedSubUnit,
              courses: courseOptions,
              selectedCourse: selectedCourse,
              selectedCourseType: selectedCourseType,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E3),
                border: Border.all(color: const Color(0xFFFFE2AE)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFFF7900),
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scopeRows.isEmpty
                              ? 'Không có học viên trong phạm vi lọc'
                              : notStarted == 0
                              ? 'Học viên trong $courseScopeLabel đều đã bắt đầu học'
                              : 'Còn $notStarted học viên chưa bắt đầu khóa nào',
                          style: const TextStyle(
                            color: Color(0xFF28364B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$courseScopeLabel • Phạm vi: ${scopeRows.length} học viên, '
                          '${selectedCourseDefinitions.length} khóa học',
                          style: const TextStyle(color: Color(0xFF60779A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _studentsTable(filteredRows, scoresByUser),
          ),
        ],
      );
    },
  );
}
