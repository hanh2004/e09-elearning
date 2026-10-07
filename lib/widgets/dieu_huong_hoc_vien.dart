// GIAO DIỆN DÙNG CHUNG: Thanh menu dưới của học viên và chuyển tab từ trang con.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';

class LearnerNavigation extends StatelessWidget {
  const LearnerNavigation({
    super.key,
    required this.selectedIndex,
    this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  static final section = ValueNotifier<int>(0);
  static void open(BuildContext context, int viTri) {
    section.value = viTri;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
        boxShadow: [
          BoxShadow(
            color: Color(0x140E1C4D),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, item) in const [
              (0, (Icons.home_outlined, 'Trang chủ')),
              (5, (Icons.newspaper_outlined, 'Tin tức')),
              (1, (Icons.menu_book_outlined, 'Học tập')),
              (2, (Icons.assignment_outlined, 'Kiểm tra')),
              (6, (Icons.grid_view_rounded, 'Tiện ích')),
            ])
              Expanded(
                child: Semantics(
                  selected: index == selectedIndex,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected != null
                        ? onSelected!(index)
                        : open(context, index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: index == selectedIndex
                                  ? AppTheme.red.withValues(alpha: .10)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.$1,
                              size: 22,
                              color: index == selectedIndex
                                  ? AppTheme.red
                                  : const Color(0xFF8995AA),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: index == selectedIndex
                                  ? AppTheme.red
                                  : const Color(0xFF68758C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
