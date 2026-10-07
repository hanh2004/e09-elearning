// XỬ LÝ TÀI KHOẢN HỌC VIÊN: Cập nhật đơn vị trực thuộc và đổi mật khẩu.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import '../ket_noi_api/api_tai_khoan.dart';
import '../thong_bao_loi_ung_dung.dart';

Future<void> updateLearnerUnit(
  BuildContext context, {
  required String uid,
  FirebaseFirestore? firestore,
  AccountApi? accounts,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(uid);
  try {
    final snapshot = await userRef.get();
    if (!context.mounted) return;
    final profile = snapshot.data();
    if (profile == null) {
      _showAccountMessage(context, 'Không tìm thấy hồ sơ học viên.');
      return;
    }

    final unit = (profile['unit'] ?? '').toString().trim();
    if (unit.isEmpty) {
      _showAccountMessage(
        context,
        'Bạn chưa được phân đơn vị. Vui lòng liên hệ quản lý.',
      );
      return;
    }

    final managerId = (profile['createdBy'] ?? '').toString().trim();
    var allowedSubUnits = <String>[];
    if (managerId.isNotEmpty) {
      Map<String, dynamic> choices;
      try {
        choices = await (accounts ?? AccountApi(useBackend: true)).call(
          'accountGetSubUnits',
          {},
        );
      } on FirebaseFunctionsException {
        final manager = await db.collection('users').doc(managerId).get();
        choices = {
          'managerId': manager.id,
          'subUnits': manager.data()?['subUnits'] ?? const [],
        };
      }
      if (!context.mounted) return;
      if (choices['managerId'] != managerId) {
        _showAccountMessage(
          context,
          'Đơn vị vừa thay đổi. Hãy mở lại mục cập nhật đơn vị.',
        );
        return;
      }
      allowedSubUnits =
          ((choices['subUnits'] as List?) ?? const [])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
    }

    final field = 'Đơn vị trực thuộc (tổ/đội/bộ phận)';
    final currentSubUnit = (profile['subUnit'] ?? '').toString().trim();
    await editLearningRecord(
      context,
      title: 'Cập nhật đơn vị',
      fields: {
        field:
            allowedSubUnits.isNotEmpty &&
                !allowedSubUnits.contains(currentSubUnit)
            ? allowedSubUnits.first
            : currentSubUnit,
      },
      selectFields: allowedSubUnits.isEmpty
          ? const {}
          : {field: allowedSubUnits},
      maxLengths: {field: 200},
      note: 'Đơn vị quản lý: $unit. Bạn chỉ cập nhật phần đơn vị trực thuộc.',
      save: (values) async {
        await db.runTransaction((transaction) async {
          final latest = (await transaction.get(userRef)).data();
          if (latest == null ||
              latest['unit'] != profile['unit'] ||
              latest['createdBy'] != profile['createdBy'] ||
              (latest['unitAssignmentVersion'] ?? 0) !=
                  (profile['unitAssignmentVersion'] ?? 0)) {
            throw ArgumentError(
              'Đơn vị vừa thay đổi. Hãy đóng biểu mẫu và mở lại.',
            );
          }
          transaction.update(userRef, {
            'subUnit': values[field]!.trim(),
            'unitNeedsConfirmation': false,
            'unitConfirmedVersion': latest['unitAssignmentVersion'] ?? 0,
            'unitConfirmedAt': FieldValue.serverTimestamp(),
          });
        });
      },
    );
  } catch (error) {
    if (context.mounted) {
      _showAccountMessage(
        context,
        AppErrorMessage.from(
          error,
          feature: 'Cập nhật đơn vị trực thuộc',
          fallbackAction:
              'Kiểm tra kết nối mạng, quyền tài khoản và cấu hình máy chủ rồi thử lại.',
        ),
      );
    }
  }
}

Future<void> changeLearnerPassword(BuildContext context) async {
  await editLearningRecord(
    context,
    title: 'Đổi mật khẩu',
    fields: {
      'Mật khẩu hiện tại': '',
      'Mật khẩu mới': '',
      'Nhập lại mật khẩu mới': '',
    },
    save: (values) async {
      final newPassword = values['Mật khẩu mới']!;
      if (newPassword.length < 6 ||
          newPassword != values['Nhập lại mật khẩu mới']) {
        throw ArgumentError('Mật khẩu mới không hợp lệ hoặc chưa trùng khớp.');
      }
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        throw StateError('Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email,
          password: values['Mật khẩu hiện tại']!,
        ),
      );
      await user.updatePassword(newPassword);
    },
  );
}

void _showAccountMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
