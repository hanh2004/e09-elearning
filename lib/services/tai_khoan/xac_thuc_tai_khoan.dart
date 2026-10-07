// XỬ LÝ DỮ LIỆU / API: Đăng nhập/đăng xuất Firebase Auth và đọc hồ sơ tài khoản.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import 'phien_dang_nhap_quan_tri_web.dart';
import '../thong_bao_loi_ung_dung.dart';

String accountLoginEmail(String tenDangNhap) =>
    '${sha256.convert(utf8.encode(tenDangNhap.trim().toLowerCase()))}@accounts.invalid';

/// Chuyển mã lỗi Firebase thành hướng dẫn an toàn để hiển thị trên màn hình.
String accountLoginErrorMessage(Object error) {
  return AppErrorMessage.from(
    error,
    feature: 'Đăng nhập',
    fallbackAction: 'Hãy kiểm tra thông tin tài khoản, kết nối và cấu hình máy chủ rồi thử lại.',
  );
}

class AccountAuth {
  Future<Map<String, dynamic>?> login(
    String tenDangNhap,
    String matKhau,
  ) async {
    try {
      final auth = FirebaseAuth.instance;
      final credential = await auth.signInWithEmailAndPassword(
        email: accountLoginEmail(tenDangNhap),
        password: matKhau,
      );
      final maNguoiDung = credential.user!.uid;
      final banGhi = await FirebaseFirestore.instance
          .collection('users')
          .doc(maNguoiDung)
          .get(const GetOptions(source: Source.server));
      final duLieu = banGhi.data();
      if (duLieu == null || duLieu['status'] != 'active') {
        await auth.signOut();
        AccountSession.current = null;
        return null;
      }
      return {...duLieu, 'id': maNguoiDung};
    } on FirebaseAuthException catch (loi) {
      if ([
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'user-disabled',
        'invalid-email',
      ].contains(loi.code)) {
        // Không đăng xuất ở đây: lần thử sai không được kết thúc phiên
        // quản trị đang hoạt động trong tab web khác.
        return null;
      }
      rethrow;
    } on FirebaseException {
      await FirebaseAuth.instance.signOut();
      // Không biến lỗi Rules/kết nối Firestore thành lỗi sai mật khẩu. Sau khi
      // Auth đã xác thực, đây là lỗi hồ sơ hoặc cấu hình máy chủ cần báo rõ.
      rethrow;
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await AdminWebSession.signOut();
    AccountSession.current = null;
    await FirebaseAuth.instance.signOut();
  }
}
