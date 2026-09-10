import '../models/unit_label.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/learning_service.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.uid,
    required this.fallbackName,
    this.email = '',
    this.service,
  });
  final String uid;
  final String fallbackName;
  final String email;
  final LearningService? service;
  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  late final profile = (widget.service ?? LearningService()).db
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profile,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final avatar = data['avatarUrl'] as String? ?? '';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipOval(
                    child:
                        avatar.isNotEmpty &&
                            LearningPolicy.validateUrl(avatar) == null
                        ? Image.network(
                            avatar,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const CircleAvatar(
                              radius: 32,
                              child: Icon(Icons.person_outline, size: 32),
                            ),
                          )
                        : const CircleAvatar(
                            radius: 32,
                            child: Icon(Icons.person_outline, size: 32),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] as String? ?? widget.fallbackName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (widget.email.isNotEmpty)
                          Text(
                            widget.email,
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        if ((data['unit'] as String? ?? '').isNotEmpty)
                          Text(
                            'Đơn vị quản lý: ${data['unit']}',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        if ((data['subUnit'] as String? ?? '').isNotEmpty)
                          Text(
                            'Đơn vị: ${unitLabel(data)}',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        if (snapshot.hasError)
                          const Text(
                            'Chưa cập nhật được hồ sơ.',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
