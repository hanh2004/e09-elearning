// Luồng chọn và xóa hàng loạt tài khoản; chỉ admin tổng được mở chức năng này.
// Đây là phần xử lý tách riêng của quan_ly_tai_khoan.dart.
part of "quan_ly_tai_khoan.dart";

extension _AdminAccountBulkDelete on _TrangThaiTaiKhoanQuanTri {
  void _moXoaHangLoat() {
    if (_danhTinh?.isRoot != true) return;
    _capNhatTrangThaiXoaHangLoat(() {
      _hienXoaHangLoat = true;
      _hienYeuCauCapLaiMatKhau = false;
      _hienYeuCauDuyetQuanLy = false;
      _dangXoaHangLoat = false;
      _buocXoaHangLoat = 0;
      _quanLyChonXoa.clear();
      _hocVienChonXoa.clear();
    });
  }

  void _huyXoaHangLoat() {
    _capNhatTrangThaiXoaHangLoat(() {
      _hienXoaHangLoat = false;
      _dangXoaHangLoat = false;
      _buocXoaHangLoat = 0;
      _quanLyChonXoa.clear();
      _hocVienChonXoa.clear();
    });
  }

  String _tenTaiKhoan(Map<String, dynamic> duLieu) =>
      (duLieu['name'] ?? duLieu['username'] ?? 'Tài khoản').toString();

