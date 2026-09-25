import 'package:flutter_test/flutter_test.dart';
import 'package:e09_elearning/models/course_completion_report.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';

void main() {
  final end = DateTime(2026, 9, 11, 12);
  test('server-finalized exams at the exact deadline count, late completion does not', () {
    final report = CourseCompletionReport.build(
      users: {'onTime': {'role':'user'}, 'late': {'role':'user'}, 'readOnly': {'role':'user'}},
      lessonIds: {'l'},
      progress: {
        for (final uid in ['onTime', 'late', 'readOnly']) uid: [{
          'courseId':'c', 'lessonId':'l', 'completed':true,
          'examCompleted': uid != 'readOnly', 'completedExamId':'e',
          'completedAt': uid == 'late' ? end.add(const Duration(milliseconds: 1)) : end,
        }],
      },
      courseId: 'c', endsAt: end,
      course: {'learningMode':'study_exam', 'examId':'e'},
    );
    expect(report.rows.singleWhere((row) => row.id == 'onTime').done, true);
    expect(report.rows.singleWhere((row) => row.id == 'late').done, false);
    expect(report.rows.singleWhere((row) => row.id == 'readOnly').done, false);
  });
  test(
    'end boundary locks even stopped courses; scheduled courses are unreadable',
    () {
      final course = {
        'published': true,
        'startsAt': end.subtract(const Duration(hours: 1)),
        'endsAt': end,
      };
      expect(
        LearningPolicy.canRead(
          course,
          '',
          now: end.subtract(const Duration(hours: 2)),
        ),
        false,
      );
      expect(
        LearningPolicy.canRead(
          course,
          '',
          now: end.subtract(const Duration(seconds: 1)),
        ),
        true,
      );
      expect(LearningPolicy.hasEnded(course, now: end), true);
      expect(LearningPolicy.canRead(course, '', now: end), false);
      expect(
        LearningPolicy.deploymentLabel({
          ...course,
          'published': false,
        }, now: end),
        'Đã triển khai',
      );
    },
  );
  test('counts complete, partial, late and absent learners by effective parent unit', () {
    final users = <String, Map<String, dynamic>>{
      'a': {'role': 'admin', 'unit': 'D1'},
      'b': {'role': 'admin', 'unit': 'D2'},
      for (final id in ['done', 'partial', 'late', 'absent'])
        id: {
          'role': 'user',
          'name': id,
          'createdBy': id == 'absent' ? 'b' : 'a',
          'unit': 'old',
        },
      'new': {'role': 'user', 'createdAt': end},
      'deleted': {'role': 'user', 'status': 'deleted'},
    };
    Map<String, dynamic> record(String lesson, {DateTime? at}) => {
      'courseId': 'c',
      'lessonId': lesson,
      'completed': true,
      'startedAt': end.subtract(const Duration(minutes: 5)),
      'completedAt': at ?? end.subtract(const Duration(minutes: 1)),
    };
    final progress = {
      'done': [record('1'), record('2'), record('2'), record('deleted')],
      'partial': [record('1')],
      'late': [
        record('1'),
        record('2', at: end.add(const Duration(seconds: 1))),
      ],
    };
    final report = CourseCompletionReport.build(
      users: users,
      lessonIds: {'1', '2'},
      progress: progress,
      courseId: 'c',
      endsAt: end,
    );
    expect(report.rows.length, 4);
    expect(report.completed, 1);
    expect(report.incomplete, 3);
    expect(report.rows.where((r) => r.unit == 'D1').length, 3);
    expect(report.rows.singleWhere((r) => r.id == 'absent').status, 'Chưa học');
    final own = CourseCompletionReport.build(
      users: users,
      lessonIds: {'1', '2'},
      progress: progress,
      courseId: 'c',
      endsAt: end,
      ownerId: 'a',
    );
    expect(own.rows.length, 3);
    final empty = CourseCompletionReport.build(
      users: users,
      lessonIds: {},
      progress: progress,
      courseId: 'c',
      endsAt: end,
    );
    expect(empty.completed, 0);
  });
}
