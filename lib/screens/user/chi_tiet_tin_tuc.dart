import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bai_viet_tin_tuc.dart';
import '../../services/nghiep_vu/dich_vu_tin_tuc.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/hien_thi_noi_dung_bai_hoc.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({super.key, required this.id, required this.service});
  final String id;
  final NewsService service;
  @override
  State<NewsDetailScreen> createState() => _TrangThaiChiTietTinTuc();
}

class _TrangThaiChiTietTinTuc extends State<NewsDetailScreen> {
  late final article = widget.service.db
      .collection('news')
      .doc(widget.id)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: article,
        builder: (context, duLieuNhan) {
          final duLieu = duLieuNhan.data?.data();
          final visible = !duLieuNhan.hasError && duLieu?['published'] == true;
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: LearnerHeader(
              title: const Text('Tin tức'),
              backgroundColor: AppTheme.red,
            ),
            body: !duLieuNhan.hasData && !duLieuNhan.hasError
                ? const Center(child: CircularProgressIndicator())
                : !visible
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Bài viết không còn được đăng hoặc chưa thể tải. Vui lòng quay lại danh sách.',
                      ),
                    ),
                  )
                : _noiDung(NewsArticle(widget.id, duLieu!)),
          );
        },
      );

  Widget _noiDung(NewsArticle baiViet) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            baiViet.category.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.red,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            baiViet.title,
            style: const TextStyle(
              fontSize: 25,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            baiViet.timeLabel(),
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 18),
          if (baiViet.summary.isNotEmpty) ...[
            SelectableText(
              baiViet.summary,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.6),
            ),
            const SizedBox(height: 18),
          ],
          if (baiViet.coverUrl.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CourseCover(url: baiViet.coverUrl, width: double.infinity),
            ),
            const SizedBox(height: 20),
          ],
          LessonContentRenderer(content: baiViet.content),
        ],
      ),
    ),
  );
}
