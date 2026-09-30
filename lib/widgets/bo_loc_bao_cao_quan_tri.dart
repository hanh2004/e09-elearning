import 'package:flutter/material.dart';

/// Bộ lọc chung cho các bảng báo cáo.
class AdminReportFilters extends StatelessWidget {
  const AdminReportFilters({
    super.key,
    required this.units,
    required this.subUnits,
    required this.selectedUnit,
    required this.selectedSubUnit,
    required this.searchController,
    required this.searchLabel,
    required this.onUnitChanged,
    required this.onSubUnitChanged,
    required this.onSearchChanged,
    this.exams,
    this.selectedExam,
    this.onExamChanged,
    this.onClear,
  });

  final List<String> units;
  final List<String> subUnits;
  final String? selectedUnit;
  final String? selectedSubUnit;
  final TextEditingController searchController;
  final String searchLabel;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<String?> onSubUnitChanged;
  final ValueChanged<String> onSearchChanged;
  final List<(String, String)>? exams;
  final String? selectedExam;
  final ValueChanged<String?>? onExamChanged;
  final VoidCallback? onClear;

  Widget _dropdown(
    double width,
    String key,
    String label,
    IconData icon,
    String? value,
    String allLabel,
    List<(String, String)> options,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        DropdownMenuItem<String>(value: null, child: Text(allLabel)),
        for (final option in options)
          DropdownMenuItem<String>(
            value: option.$1,
            child: Text(option.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          _dropdown(
            width,
            'unit:$selectedUnit',
            'Đơn vị',
            Icons.apartment,
            selectedUnit,
            'Tất cả đơn vị',
            [
              for (final unit in units)
                (unit, unit.isEmpty ? 'Chưa phân đơn vị' : unit),
            ],
            onUnitChanged,
          ),
          if (selectedUnit != null)
            _dropdown(
              width,
              'sub-unit:$selectedUnit:$selectedSubUnit',
              'Trực thuộc',
              Icons.account_tree_outlined,
              selectedSubUnit,
              'Tất cả trực thuộc',
              [for (final subUnit in subUnits) (subUnit, subUnit)],
              onSubUnitChanged,
            ),
          SizedBox(
            width: width,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: searchLabel,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          if (onExamChanged != null)
            _dropdown(
              width,
              'exam:$selectedExam',
              'Bài thi',
              Icons.assignment_outlined,
              selectedExam,
              'Tất cả bài thi',
              exams ?? const [],
              onExamChanged!,
            ),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Xóa bộ lọc'),
            ),
        ],
      );
    },
  );
}
