// XỬ LÝ LỖI: Chuyển lỗi Firebase/API thành thông báo tiếng Việt kèm hướng xử lý.
// Các màn hình truyền tên chức năng để người dùng biết thao tác nào bị lỗi.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppErrorMessage {
  static String from(
    Object error, {
    required String feature,
    String? fallbackAction,
  }) {
    final technicalCode = technicalCodeFor(error);
    final serverMessage = _serverMessage(error);
    final action = fallbackAction ?? 'Hãy tải lại chức năng rồi thử lại.';

    if (error is FirebaseAuthException) {
      final detail = switch (error.code) {
        'unauthorized-domain' =>
          'tên miền ứng dụng chưa được cho phép trong Firebase Authentication',
        'operation-not-allowed' =>
          'Firebase Authentication chưa bật phương thức đăng nhập này',
        'invalid-api-key' ||
        'app-not-authorized' ||
        'project-not-found' => 'cấu hình Firebase của ứng dụng chưa đúng',
        'too-many-requests' =>
          'Firebase tạm chặn yêu cầu do có quá nhiều lần thử',
        'network-request-failed' =>
          'không kết nối được Firebase Authentication',
        _ =>
          serverMessage ??
              'Firebase Authentication không xác thực được yêu cầu',
      };
      final fix = switch (error.code) {
        'unauthorized-domain' ||
        'operation-not-allowed' ||
        'invalid-api-key' ||
        'app-not-authorized' ||
        'project-not-found' => 'Cần kiểm tra cấu hình Firebase project, API key và tên miền được phép.',
        'too-many-requests' => 'Vui lòng chờ rồi thử lại.',
        'network-request-failed' =>
          'Kiểm tra mạng, kết nối lại rồi thử đăng nhập lại.',
        _ => action,
      };
      return _format(
        feature,
        detail,
        fix,
        technicalCode,
        error.code != 'too-many-requests',
      );
    }

    if (error is FirebaseFunctionsException) {
      final detail = switch (error.code) {
        'permission-denied' =>
          serverMessage == null
              ? 'máy chủ từ chối quyền thực hiện yêu cầu'
              : 'máy chủ từ chối yêu cầu: $serverMessage',
        'unauthenticated' => 'phiên đăng nhập không hợp lệ hoặc đã hết hạn',
        'unavailable' ||
        'network-request-failed' => 'không kết nối được Cloud Functions',
        'deadline-exceeded' => 'máy chủ phản hồi quá thời gian cho phép',
        'failed-precondition' =>
          serverMessage ?? 'chức năng chưa được cấu hình đầy đủ',
        'not-found' =>
          serverMessage ?? 'không tìm thấy chức năng hoặc dữ liệu yêu cầu',
        'invalid-argument' => serverMessage ?? 'dữ liệu gửi lên chưa hợp lệ',
        'internal' || 'unknown' => 'Cloud Functions gặp lỗi nội bộ',
        _ => serverMessage ?? 'Cloud Functions không hoàn tất yêu cầu',
      };
      final fix = switch (error.code) {
        'permission-denied' =>
          'Hãy kiểm tra quyền tài khoản và cấu hình máy chủ.',
        'unauthenticated' => 'Hãy đăng xuất rồi đăng nhập lại.',
        'unavailable' || 'network-request-failed' =>
          'Kiểm tra mạng, kết nối lại rồi tải lại chức năng.',
        'deadline-exceeded' => 'Hãy tải lại chức năng sau ít phút.',
        'failed-precondition' || 'not-found' =>
          'Chức năng có thể chưa được cấu hình hoặc triển khai đúng.',
        'invalid-argument' => 'Kiểm tra lại thông tin vừa nhập.',
        _ => action,
      };
      return _format(feature, detail, fix, technicalCode);
    }

    if (error is FirebaseException) {
      final detail = switch (error.code) {
        'permission-denied' => 'máy chủ từ chối quyền truy cập dữ liệu',
        'unauthenticated' => 'phiên đăng nhập không hợp lệ hoặc đã hết hạn',
        'unavailable' || 'network-request-failed' =>
          'không kết nối được dịch vụ Firebase ${error.plugin}',
        'deadline-exceeded' => 'dịch vụ Firebase phản hồi quá lâu',
        'failed-precondition' => 'dịch vụ Firebase chưa được cấu hình đầy đủ',
        'not-found' => 'không tìm thấy dữ liệu yêu cầu',
        _ => 'dịch vụ Firebase ${error.plugin} trả về lỗi ${error.code}',
      };
      final fix = switch (error.code) {
        'permission-denied' => 'Kiểm tra đúng tài khoản và quyền được cấp.',
        'unauthenticated' => 'Hãy đăng xuất rồi đăng nhập lại.',
        'unavailable' || 'network-request-failed' =>
          'Kiểm tra mạng, kết nối lại rồi tải lại chức năng.',
        'failed-precondition' => 'Chức năng có thể chưa được cấu hình đầy đủ.',
        _ => action,
      };
      return _format(feature, detail, fix, technicalCode);
    }

    if (error is ArgumentError) {
      return _format(
        feature,
        error.message.toString(),
        'Kiểm tra lại dữ liệu vừa nhập.',
      );
    }
    if (error is StateError) {
      return _format(
        feature,
        error.message,
        'Đọc hướng dẫn trên màn hình rồi thử lại.',
      );
    }

    return _format(
      feature,
      'đã xảy ra lỗi không xác định',
      action,
      error.runtimeType.toString(),
    );
  }

  static String _format(
    String feature,
    String detail,
    String action, [
    String? code,
    bool suggestAdmin = true,
  ]) =>
      'Chức năng $feature đang bị lỗi: $detail. $action'
      '${suggestAdmin ? ' Nếu lỗi còn tiếp diễn hoặc liên quan đến mã nguồn/giao diện, hãy liên hệ Admin để báo sửa lỗi.' : ''}'
      '${code == null ? '' : ' ($code)'}';

  static String technicalCodeFor(Object error) => switch (error) {
    FirebaseFunctionsException() => 'cloud_functions/${error.code}',
    FirebaseException() => '${error.plugin}/${error.code}',
    _ => error.runtimeType.toString(),
  };

  static String? _serverMessage(Object error) {
    final message = switch (error) {
      FirebaseFunctionsException() => error.message,
      FirebaseException() => error.message,
      _ => null,
    }?.trim();
    return message == null || message.isEmpty
        ? null
        : message.replaceFirst(RegExp(r'[.!?]+$'), '');
  }
}
