// XỬ LÝ DỮ LIỆU / API: Đăng nhập/đăng xuất Firebase Auth và đọc hồ sơ tài khoản.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_identity.dart';

String accountLoginEmail(String tenDangNhap) =>
    '${sha256.convert(utf8.encode(tenDangNhap.trim().toLowerCase()))}@accounts.invalid';

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
    } on FirebaseException catch (loi) {
      await FirebaseAuth.instance.signOut();
      // Tài khoản bị khóa/xóa không đọc được hồ sơ của mình. Trả cùng lỗi với
      // sai thông tin để không làm lộ trạng thái tài khoản.
      if (loi.code == 'permission-denied') return null;
      rethrow;
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  static Future<void> signOut() async {
    AccountSession.current = null;
    await FirebaseAuth.instance.signOut();
  }
}
