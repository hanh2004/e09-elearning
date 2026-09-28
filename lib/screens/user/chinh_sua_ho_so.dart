// APP HỌC VIÊN: Chỉnh sửa họ tên, đơn vị trực thuộc và mật khẩu của học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/dau_trang_hoc_vien.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import '../../widgets/the_hoc_vien.dart';
import '../../widgets/anh_dai_dien_mac_dinh.dart';
import '../../models/nhan_don_vi.dart';
import '../../services/ket_noi_api/api_tai_khoan.dart';

/// Chỉnh sửa họ tên, đơn vị trực thuộc và mật khẩu của học viên.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.uid,
    this.firestore,
    this.openEditor = false,
    this.accounts,
  });
  final String uid;
  final FirebaseFirestore? firestore;
  final bool openEditor;
  final AccountApi? accounts;
  @override
  State<ProfileEditScreen> createState() => _TrangThaiSuaHoSo();
}

class _TrangThaiSuaHoSo extends State<ProfileEditScreen> {
  bool _daMoTrinhSua = false;
  late final ref = (widget.firestore ?? FirebaseFirestore.instance)
      .collection('users')
      .doc(widget.uid);
  late final stream = ref.snapshots();
  Future<void> edit(Map<String, dynamic> duLieu) async {
    final managerId = (duLieu['createdBy'] ?? '').toString().trim();
    var allowed = <String>[];
    if (managerId.isNotEmpty) {
      try {
        Map<String, dynamic> cacLuaChon;
        try {
          cacLuaChon = await (widget.accounts ?? AccountApi(useBackend: true))
              .call('accountGetSubUnits', {});
        } on FirebaseFunctionsException {
          final manager = await ref.firestore
              .collection('users')
              .doc(managerId)
              .get();
          cacLuaChon = {
            'managerId': manager.id,
            'subUnits': manager.data()?['subUnits'] ?? const [],
          };
        }
        if (cacLuaChon['managerId'] != managerId) {
          throw StateError('Đơn vị vừa thay đổi.');
        }
        allowed =
            ((cacLuaChon['subUnits'] as List?) ?? const [])
                .whereType<String>()
                .map((giaTri) => giaTri.trim())
                .where((giaTri) => giaTri.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không tải được danh sách trực thuộc. Vui lòng thử lại.',
              ),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final currentSubUnit = (duLieu['subUnit'] ?? '').toString().trim();
    await editLearningRecord(
      context,
      title: 'Cập nhật hồ sơ',
      fields: {
        'Họ tên': duLieu['name'] ?? '',
        'Đơn vị trực thuộc (tổ/đội/bộ phận)':
            allowed.isNotEmpty && !allowed.contains(currentSubUnit)
            ? allowed.first
            : currentSubUnit,
      },
      selectFields: allowed.isEmpty
          ? const {}
          : {'Đơn vị trực thuộc (tổ/đội/bộ phận)': allowed},
      note:
          'Đơn vị quản lý: ${duLieu['unit'] ?? 'Chưa phân đơn vị'}. Chỉ quản lý tổng mới đổi đơn vị quản lý; bạn có thể cập nhật đơn vị trực thuộc bên dưới.',
      maxLengths: {'Họ tên': 100, 'Đơn vị trực thuộc (tổ/đội/bộ phận)': 200},
      save: (v) async {
        await ref.firestore.runTransaction((tx) async {
          final latest = (await tx.get(ref)).data();
          if (latest == null ||
              latest['unit'] != duLieu['unit'] ||
              latest['createdBy'] != duLieu['createdBy'] ||
              (latest['unitAssignmentVersion'] ?? 0) !=
                  (duLieu['unitAssignmentVersion'] ?? 0)) {
            throw ArgumentError(
              'Đơn vị vừa thay đổi. Hãy đóng biểu mẫu và mở lại để cập nhật đơn vị mới.',
            );
          }
          final hasUnit = (latest['unit'] as String? ?? '').trim().isNotEmpty;
          tx.update(ref, {
            'name': v['Họ tên']!.trim(),
            'subUnit': v['Đơn vị trực thuộc (tổ/đội/bộ phận)']!.trim(),
            if (hasUnit) ...{
              'unitNeedsConfirmation': false,
              'unitConfirmedVersion': latest['unitAssignmentVersion'] ?? 0,
              'unitConfirmedAt': FieldValue.serverTimestamp(),
            },
          });
        });
      },
    );
  }

  Future<void> password() async {
    await editLearningRecord(
      context,
      title: 'Đổi mật khẩu',
      fields: {
        'Mật khẩu hiện tại': '',
        'Mật khẩu mới': '',
        'Nhập lại mật khẩu mới': '',
      },
      save: (v) async {
        if (v['Mật khẩu mới']!.length < 6 ||
            v['Mật khẩu mới'] != v['Nhập lại mật khẩu mới']) {
          throw ArgumentError('Mật khẩu không hợp lệ');
        }
        final nguoiDung = FirebaseAuth.instance.currentUser!;
        await nguoiDung.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: nguoiDung.email!,
            password: v['Mật khẩu hiện tại']!,
          ),
        );
        await nguoiDung.updatePassword(v['Mật khẩu mới']!);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Hồ sơ và bảo mật')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError) {
          return const Center(child: Text('Không tải được hồ sơ.'));
        }
        if (!duLieuNhan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = duLieuNhan.data!.data() ?? {};
        if (widget.openEditor && !_daMoTrinhSua) {
          _daMoTrinhSua = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) edit(d);
          });
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LearnerCard(
              accentColor: const Color(0xFFB51F24),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const DefaultUserAvatar(radius: 48),
                  const SizedBox(height: 14),
                  Text(
                    d['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đơn vị: ${unitLabel(d)}',
                    style: const TextStyle(color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Đơn vị quản lý: ${d['unit'] ?? 'Chưa phân đơn vị'}',
                    style: const TextStyle(color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            LearnerCard(
              accentColor: const Color(0xFFD7B558),
              padding: const EdgeInsets.all(16),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF8D6E00)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bạn chỉ bổ sung phần đơn vị đứng trước. Phần đơn vị quản lý phía sau do quản lý tổng phân cho quản lý và không thể tự sửa.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => edit(d),
              icon: const Icon(Icons.edit),
              label: const Text('Cập nhật hồ sơ'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: password,
              icon: const Icon(Icons.lock),
              label: const Text('Đổi mật khẩu'),
            ),
          ],
        );
      },
    ),
  );
}
