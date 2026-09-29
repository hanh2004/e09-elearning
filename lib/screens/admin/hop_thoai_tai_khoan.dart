part of "quan_ly_tai_khoan.dart";

extension _AdminAccountDialogs on _TrangThaiTaiKhoanQuanTri {
  Future<void> _moHopThoaiTaiKhoan({
    String? id,
    Map<String, dynamic>? user,
    bool propose = false,
  }) async {
    if (_danhTinh?.isAdmin != true || (propose && !_danhTinh!.isRoot)) return;
    if (id != null && !_danhTinh!.canEdit(id, user!)) return;
    String? actorUnit;
    if (id == null && !propose) {
      try {
        actorUnit = _danhTinh!.isRoot
            ? 'E09'
            : ((await _dichVu.db.collection('users').doc(_danhTinh!.id).get())
                              .data()?['unit']
                          as String? ??
                      '')
                  .trim();
      } catch (loi) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tải được mã đơn vị. ${_loiTaiKhoan(loi)}'),
            ),
          );
        }
        return;
      }
      if (actorUnit.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quản lý chưa được phân mã đơn vị.')),
          );
        }
        return;
      }
    }
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
    final userCode = TextEditingController(
      text:
          user?['userCodeSuffix']?.toString() ??
          (() {
            final fullCode = user?['userCode']?.toString() ?? '';
            final oldUnit = user?['unit']?.toString() ?? '';
            return fullCode.startsWith('$oldUnit-')
                ? fullCode.substring(oldUnit.length + 1)
                : '';
          })(),
    );
    final donVi = TextEditingController(text: user?['unit'] ?? '');
    final form = GlobalKey<FormState>();
    var busy = false;
    String? loi;
    final isStudentEdit = id != null && user?['role'] == 'user';
    final rootCanChangeCodeUnit = isStudentEdit && _danhTinh!.isRoot;
    final managerCanChangeCodeSuffix = isStudentEdit && !_danhTinh!.isRoot;
    await showDialog<void>(
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
                            helperText: 'Mã này sẽ đứng trước mã người dùng.',
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
                      if (rootCanChangeCodeUnit)
                        TextFormField(
                          controller: donVi,
                          decoration: InputDecoration(
                            labelText: 'Mã đơn vị trong mã người dùng',
                            helperText:
                                'Mã đầy đủ: ${donVi.text}-${userCode.text}. '
                                'Đuôi do quản lý phụ trách giữ nguyên.',
                          ),
                          onChanged: (_) => update(() {}),
                          validator: (v) =>
                              v == null ||
                                  v.trim().isEmpty ||
                                  v.trim().length > 100
                              ? 'Nhập mã đơn vị, tối đa 100 ký tự.'
                              : null,
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
                      if (id == null && !propose)
                        TextFormField(
                          controller: userCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Mã người dùng',
                            prefixText: '$actorUnit-',
                            helperText: 'Mã hoàn chỉnh: $actorUnit-mã bạn nhập',
                          ),
                          validator: (v) =>
                              v == null ||
                                  !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$')
                                      .hasMatch(v.trim())
                              ? 'Mã gồm 1–64 ký tự không dấu, số, _, ., @ hoặc -.'
                              : null,
                        ),
                      if (managerCanChangeCodeSuffix)
                        TextFormField(
                          controller: userCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Đuôi mã người dùng',
                            prefixText: '${user?['unit'] ?? ''}-',
                            helperText: 'Chỉ đổi phần đuôi; mã đơn vị do quản lý tổng đặt.',
                          ),
                          validator: (v) =>
                              v == null ||
                                  !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$')
                                      .hasMatch(v.trim())
                              ? 'Đuôi mã gồm 1–64 ký tự hợp lệ.'
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
                              unit: rootCanChangeCodeUnit
                                  ? donVi.text.trim()
                                  : null,
                              userCodeSuffix: managerCanChangeCodeSuffix
                                  ? userCode.text.trim()
                                  : null,
                            );
                          } else {
                            await _dichVu.addUser(
                              name: ten.text.trim(),
                              username: tenDangNhap.text,
                              password: matKhau.text,
                              role: 'user',
                              userCodeSuffix: userCode.text.trim(),
                              unit: actorUnit,
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
    // Hủy controller sau khi hiệu ứng đóng hộp thoại đã gỡ các ô nhập liệu.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    ten.dispose();
    tenDangNhap.dispose();
    matKhau.dispose();
    userCode.dispose();
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Quản lý mục trực thuộc'),
          content: SizedBox(
            width: 430,
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
                              : () => update(() => cacGiaTri.remove(giaTri)),
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
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
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
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
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
    );
    boDieuKhien.dispose();
  }

  Future<void> _moHopThoaiChuyenQuanLy(
    String userId,
    Map<String, dynamic> nguoiDung,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacQuanLy,
  ) async {
    final targetUnit = (nguoiDung['unit'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final eligibleManagers = cacQuanLy
        .where(
          (manager) =>
              (manager.data()['unit'] ?? '').toString().trim().toLowerCase() !=
              targetUnit,
        )
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
          title: const Text('Chuyển học viên cho quản lý'),
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
                        labelText: 'Quản lý mới',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final manager in eligibleManagers)
                          DropdownMenuItem(
                            value: manager.id,
                            child: Text(
                              '${manager.data()['name'] ?? manager.data()['username'] ?? manager.id} • ${manager.data()['unit'] ?? 'Chưa có mã đơn vị'}',
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
                      'Phần đuôi mã hiện tại sẽ được giữ nguyên; chỉ phần mã đơn vị thay đổi.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tiến độ học tập, bài đã làm và lịch sử thi của học viên sẽ được giữ nguyên.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nếu kết nối bị gián đoạn, hãy nhập lại cùng mã đơn vị và bấm Lưu để tiếp tục.',
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
    await showDialog<void>(
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
                      const Text(
                        'Phần đuôi mã của từng học viên sẽ được giữ nguyên. '
                        'Chỉ mã đơn vị ở đầu mã được đổi.',
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
                                'Đã đổi mã đơn vị; đuôi mã học viên được giữ nguyên.',
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
  }
}
