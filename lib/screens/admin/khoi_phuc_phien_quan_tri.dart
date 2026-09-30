// Cổng xác thực quyền admin và nhận phiên đăng nhập trước khi mở khu vực quản trị.
// Nếu tài khoản đang có phiên khác, hộp thoại cho phép xác nhận đăng xuất phiên đó.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/tai_khoan/phien_dang_nhap_quan_tri_web.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../man_hinh_dang_nhap.dart';
import '../../widgets/hop_thoai_phien_dang_nhap.dart';

/// Validates the active Firebase admin session before showing the console.
class AdminSessionGate extends StatefulWidget {
  const AdminSessionGate({super.key, required this.homeBuilder});

  final Widget Function(Map<String, dynamic>) homeBuilder;

  @override
  State<AdminSessionGate> createState() => _AdminSessionGateState();
}

class _AdminSessionGateState extends State<AdminSessionGate> {
  StreamSubscription<User?>? _authSubscription;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  int _restoreRevision = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _restoreSession,
      onError: (_) {
        if (!mounted) return;
        AccountSession.current = null;
        setState(() {
          _loading = false;
          _profile = null;
        });
      },
    );
  }

  Future<void> _restoreSession(User? user) async {
    // Khi đã hiện form, LoginScreen tự xử lý xác thực và chuyển trang.
    // Không thay form bằng màn hình chờ khi Auth phát sự kiện đăng nhập:
    // form bị dispose giữa chừng sẽ tự đăng xuất phiên vừa tạo.
    if (!_loading && _profile == null) return;

    final revision = ++_restoreRevision;
    if (user == null) {
      AccountSession.current = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _profile = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _profile = null;
      });
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final data = snapshot.data();
      if (revision != _restoreRevision || !mounted) return;
      if (data == null || data['status'] != 'active') {
        AccountSession.current = null;
        setState(() {
          _loading = false;
          _profile = null;
        });
        return;
      }

      final identity = AccountIdentity(
        id: user.uid,
        role: (data['role'] ?? '').toString(),
      );
      if (!identity.isAdmin) {
        AccountSession.current = null;
        setState(() {
          _loading = false;
          _profile = null;
        });
        return;
      }

      final claimResult = await AdminWebSession.claimWithConfirmation(
        user.uid,
        canContinue: () => mounted && revision == _restoreRevision,
        confirmTakeover: () => confirmAccountSessionTakeover(context),
      );
      if (claimResult != AdminWebSessionClaimResult.claimed) {
        await AccountAuth.signOut();
        if (revision != _restoreRevision || !mounted) return;
        setState(() {
          _loading = false;
          _profile = null;
        });
        return;
      }

      if (revision != _restoreRevision || !mounted) {
        await AccountAuth.signOut();
        return;
      }

      AccountSession.current = identity;
      setState(() {
        _loading = false;
        _profile = {...data, 'id': user.uid};
      });
    } catch (_) {
      await AccountAuth.signOut();
      AccountSession.current = null;
      if (revision != _restoreRevision || !mounted) return;
      setState(() {
        _loading = false;
        _profile = null;
      });
    }
  }

  @override
  void dispose() {
    _restoreRevision++;
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    return profile == null ? const LoginScreen() : widget.homeBuilder(profile);
  }
}
