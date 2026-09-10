import '../../models/unit_label.dart';

import 'package:flutter/material.dart';

import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});
  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  final service = LearningService();
  late final stream = service.db
      .collection('users')
      .where('role', isEqualTo: 'user')
      .snapshots();
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đơn vị học viên')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Tìm học viên hoặc đơn vị',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: LearningList(
            stream: stream,
            builder: (docs) => ListView(
              children: [
                for (final doc in docs.where(
                  (d) =>
                      '${d.data()['name']} ${d.data()['classId']} ${d.data()['unit']} ${d.data()['subUnit'] ?? ''}'
                          .toLowerCase()
                          .contains(search),
                ))
                  ListTile(
                    title: Text(doc.data()['name'] ?? ''),
                    subtitle: Text('Đơn vị: ${unitLabel(doc.data())}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class AdminLearningAuditScreen extends StatefulWidget {
  const AdminLearningAuditScreen({super.key});
  @override
  State<AdminLearningAuditScreen> createState() =>
      _AdminLearningAuditScreenState();
}

class _AdminLearningAuditScreenState extends State<AdminLearningAuditScreen> {
  final service = LearningService();
  late final stream = service.db
      .collection('learning_audit')
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử chỉnh sửa học tập')),
    body: LearningList(
      stream: stream,
      builder: (docs) => docs.isEmpty
          ? const Center(child: Text('Chưa có chỉnh sửa.'))
          : ListView(
              children: [
                for (final doc in docs)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(doc.data()['path'] ?? ''),
                    subtitle: Text(
                      '${doc.data()['actorId']} • ${doc.data()['at']}',
                    ),
                  ),
              ],
            ),
    ),
  );
}
