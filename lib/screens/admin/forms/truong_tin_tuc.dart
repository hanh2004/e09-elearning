part of '../quan_ly_tin_tuc.dart';

class _NhanTrinhSua extends StatelessWidget {
  const _NhanTrinhSua(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700),
  );
}

class _TruongNhapTinTuc extends StatelessWidget {
  const _TruongNhapTinTuc({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.displayLimit,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int? displayLimit;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminUi.border),
      ),
    ),
    buildCounter:
        (context, {required currentLength, required isFocused, maxLength}) =>
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$currentLength/${displayLimit ?? this.maxLength}',
                style: const TextStyle(color: Color(0xFF60779A), fontSize: 12),
              ),
            ),
  );
}

class _VungChonAnhBia extends StatelessWidget {
  const _VungChonAnhBia({required this.imageUrl, required this.selectedImage});

  final String imageUrl;
  final SelectedUploadImage? selectedImage;

  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD7A7A7)),
    ),
    child: selectedImage != null
        ? Image.memory(
            selectedImage!.bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          )
        : imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, _, _) => const _AnhBiaMacDinh(),
          )
        : const _AnhBiaMacDinh(),
  );
}

class _AnhBiaMacDinh extends StatelessWidget {
  const _AnhBiaMacDinh();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, color: Color(0xFF815353), size: 40),
        SizedBox(height: 8),
        Text('Ảnh tiêu đề', style: TextStyle(color: Color(0xFF6D4141))),
        SizedBox(height: 4),
        Text(
          'Tỷ lệ 16:9, tối đa 20 MB',
          style: TextStyle(color: Color(0xFF7785A0), fontSize: 13),
        ),
      ],
    ),
  );
}

class _CongTacCaiDat extends StatelessWidget {
  const _CongTacCaiDat({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: value, onChanged: onChanged),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      Tooltip(
        message: hint,
        child: const Padding(
          padding: EdgeInsets.only(left: 5),
          child: Icon(Icons.info_outline, size: 19, color: AppTheme.navy),
        ),
      ),
    ],
  );
}