  Widget _manHinhXoaHangLoat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> taiKhoan,
  ) {
    final tenTaiKhoanTheoId = {
      for (final banGhi in taiKhoan) banGhi.id: _tenTaiKhoan(banGhi.data()),
    };
    final cacQuanLy =
        taiKhoan
            .where(
              (banGhi) =>
                  ['admin', 'super_admin'].contains(banGhi.data()['role']) &&
                  ['active', 'blocked'].contains(banGhi.data()['status']),
            )
            .toList()
          ..sort(
            (a, b) => _tenTaiKhoan(a.data()).compareTo(_tenTaiKhoan(b.data())),
          );
    final cacHocVien =
        taiKhoan
            .where(
              (banGhi) =>
                  banGhi.data()['role'] == 'user' &&
                  [
                    'active',
                    'blocked',
                    'deleting',
                  ].contains(banGhi.data()['status']),
            )
            .toList()
          ..sort(
            (a, b) => _tenTaiKhoan(a.data()).compareTo(_tenTaiKhoan(b.data())),
          );
    final hocVienTheoQuanLy = cacHocVien
        .where((banGhi) => _quanLyChonXoa.contains(banGhi.data()['createdBy']))
        .toList();
    final hocVienDuocChon = hocVienTheoQuanLy
        .where((banGhi) => _hocVienChonXoa.contains(banGhi.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _buocXoaHangLoat == 0
                      ? 'Xóa nhiều học viên · Bước 1/2: Chọn quản lý'
                      : 'Xóa nhiều học viên · Bước 2/2: Chọn học viên',
                  style: const TextStyle(
                    color: Color(0xFF1B2D5B),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _buocXoaHangLoat == 0
                ? 'Chọn một hoặc nhiều quản lý, bao gồm admin phụ và admin tổng.'
                : 'Đang chọn học viên do ${_quanLyChonXoa.length} quản lý đã chọn phụ trách.',
            style: const TextStyle(color: Color(0xFF6079A4)),
          ),
          const SizedBox(height: 12),
          if (_buocXoaHangLoat == 0) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _dangXoaHangLoat || cacQuanLy.isEmpty
                    ? null
                    : () => _capNhatTrangThaiXoaHangLoat(() {
                        if (_quanLyChonXoa.length == cacQuanLy.length) {
                          _quanLyChonXoa.clear();
                        } else {
                          _quanLyChonXoa
                            ..clear()
                            ..addAll(cacQuanLy.map((banGhi) => banGhi.id));
                        }
                      }),
                icon: const Icon(Icons.select_all),
                label: Text(
                  cacQuanLy.isNotEmpty &&
                          _quanLyChonXoa.length == cacQuanLy.length
                      ? 'Bỏ chọn tất cả'
                      : 'Chọn tất cả quản lý',
                ),
              ),
            ),
            Expanded(
              child: cacQuanLy.isEmpty
                  ? const Center(child: Text('Không có quản lý khả dụng.'))
                  : ListView.builder(
                      itemCount: cacQuanLy.length,
                      itemBuilder: (context, index) {
                        final quanLy = cacQuanLy[index];
                        final duLieu = quanLy.data();
                        final soHocVien = cacHocVien
                            .where(
                              (hocVien) =>
                                  hocVien.data()['createdBy'] == quanLy.id,
                            )
                            .length;
                        return Card(
                          child: CheckboxListTile(
                            value: _quanLyChonXoa.contains(quanLy.id),
                            onChanged: _dangXoaHangLoat
                                ? null
                                : (chon) => _capNhatTrangThaiXoaHangLoat(() {
                                    if (chon == true) {
                                      _quanLyChonXoa.add(quanLy.id);
                                    } else {
                                      _quanLyChonXoa.remove(quanLy.id);
                                    }
                                  }),
                            title: Text(_tenTaiKhoan(duLieu)),
                            subtitle: Text(
                              '${duLieu['username'] ?? ''} · ${duLieu['role'] == 'super_admin' ? 'Admin tổng' : 'Admin phụ'} · ${_donViCua(duLieu)} · $soHocVien học viên',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
          ] else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _dangXoaHangLoat
                      ? null
                      : () => _capNhatTrangThaiXoaHangLoat(
                          () => _buocXoaHangLoat = 0,
                        ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại chọn quản lý'),
                ),
                TextButton.icon(
                  onPressed: _dangXoaHangLoat || hocVienTheoQuanLy.isEmpty
                      ? null
                      : () => _capNhatTrangThaiXoaHangLoat(() {
                          if (_hocVienChonXoa.length ==
                              hocVienTheoQuanLy.length) {
                            _hocVienChonXoa.clear();
                          } else {
                            _hocVienChonXoa
                              ..clear()
                              ..addAll(
                                hocVienTheoQuanLy.map((banGhi) => banGhi.id),
                              );
                          }
                        }),
                  icon: const Icon(Icons.select_all),
                  label: Text(
                    hocVienTheoQuanLy.isNotEmpty &&
                            _hocVienChonXoa.length == hocVienTheoQuanLy.length
                        ? 'Bỏ chọn tất cả'
                        : 'Chọn tất cả học viên',
                  ),
                ),
              ],
            ),
            Expanded(
              child: hocVienTheoQuanLy.isEmpty
                  ? const Center(
                      child: Text(
                        'Các quản lý đã chọn không có học viên để xóa.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: hocVienTheoQuanLy.length,
                      itemBuilder: (context, index) {
                        final hocVien = hocVienTheoQuanLy[index];
                        final duLieu = hocVien.data();
                        final ownerId = duLieu['createdBy']?.toString();
                        final ownerName = ownerId == null
                            ? 'Không rõ quản lý'
                            : tenTaiKhoanTheoId[ownerId] ?? ownerId;
                        return Card(
                          child: CheckboxListTile(
                            value: _hocVienChonXoa.contains(hocVien.id),
                            onChanged: _dangXoaHangLoat
                                ? null
                                : (chon) => _capNhatTrangThaiXoaHangLoat(() {
                                    if (chon == true) {
                                      _hocVienChonXoa.add(hocVien.id);
                                    } else {
                                      _hocVienChonXoa.remove(hocVien.id);
                                    }
                                  }),
                            title: Text(_tenTaiKhoan(duLieu)),
                            subtitle: Text(
                              '${duLieu['username'] ?? ''} · Quản lý: $ownerName · ${duLieu['status'] == 'blocked'
                                  ? 'Đã khóa'
                                  : duLieu['status'] == 'deleting'
                                  ? 'Đang chờ xóa'
                                  : 'Đang hoạt động'}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
          ],
          if (_dangXoaHangLoat) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Đang xóa các tài khoản đã chọn…'),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dangXoaHangLoat ? null : _huyXoaHangLoat,
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 8),
              if (_buocXoaHangLoat == 0)
                FilledButton.icon(
                  onPressed: _dangXoaHangLoat || _quanLyChonXoa.isEmpty
                      ? null
                      : () => _capNhatTrangThaiXoaHangLoat(() {
                          _buocXoaHangLoat = 1;
                          final eligible = cacHocVien
                              .where(
                                (banGhi) => _quanLyChonXoa.contains(
                                  banGhi.data()['createdBy'],
                                ),
                              )
                              .map((banGhi) => banGhi.id)
                              .toSet();
                          _hocVienChonXoa.removeWhere(
                            (id) => !eligible.contains(id),
                          );
                        }),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Tiếp tục (${_quanLyChonXoa.length})'),
                )
              else
                FilledButton.icon(
                  onPressed: _dangXoaHangLoat || hocVienDuocChon.isEmpty
                      ? null
                      : () => _xacNhanXoaHangLoat(hocVienDuocChon),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text('Xóa ${hocVienDuocChon.length} học viên'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _xacNhanXoaHangLoat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> hocVien,
  ) async {
    if (_danhTinh?.isRoot != true || hocVien.isEmpty) return;
    final names = hocVien.map((banGhi) {
      final duLieu = banGhi.data();
      final username = duLieu['username']?.toString();
      return username == null || username.isEmpty
          ? _tenTaiKhoan(duLieu)
          : '${_tenTaiKhoan(duLieu)} ($username)';
    }).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Bạn có chắc muốn xóa ${hocVien.length} học viên?'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tài khoản và toàn bộ bài làm của các học viên đã chọn sẽ bị xóa vĩnh viễn. Thao tác này không thể hoàn tác.',
              ),
              const SizedBox(height: 12),
              for (final name in names.take(8)) Text('• $name'),
              if (names.length > 8)
                Text('… và ${names.length - 8} học viên khác'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
            ),
            child: Text('Xóa ${hocVien.length} học viên'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _capNhatTrangThaiXoaHangLoat(() => _dangXoaHangLoat = true);
    final deletedIds = <String>{};
    Object? failure;
    for (var start = 0; start < hocVien.length; start += 3) {
      final batch = hocVien.skip(start).take(3).toList();
      final results = await Future.wait<MapEntry<String, Object?>>(
        batch.map((banGhi) async {
          try {
            await _dichVu.deleteUser(banGhi.id);
            return MapEntry(banGhi.id, null);
          } catch (error) {
            return MapEntry(banGhi.id, error);
          }
        }),
      );
      for (final result in results) {
        if (result.value == null) {
          deletedIds.add(result.key);
        } else {
          failure ??= result.value;
        }
      }
      if (results.any((result) => result.value != null)) break;
    }
    if (!mounted) return;

    if (deletedIds.length == hocVien.length) {
      _huyXoaHangLoat();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${deletedIds.length} học viên.')),
      );
      return;
    }
    _capNhatTrangThaiXoaHangLoat(() {
      _dangXoaHangLoat = false;
      _hocVienChonXoa.removeAll(deletedIds);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã xóa ${deletedIds.length}/${hocVien.length} học viên. ${_loiTaiKhoan(failure ?? StateError('Có tài khoản chưa xóa được.'))}',
        ),
      ),
    );
  }
}
