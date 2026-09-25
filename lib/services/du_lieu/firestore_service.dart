// XỬ LÝ DỮ LIỆU / API: Đọc/ghi tài khoản, đề thi, câu hỏi và lượt thi; chuyển thao tác tài khoản sang API.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/cau_hoi_model.dart';
import '../../models/cau_tra_loi_model.dart';
import '../../models/exam_attempt_session.dart';
import '../../models/user_import.dart';
import '../../models/account_identity.dart';
import '../../models/learning_policy.dart';
import '../ket_noi_api/account_api.dart';
import '../tai_khoan/account_auth.dart';
import 'firestore_batch.dart';
import '../../app/app_config.dart';

part 'firestore_exam_operations.dart';
part 'firestore_account_operations.dart';
part 'firestore_maintenance_operations.dart';

FirebaseApp? _ungDungCapTaiKhoan;
bool _daCauHinhGiaLapCapTaiKhoan = false;

class AccountProvisioningException implements Exception {
  const AccountProvisioningException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class _FirestoreServiceCore {
  FirebaseFirestore get _coSoDuLieu;
  AccountApi get _apiTaiKhoan;
  FirebaseFirestore get db;

  Future<void> _xoaCacLuotThi(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
  ) async {
    for (final luotThi in cacLuotThi) {
      final cacLanThi = await luotThi.reference.collection('runs').get();
      await deleteFirestoreDocuments(
        _coSoDuLieu,
        cacLanThi.docs.map((lanThi) => lanThi.reference),
        batchSize: 400,
      );
    }
  }
}

class FirestoreService extends _FirestoreServiceCore
    with
        _FirestoreExamOperations,
        _FirestoreAccountOperations,
        _FirestoreMaintenanceOperations {
  FirestoreService({FirebaseFirestore? firestore, AccountApi? accounts})
    : _coSoDuLieu = firestore ?? FirebaseFirestore.instance,
      _apiTaiKhoan =
          accounts ??
          AccountApi(
            useBackend: firestore == null && AppConfig.useSecureBackend,
          );

  @override
  final FirebaseFirestore _coSoDuLieu;
  @override
  final AccountApi _apiTaiKhoan;
  @override
  FirebaseFirestore get db => _coSoDuLieu;
}
