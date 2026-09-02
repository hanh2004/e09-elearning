import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cau_hoi_model.dart';
import '../models/cau_tra_loi_model.dart';
import '../models/exam_attempt_session.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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
    Map<String, dynamic>? bestData;
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
        bestData = data;
      }
    }

    if (maxAttempts != null && attemptCount >= maxAttempts) {
      throw StateError('Bạn đã sử dụng hết $maxAttempts lượt làm bài.');
    }

    final endsAt = DateTime.now().add(Duration(minutes: durationMinutes));
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
        'attemptCount': attemptCount,
        'bestScore': bestScore < 0 ? null : bestScore,
        'diemSo': bestScore < 0 ? null : bestScore,
        'answers': bestData?['bestAnswers'] ?? bestData?['answers'],
        'bestCompletedAt':
            bestData?['bestCompletedAt'] ?? bestData?['completedAt'],
        'startedAt': FieldValue.serverTimestamp(),
        'endsAt': Timestamp.fromDate(endsAt),
        'selectedAnswers': <String, int>{},
        'currentQuestionIndex': 0,
      });
      for (final oldAttempt in examAttempts) {
        if (oldAttempt.id != keeper.id) batch.delete(oldAttempt.reference);
      }
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
    required String duration,
    required bool isOpen,
    int? maxAttempts,
  }) async {
    await _db.collection('exams').add({
      'title': title,
      'duration': duration,
      'questions': 0,
      'isOpen': isOpen,
      'maxAttempts': maxAttempts,
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExamStatus(String docId, bool isOpen) async {
    await _db.collection('exams').doc(docId).update({
      'isOpen': isOpen,
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
    });
  }

  Future<void> deleteExam(String docId) async {
    final questions = await _db
        .collection('exams')
        .doc(docId)
        .collection('questions')
        .get();
    final attempts = await _db
        .collection('exam_attempts')
        .where('examId', isEqualTo: docId)
        .get();
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
  }) async {
    await _db.collection('exams').doc(examId).collection('questions').add({
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _syncQuestionCount(examId);
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
  ) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .where('password', isEqualTo: password.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          ...(snapshot.docs.first.data() as Map<String, dynamic>),
          'id': snapshot.docs.first.id,
        };
      }
    } catch (e) {
      debugPrint("Lỗi đăng nhập: $e");
    }
    return null;
  }

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    await _db.collection('users').add({
      'name': name,
      'username': username,
      'password': password,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    return _db.collection('users').snapshots();
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

  Future<void> updateUser({
    required String docId,
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    await _db.collection('users').doc(docId).update({
      'name': name,
      'username': username,
      'password': password,
      'role': role,
    });
  }

  Future<void> deleteUser(String docId) async {
    await _db.collection('users').doc(docId).delete();
  }
}
