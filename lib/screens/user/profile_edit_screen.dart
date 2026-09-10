import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/learning_widgets.dart';
import '../../models/unit_label.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.uid, this.firestore});
  final String uid;
  final FirebaseFirestore? firestore;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final ref = (widget.firestore ?? FirebaseFirestore.instance)
      .collection('users')
      .doc(widget.uid);
  late final stream = ref.snapshots();
  Future<void> edit(Map<String, dynamic> data) => editLearningRecord(
    context,
    title: 'Cập nhật hồ sơ',
    fields: {
      'Họ tên': data['name'] ?? '',
      'Đơn vị trực thuộc (tổ/đội/bộ phận)': data['subUnit'] ?? '',
    },
    optional: {'Đơn vị trực thuộc (tổ/đội/bộ phận)'},
    imageFolder: 'avatars/${widget.uid}',
    initialImage: data['avatarUrl'] ?? '',
    note:
        'Đơn vị quản lý được khóa: ${data['unit'] ?? ''}. Chỉ nhập phần đứng trước, ví dụ c1 để thành c1-${data['unit'] ?? ''}.',
    maxLengths: {
      'Họ tên': 100,
      'Đơn vị trực thuộc (tổ/đội/bộ phận)': 200,
    },
    save: (v) => ref.update({
      'name': v['Họ tên'],
      'avatarUrl': v['imageUrl'],
      'subUnit': v['Đơn vị trực thuộc (tổ/đội/bộ phận)'],
    }),
  );
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
        final user = FirebaseAuth.instance.currentUser!;
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: v['Mật khẩu hiện tại']!,
          ),
        );
        await user.updatePassword(v['Mật khẩu mới']!);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ và bảo mật')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không tải được hồ sơ.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data!.data() ?? {};
        final url = d['avatarUrl'] as String? ?? '';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (url.isNotEmpty)
              Center(
                child: ClipOval(
                  child: Image.network(
                    url,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) =>
                        const Icon(Icons.person, size: 96),
                  ),
                ),
              ),
            ListTile(
              title: Text(d['name'] ?? ''),
              subtitle: Text(
                'Đơn vị: ${unitLabel(d)}\nĐơn vị quản lý (khóa): ${d['unit'] ?? 'Chưa phân đơn vị'}',
              ),
            ),
            const Text(
              'Bạn chỉ bổ sung phần đơn vị đứng trước. Phần đơn vị quản lý phía sau do admin tổng phân cho admin phụ và không thể tự sửa.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => edit(d),
              icon: const Icon(Icons.edit),
              label: const Text('Cập nhật hồ sơ'),
            ),
            OutlinedButton.icon(
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
