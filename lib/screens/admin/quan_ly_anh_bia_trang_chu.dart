import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/anh_bia_trang_chu.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'khung_giao_dien_quan_tri.dart';

class AdminHomeBannersScreen extends StatefulWidget {
  const AdminHomeBannersScreen({super.key, this.service});
  final LearningService? service;

  @override
  State<AdminHomeBannersScreen> createState() => _TrangThaiBannerQuanTri();
}

class _TrangThaiBannerQuanTri extends State<AdminHomeBannersScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.db.collection('home_banners').snapshots();

  Future<void> edit([
    QueryDocumentSnapshot<Map<String, dynamic>>? banGhi,
  ]) async {
    final taiKhoan = AccountSession.current;
    if (taiKhoan?.isRoot != true) return;
    final duLieu = banGhi?.data() ?? <String, dynamic>{};
    final thamChieu =
        banGhi?.reference ?? service.db.collection('home_banners').doc();
    await editLearningRecord(
      context,
      fullPage: true,
      title: banGhi == null ? 'Thêm banner trang chủ' : 'Đổi ảnh banner',
      fields: {
        'title': duLieu['title'] ?? '',
        'order': '${duLieu['order'] ?? 1}',
        'active': duLieu['active'] == false ? 'Không' : 'Có',
      },
      labels: const {
        'title': 'Tên banner (tùy chọn)',
        'order': 'Vị trí (1 đến 5)',
        'active': 'Hiển thị banner',
      },
      optional: const {'title'},
      maxLengths: const {'title': 120},
      selectFields: const {
        'active': ['Có', 'Không'],
      },
      imageFolder: 'home-banners',
      initialImage: duLieu['imageUrl'] as String? ?? '',
      imageRequired: true,
      note: 'Tải ảnh ngang cho banner trang chủ. Tối đa 5 banner đang hiển thị; mỗi ảnh tự chuyển sau 5 giây. Vị trí nhỏ hơn sẽ hiển thị trước.',
      save: (cacGiaTri) async {
        final duLieuGui = HomeBanner.toFirestore(cacGiaTri);
        await thamChieu.set({
          ...duLieuGui,
          'updatedBy': taiKhoan!.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
    );
  }

  Future<void> remove(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    if (AccountSession.current?.isRoot != true) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa banner?'),
        content: const Text('Ảnh sẽ không còn xuất hiện trên trang chủ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) await banGhi.reference.delete();
  }

  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: 'Banner trang chủ',
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      appBar: AdminUi.appBar('Banner trang chủ'),
      body: LearningList(
        stream: stream,
        builder: (cacBanGhi) {
          final sortedDocs = [...cacBanGhi]
            ..sort(
              (a, b) => ((a.data()['order'] as int?) ?? 0).compareTo(
                (b.data()['order'] as int?) ?? 0,
              ),
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                color: const Color(0xFFFFF7D8),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Banner trang chủ gồm tối đa 5 ảnh. Ảnh đang hiển thị sẽ tự chạy 5 giây một lần trên ứng dụng học viên.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (sortedDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có banner. Bấm “Thêm banner” để tải ảnh.'),
                ),
              for (final banGhi in sortedDocs)
                Card(
                  child: ListTile(
                    leading: CourseCover(
                      url: banGhi.data()['imageUrl'] ?? '',
                      width: 100,
                      height: 60,
                    ),
                    title: Text(
                      'Vị trí ${(banGhi.data()['order'] as int?) ?? '-'} • ${banGhi.data()['active'] == false ? 'Đang ẩn' : 'Đang hiện'}',
                    ),
                    subtitle: Text(
                      banGhi.data()['title'] ?? 'Banner trang chủ',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Đổi ảnh banner',
                          onPressed: () => edit(banGhi),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Xóa banner',
                          onPressed: () => remove(banGhi),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: AccountSession.current?.isRoot != true
          ? null
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, duLieuNhan) => FloatingActionButton.extended(
                onPressed: (duLieuNhan.data?.docs.length ?? 0) >= 5
                    ? null
                    : () => edit(),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  (duLieuNhan.data?.docs.length ?? 0) >= 5
                      ? 'Đủ 5 banner'
                      : 'Thêm banner',
                ),
              ),
            ),
    ),
  );
}
