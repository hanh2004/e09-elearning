// APP HỌC VIÊN: Danh sách khóa học chỉ học đã hoàn thành, có thể mở lại nội dung.

import 'package:flutter/material.dart';

import '../../models/bieu_mau_khoa_hoc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/danh_muc_khoa_hoc_hoc_vien.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'cac_khoa_hoc.dart';

/// Các khóa chỉ học đã hoàn thành được tự động lưu.
class SavedLessonsScreen extends StatefulWidget {
  const SavedLessonsScreen({
    super.key,
    required this.uid,
    required this.service,
  });
  final String uid;
  final LearningService service;

  @override
  State<SavedLessonsScreen> createState() => _TrangThaiBaiHocDaLuu();
}

class _TrangThaiBaiHocDaLuu extends State<SavedLessonsScreen> {
  late final courses = widget.service.courses(publishedOnly: true);
  late final progress = widget.service.watchQuery(
    widget.service.db
        .collection('users')
        .doc(widget.uid)
        .collection('learning')
        .where('completed', isEqualTo: true),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Bài đã lưu')),
    body: LearningList(
      stream: courses,
      errorTitle: 'Tải khóa học đã lưu',
      builder: (cacKhoaHoc) => LearningList(
        stream: progress,
        errorTitle: 'Tải tiến độ bài đã lưu',
        builder: (cacMauTin) {
          final daXongTheoKhoa = <String, Set<String>>{};
          for (final mauTin in cacMauTin) {
            final duLieu = mauTin.data();
            final courseId = duLieu['courseId']?.toString() ?? '';
            final lessonId = duLieu['lessonId']?.toString() ?? '';
            if (courseId.isEmpty || lessonId.isEmpty) continue;
            daXongTheoKhoa.putIfAbsent(courseId, () => {}).add(lessonId);
          }
          return LearnerCourseCatalog(
            courses: cacKhoaHoc
                .where((khoaHoc) => daXongTheoKhoa.containsKey(khoaHoc.id))
                .toList(),
            service: widget.service,
            builder: (entries) {
              final cacMuc = entries
                  .where(
                    (entry) =>
                        !entry.hasExam &&
                        entry.lessons.isNotEmpty &&
                        entry.lessons.every(
                          (baiHoc) => daXongTheoKhoa[entry.course.id]!.contains(
                            baiHoc.id,
                          ),
                        ),
                  )
                  .map((entry) => entry.course)
                  .toList();
              if (cacMuc.isEmpty) {
                return const Center(
                  child: Text('Chưa có khóa học chỉ học nào đã hoàn thành.'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Khóa chỉ học được lưu khi học xong toàn bộ bài. Bạn vẫn có thể mở lại các bài học sau khi admin kết thúc khóa học.',
                  ),
                  const SizedBox(height: 12),
                  for (final khoaHoc in cacMuc)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.menu_book_outlined,
                          color: Colors.green,
                        ),
                        title: Text(
                          khoaHoc.data()['title'] ?? 'Khóa học',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          CourseForm.formatReleaseDateTime(
                            khoaHoc.data()['publishedAt'],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => UserLessonsScreen(
                              uid: widget.uid,
                              course: khoaHoc,
                              service: widget.service,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
