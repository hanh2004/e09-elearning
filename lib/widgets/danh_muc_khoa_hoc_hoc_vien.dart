import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'thong_bao_loi.dart';

typedef LearnerCourseDocument = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Khóa học và toàn bộ bài học hiện tại, kể cả bài cũ thiếu trường order.
class LearnerCourseEntry {
  const LearnerCourseEntry({required this.course, required this.lessons});

  final LearnerCourseDocument course;
  final List<LearnerCourseDocument> lessons;

  bool get hasExam => LearningPolicy.isExamCourse(
    course.data(),
    lessons.map((lesson) => lesson.data()),
  );
}

/// Giữ danh sách, bộ lọc và phân loại khóa đồng bộ khi bài học thay đổi.
class LearnerCourseCatalog extends StatefulWidget {
  const LearnerCourseCatalog({
    super.key,
    required this.courses,
    required this.service,
    required this.builder,
  });

  final List<LearnerCourseDocument> courses;
  final LearningService service;
  final Widget Function(List<LearnerCourseEntry>) builder;

  @override
  State<LearnerCourseCatalog> createState() => _LearnerCourseCatalogState();
}

class _LessonLoad {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
  Timer? timer;
  List<LearnerCourseDocument>? lessons;
  Object? error;

  void cancel() {
    timer?.cancel();
    unawaited(subscription?.cancel());
  }
}

class _LearnerCourseCatalogState extends State<LearnerCourseCatalog> {
  final _loads = <String, _LessonLoad>{};

  @override
  void initState() {
    super.initState();
    _syncCourses();
  }

  @override
  void didUpdateWidget(covariant LearnerCourseCatalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _cancelSubscriptions();
    }
    _syncCourses();
  }

  void _syncCourses() {
    final ids = widget.courses.map((course) => course.id).toSet();
    for (final id in _loads.keys.toList()) {
      if (!ids.contains(id)) {
        _loads.remove(id)?.cancel();
      }
    }
    for (final id in ids) {
      if (_loads.containsKey(id)) continue;
      final load = _LessonLoad();
      _loads[id] = load;
      load.timer = Timer(const Duration(seconds: 20), () {
        if (load.lessons != null) return;
        _showError(
          id,
          load,
          TimeoutException('Chưa tải được bài học từ máy chủ.'),
        );
      });
      try {
        load.subscription = widget.service
            .lessons(id)
            .listen(
              (snapshot) {
                if (!mounted || _loads[id] != load) return;
                load.timer?.cancel();
                setState(() {
                  load.lessons = LearningPolicy.sortLessons(snapshot.docs);
                  load.error = null;
                });
              },
              onError: (Object error) {
                _showError(id, load, error);
              },
              onDone: () {
                if (load.lessons != null || load.error != null) return;
                _showError(
                  id,
                  load,
                  StateError('Chưa nhận được dữ liệu bài học.'),
                );
              },
            );
      } catch (error) {
        _showError(id, load, error);
      }
    }
  }

  void _showError(String id, _LessonLoad load, Object error) {
    if (!mounted || _loads[id] != load) return;
    load.timer?.cancel();
    setState(() => load.error = error);
  }

  void _cancelSubscriptions() {
    final loads = _loads.values.toList();
    _loads.clear();
    for (final load in loads) {
      load.cancel();
    }
  }

  void _retry() => setState(() {
    _cancelSubscriptions();
    _syncCourses();
  });

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final load in _loads.values) {
      if (load.error != null) {
        return AppErrorNotice(
          error: load.error!,
          feature: 'Tải bài học trong khóa học',
          fallbackAction: 'Kiểm tra kết nối và quyền truy cập rồi tải lại.',
          onRetry: _retry,
        );
      }
    }
    if (_loads.values.any((load) => load.lessons == null)) {
      return const Center(
        child: SizedBox(width: 220, child: LinearProgressIndicator()),
      );
    }
    return widget.builder([
      for (final course in widget.courses)
        LearnerCourseEntry(
          course: course,
          lessons: _loads[course.id]!.lessons!,
        ),
    ]);
  }
}
