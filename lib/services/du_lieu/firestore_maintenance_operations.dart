part of 'firestore_service.dart';

mixin _FirestoreMaintenanceOperations on _FirestoreServiceCore {
  Stream<bool> getMaintenanceModeStream() => _coSoDuLieu
      .collection('system')
      .doc('app_status')
      .snapshots()
      .map((duLieuNhan) => duLieuNhan.data()?['maintenance'] == true);

  Future<bool> isMaintenanceMode() async {
    final duLieuNhan = await _coSoDuLieu
        .collection('system')
        .doc('app_status')
        .get(const GetOptions(source: Source.server));
    return duLieuNhan.data()?['maintenance'] == true;
  }

  Future<void> setMaintenanceMode(bool daBat) async {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isRoot != true) {
      throw StateError('Chỉ quản lý tổng được cập nhật trạng thái ứng dụng.');
    }
    await _coSoDuLieu.collection('system').doc('app_status').set({
      'maintenance': daBat,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': danhTinh!.id,
    });
  }
}
