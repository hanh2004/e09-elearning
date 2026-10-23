import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';
import '../models/bieu_mau_khoa_hoc.dart';
import 'anh_bia_khoa_hoc.dart';

/// Thẻ khóa học dùng chung trong thư viện học tập và mục kiểm tra.
class LearnerCourseCard extends StatelessWidget {
  const LearnerCourseCard({
    super.key,
    required this.courseData,
    required this.lessonCount,
    required this.status,
    required this.statusColor,
    required this.trailing,
    this.onTap,
    this.subjectMaxLines,
  });

  final Map<String, dynamic> courseData;
  final int lessonCount;
  final String status;
  final Color statusColor;
  final Widget trailing;
  final VoidCallback? onTap;
  final int? subjectMaxLines;

  @override
  Widget build(BuildContext context) {
    final releaseDate = CourseForm.formatReleaseDateTime(
      courseData['publishedAt'],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseCover(
                url: courseData['coverUrl'] ?? '',
                width: 86,
                height: 100,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (courseData['subject'] as String? ?? '').toUpperCase(),
                      maxLines: subjectMaxLines,
                      overflow: subjectMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      courseData['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                    if (releaseDate.isNotEmpty)
                      Text(
                        releaseDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          lessonCount == 0
                              ? 'Chưa có bài học'
                              : '$lessonCount bài học',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(fontSize: 11, color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bộ lọc môn học đặt dưới ô tìm kiếm của các danh sách khóa học.
class LearnerSubjectFilter extends StatelessWidget {
  const LearnerSubjectFilter({
    super.key,
    required this.subjects,
    required this.selected,
    required this.onSelected,
  });

  final List<String> subjects;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in <String?>[null, ...subjects])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              selected: selected == value,
              selectedColor: AppTheme.red,
              label: Text(
                value ?? 'Tất cả',
                style: TextStyle(
                  color: selected == value ? Colors.white : AppTheme.navy,
                ),
              ),
              onSelected: (_) => onSelected(value),
            ),
          ),
      ],
    ),
  );
}
