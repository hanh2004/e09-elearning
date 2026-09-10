import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/learning_widgets.dart';

class UserScheduleScreen extends StatefulWidget {
  const UserScheduleScreen({super.key, required this.uid});
  final String uid;
  @override
  State<UserScheduleScreen> createState() => _UserScheduleScreenState();
}

class _UserScheduleScreenState extends State<UserScheduleScreen> {
  late final profile = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch học và lịch thi')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không tải được lịch.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LearningList(
          stream: FirebaseFirestore.instance
              .collection('learning_events')
              .where('audience', isEqualTo: 'all')
              .snapshots(),
          builder: (docs) {
            final events = docs.toList()
              ..sort(
                (a, b) => (a.data()['startsAt'] as Timestamp).compareTo(
                  b.data()['startsAt'] as Timestamp,
                ),
              );
            if (events.isEmpty) {
              return const Center(
                child: Text('Chưa có lịch học hoặc lịch thi.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final doc in events)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        doc.data()['type'] == 'exam'
                            ? Icons.assignment
                            : Icons.school,
                      ),
                      title: Text(doc.data()['title'] ?? ''),
                      subtitle: Text(
                        '${(doc.data()['startsAt'] as Timestamp).toDate()} – ${(doc.data()['endsAt'] as Timestamp).toDate()}\n${doc.data()['note'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
