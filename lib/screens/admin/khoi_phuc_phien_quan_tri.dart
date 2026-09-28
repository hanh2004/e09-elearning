import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../man_hinh_dang_nhap.dart';

/// Restores an existing Firebase admin session after a browser reload.
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

      AccountSession.current = identity;
      setState(() {
        _loading = false;
        _profile = {...data, 'id': user.uid};
      });
    } catch (_) {
      if (revision != _restoreRevision || !mounted) return;
      AccountSession.current = null;
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
