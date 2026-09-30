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
    this.courses,
    this.selectedCourse,
    this.onCourseChanged,
    this.courseTypes,
    this.selectedCourseType,
    this.onCourseTypeChanged,
    this.onClear,
    this.trailing,
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
  final List<(String, String)>? courses;
  final String? selectedCourse;
  final ValueChanged<String?>? onCourseChanged;
  final List<(String, String)>? courseTypes;
  final String? selectedCourseType;
  final ValueChanged<String?>? onCourseTypeChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

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
          if (trailing != null) SizedBox(width: width, child: trailing),
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
          if (onCourseChanged != null)
            _dropdown(
              width,
              'course:$selectedCourse',
              'Khóa học',
              Icons.menu_book_outlined,
              selectedCourse,
              'Tất cả khóa học',
              courses ?? const [],
              onCourseChanged!,
            ),
          if (onCourseTypeChanged != null)
            _dropdown(
              width,
              'course-type:$selectedCourseType',
              'Loại khóa học',
              Icons.category_outlined,
              selectedCourseType,
              'Tất cả loại khóa học',
              courseTypes ?? const [],
              onCourseTypeChanged!,
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
