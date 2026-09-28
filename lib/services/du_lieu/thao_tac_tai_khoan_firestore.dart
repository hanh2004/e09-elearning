part of 'dich_vu_firestore.dart';

Map<String, Object?> _optionalAccountField(String key, Object? value) =>
    value == null ? const {} : {key: value};

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

  Future<void> _taoTaiKhoanSpark({
    required String name,
    required String username,
    required String password,
    required String role,
    required String status,
    required String createdBy,
    required String unit,
    required String userCode,
    required String userCodeSuffix,
  }) async {
    // Mã duy nhất phải được máy chủ giữ trong cùng transaction với tài khoản.
    throw const AccountProvisioningException(
      'Tạo học viên cần kết nối dịch vụ quản lý tài khoản. Vui lòng dùng bản cập nhật mới.',
    );
  }

  Future<Map<String, dynamic>?> loginWithUsername(
    String tenDangNhap,
    String matKhau,
  ) => AccountAuth().login(tenDangNhap, matKhau);

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
    String? userCodeSuffix,
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
            if (userCodeSuffix != null && userCodeSuffix.trim().isNotEmpty)
              'code': userCodeSuffix.trim(),
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
    final suffix = (userCodeSuffix ?? username).trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$').hasMatch(suffix)) {
      throw ArgumentError(
        'Mã người dùng gồm 1–64 ký tự không dấu, số, _, ., @ hoặc -.',
      );
    }
    await _taoTaiKhoanSpark(
      name: name,
      username: username,
      password: password,
      role: 'user',
      status: 'active',
      createdBy: nguoiThaoTac!.id,
      unit: resolvedUnit,
      userCode: '$resolvedUnit-$suffix',
      userCodeSuffix: suffix,
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
          !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$').hasMatch(dong.username) ||
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
                if (dong.userCodeSuffix != null) 'code': dong.userCodeSuffix,
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
    for (final dong in cacDong) {
      final suffix = (dong.userCodeSuffix ?? dong.username).trim();
      await _taoTaiKhoanSpark(
        name: dong.name.trim(),
        username: dong.username,
        password: dong.password,
        role: 'user',
        status: 'active',
        createdBy: currentActor.id,
        unit: importUnit,
        userCode: '$importUnit-$suffix',
        userCodeSuffix: suffix,
      );
    }
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

  /// Máy chủ xác thực tên đăng nhập và mã đuôi, sau đó tự gắn yêu cầu với
  /// quản lý phụ trách. Trả về false nếu thông tin không khớp.
  Future<bool> requestPasswordReset({
    required String username,
    required String codeSuffix,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Chức năng quên mật khẩu cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    final result = await _apiTaiKhoan.call('accountRequestPasswordReset', {
      'username': username.trim(),
      'codeSuffix': codeSuffix.trim(),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getPasswordResetRequestsStream() {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isAdmin != true) {
      return Stream.error(StateError('Cần đăng nhập quản trị.'));
    }
    Query<Map<String, dynamic>> truyVan = _coSoDuLieu.collection(
      'password_reset_requests',
    );
    if (danhTinh!.isRoot) {
      truyVan = truyVan.where(
        'status',
        whereIn: ['pending', 'approved_once', 'approved', 'processing'],
      );
    } else {
      truyVan = truyVan
          .where('managerId', isEqualTo: danhTinh.id)
          .where(
            'status',
            whereIn: ['pending', 'approved_once', 'approved', 'processing'],
          );
    }
    return truyVan.snapshots();
  }

  Future<void> approvePasswordReset(String requestId) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Duyệt cấp lại mật khẩu cần kết nối dịch vụ quản lý tài khoản.',
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

  Future<void> setAdminUnit(
    String maNguoiDung,
    String donVi, {
    Map<String, String> codeSuffixes = const {},
  }) async {
    await _apiTaiKhoan.call('accountSetUnit', {
      'userId': maNguoiDung,
      'unit': donVi,
      if (codeSuffixes.isNotEmpty) 'codes': codeSuffixes,
    });
  }

  Future<void> reassignUser({
    required String userId,
    required String managerId,
    String? userCodeSuffix,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      throw const AccountProvisioningException(
        'Chuyển đơn vị cần kết nối dịch vụ quản lý tài khoản.',
      );
    }
    await _apiTaiKhoan.call('accountReassignUser', {
      'userId': userId,
      'managerId': managerId,
      ..._optionalAccountField('userCodeSuffix', userCodeSuffix),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserAttemptsStream(
    String userId,
  ) {
    return _coSoDuLieu
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .snapshots();
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
    String? unit,
    String? userCodeSuffix,
  }) async {
    if (!_apiTaiKhoan.hasTransport) {
      if (unit != null || userCodeSuffix != null) {
        throw const AccountProvisioningException(
          'Đổi mã người dùng cần kết nối dịch vụ tài khoản trên máy chủ.',
        );
      }
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
      ..._optionalAccountField('unit', unit),
      ..._optionalAccountField('userCodeSuffix', userCodeSuffix),
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
