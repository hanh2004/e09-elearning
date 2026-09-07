class WorkbookPickerException implements Exception {
  const WorkbookPickerException(this.message);

  final String message;
}

void validateWorkbookFile(String name, int size) {
  if (!name.toLowerCase().endsWith('.xlsx') || size > 2 * 1024 * 1024) {
    throw const WorkbookPickerException('Chỉ nhận file .xlsx tối đa 2 MB.');
  }
}
