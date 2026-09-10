import 'package:cloud_functions/cloud_functions.dart';

typedef ExamCall = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

class SecureExamService {
  SecureExamService({this.transport});
  final ExamCall? transport;
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (transport != null) return transport!(name, data);
    final response = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable(name).call<Map<String, dynamic>>(data);
    return response.data;
  }

  static String error(Object error) => error is FirebaseFunctionsException
      ? error.message ?? 'Không kết nối được máy chủ.'
      : 'Không hoàn tất thao tác. Hãy thử lại.';
}
