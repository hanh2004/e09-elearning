import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key});

  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color primaryColor = const Color(0xFF6B0000);
  String _searchQuery = '';

  void _showUserDialog({String? docId, Map<String, dynamic>? userData}) {
    final nameController = TextEditingController(text: userData?['name'] ?? '');
    final usernameController = TextEditingController(
      text: userData?['username'] ?? '',
    );
    final passwordController = TextEditingController(
      text: userData?['password'] ?? '',
    );
    String selectedRole = userData?['role'] ?? 'Học viên';

    final isEditing = docId != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          return AlertDialog(
            title: Text(isEditing ? 'Sửa Tài Khoản' : 'Thêm Tài Khoản Mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                  ),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Học viên',
                        child: Text('Học viên'),
                      ),
                      DropdownMenuItem(
                        value: 'Giáo viên',
                        child: Text('Giáo viên'),
                      ),
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final username = usernameController.text.trim();
                  final password = passwordController.text.trim();

                  if (name.isNotEmpty &&
                      username.isNotEmpty &&
                      password.isNotEmpty) {
                    if (isEditing) {
                      await _firestoreService.updateUser(
                        docId: docId,
                        name: name,
                        username: username,
                        password: password,
                        role: selectedRole,
                      );
                    } else {
                      await _firestoreService.addUser(
                        name: name,
                        username: username,
                        password: password,
                        role: selectedRole,
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng điền đầy đủ thông tin!'),
                      ),
                    );
                  }
                },
                child: Text(
                  isEditing ? 'Cập nhật' : 'Thêm',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Quản lý Tài khoản',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm tên hoặc tài khoản...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Lỗi tải dữ liệu'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final username = (data['username'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      username.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy tài khoản nào'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final user = doc.data();
                    return _buildUserCard(doc.id, user);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserCard(String docId, Map<String, dynamic> user) {
    final String role = user['role'] ?? 'Học viên';
    Color roleColor = Colors.blue;
    if (role == 'Admin') roleColor = Colors.red;
    if (role == 'Giáo viên') roleColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: roleColor),
        ),
        title: Text(
          user['name'] ?? 'Không có tên',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('TK: ${user['username'] ?? 'N/A'} | Vai trò: $role'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _showUserDialog(docId: docId, userData: user),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: Text(
                      'Bạn có chắc muốn xóa tài khoản "${user['name']}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Xóa',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _firestoreService.deleteUser(docId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
