// XỬ LÝ DỮ LIỆU / API: Đọc/ghi tài khoản, đề thi, câu hỏi và lượt thi; chuyển thao tác tài khoản sang API.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/mo_hinh_cau_hoi.dart';
import '../../models/mo_hinh_cau_tra_loi.dart';
import '../../models/phien_lam_bai_kiem_tra.dart';
import '../../models/du_lieu_nhap_hoc_vien.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../ket_noi_api/api_tai_khoan.dart';
import '../tai_khoan/xac_thuc_tai_khoan.dart';
import 'lo_ghi_firestore.dart';
import '../../app/cau_hinh_ung_dung.dart';

part 'thao_tac_bai_kiem_tra_firestore.dart';
part 'thao_tac_tai_khoan_firestore.dart';
part 'thao_tac_bao_tri_firestore.dart';

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
