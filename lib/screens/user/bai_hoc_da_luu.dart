// APP HỌC VIÊN: Danh sách bài học đã hoàn thành/lưu để mở lại nội dung.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/bieu_mau_khoa_hoc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
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
  late final courses = widget.service.courses(classId: '');
  late final progress = widget.service.db
      .collection('users')
      .doc(widget.uid)
      .collection('learning')
      .where('completed', isEqualTo: true)
      .snapshots();

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> load(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacKhoaHoc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacMauTin,
  ) async {
    final cacMuc = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final khoaHoc in cacKhoaHoc) {
      final daXong = {
        for (final mauTin in cacMauTin)
          if (mauTin.data()['courseId'] == khoaHoc.id)
            mauTin.data()['lessonId'],
      };
      if (daXong.isEmpty || LearningPolicy.requiresExam(khoaHoc.data(), {})) {
        continue;
      }
      final cacBaiHoc = await widget.service.db
          .collection('courses')
          .doc(khoaHoc.id)
          .collection('lessons')
          .orderBy('order')
          .get();
      final studyLessons = cacBaiHoc.docs
          .where(
            (baiHoc) =>
                !LearningPolicy.requiresExam(khoaHoc.data(), baiHoc.data()),
          )
          .toList();
      if (studyLessons.isEmpty ||
          !studyLessons.every((baiHoc) => daXong.contains(baiHoc.id))) {
        continue;
      }
      cacMuc.add(khoaHoc);
    }
    return cacMuc;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Bài đã lưu')),
    body: LearningList(
      stream: courses,
      builder: (cacKhoaHoc) => LearningList(
        stream: progress,
        builder: (cacMauTin) => FutureBuilder(
          future: load(cacKhoaHoc, cacMauTin),
          builder: (context, duLieuNhan) {
            if (duLieuNhan.hasError) {
              return const Center(
                child: Text('Chưa tải được bài đã lưu. Hãy mở lại để thử lại.'),
              );
            }
            if (!duLieuNhan.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cacMuc = duLieuNhan.data!;
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
                        'Đã hoàn thành • Nhấn để xem bài học${CourseForm.formatReleaseDateTime(khoaHoc.data()['publishedAt']).isEmpty ? '' : ' • Phát hành: ${CourseForm.formatReleaseDateTime(khoaHoc.data()['publishedAt'])}'}',
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
        ),
      ),
    ),
  );
}
