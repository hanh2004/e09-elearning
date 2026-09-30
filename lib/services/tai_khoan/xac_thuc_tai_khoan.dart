// XỬ LÝ DỮ LIỆU / API: Đăng nhập/đăng xuất Firebase Auth và đọc hồ sơ tài khoản.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import 'phien_dang_nhap_quan_tri_web.dart';

String accountLoginEmail(String tenDangNhap) =>
    '${sha256.convert(utf8.encode(tenDangNhap.trim().toLowerCase()))}@accounts.invalid';

/// Chuyển mã lỗi Firebase thành hướng dẫn an toàn để hiển thị trên màn hình.
String accountLoginErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'network-request-failed' => 'Không kết nối được Firebase Authentication. Kiểm tra mạng rồi thử lại.',
      'unauthorized-domain' =>
        'Tên miền web Admin chưa được cho phép trong Firebase Authentication.',
      'operation-not-allowed' =>
        'Firebase Authentication chưa bật đăng nhập Email/Password.',
      'invalid-api-key' || 'app-not-authorized' || 'project-not-found' => 'Cấu hình Firebase của web Admin không hợp lệ. Hãy kiểm tra project và API key.',
      'too-many-requests' => 'Firebase tạm khóa yêu cầu đăng nhập do thử quá nhiều lần. Vui lòng chờ rồi thử lại.',
      _ =>
        'Không xác thực được với Firebase (${error.code}). Kiểm tra thông tin đăng nhập và trạng thái tài khoản.',
    };
  }

  if (error is FirebaseException) {
    if (error.code == 'network-request-failed' ||
        error.code == 'unavailable' ||
        error.code == 'deadline-exceeded') {
      return 'Không kết nối được máy chủ Firebase (${error.plugin}). Kiểm tra mạng hoặc trạng thái dịch vụ.';
    }
    if (error.plugin == 'cloud_firestore' &&
        error.code == 'permission-denied') {
      return 'Đăng nhập Firebase thành công nhưng Firestore từ chối đọc hồ sơ. Kiểm tra Firestore Rules và quyền tài khoản.';
    }
    if (error.plugin == 'cloud_firestore' &&
        error.code == 'failed-precondition') {
      return 'Firestore chưa sẵn sàng hoặc chưa được cấu hình cho project Firebase này.';
    }
    return 'Dịch vụ Firebase ${error.plugin} trả lỗi ${error.code}. Kiểm tra cấu hình máy chủ.';
  }

  return 'Không thể hoàn tất đăng nhập (${error.runtimeType}). Kiểm tra kết nối máy chủ rồi thử lại.';
}

/// Mã kỹ thuật không chứa tên đăng nhập hoặc mật khẩu, dùng để đối chiếu log.
String accountLoginErrorCode(Object error) {
  if (error is FirebaseException) return '${error.plugin}/${error.code}';
  return error.runtimeType.toString();
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
