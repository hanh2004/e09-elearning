// GIAO DIỆN DÙNG CHUNG: Giao diện dùng chung cho web admin: màu, thanh tiêu đề và thẻ nội dung.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';

class AdminUi {
  static ThemeData get theme => AppTheme.light.copyWith(
    cardTheme: AppTheme.light.cardTheme.copyWith(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
  );
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
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    toolbarHeight: 72,
    backgroundColor: AppTheme.red,
    foregroundColor: Colors.white,
    surfaceTintColor: AppTheme.red,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 22,
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
            padding: const EdgeInsets.only(right: 20, left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
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
                const SizedBox(width: 16),
                const VerticalDivider(
                  width: 1,
                  indent: 14,
                  endIndent: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 16),
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
      borderRadius: BorderRadius.circular(14),
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
  const AdminPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vanBan = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: AppTheme.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xFF60779A)),
            ),
          ],
        );
        if (action == null || constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vanBan,
              if (action != null) ...[const SizedBox(height: 14), action!],
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
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconBox = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
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
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: const TextStyle(color: Color(0xFF60779A))),
            ],
          );
          if (constraints.maxWidth < 280) {
            return Column(
              children: [iconBox, const SizedBox(height: 8), labels],
            );
          }
          return Row(
            children: [
              iconBox,
              const SizedBox(width: 14),
              Expanded(child: labels),
            ],
          );
        },
      ),
    ),
  );
}
