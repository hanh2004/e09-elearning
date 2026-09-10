String unitLabel(Map<String, dynamic> data) {
  final unit = (data['unit'] ?? '').toString().trim();
  final prefix = (data['subUnit'] ?? '').toString().trim();
  if (prefix.isEmpty) return unit;
  return unit.isEmpty ? prefix : '$prefix-$unit';
}
