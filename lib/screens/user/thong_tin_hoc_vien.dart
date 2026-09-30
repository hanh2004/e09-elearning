// APP HỌC VIÊN: Tab thông tin, gom lối vào Tin tức và Thông báo.

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import 'danh_sach_tin_tuc.dart';
import 'thong_bao_hoc_vien.dart';

/// Điểm vào chung cho tin tức và thông báo học viên.
class UserInformationScreen extends StatelessWidget {
  const UserInformationScreen({
    super.key,
    required this.uid,
    required this.service,
  });

  final String uid;
  final LearningService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: LearnerHeader(
      title: const Text('Thông tin'),
      backgroundColor: AppTheme.red,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _openInfo(
          context,
          'Tin tức',
          Icons.newspaper_outlined,
          NewsScreen(service: service),
        ),
        _openInfo(
          context,
          'Thông báo',
          Icons.notifications_active_outlined,
          UserNotificationsScreen(uid: uid, service: service),
        ),
      ],
    ),
  );

  Widget _openInfo(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppTheme.red),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.of(context)
              .push<void>(MaterialPageRoute<void>(builder: (_) => screen)),
    ),
  );
}
