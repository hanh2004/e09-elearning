// Form thêm/sửa tài khoản quản trị, gồm thông tin đăng nhập, vai trò và đơn vị.
// Đây là phần xử lý hộp thoại tách riêng của quan_ly_tai_khoan.dart.
part of "quan_ly_tai_khoan.dart";

extension _AdminAccountDialogs on _TrangThaiTaiKhoanQuanTri {
  Future<void> _moHopThoaiTaiKhoan({
    String? id,
    Map<String, dynamic>? user,
    bool propose = false,
  }) async {
    if (_danhTinh?.isAdmin != true || (propose && !_danhTinh!.isRoot)) return;
    if (id != null && !_danhTinh!.canEdit(user!)) return;
    var availableSubUnits = <String>[];
    if (id == null && !propose && _danhTinh != null) {
      final actorDoc = await _dichVu.db
          .collection('users')
          .doc(_danhTinh!.id)
          .get();
      availableSubUnits = ((actorDoc.data()?['subUnits'] as List?) ?? const [])
          .map((giaTri) => giaTri.toString().trim())
          .where((giaTri) => giaTri.isNotEmpty)
          .toSet()
          .toList();
    }
    String? selectedSubUnit;
    if (!mounted) return;
    final ten = TextEditingController(text: user?['name'] ?? '');
    final tenDangNhap = TextEditingController(text: user?['username'] ?? '');
    final matKhau = TextEditingController();
    final donVi = TextEditingController(text: user?['unit'] ?? '');
    final isStudentEdit = id != null && user?['role'] == 'user';
    final form = GlobalKey<FormState>();
    var busy = false;
    String? loi;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(
              propose
                  ? 'Đề xuất Quản lý'
                  : id == null
                  ? 'Thêm học viên'
                  : 'Sửa tài khoản',
            ),
            content: SizedBox(
              width: 430,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (propose)
                        const Text(
                          'Tài khoản chỉ hoạt động sau khi quản lý tổng còn lại đồng ý.',
                        ),
                      if (propose)
                        TextFormField(
                          controller: donVi,
                          decoration: const InputDecoration(
                            labelText: 'Mã đơn vị quản lý',
                            helperText:
                                'Đơn vị quản lý sẽ được gán cho tài khoản.',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty || v.length > 100
                              ? 'Nhập mã đơn vị, tối đa 100 ký tự.'
                              : null,
                        ),
                      if (id == null && !propose)
                        const Text(
                          'Học viên tự động thuộc đơn vị của quản lý tạo tài khoản.',
                        ),
                      if (id == null &&
                          !propose &&
                          availableSubUnits.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Trực thuộc',
                            prefixIcon: Icon(Icons.account_tree_outlined),
                          ),
                          hint: const Text('Không chọn'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Không chọn'),
                            ),
                            for (final giaTri in availableSubUnits)
                              DropdownMenuItem(
                                value: giaTri,
                                child: Text(giaTri),
                              ),
                          ],
                          onChanged: (giaTri) => selectedSubUnit = giaTri,
                        ),
                      if (isStudentEdit)
                        TextFormField(
                          controller: donVi,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị hiện tại',
                            helperText:
                                'Muốn đổi đơn vị, dùng thao tác Chuyển đơn vị.',
                          ),
                        ),
                      TextFormField(
                        controller: ten,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty || v.length > 100
                            ? 'Nhập họ tên, tối đa 100 ký tự.'
                            : null,
                      ),
                      TextFormField(
                        controller: tenDangNhap,
                        enabled: id == null,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                        ),
                        validator: (v) =>
                            v == null || !AccountIdentity.isValidUsername(v)
                            ? 'Tên đăng nhập 3–64 ký tự không dấu, không khoảng trắng.'
                            : null,
                      ),
                      if (id == null)
                        TextFormField(
                          controller: matKhau,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                          ),
                          validator: (v) =>
                              v == null || v.length < 6 || v.length > 128
                              ? 'Mật khẩu từ 6 đến 128 ký tự.'
                              : null,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Không đổi mật khẩu tài khoản khác tại đây; '
                            'hãy dùng chức năng cấp lại mật khẩu.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        propose
                            ? 'Vai trò: Quản lý (chờ duyệt)'
                            : id == null
                            ? 'Vai trò: Học viên'
                            : 'Không thay đổi vai trò hoặc người tạo qua màn hình sửa.',
                      ),
                      if (loi != null)
                        Text(loi!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (busy) return;
                        if (!form.currentState!.validate()) return;
                        update(() {
                          busy = true;
                          loi = null;
                        });
                        try {
                          if (propose) {
                            await _dichVu.proposeAdmin(
                              name: ten.text.trim(),
                              username: tenDangNhap.text,
                              password: matKhau.text,
                              unit: donVi.text.trim(),
                            );
                          } else if (id != null) {
                            await _dichVu.updateUser(
                              docId: id,
                              name: ten.text.trim(),
                              username: tenDangNhap.text,
                              password: matKhau.text,
                              role: user!['role'].toString(),
                            );
                          } else {
                            await _dichVu.addUser(
                              name: ten.text.trim(),
                              username: tenDangNhap.text,
                              password: matKhau.text,
                              role: 'user',
                              subUnit: selectedSubUnit,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            update(() {
                              busy = false;
                              loi = _loiTaiKhoan(e);
                            });
                          }
                        }
                      },
                child: Text(
                  busy
                      ? 'Đang xử lý…'
                      : propose
                      ? 'Gửi yêu cầu'
                      : id == null
                      ? 'Thêm'
                      : 'Cập nhật',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    ten.dispose();
    tenDangNhap.dispose();
    matKhau.dispose();
    donVi.dispose();
  }

  Future<void> _moHopThoaiTrucThuoc() async {
    final danhTinh = _danhTinh;
    if (danhTinh == null || !danhTinh.isAdmin) return;
    final thamChieu = _dichVu.db.collection('users').doc(danhTinh.id);
    final hienHanh = (await thamChieu.get()).data();
    if (!mounted) return;
    final cacGiaTri =
        (((hienHanh?['subUnits'] as List?) ?? const [])
              .map((giaTri) => giaTri.toString().trim())
              .where((giaTri) => giaTri.isNotEmpty)
              .toSet()
              .toList())
          ..sort();
    final boDieuKhien = TextEditingController();
    var busy = false;
    String? loi;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('Quản lý mục trực thuộc'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: boDieuKhien,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Tên trực thuộc',
                        hintText: 'Ví dụ: Đội 1, Tổ Kỹ thuật',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (cacGiaTri.isEmpty)
                      const Text('Chưa có mục trực thuộc.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final giaTri in cacGiaTri)
                            InputChip(
                              label: Text(giaTri),
                              onDeleted: busy
                                  ? null
                                  : () =>
                                        update(() => cacGiaTri.remove(giaTri)),
                            ),
                        ],
                      ),
                    if (loi != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          loi!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (busy) return;
                        final giaTri = boDieuKhien.text.trim();
                        if (giaTri.isNotEmpty && !cacGiaTri.contains(giaTri)) {
                          update(() {
                            cacGiaTri.add(giaTri);
                            cacGiaTri.sort();
                            boDieuKhien.clear();
                          });
                        }
                        update(() {
                          busy = true;
                          loi = null;
                        });
                        try {
                          await _dichVu.setAdminSubUnits(cacGiaTri);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          update(() {
                            busy = false;
                            loi = _loiTaiKhoan(e);
                          });
                        }
                      },
                child: Text(busy ? 'Đang lưu…' : 'Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    boDieuKhien.dispose();
  }

  Future<void> _moHopThoaiChuyenQuanLy(
    String userId,
    Map<String, dynamic> nguoiDung,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacQuanLy,
  ) async {
    final eligibleManagers = cacQuanLy
        .where((manager) => _coTheChuyenHocVienCho(manager, nguoiDung))
        .toList();
    if (_danhTinh?.isRoot != true || eligibleManagers.isEmpty) return;
    final pageContext = context;
    final messenger = ScaffoldMessenger.maybeOf(pageContext);
    var daChon = eligibleManagers.first.id;
    var busy = false;
    String? loi;
    final codeKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, update) => AlertDialog(
          title: const Text('Chuyển học viên sang đơn vị khác'),
          content: SizedBox(
            width: 430,
            child: Form(
              key: codeKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học viên: ${nguoiDung['name'] ?? nguoiDung['username'] ?? userId}',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: daChon,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị / quản lý tiếp nhận',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final manager in eligibleManagers)
                          DropdownMenuItem(
                            value: manager.id,
                            child: Text(
                              '${manager.data()['name'] ?? manager.data()['username'] ?? manager.id} • ${manager.data()['role'] == 'super_admin' ? 'Quản lý tổng, E09' : manager.data()['unit'] ?? 'Chưa có mã đơn vị'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (giaTri) {
                              if (giaTri != null) {
                                update(() => daChon = giaTri);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tên đăng nhập của học viên vẫn giữ nguyên khi chuyển đơn vị.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tiến độ học tập, bài đã làm và lịch sử thi của học viên sẽ được giữ nguyên.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nếu kết nối bị gián đoạn, hãy chọn lại cùng quản lý và bấm Chuyển để tiếp tục.',
                    ),
                    if (loi != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          loi!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (busy) return;
                      if (!(codeKey.currentState?.validate() ?? false)) return;
                      update(() {
                        busy = true;
                        loi = null;
                      });
                      try {
                        await _dichVu.reassignUser(
                          userId: userId,
                          managerId: daChon,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          messenger?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã chuyển học viên và giữ nguyên dữ liệu học tập.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            busy = false;
                            loi = _loiTaiKhoan(e);
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Đang chuyển…' : 'Chuyển'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moHopThoaiDonVi(
    String managerId,
    Map<String, dynamic> manager,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> children,
  ) async {
    if (_danhTinh?.isRoot != true) return;
    final unitController = TextEditingController(
      text: manager['unit']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? loi;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, update) => AlertDialog(
          title: const Text('Đổi mã đơn vị của quản lý'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: unitController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị mới',
                        border: OutlineInputBorder(),
                      ),
                      validator: (giaTri) => (giaTri?.trim().isEmpty ?? true)
                          ? 'Cần nhập mã đơn vị.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    if (children.isNotEmpty)
                      const Text('Tên đăng nhập của học viên không đổi.'),
                    if (loi != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          loi!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (busy) return;
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      update(() {
                        busy = true;
                        loi = null;
                      });
                      try {
                        await _dichVu.setAdminUnit(
                          managerId,
                          unitController.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã đổi mã đơn vị; tên đăng nhập của học viên không đổi.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            busy = false;
                            loi = _loiTaiKhoan(e);
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Đang đồng bộ…' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    unitController.dispose();
  }
}
