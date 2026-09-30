// XỬ LÝ DỮ LIỆU / API: Gọi API thi: lấy danh sách, bắt đầu, lưu câu trả lời, nộp và xem lịch sử.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'package:cloud_functions/cloud_functions.dart';

import '../../app/cau_hinh_ung_dung.dart';
import '../tai_khoan/phien_dang_nhap_quan_tri_web.dart';

typedef ExamCall = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class SecureExamService {
  SecureExamService({this.transport});
  final ExamCall? transport;
  Future<Map<String, dynamic>> call(
    String ten, [
    Map<String, dynamic> duLieu = const {},
  ]) async {
    if (transport != null) return transport!(ten, duLieu);
    final response =
        await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
            .httpsCallable(ten)
            .call<Map<String, dynamic>>(AdminWebSession.addToken(duLieu));
    return response.data;
  }

  static String error(Object loi) => loi is FirebaseFunctionsException
      ? loi.message ?? 'Không kết nối được máy chủ.'
      : 'Không hoàn tất thao tác. Hãy thử lại.';
}
