// GIAO DIỆN DÙNG CHUNG: Thẻ hồ sơ học viên: ảnh đại diện, họ tên và đơn vị.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import '../models/nhan_don_vi.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'anh_dai_dien_mac_dinh.dart';
import 'the_hoc_vien.dart';
import 'thong_bao_loi.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.uid,
    required this.fallbackName,
    this.email = '',
    this.service,
  });
  final String uid;
  final String fallbackName;
  final String email;
  final LearningService? service;
  @override
  State<ProfileCard> createState() => _TrangThaiTheHoSo();
}

class _TrangThaiTheHoSo extends State<ProfileCard> {
  late final service = widget.service ?? LearningService();
  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream() => service.db
      .collection('users')
      .doc(widget.uid)
      .snapshots(includeMetadataChanges: true);
  @override
  Widget build(BuildContext context) =>
      ReloadableStreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        streamFactory: _profileStream,
        feature: 'Tải hồ sơ học viên',
        isUsableData: (data) => data.exists || !data.metadata.isFromCache,
        builder: (context, duLieuNhan) {
          if (!duLieuNhan.hasData) return const LinearProgressIndicator();
          final duLieu = duLieuNhan.data?.data() ?? {};
          final username = (duLieu['username'] as String? ?? '').trim();
          final donVi = (duLieu['unit'] as String? ?? '').trim();
          return LearnerCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const DefaultUserAvatar(radius: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duLieu['name'] as String? ?? widget.fallbackName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.email.isNotEmpty)
                        Text(
                          widget.email,
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      if (username.isNotEmpty)
                        Text(
                          'Tài khoản: $username',
                          style: const TextStyle(
                            color: Color(0xFF8A1C20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (donVi.isNotEmpty)
                        Text(
                          'Đơn vị quản lý: ${duLieu['unit']}',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      if ((duLieu['subUnit'] as String? ?? '').isNotEmpty)
                        Text(
                          'Đơn vị: ${unitLabel(duLieu)}',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
