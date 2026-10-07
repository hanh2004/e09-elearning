// APP HỌC VIÊN: Tab Tin tức trong thanh điều hướng chính.

import 'package:flutter/material.dart';

import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'danh_sach_tin_tuc.dart';

/// Giữ tên widget cũ để không làm hỏng các route hiện đang trỏ tới tab này.
class UserInformationScreen extends StatelessWidget {
  const UserInformationScreen({super.key, required this.service});

  final LearningService service;

  @override
  Widget build(BuildContext context) => NewsScreen(service: service);
}
