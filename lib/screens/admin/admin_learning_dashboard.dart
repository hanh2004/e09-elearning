import '../../models/account_identity.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class AdminLearningDashboard extends StatefulWidget {
  const AdminLearningDashboard({super.key});
  @override
  State<AdminLearningDashboard> createState() => _AdminLearningDashboardState();
}

class _AdminLearningDashboardState extends State<AdminLearningDashboard> {
  final service = LearningService();
  late Future<Map<String, dynamic>> report = load();
  Future<Map<String, dynamic>> load() async {
    final snapshots = await Future.wait([
      service.db.collection('users').where('role', isEqualTo: 'user').get(),
      service.db.collection('courses').get(),
      service.db.collection('exam_attempts').get(),
    ]);
    final students = snapshots[0].docs;
    final courses = snapshots[1].docs;
    final attempts = snapshots[2].docs;
    final lessons = <String, Set<String>>{};
    for (final course in courses) {
      lessons[course.id] = (await course.reference.collection('lessons').get())
          .docs
          .map((d) => d.id)
          .toSet();
    }
    final rows = <Map<String, dynamic>>[];
    for (final student in students) {
      final profile = student.data();
      final progress = await student.reference.collection('learning').get();
      var total = 0;
      var completed = 0;
      for (final course in courses.where(
        (c) => LearningPolicy.canRead(c.data(), profile['classId'] ?? ''),
      )) {
        final ids = lessons[course.id]!;
        total += ids.length;
        completed += progress.docs
            .where(
              (d) =>
                  d.data()['courseId'] == course.id &&
                  d.data()['completed'] == true,
            )
            .map((d) => d.data()['lessonId'])
            .toSet()
            .intersection(ids)
            .length;
      }
      final scores = attempts
          .where(
            (a) =>
                a.data()['userId'] == student.id && a.data()['diemSo'] is num,
          )
          .map((a) => (a.data()['diemSo'] as num).toDouble())
          .toList();
      rows.add({
        'name': profile['name'] ?? '',
        'classId': profile['classId'] ?? '',
        'unit': profile['unit'] ?? '',
        'completed': completed,
        'total': total,
        'average': scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length,
      });
    }
    final scores = attempts
        .where((a) => a.data()['diemSo'] is num)
        .map((a) => (a.data()['diemSo'] as num).toDouble())
        .toList();
    return {
      'students': students.length,
      'courses': courses.length,
      'lessons': lessons.values.fold<int>(
        0,
        (total, ids) => total + ids.length,
      ),
      'attempts': attempts.fold<int>(
        0,
        (total, a) =>
            total +
            ((a.data()['attemptCount'] as num?)?.toInt() ??
                (a.data()['status'] == 'completed' ? 1 : 0)),
      ),
      'average': scores.isEmpty
          ? '—'
          : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(2),
      'rows': rows,
    };
  }

  String search = '';
  bool incomplete = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tổng quan học tập'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => setState(() => report = load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: report,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Không tải được thống kê. Bấm làm mới để thử lại.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final rows = data['rows'] as List<Map<String, dynamic>>;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in {
                  'students': 'Học viên',
                  'courses': 'Khóa học',
                  'lessons': 'Bài học',
                  'attempts': 'Lượt thi',
                  'average': 'Điểm TB tốt nhất',
                }.entries)
                  SizedBox(
                    width: 180,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '${data[entry.key]}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(entry.value),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Lọc học viên, đơn vị',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v.toLowerCase()),
            ),
            SwitchListTile(
              title: const Text('Chỉ học viên chưa hoàn thành'),
              value: incomplete,
              onChanged: (v) => setState(() => incomplete = v),
            ),
            for (final row in rows.where(
              (r) =>
                  '${r['name']} ${r['classId']} ${r['unit']}'
                      .toLowerCase()
                      .contains(search) &&
                  (!incomplete || r['completed'] < r['total']),
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['name']} • ${row['unit']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${row['completed']}/${row['total']} bài học • Điểm TB tốt nhất: ${(row['average'] as double?)?.toStringAsFixed(2) ?? 'Chưa thi'}',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: row['total'] == 0
                            ? 0
                            : row['completed'] / row['total'],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});
  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final service = LearningService();
  late final stream = service.db
      .collection('learning_events')
      .orderBy('startsAt')
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch học và lịch thi')),
    floatingActionButton: AccountSession.current?.isRoot != true
        ? null
        : FloatingActionButton(
            onPressed: () => editLearningRecord(
              context,
              title: 'Tạo lịch',
              fields: {
                'Tiêu đề': '',
                'Loại (lesson/exam)': 'lesson',
                'Bắt đầu (YYYY-MM-DD HH:mm)': '',
                'Kết thúc (YYYY-MM-DD HH:mm)': '',
                'Địa điểm hoặc ghi chú': '',
              },
              optional: {'Địa điểm hoặc ghi chú'},
              save: (v) async {
                final start = DateTime.tryParse(
                  v['Bắt đầu (YYYY-MM-DD HH:mm)']!,
                );
                final end = DateTime.tryParse(
                  v['Kết thúc (YYYY-MM-DD HH:mm)']!,
                );
                if (start == null ||
                    end == null ||
                    !end.isAfter(start) ||
                    !['lesson', 'exam'].contains(v['Loại (lesson/exam)'])) {
                  throw ArgumentError('Lịch không hợp lệ');
                }
                await service.saveContent(
                  AccountSession.current!.id,
                  service.db.collection('learning_events').doc(),
                  {
                    'title': v['Tiêu đề'],
                    'type': v['Loại (lesson/exam)'],
                    'audience': 'all',
                    'startsAt': Timestamp.fromDate(start),
                    'endsAt': Timestamp.fromDate(end),
                    'note': v['Địa điểm hoặc ghi chú'],
                  },
                );
              },
            ),
            child: const Icon(Icons.add),
          ),
    body: LearningList(
      stream: stream,
      builder: (docs) => ListView(
        children: [
          for (final doc in docs)
            ListTile(
              title: Text(doc.data()['title'] ?? ''),
              subtitle: Text(
                '${(doc.data()['startsAt'] as Timestamp).toDate()} • ${doc.data()['audience']}',
              ),
            ),
        ],
      ),
    ),
  );
}
