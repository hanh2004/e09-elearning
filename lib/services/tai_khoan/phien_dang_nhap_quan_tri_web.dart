import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/cau_hinh_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';

enum AdminWebSessionClaimResult {
  claimed,
  keptExisting,
  unavailable,
  cancelled,
}

/// Enforces one active web or mobile app session per Firebase account.
class AdminWebSession {
  AdminWebSession._();

  static const _sessionField = '_adminWebSession';
  static const _heartbeatInterval = Duration(seconds: 20);
  static final _forcedOut = StreamController<void>.broadcast();

  static Stream<void> get forcedOut => _forcedOut.stream;

  static String? _uid;
  static String? _token;
  static String? _pendingUid;
  static String? _pendingToken;
  static Timer? _heartbeatTimer;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _sessionSubscription;
  static bool _forcingOut = false;

  static String? get token => _token;

  /// Returns false when another live account session must be confirmed.
  static Future<bool> claim(String uid, {bool takeOver = false}) async {
    if (_uid == uid && _token != null) return true;
    if (_pendingUid != uid || _pendingToken == null) {
      _pendingUid = uid;
      _pendingToken = _newToken();
    }

    final result =
        await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
            .httpsCallable('adminSessionClaim')
            .call<Map<String, dynamic>>({
              'sessionToken': _pendingToken,
              'takeOver': takeOver,
            });
    if (result.data['occupied'] == true) return false;
    if (result.data['claimed'] != true) {
      throw StateError('Không thể tạo phiên đăng nhập. Hãy thử lại.');
    }

    _uid = uid;
    _token = _pendingToken;
    _pendingUid = null;
    _pendingToken = null;
    _forcingOut = false;
    _watchSession(uid, _token!);
    _startHeartbeat(uid, _token!);
    return true;
  }

  /// Shares the claim/takeover sequence between fresh login and session restore.
  /// Callers sign out locally when the result is not [AdminWebSessionClaimResult.claimed].
  static Future<AdminWebSessionClaimResult> claimWithConfirmation(
    String uid, {
    required Future<bool> Function() confirmTakeover,
    required bool Function() canContinue,
  }) async {
    try {
      var hasSession = await claim(uid);
      if (!canContinue()) return AdminWebSessionClaimResult.cancelled;
      if (hasSession) return AdminWebSessionClaimResult.claimed;

      final takeOver = await confirmTakeover();
      if (!canContinue()) return AdminWebSessionClaimResult.cancelled;
      if (!takeOver) return AdminWebSessionClaimResult.keptExisting;

      hasSession = await claim(uid, takeOver: true);
      if (!canContinue()) return AdminWebSessionClaimResult.cancelled;
      return hasSession
          ? AdminWebSessionClaimResult.claimed
          : AdminWebSessionClaimResult.unavailable;
    } finally {
      cancelPendingClaim();
    }
  }

  static void cancelPendingClaim() {
    _pendingUid = null;
    _pendingToken = null;
  }

  static Map<String, dynamic> addToken(Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = uid == _uid ? _token : null;
    return token == null ? data : {...data, _sessionField: token};
  }

  static Future<void> signOut() async {
    final uid = _uid;
    final token = _token;
    _stopLocalSession();
    cancelPendingClaim();
    if (uid == null || token == null) return;
    try {
      await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
          .httpsCallable('adminSessionRelease')
          .call<Map<String, dynamic>>({'sessionToken': token})
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // A closed or offline app session expires through the server heartbeat lease.
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _hash(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static void _watchSession(String uid, String token) {
    _sessionSubscription?.cancel();
    _sessionSubscription = FirebaseFirestore.instance
        .collection('admin_web_sessions')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (snapshot.metadata.isFromCache || _token != token) return;
          if (snapshot.data()?['tokenHash'] != _hash(token)) {
            unawaited(_forceSignOut());
          }
        }, onError: (_) {});
  }

  static void _startHeartbeat(String uid, String token) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_sendHeartbeat(uid, token));
    });
  }

  static Future<void> _sendHeartbeat(String uid, String token) async {
    if (_uid != uid || _token != token) return;
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
              .httpsCallable('adminSessionHeartbeat')
              .call<Map<String, dynamic>>({'sessionToken': token});
      if (result.data['active'] != true) await _forceSignOut();
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated' ||
          error.code == 'permission-denied') {
        await _forceSignOut();
      }
    } catch (_) {
      // Retry on the next heartbeat; a transient network failure is not a takeover.
    }
  }

  static Future<void> _forceSignOut() async {
    if (_forcingOut) return;
    _forcingOut = true;
    _stopLocalSession();
    cancelPendingClaim();
    AccountSession.current = null;
    _forcedOut.add(null);
    await FirebaseAuth.instance.signOut();
  }

  static void _stopLocalSession() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _uid = null;
    _token = null;
  }
}
