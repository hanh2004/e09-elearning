import 'package:flutter/material.dart';

/// Hiện cả khi chưa nhập đơn vị cá nhân và khi quản lý vừa chuyển đơn vị.
class UnitUpdateNotice extends StatelessWidget {
  const UnitUpdateNotice({
    super.key,
    required this.profile,
    required this.onUpdate,
  });
  final Map<String, dynamic> profile;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final noManagerUnit = (profile['unit'] as String? ?? '').trim().isEmpty;
    final missingUnit = (profile['subUnit'] as String? ?? '').trim().isEmpty;
    final changed = profile['unitNeedsConfirmation'] == true;
    if (!noManagerUnit && !missingUnit && !changed) {
      return const SizedBox.shrink();
    }
    final thongDiep = noManagerUnit
        ? 'Chưa có mã đơn vị. Vui lòng liên hệ quản lý.'
        : changed
        ? 'Vui lòng cập nhật, xác nhận đơn vị của bạn.'
        : 'Bạn chưa nhập đơn vị. Hãy cập nhật hồ sơ.';
    return Material(
      color: const Color(0xFFFFF3CD),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onUpdate,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF8A6500)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    thongDiep,
                    style: const TextStyle(color: Color(0xFF6B5000)),
                  ),
                ),
                IconButton(
                  tooltip: 'Cập nhật đơn vị',
                  onPressed: onUpdate,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
