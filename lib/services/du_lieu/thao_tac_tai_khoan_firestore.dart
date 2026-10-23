part of 'dich_vu_firestore.dart';

mixin _FirestoreAccountOperations on _FirestoreServiceCore {
  Future<FirebaseAuth> _xacThucCapTaiKhoan() async {
    _ungDungCapTaiKhoan ??= await Firebase.initializeApp(
      name: 'account-provisioning',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: _ungDungCapTaiKhoan!);
    const emulator = AppConfig.emulatorHost;
    if (emulator.isNotEmpty && !_daCauHinhGiaLapCapTaiKhoan) {
      await auth.useAuthEmulator(emulator, AppConfig.authEmulatorPort);
      _daCauHinhGiaLapCapTaiKhoan = true;
    }
    return auth;
  }

  Future<String> _taoThongTinXacThuc(
    String tenDangNhap,
    String matKhau,
    String ten,
  ) async {
    final normalizedUsername = tenDangNhap.trim();
    final usernameSnapshot = await _coSoDuLieu
        .collection('usernames')
        .doc(_khoaTenDangNhap(normalizedUsername))
        .get();
    if (usernameSnapshot.exists) {
      throw const AccountProvisioningException(
        'Tên đăng nhập đã tồn tại. Hãy chọn tên khác.',
      );
    }
    final auth = await _xacThucCapTaiKhoan();
    await auth.signOut();
    final thuDienTu = accountLoginEmail(normalizedUsername);
    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: thuDienTu,
        password: matKhau,
      );
    } on FirebaseAuthException catch (loi) {
      if (loi.code != 'email-already-in-use') rethrow;
      try {
        // Khôi phục tài khoản Auth còn sót lại sau một lần ghi bị gián đoạn.
        credential = await auth.signInWithEmailAndPassword(
          email: thuDienTu,
          password: matKhau,
        );
      } on FirebaseAuthException {
        throw const AccountProvisioningException(
          'Tên đăng nhập đã tồn tại trong Authentication. Hãy chọn tên khác.',
        );
      }
    }
    await credential.user!.updateDisplayName(ten);
    final maNguoiDung = credential.user!.uid;
    await auth.signOut();
    return maNguoiDung;
  }

  String _khoaTenDangNhap(String tenDangNhap) =>
      accountLoginEmail(tenDangNhap).split('@').first;

  Future<Map<String, dynamic>?> loginWithUsername(
    String tenDangNhap,
    String matKhau,
  ) => AccountAuth().login(tenDangNhap, matKhau);

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
    String? unit,
    String? subUnit,
  }) async {
    if (role != 'user') {
      throw ArgumentError('Quản lý phải được đề xuất và duyệt riêng.');
    }
    if (_apiTaiKhoan.hasTransport) {
      await _apiTaiKhoan.idempotent('accountImportUsers', {
        'rows': [
          {
            'name': name,
            'username': username,
            'password': password,
            if (subUnit != null && subUnit.trim().isNotEmpty)
              'subUnit': subUnit.trim(),
          },
        ],
      });
      return;
    }
    final nguoiThaoTac = AccountSession.current;
    if (nguoiThaoTac?.isAdmin != true) {
      throw StateError('Cần đăng nhập quản trị.');
    }
    final resolvedUnit = (unit ?? (nguoiThaoTac!.isRoot ? 'E09' : '')).trim();
    if (resolvedUnit.isEmpty) {
      throw StateError('Quản lý chưa được phân mã đơn vị.');
    }
    // Không còn đường ghi trực tiếp: tên đăng nhập phải được máy chủ kiểm tra
    // và tạo cùng hồ sơ trong một transaction.
    throw const AccountProvisioningException(
      'Tạo học viên cần kết nối dịch vụ quản lý tài khoản. Vui lòng dùng bản cập nhật mới.',
    );
  }

  Future<void> setAdminSubUnits(List<String> subUnits) async {
    if (subUnits.length > 200 ||
        subUnits.any(
          (giaTri) => giaTri.trim().isEmpty || giaTri.trim().length > 100,
        )) {
      throw ArgumentError(
        'Tối đa 200 mục trực thuộc, mỗi mục từ 1 đến 100 ký tự.',
      );
    }
    final cacGiaTri = subUnits
        .map((giaTri) => giaTri.trim())
        .where((giaTri) => giaTri.isNotEmpty)
        .toSet()
        .toList();
    if (_apiTaiKhoan.hasTransport) {
      await _apiTaiKhoan.call('accountSetSubUnits', {'subUnits': cacGiaTri});
      return;
    }
    final nguoiThaoTac = AccountSession.current;
    if (nguoiThaoTac?.isAdmin != true) {
      throw StateError('Cần đăng nhập quản trị.');
    }
    await _coSoDuLieu.collection('users').doc(nguoiThaoTac!.id).update({
      'subUnits': cacGiaTri,
    });
  }

  Future<List<String>> checkUsernames(List<String> names) async {
    if (!_apiTaiKhoan.hasTransport) {
      if (names.isEmpty) return [];
      final cacBanGhi = await Future.wait(
        names.map(
          (ten) => _coSoDuLieu
              .collection('usernames')
              .doc(_khoaTenDangNhap(ten))
              .get(),
        ),
      );
      return [
        for (var i = 0; i < names.length; i++)
          if (cacBanGhi[i].exists) names[i],
      ];
    }
    final ketQua = await _apiTaiKhoan.call('accountCheckUsernames', {
      'usernames': names,
    });
    return List<String>.from(ketQua['existing'] as List);
  }

  /// Máy chủ kiểm tra và tạo Auth trước khi kích hoạt hồ sơ trong một lần ghi.
  /// Nhập Excel không nhận vai trò hoặc người tạo do file cung cấp.
  Future<void> importUsers(List<UserImportRow> cacDong) async {
    if (cacDong.isEmpty || cacDong.length > UserImportPreview.maxUsers) {
      throw ArgumentError('Danh sách phải có từ 1 đến 200 học viên.');
    }
    final seen = <String>{};
    for (final dong in cacDong) {
      if (dong.errors.isNotEmpty ||
          dong.name.trim().isEmpty ||
          dong.name.length > 100 ||
          !AccountIdentity.isValidUsername(dong.username) ||
          dong.password.trim().length < 6 ||
          dong.password.length > 128 ||
          !seen.add(dong.username.toLowerCase())) {
        throw ArgumentError(
          'Dữ liệu học viên không hợp lệ. Hãy kiểm tra lại file.',
        );
      }
    }
    if (_apiTaiKhoan.hasTransport) {
      await _apiTaiKhoan.idempotent('accountImportUsers', {
        'rows': cacDong
            .map(
              (dong) => {
                'name': dong.name.trim(),
                'username': dong.username,
                'password': dong.password,
                if (dong.serialNumber != null)
                  'serialNumber': dong.serialNumber,
              },
            )
            .toList(),
      });
      return;
    }
    final nguoiThaoTac = AccountSession.current;
    if (nguoiThaoTac?.isAdmin != true) {
      throw StateError('Cần đăng nhập quản trị.');
    }
    final currentActor = nguoiThaoTac!;
    final importUnit = currentActor.isRoot
        ? 'E09'
        : ((await _coSoDuLieu.collection('users').doc(currentActor.id).get())
                          .data()?['unit']
                      as String? ??
                  '')
              .trim();
    if (importUnit.isEmpty) {
      throw StateError('Quản lý chưa được phân mã đơn vị.');
    }
    // Không còn đường ghi trực tiếp: toàn bộ lô phải qua API để cấp mã an toàn.
    throw const AccountProvisioningException(
      'Tạo học viên cần kết nối dịch vụ quản lý tài khoản. Vui lòng dùng bản cập nhật mới.',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isAdmin == true) {
      return _coSoDuLieu.collection('users').snapshots();
    }
    return Stream.error(StateError('Cần đăng nhập quản trị.'));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAdminRequestsStream() =>
      _coSoDuLieu.collection('admin_requests').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> getAdminDeletionRequestsStream() {
    if (AccountSession.current?.isRoot != true) {
      return Stream.error(StateError('Chỉ quản lý tổng được xem yêu cầu xóa.'));
    }
    return _coSoDuLieu.collection('admin_delete_requests').snapshots();
  }

  Future<void> requestAdminDeletion({required String userId}) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Gửi duyệt xóa quản lý cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountRequestAdminDeletion', {'userId': userId});
  }

  Future<void> decideAdminDeletion(String requestId, bool approve) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Duyệt xóa quản lý cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountDecideAdminDeletion', {
      'requestId': requestId,
      'approve': approve,
    });
  }

  /// Máy chủ xác thực tên đăng nhập rồi gắn yêu cầu với quản lý phụ trách.
  Future<bool> requestPasswordReset({required String username}) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Chức năng quên mật khẩu cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    final result = await _apiTaiKhoan.call('accountRequestPasswordReset', {
      'username': username.trim(),
    });
    final matched = result['matched'];
    if (matched is! bool) {
      throw const AccountProvisioningException(
        'Máy chủ chưa hỗ trợ xác thực thông tin quên mật khẩu. Vui lòng cập nhật máy chủ rồi thử lại.',
      );
    }
    return matched;
  }

  Future<void> requestRootPasswordReset({
    required String username,
    required String proof,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Cần kết nối dịch vụ khôi phục mật khẩu admin tổng.',
      );
    }
    await _apiTaiKhoan.call('rootPasswordResetRequest', {
      'username': username.trim(),
      'proof': proof,
    });
  }

  Future<String> rootPasswordResetStatus({
    required String username,
    required String proof,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Cần kết nối dịch vụ khôi phục mật khẩu admin tổng.',
      );
    }
    final result = await _apiTaiKhoan.call('rootPasswordResetStatus', {
      'username': username.trim(),
      'proof': proof,
    });
    return result['status']?.toString() ?? 'not_found';
  }

  Future<void> finishRootPasswordReset({
    required String username,
    required String proof,
    required String password,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Cần kết nối dịch vụ khôi phục mật khẩu admin tổng.',
      );
    }
    await _apiTaiKhoan.call('rootPasswordResetFinish', {
      'username': username.trim(),
      'proof': proof,
      'password': password,
    });
  }

  Future<PasswordResetRequest> _normalizePasswordResetRequest(
    String id,
    Map<String, dynamic> rawData,
    AccountIdentity actor,
  ) async {
    final data = Map<String, dynamic>.from(rawData);
    // Yêu cầu cũ chưa lưu userRole; đọc hồ sơ đích để cả hai admin tổng
    // thấy admin phụ, đồng thời không nhầm với học viên do admin tổng tạo.
    if (actor.isRoot &&
        data['type'] != 'root_recovery' &&
        !const ['user', 'admin'].contains(data['userRole'])) {
      final userId = data['userId'];
      if (userId is String && userId.isNotEmpty && !userId.contains('/')) {
        final profile = await _coSoDuLieu.collection('users').doc(userId).get();
        final role = profile.data()?['role'];
        if (const ['user', 'admin'].contains(role)) data['userRole'] = role;
      }
    }
    return PasswordResetRequest(id: id, data: data);
  }

  Stream<List<PasswordResetRequest>> getPasswordResetRequestsStream() {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isAdmin != true) {
      return Stream.error(StateError('Cần đăng nhập quản trị.'));
    }
    Query<Map<String, dynamic>> truyVan = _coSoDuLieu.collection(
      'password_reset_requests',
    );
    final actor = danhTinh!;
    if (actor.isRoot) {
      truyVan = truyVan.where(
        'status',
        whereIn: PasswordResetRequest.openStatuses,
      );
    } else {
      truyVan = truyVan
          .where('managerId', isEqualTo: actor.id)
          .where('status', whereIn: PasswordResetRequest.openStatuses);
    }
    return truyVan.snapshots().asyncMap((snapshot) async {
      final requests = await Future.wait(
        snapshot.docs.map(
          (document) => _normalizePasswordResetRequest(
            document.id,
            document.data(),
            actor,
          ),
        ),
      );
      return requests.where((request) => request.isVisibleTo(actor)).toList();
    });
  }

  Stream<PasswordResetRequest?> getPasswordResetRequestStream(
    String requestId,
  ) {
    final actor = AccountSession.current;
    if (actor?.isAdmin != true) {
      return Stream.error(StateError('Cần đăng nhập quản trị.'));
    }
    return _coSoDuLieu
        .collection('password_reset_requests')
        .doc(requestId)
        .snapshots()
        .asyncMap((document) async {
          final data = document.data();
          return data == null
              ? null
              : _normalizePasswordResetRequest(document.id, data, actor!);
        });
  }

  Future<void> approvePasswordReset(String requestId) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Đồng ý cấp lại mật khẩu admin phụ cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountApprovePasswordReset', {
      'requestId': requestId,
    });
  }

  Future<void> approveRootPasswordReset(String requestId) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Duyệt khôi phục admin tổng cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('rootPasswordResetApprove', {
      'requestId': requestId,
    });
  }

  Future<void> resolvePasswordReset({
    required String requestId,
    required String userId,
    required String password,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Cấp lại mật khẩu cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountResolvePasswordReset', {
      'requestId': requestId,
      'userId': userId,
      'password': password,
    });
  }

  Future<void> proposeAdmin({
    required String name,
    required String username,
    required String password,
    String unit = 'E09',
  }) async {
    if (_apiTaiKhoan.hasTransport) {
      await _apiTaiKhoan.idempotent('accountProposeAdmin', {
        'unit': unit,
        'account': {'name': name, 'username': username, 'password': password},
      });
      return;
    }
    final nguoiThaoTac = AccountSession.current;
    if (nguoiThaoTac?.isRoot != true) {
      throw StateError('Chỉ quản lý tổng được đề xuất.');
    }
    final maNguoiDung = await _taoThongTinXacThuc(username, password, name);
    final request = _coSoDuLieu.collection('admin_requests').doc();
    final loGhi = _coSoDuLieu.batch();
    loGhi.set(
      _coSoDuLieu.collection('usernames').doc(_khoaTenDangNhap(username)),
      {'uid': maNguoiDung, 'username': username.trim()},
    );
    loGhi.set(_coSoDuLieu.collection('users').doc(maNguoiDung), {
      'name': name,
      'username': username.trim(),
      'role': 'admin',
      'status': 'pending',
      'createdBy': nguoiThaoTac!.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    loGhi.set(request, {
      'targetUid': maNguoiDung,
      'name': name,
      'username': username.trim(),
      'status': 'pending',
      'createdBy': nguoiThaoTac.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await loGhi.commit();
  }

  Future<void> setAdminUnit(String maNguoiDung, String donVi) async {
    await _apiTaiKhoan.call('accountSetUnit', {
      'userId': maNguoiDung,
      'unit': donVi,
    });
  }

  Future<void> reassignUser({
    required String userId,
    required String managerId,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Chuyển đơn vị cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountReassignUser', {
      'userId': userId,
      'managerId': managerId,
    });
  }

  Future<void> decideAdmin(String requestId, bool approve) async {
    if (!_apiTaiKhoan.hasTransport) {
      final nguoiThaoTac = AccountSession.current;
      if (nguoiThaoTac?.isRoot != true) {
        throw StateError('Chỉ quản lý tổng được duyệt.');
      }
      final requestRef = _coSoDuLieu
          .collection('admin_requests')
          .doc(requestId);
      await _coSoDuLieu.runTransaction((transaction) async {
        final duLieuNhan = await transaction.get(requestRef);
        final duLieu = duLieuNhan.data();
        if (duLieu == null ||
            duLieu['createdBy'] == nguoiThaoTac!.id ||
            duLieu['status'] != 'pending') {
          throw StateError(
            'Yêu cầu không hợp lệ hoặc bạn không được tự duyệt.',
          );
        }
        transaction.update(requestRef, {
          'status': approve ? 'approved' : 'rejected',
          'decidedBy': nguoiThaoTac.id,
          'decidedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(
          _coSoDuLieu.collection('users').doc(duLieu['targetUid']),
          {
            'status': approve ? 'active' : 'rejected',
            'approvedBy': approve ? nguoiThaoTac.id : null,
          },
        );
      });
      return;
    }
    await _apiTaiKhoan.call('accountDecideAdmin', {
      'requestId': requestId,
      'approve': approve,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExamAttemptsStream() {
    return _coSoDuLieu.collection('exam_attempts').snapshots();
  }

  Future<void> setUserBlocked(String maNguoiDung, bool blocked) async {
    await _apiTaiKhoan.call('accountSetStatus', {
      'userId': maNguoiDung,
      'disabled': blocked,
    });
  }

  Future<void> updateUser({
    required String docId,
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      await _coSoDuLieu.collection('users').doc(docId).update({
        'name': name.trim(),
        'updatedBy': AccountSession.current!.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _apiTaiKhoan.call('accountUpdateUser', {
      'userId': docId,
      'name': name,
      if (password.isNotEmpty) 'password': password,
    });
  }

  Future<void> deleteUser(String docId) async {
    if (!_apiTaiKhoan.hasTransport) {
      final userRef = _coSoDuLieu.collection('users').doc(docId);
      final userSnapshot = await userRef.get();
      final nguoiDung = userSnapshot.data();
      if (nguoiDung == null) {
        throw const AccountProvisioningException(
          'Không tìm thấy tài khoản cần xóa.',
        );
      }
      final cacLuotThi = await _coSoDuLieu
          .collection('exam_attempts')
          .where('userId', isEqualTo: docId)
          .get();
      await _xoaCacLuotThi(cacLuotThi.docs);
      final learning = await userRef.collection('learning').get();
      final related = <DocumentReference<Map<String, dynamic>>>[
        ...learning.docs.map((banGhi) => banGhi.reference),
        ...cacLuotThi.docs.map((banGhi) => banGhi.reference),
      ];
      if (AccountSession.current?.isRoot == true) {
        final requests = await _coSoDuLieu
            .collection('admin_requests')
            .where('targetUid', isEqualTo: docId)
            .get();
        related.addAll(requests.docs.map((banGhi) => banGhi.reference));
      }
      await deleteFirestoreDocuments(_coSoDuLieu, related);
      final finalBatch = _coSoDuLieu.batch();
      finalBatch.delete(
        _coSoDuLieu
            .collection('usernames')
            .doc(_khoaTenDangNhap(nguoiDung['username'])),
      );
      finalBatch.delete(userRef);
      await finalBatch.commit();
      return;
    }
    await _apiTaiKhoan.call('accountDeleteUser', {'userId': docId});
  }
}
