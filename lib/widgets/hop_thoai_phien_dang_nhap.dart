import 'package:flutter/material.dart';

Future<bool> confirmAccountSessionTakeover(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tài khoản đang được sử dụng'),
        content: const Text(
          'Tài khoản này đang có phiên đăng nhập khác. '
          'Bạn có muốn kết thúc phiên đó và đăng nhập tại đây không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Có, đăng xuất phiên kia'),
          ),
        ],
      ),
    ) ??
    false;
