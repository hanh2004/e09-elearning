// APP HỌC VIÊN: Đọc trạng thái bảo trì, kết thúc phiên và thay nội dung app bằng màn hình chặn.
// Được gắn tại diem_vao_hoc_vien.dart để áp dụng toàn app và hủy các trang/luồng con đang mở.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';

Stream<bool> maintenanceSignals(Stream<Map<String, dynamic>?> statuses) async* {
  var received = false;
  Object? previousEpoch;
  await for (final status in statuses) {
    final epoch = status?['lastMaintenanceAt'];
    final missedUpdate = received && epoch != null && epoch != previousEpoch;
    received = true;
    previousEpoch = epoch;
    yield status?['maintenance'] == true || missedUpdate;
  }
}

bool sessionPredatesMaintenance(
  Object? maintenanceEpoch,
  DateTime? lastSignInTime,
  bool authenticated,
) {
  if (!authenticated || maintenanceEpoch is! Timestamp) return false;
  if (lastSignInTime == null) return true;
  return lastSignInTime.isBefore(maintenanceEpoch.toDate());
}

class UserMaintenanceGate extends StatefulWidget {
  const UserMaintenanceGate({
    super.key,
    required this.child,
    this.statusStream,
    this.signOut,
    this.exitApp,
    this.signedInEvents,
  });

  final Widget child;
  final Stream<bool> Function()? statusStream;
  final Future<void> Function()? signOut;
  final Future<void> Function()? exitApp;
  final Stream<void>? signedInEvents;

  @override
  State<UserMaintenanceGate> createState() => _UserMaintenanceGateState();
}

class _UserMaintenanceGateState extends State<UserMaintenanceGate> {
  StreamSubscription<bool>? _subscription;
  StreamSubscription<void>? _sessionSubscription;
  Timer? _initialCheckTimeout;
  bool _ready = false;
  bool _blocked = false;
  bool _signingOut = false;
  bool _signedOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listen();
    final sessions =
        widget.signedInEvents ??
        FirebaseAuth.instance
            .authStateChanges()
            .where((user) => user != null)
            .map<void>((_) {});
    _sessionSubscription = sessions.listen((_) {
      if (!mounted || !_blocked) return;
      _signedOut = false;
      unawaited(_signOut());
    });
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _initialCheckTimeout?.cancel();
    _initialCheckTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted || _ready || _blocked) return;
      setState(
        () => _error =
            'Chưa kết nối được máy chủ. Vui lòng kiểm tra kết nối và thử lại.',
      );
    });
    final stream =
        widget.statusStream?.call() ??
        maintenanceSignals(
          FirebaseFirestore.instance
              .collection('system')
              .doc('app_status')
              .snapshots(includeMetadataChanges: true)
              // Bản cache có thể vẫn bật bảo trì sau khi admin đã tắt.
              .where((snapshot) => !snapshot.metadata.isFromCache)
              .asyncMap((snapshot) async {
                final status = snapshot.data();
                final user = FirebaseAuth.instance.currentUser;
                if (status?['maintenance'] != true &&
                    sessionPredatesMaintenance(
                      status?['lastMaintenanceAt'],
                      user?.metadata.lastSignInTime,
                      user != null,
                    )) {
                  // App có thể đã bị đóng trong cả đợt cập nhật. Firebase vẫn
                  // lưu token cũ; xóa token trước khi mở trang đăng nhập.
                  await AccountAuth.signOut();
                }
                return status;
              }),
        );
    _subscription = stream.listen(
      (maintenance) {
        if (!mounted || _blocked) return;
        _initialCheckTimeout?.cancel();
        setState(() {
          _ready = true;
          _error = null;
          _blocked = maintenance;
        });
        if (maintenance) unawaited(_signOut());
      },
      onError: (Object error) {
        if (!mounted || _blocked || _ready) return;
        _initialCheckTimeout?.cancel();
        setState(
          () => _error = 'Chưa kiểm tra được trạng thái ứng dụng. Vui lòng kiểm tra kết nối và thử lại.',
        );
      },
    );
  }

  Future<void> _signOut() async {
    if (_signingOut || _signedOut) return;
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await (widget.signOut ?? AccountAuth.signOut)();
      _signedOut = true;
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Chưa kết thúc được phiên đăng nhập. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _exit() async {
    await _signOut();
    if (!_signedOut || !mounted) return;
    try {
      await (widget.exitApp ?? SystemNavigator.pop)();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
          'Vui lòng đóng ứng dụng rồi mở lại sau khi bảo trì hoàn tất.',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    _initialCheckTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && !_blocked) return widget.child;
    // Dispose cả Navigator, trang thi, đồng hồ và hộp thoại ngay. Giữ khóa đến
    // khi thoát, kể cả admin tắt cập nhật trong lúc người dùng đang đọc thông báo.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_blocked) ...[
                        const Icon(
                          Icons.system_update_alt,
                          size: 64,
                          color: AppTheme.red,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ứng dụng đang được bảo trì',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Hệ thống đang tạm dừng để bảo trì. Vui lòng thoát ứng dụng và quay lại sau khi bảo trì hoàn tất.',
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_error == null) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Đang kiểm tra trạng thái ứng dụng…'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                      if (_blocked || _error != null) ...[
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _signingOut
                              ? null
                              : _blocked
                              ? _exit
                              : () {
                                  setState(() => _error = null);
                                  _listen();
                                },
                          child: Text(
                            _blocked
                                ? _signingOut
                                      ? 'Đang kết thúc phiên…'
                                      : 'Xác nhận và thoát'
                                : 'Thử lại',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
