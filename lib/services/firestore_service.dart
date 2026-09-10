import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/cau_hoi_model.dart';
import '../models/cau_tra_loi_model.dart';
import '../models/exam_attempt_session.dart';
import '../models/user_import.dart';
import '../models/account_identity.dart';
import 'account_api.dart';
import 'account_auth.dart';

class AccountProvisioningException implements Exception {
  const AccountProvisioningException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, AccountApi? accounts})
    : _db = firestore ?? FirebaseFirestore.instance,
      _accounts =
          accounts ??
          AccountApi(
            useBackend:
                firestore == null &&
                const bool.fromEnvironment(
                  'USE_SECURE_BACKEND',
                  defaultValue: true,
                ),
          );

  final FirebaseFirestore _db;
  final AccountApi _accounts;
  static FirebaseApp? _provisioningApp;
  static bool _provisioningEmulatorConfigured = false;

  Future<FirebaseAuth> _provisioningAuth() async {
    _provisioningApp ??= await Firebase.initializeApp(
      name: 'account-provisioning',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: _provisioningApp!);
    const emulator = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (emulator.isNotEmpty && !_provisioningEmulatorConfigured) {
      await auth.useAuthEmulator(emulator, 9099);
      _provisioningEmulatorConfigured = true;
    }
    return auth;
  }

  Future<String> _createCredential(
    String username,
    String password,
    String name,
  ) async {
    final normalizedUsername = username.trim();
    final usernameSnapshot = await _db
        .collection('usernames')
        .doc(_usernameKey(normalizedUsername))
        .get();
    if (usernameSnapshot.exists) {
      throw const AccountProvisioningException(
        'Tên đăng nhập đã tồn tại. Hãy chọn tên khác.',
      );
    }
    final auth = await _provisioningAuth();
    await auth.signOut();
    final email = accountLoginEmail(normalizedUsername);
    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      try {
        // Recover an Auth account left behind by an interrupted earlier write.
        credential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException {
        throw const AccountProvisioningException(
          'Tên đăng nhập đã tồn tại trong Authentication. Hãy chọn tên khác.',
        );
      }
    }
    await credential.user!.updateDisplayName(name);
    final uid = credential.user!.uid;
    await auth.signOut();
    return uid;
  }

  String _usernameKey(String username) =>
      accountLoginEmail(username).split('@').first;

  Future<void> _createSparkAccount({
    required String name,
    required String username,
    required String password,
    required String role,
    required String status,
    required String createdBy,
  }) async {
    final uid = await _createCredential(username, password, name);
    final batch = _db.batch();
    batch.set(_db.collection('usernames').doc(_usernameKey(username)), {
      'uid': uid,
      'username': username.trim(),
    });
    batch.set(_db.collection('users').doc(uid), {
      'name': name,
      'username': username.trim(),
      'role': role,
      'status': status,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<CauHoiModel>> getQuestionsForExam(String examId) async {
    final dsCauHoi = <CauHoiModel>[];
    try {
      final snapshot = await _db
          .collection('exams')
          .doc(examId)
          .collection('questions')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        dsCauHoi.add(CauHoiModel.fromMap(data, doc.id));
      }

      if (dsCauHoi.isNotEmpty) return dsCauHoi;

      final examDoc = await _db.collection('exams').doc(examId).get();
      final examData = examDoc.data();
      if (examData != null) {
        final embedded = examData['questions'] is List
            ? examData['questions'] as List
            : examData['dsCauHoi'] is List
            ? examData['dsCauHoi'] as List
            : examData['ds_cau_hoi'] is List
            ? examData['ds_cau_hoi'] as List
            : const [];

        for (var index = 0; index < embedded.length; index++) {
          final rawQuestion = embedded[index];
          if (rawQuestion is Map) {
            dsCauHoi.add(
              CauHoiModel.fromMap(
                Map<String, dynamic>.from(rawQuestion),
                '${examId}_$index',
              ),
            );
          }
        }
        if (dsCauHoi.isNotEmpty) return dsCauHoi;

        final rawIds =
            examData['questionIds'] ??
            examData['dsMaCauHoi'] ??
            examData['ds_ma_cau_hoi'];
        if (rawIds is List) {
          dsCauHoi.addAll(
            await getQuestionsByIds(rawIds.map((id) => id.toString()).toList()),
          );
        }
      }

      if (dsCauHoi.isNotEmpty) return dsCauHoi;

      for (final collection in ['questions', 'CAU_HOI']) {
        for (final field in [
          'examId',
          'exam_id',
          'maBaiKiemTra',
          'ma_bai_kiem_tra',
          'ma_bai_thi',
        ]) {
          final legacySnapshot = await _db
              .collection(collection)
              .where(field, isEqualTo: examId)
              .get();
          for (final doc in legacySnapshot.docs) {
            dsCauHoi.add(CauHoiModel.fromMap(doc.data(), doc.id));
          }
          if (dsCauHoi.isNotEmpty) break;
        }
        if (dsCauHoi.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách câu hỏi theo ExamId: $e');
      rethrow;
    }
    return dsCauHoi;
  }

  // --- 1. LƯỢT LÀM BÀI VÀ NỘP BÀI THI ---
  Future<ExamAttemptSession> getOrCreateAttempt({
    required String userId,
    required String examId,
    required int durationMinutes,
    int? maxAttempts,
  }) async {
    final examSnapshot = await _db.collection('exams').doc(examId).get();
    final exam = examSnapshot.data();
    if (exam == null || exam['isOpen'] != true) {
      throw StateError('Bài thi hiện đang đóng.');
    }
    durationMinutes =
        (exam['durationMinutes'] as num?)?.toInt() ?? durationMinutes;
    maxAttempts = (exam['maxAttempts'] as num?)?.toInt();
    if (durationMinutes <= 0) {
      throw StateError('Thời gian bài thi không hợp lệ.');
    }
    final closesAt = exam['closesAt'];
    final closingTime = closesAt is Timestamp ? closesAt.toDate() : null;
    if (closingTime != null && !closingTime.isAfter(DateTime.now())) {
      throw StateError('Bài thi đã hết hạn nộp bài.');
    }
    final attempts = await _db
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .get();

    final examAttempts = attempts.docs
        .where((doc) => doc.data()['examId'] == examId)
        .toList();

    for (final doc in examAttempts) {
      final data = doc.data();
      if (data['examId'] == examId && data['status'] == 'in_progress') {
        DateTime endsAt;
        final rawEndsAt = data['endsAt'];
        if (rawEndsAt is Timestamp) {
          endsAt = rawEndsAt.toDate();
        } else {
          final startedAt = data['startedAt'];
          final start = startedAt is Timestamp
              ? startedAt.toDate()
              : DateTime.now();
          endsAt = start.add(Duration(minutes: durationMinutes));
          await doc.reference.update({'endsAt': Timestamp.fromDate(endsAt)});
        }

        final selectedAnswers = <int, int>{};
        final rawAnswers = data['selectedAnswers'];
        if (rawAnswers is Map) {
          for (final entry in rawAnswers.entries) {
            final questionIndex = int.tryParse(entry.key.toString());
            final optionIndex = entry.value is int
                ? entry.value as int
                : int.tryParse(entry.value.toString());
            if (questionIndex != null && optionIndex != null) {
              selectedAnswers[questionIndex] = optionIndex;
            }
          }
        }

        return ExamAttemptSession(
          attemptId: doc.id,
          endsAt: endsAt,
          selectedAnswers: selectedAnswers,
          currentQuestionIndex:
              (data['currentQuestionIndex'] as num?)?.toInt() ?? 0,
        );
      }
    }

    var attemptCount = 0;
    var bestScore = -1.0;
    QueryDocumentSnapshot<Map<String, dynamic>>? keeper;
    for (final doc in examAttempts) {
      final data = doc.data();
      final count =
          (data['attemptCount'] as num?)?.toInt() ??
          (data['status'] == 'completed' ? 1 : 0);
      attemptCount += count;
      final score =
          (data['bestScore'] as num?)?.toDouble() ??
          (data['diemSo'] as num?)?.toDouble() ??
          -1;
      if (keeper == null || score > bestScore) {
        keeper = doc;
        bestScore = score;
      }
    }

    if (maxAttempts != null && attemptCount >= maxAttempts) {
      throw StateError('Bạn đã sử dụng hết $maxAttempts lượt làm bài.');
    }

    final durationEnd = DateTime.now().add(Duration(minutes: durationMinutes));
    final endsAt = closingTime != null && closingTime.isBefore(durationEnd)
        ? closingTime
        : durationEnd;
    late final DocumentReference<Map<String, dynamic>> attemptRef;
    if (keeper == null) {
      attemptRef = await _db.collection('exam_attempts').add({
        'userId': userId,
        'examId': examId,
        'startedAt': FieldValue.serverTimestamp(),
        'endsAt': Timestamp.fromDate(endsAt),
        'status': 'in_progress',
        'attemptCount': 0,
        'selectedAnswers': <String, int>{},
        'currentQuestionIndex': 0,
      });
    } else {
      attemptRef = keeper.reference;
      final batch = _db.batch();
      batch.update(attemptRef, {
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'endsAt': Timestamp.fromDate(endsAt),
        'selectedAnswers': <String, int>{},
        'currentQuestionIndex': 0,
      });
      await batch.commit();
    }
    return ExamAttemptSession(
      attemptId: attemptRef.id,
      endsAt: endsAt,
      selectedAnswers: const {},
      currentQuestionIndex: 0,
    );
  }

  Future<void> saveAttemptProgress({
    required String attemptId,
    required Map<int, int> selectedAnswers,
    required int currentQuestionIndex,
  }) {
    return _db.collection('exam_attempts').doc(attemptId).update({
      'selectedAnswers': selectedAnswers.map(
        (question, option) => MapEntry(question.toString(), option),
      ),
      'currentQuestionIndex': currentQuestionIndex,
      'lastSavedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<CauHoiModel>> getQuestionsByIds(List<String> dsMaCauHoi) async {
    List<CauHoiModel> dsCauHoi = [];
    try {
      for (String id in dsMaCauHoi) {
        for (final collection in ['questions', 'CAU_HOI']) {
          final doc = await _db.collection(collection).doc(id).get();
          if (doc.exists && doc.data() != null) {
            dsCauHoi.add(CauHoiModel.fromMap(doc.data()!, doc.id));
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi lấy danh sách câu hỏi: $e');
      rethrow;
    }
    return dsCauHoi;
  }

  Future<void> submitExam({
    required String maLuot,
    required double diemSo,
    required List<CauTraLoiModel> dsCauTraLoi,
    required String examTitle,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    final ref = _db.collection('exam_attempts').doc(maLuot);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (data['status'] == 'completed') return;
      final runNumber = ((data['attemptCount'] as num?)?.toInt() ?? 0) + 1;
      transaction.set(ref.collection('runs').doc(runNumber.toString()), {
        'userId': data['userId'],
        'examId': data['examId'],
        'examTitle': examTitle,
        'score': diemSo,
        'correctAnswers': correctAnswers,
        'totalQuestions': totalQuestions,
        'answers': dsCauTraLoi.map((answer) => answer.toMap()).toList(),
        'runNumber': runNumber,
        'completedAt': FieldValue.serverTimestamp(),
      });
      final oldBest =
          (data['bestScore'] as num?)?.toDouble() ??
          (data['diemSo'] as num?)?.toDouble() ??
          -1;
      final isNewBest = diemSo > oldBest;
      final updates = <String, dynamic>{
        'examTitle': examTitle,
        'status': 'completed',
        'attemptCount': ((data['attemptCount'] as num?)?.toInt() ?? 0) + 1,
        'lastAttemptAt': FieldValue.serverTimestamp(),
        'selectedAnswers': FieldValue.delete(),
        'currentQuestionIndex': FieldValue.delete(),
      };
      if (isNewBest) {
        updates.addAll({
          'bestScore': diemSo,
          'diemSo': diemSo,
          'bestCorrectAnswers': correctAnswers,
          'correctAnswers': correctAnswers,
          'totalQuestions': totalQuestions,
          'bestCompletedAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
          'bestAnswers': dsCauTraLoi.map((e) => e.toMap()).toList(),
          'answers': dsCauTraLoi.map((e) => e.toMap()).toList(),
        });
      }
      transaction.update(ref, updates);
    });
  }

  // --- 2. QUẢN LÝ BÀI THI ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getExamsStream() {
    return _db.collection('exams').snapshots();
  }

  Future<void> addExam({
    required String title,
    required int durationMinutes,
    required bool isOpen,
    int? maxAttempts,
    DateTime? closesAt,
  }) async {
    if (title.trim().isEmpty ||
        durationMinutes < 1 ||
        durationMinutes > 1440 ||
        (maxAttempts != null && maxAttempts < 1)) {
      throw ArgumentError('Thông tin bài thi không hợp lệ.');
    }
    await _db.collection('exams').add({
      'title': title,
      'duration': '$durationMinutes phút',
      'durationMinutes': durationMinutes,
      'questions': 0,
      'isOpen': isOpen,
      'maxAttempts': maxAttempts,
      'closesAt': closesAt == null ? null : Timestamp.fromDate(closesAt),
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExamPolicy(String id, Map<String, dynamic> policy) =>
      _db.collection('exams').doc(id).update(policy);

  Future<void> updateExamStatus(String docId, bool isOpen) async {
    await _db.collection('exams').doc(docId).update({
      'isOpen': isOpen,
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
    });
  }

  Future<void> _deleteAttemptRuns(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  ) async {
    for (final attempt in attempts) {
      final runs = await attempt.reference.collection('runs').get();
      for (var offset = 0; offset < runs.docs.length; offset += 400) {
        final batch = _db.batch();
        for (final run in runs.docs.skip(offset).take(400)) {
          batch.delete(run.reference);
        }
        await batch.commit();
      }
    }
  }

  Future<void> deleteExam(String docId) async {
    if (_accounts.hasTransport) {
      await _accounts.call('examDelete', {'examId': docId});
      return;
    }
    final questions = await _db
        .collection('exams')
        .doc(docId)
        .collection('questions')
        .get();
    final attempts = await _db
        .collection('exam_attempts')
        .where('examId', isEqualTo: docId)
        .get();
    await _deleteAttemptRuns(attempts.docs);
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...questions.docs.map((question) => question.reference),
      ...attempts.docs.map((attempt) => attempt.reference),
      _db.collection('exams').doc(docId),
    ];

    const batchLimit = 500;
    for (var offset = 0; offset < references.length; offset += batchLimit) {
      final end = (offset + batchLimit < references.length)
          ? offset + batchLimit
          : references.length;
      final batch = _db.batch();
      for (final reference in references.sublist(offset, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  // --- 3. QUẢN LÝ CÂU HỎI ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getQuestionsStream(
    String examId,
  ) {
    return _db
        .collection('exams')
        .doc(examId)
        .collection('questions')
        .snapshots();
  }

  Future<void> addQuestion(
    String examId, {
    required String questionText,
    required List<String> options,
    required int correctAnswerIndex,
    String explanation = '',
    String? questionId,
  }) async {
    if (questionText.trim().isEmpty ||
        options.length < 2 ||
        options.any((value) => value.trim().isEmpty) ||
        correctAnswerIndex < 0 ||
        correctAnswerIndex >= options.length) {
      throw ArgumentError('Câu hỏi hoặc đáp án không hợp lệ.');
    }
    final collection = _db
        .collection('exams')
        .doc(examId)
        .collection('questions');
    final value = <String, dynamic>{
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation.trim(),
      if (questionId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (questionId == null) {
      await collection.add(value);
      await _syncQuestionCount(examId);
    } else {
      await collection.doc(questionId).update(value);
    }
  }

  Future<void> deleteQuestion(String examId, String questionId) async {
    await _db
        .collection('exams')
        .doc(examId)
        .collection('questions')
        .doc(questionId)
        .delete();
    await _syncQuestionCount(examId);
  }

  Future<void> _syncQuestionCount(String examId) async {
    final count = await _db
        .collection('exams')
        .doc(examId)
        .collection('questions')
        .count()
        .get();
    await _db.collection('exams').doc(examId).update({
      'questions': count.count ?? 0,
    });
  }

  // --- 4. QUẢN LÝ TÀI KHOẢN ---
  Future<Map<String, dynamic>?> loginWithUsername(
    String username,
    String password,
  ) => AccountAuth().login(username, password);

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (role != 'user') {
      throw ArgumentError('Admin phải được đề xuất và duyệt riêng.');
    }
    if (_accounts.hasTransport) {
      await _accounts.idempotent('accountImportUsers', {
        'rows': [
          {'name': name, 'username': username, 'password': password},
        ],
      });
      return;
    }
    final actor = AccountSession.current;
    if (actor?.isAdmin != true) throw StateError('Cần đăng nhập quản trị.');
    await _createSparkAccount(
      name: name,
      username: username,
      password: password,
      role: 'user',
      status: 'active',
      createdBy: actor!.id,
    );
  }

  Future<List<String>> checkUsernames(List<String> names) async {
    if (!_accounts.hasTransport) {
      if (names.isEmpty) return [];
      final docs = await Future.wait(
        names.map(
          (name) => _db.collection('usernames').doc(_usernameKey(name)).get(),
        ),
      );
      return [
        for (var i = 0; i < names.length; i++)
          if (docs[i].exists) names[i],
      ];
    }
    final result = await _accounts.call('accountCheckUsernames', {
      'usernames': names,
    });
    return List<String>.from(result['existing'] as List);
  }

  /// Server validates and provisions Auth before atomically activating profiles.
  /// Import never accepts a role or creator supplied by a workbook.
  Future<void> importUsers(List<UserImportRow> rows) async {
    if (rows.isEmpty || rows.length > UserImportPreview.maxUsers) {
      throw ArgumentError('Danh sách phải có từ 1 đến 200 User.');
    }
    final seen = <String>{};
    for (final row in rows) {
      if (row.errors.isNotEmpty ||
          row.name.trim().isEmpty ||
          row.name.length > 100 ||
          !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$').hasMatch(row.username) ||
          row.password.trim().length < 6 ||
          row.password.length > 128 ||
          !seen.add(row.username.toLowerCase())) {
        throw ArgumentError(
          'Dữ liệu User không hợp lệ. Hãy kiểm tra lại file.',
        );
      }
    }
    if (_accounts.hasTransport) {
      await _accounts.idempotent('accountImportUsers', {
        'rows': rows
            .map(
              (row) => {
                'name': row.name.trim(),
                'username': row.username,
                'password': row.password,
              },
            )
            .toList(),
      });
      return;
    }
    final actor = AccountSession.current;
    if (actor?.isAdmin != true) throw StateError('Cần đăng nhập quản trị.');
    for (final row in rows) {
      await _createSparkAccount(
        name: row.name.trim(),
        username: row.username,
        password: row.password,
        role: 'user',
        status: 'active',
        createdBy: actor!.id,
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    final identity = AccountSession.current;
    if (identity?.isAdmin == true) {
      return _db.collection('users').snapshots();
    }
    return Stream.error(StateError('Cần đăng nhập quản trị.'));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAdminRequestsStream() =>
      _db.collection('admin_requests').snapshots();

  Future<void> proposeAdmin({
    required String name,
    required String username,
    required String password,
    String unit = 'E09',
  }) async {
    if (_accounts.hasTransport) {
      await _accounts.idempotent('accountProposeAdmin', {
        'unit': unit,
        'account': {'name': name, 'username': username, 'password': password},
      });
      return;
    }
    final actor = AccountSession.current;
    if (actor?.isRoot != true) throw StateError('Chỉ Admin tổng được đề xuất.');
    final uid = await _createCredential(username, password, name);
    final request = _db.collection('admin_requests').doc();
    final batch = _db.batch();
    batch.set(_db.collection('usernames').doc(_usernameKey(username)), {
      'uid': uid,
      'username': username.trim(),
    });
    batch.set(_db.collection('users').doc(uid), {
      'name': name,
      'username': username.trim(),
      'role': 'admin',
      'status': 'pending',
      'createdBy': actor!.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(request, {
      'targetUid': uid,
      'name': name,
      'username': username.trim(),
      'status': 'pending',
      'createdBy': actor.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setAdminUnit(String uid, String unit) async {
    await _accounts.call('accountSetUnit', {'userId': uid, 'unit': unit});
  }

  Future<void> decideAdmin(String requestId, bool approve) async {
    if (!_accounts.hasTransport) {
      final actor = AccountSession.current;
      if (actor?.isRoot != true) throw StateError('Chỉ Admin tổng được duyệt.');
      final requestRef = _db.collection('admin_requests').doc(requestId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(requestRef);
        final data = snapshot.data();
        if (data == null ||
            data['createdBy'] == actor!.id ||
            data['status'] != 'pending') {
          throw StateError(
            'Yêu cầu không hợp lệ hoặc bạn không được tự duyệt.',
          );
        }
        transaction.update(requestRef, {
          'status': approve ? 'approved' : 'rejected',
          'decidedBy': actor.id,
          'decidedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(_db.collection('users').doc(data['targetUid']), {
          'status': approve ? 'active' : 'rejected',
          'approvedBy': approve ? actor.id : null,
        });
      });
      return;
    }
    await _accounts.call('accountDecideAdmin', {
      'requestId': requestId,
      'approve': approve,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExamAttemptsStream() {
    return _db.collection('exam_attempts').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserAttemptsStream(
    String userId,
  ) {
    return _db
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> setUserBlocked(String uid, bool blocked) async {
    await _accounts.call('accountSetStatus', {
      'userId': uid,
      'disabled': blocked,
    });
  }

  Future<void> updateUser({
    required String docId,
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (!_accounts.hasTransport) {
      await _db.collection('users').doc(docId).update({
        'name': name.trim(),
        'updatedBy': AccountSession.current!.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await _accounts.call('accountUpdateUser', {
      'userId': docId,
      'name': name,
      if (password.isNotEmpty) 'password': password,
    });
  }

  Future<void> deleteUser(String docId) async {
    if (!_accounts.hasTransport) {
      final userRef = _db.collection('users').doc(docId);
      final userSnapshot = await userRef.get();
      final user = userSnapshot.data();
      if (user == null) {
        throw const AccountProvisioningException(
          'Không tìm thấy tài khoản cần xóa.',
        );
      }
      final attempts = await _db
          .collection('exam_attempts')
          .where('userId', isEqualTo: docId)
          .get();
      await _deleteAttemptRuns(attempts.docs);
      final learning = await userRef.collection('learning').get();
      final related = <DocumentReference<Map<String, dynamic>>>[
        ...learning.docs.map((doc) => doc.reference),
        ...attempts.docs.map((doc) => doc.reference),
      ];
      if (AccountSession.current?.isRoot == true) {
        final requests = await _db
            .collection('admin_requests')
            .where('targetUid', isEqualTo: docId)
            .get();
        related.addAll(requests.docs.map((doc) => doc.reference));
      }
      const batchLimit = 450;
      for (var offset = 0; offset < related.length; offset += batchLimit) {
        final end = (offset + batchLimit < related.length)
            ? offset + batchLimit
            : related.length;
        final batch = _db.batch();
        for (final reference in related.sublist(offset, end)) {
          batch.delete(reference);
        }
        await batch.commit();
      }
      final finalBatch = _db.batch();
      finalBatch.delete(
        _db.collection('usernames').doc(_usernameKey(user['username'])),
      );
      finalBatch.delete(userRef);
      await finalBatch.commit();
      return;
    }
    await _accounts.call('accountDeleteUser', {'userId': docId});
  }

  Stream<bool> getMaintenanceModeStream() => _db
      .collection('system')
      .doc('app_status')
      .snapshots()
      .map((snapshot) => snapshot.data()?['maintenance'] == true);

  Future<bool> isMaintenanceMode() async {
    final snapshot = await _db
        .collection('system')
        .doc('app_status')
        .get(const GetOptions(source: Source.server));
    return snapshot.data()?['maintenance'] == true;
  }

  Future<void> setMaintenanceMode(bool enabled) async {
    final identity = AccountSession.current;
    if (identity?.isRoot != true) {
      throw StateError('Chỉ Admin tổng được cập nhật trạng thái ứng dụng.');
    }
    await _db.collection('system').doc('app_status').set({
      'maintenance': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': identity!.id,
    });
  }
}
