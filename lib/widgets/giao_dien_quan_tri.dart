// GIAO DIỆN DÙNG CHUNG: Giao diện dùng chung cho web admin: màu, thanh tiêu đề và thẻ nội dung.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';
import '../models/dinh_danh_tai_khoan.dart';

class AdminUi {
  static ThemeData get theme {
    final base = AppTheme.light;
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Arial'),
      visualDensity: VisualDensity.compact,
      cardTheme: base.cardTheme.copyWith(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminUi.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        surfaceTintColor: AppTheme.red,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Arial',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xCCFFFFFF),
        labelStyle: TextStyle(
          fontFamily: 'Arial',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Arial',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  static const page = Color(0xFFF4F7FC);
  static const border = Color(0xFFDDE6F2);
  static AppBar appBar(
    String tieuDe, {
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) => AppBar(
    title: Text(
      tieuDe,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    toolbarHeight: 64,
    backgroundColor: AppTheme.red,
    foregroundColor: Colors.white,
    surfaceTintColor: AppTheme.red,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: const TextStyle(
      fontFamily: 'Arial',
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    actions: [
      ...?actions,
      Builder(
        builder: (context) {
          if (MediaQuery.sizeOf(context).width < 900) {
            return const SizedBox.shrink();
          }
          final hienTai = DateTime.now();
          final ngay =
              '${hienTai.day.toString().padLeft(2, '0')}/${hienTai.month.toString().padLeft(2, '0')}/${hienTai.year}';
          return Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 19,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ngay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const VerticalDivider(
                  width: 1,
                  indent: 14,
                  endIndent: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 12),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    AccountSession.current?.displayName ?? 'Quản lý',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          );
        },
      ),
    ],
    bottom: bottom,
  );
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AdminUi.border),
    ),
    child: child,
  );
}

/// Trạng thái đang tải của Web Admin dùng thanh ngang, không dùng vòng tròn.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(width: 220, child: LinearProgressIndicator(minHeight: 4)),
  );
}

class AdminPageHeading extends StatelessWidget {
  const AdminPageHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vanBan = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.navy,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
        if (action == null || constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vanBan,
              if (action != null) ...[const SizedBox(height: 10), action!],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: vanBan),
            action!,
          ],
        );
      },
    ),
  );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => AdminCard(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconBox = Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          );
          final labels = Column(
            crossAxisAlignment: constraints.maxWidth < 210
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF60779A), fontSize: 15),
              ),
            ],
          );
          if (constraints.maxWidth < 250) {
            return Column(
              children: [iconBox, const SizedBox(height: 8), labels],
            );
          }
          return Row(
            children: [
              iconBox,
              const SizedBox(width: 10),
              Expanded(child: labels),
            ],
          );
        },
      ),
    ),
  );
}
