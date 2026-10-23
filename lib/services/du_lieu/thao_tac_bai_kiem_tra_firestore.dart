part of 'dich_vu_firestore.dart';

mixin _FirestoreExamOperations on _FirestoreServiceCore {
  Future<List<CauHoiModel>> getQuestionsForExam(String examId) async {
    final dsCauHoi = <CauHoiModel>[];
    try {
      final duLieuNhan = await _coSoDuLieu
          .collection('exams')
          .doc(examId)
          .collection('questions')
          .get();

      for (final banGhi in duLieuNhan.docs) {
        final duLieu = banGhi.data();
        dsCauHoi.add(CauHoiModel.fromMap(duLieu, banGhi.id));
      }

      if (dsCauHoi.isNotEmpty) return dsCauHoi;

      final examDoc = await _coSoDuLieu.collection('exams').doc(examId).get();
      final examData = examDoc.data();
      if (examData != null) {
        final embedded = examData['questions'] is List
            ? examData['questions'] as List
            : examData['dsCauHoi'] is List
            ? examData['dsCauHoi'] as List
            : examData['ds_cau_hoi'] is List
            ? examData['ds_cau_hoi'] as List
            : const [];

        for (var viTri = 0; viTri < embedded.length; viTri++) {
          final rawQuestion = embedded[viTri];
          if (rawQuestion is Map) {
            dsCauHoi.add(
              CauHoiModel.fromMap(
                Map<String, dynamic>.from(rawQuestion),
                '${examId}_$viTri',
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
            await getQuestionsByIds(rawIds.map((ma) => ma.toString()).toList()),
          );
        }
      }

      if (dsCauHoi.isNotEmpty) return dsCauHoi;

      for (final collection in ['questions', 'CAU_HOI']) {
        for (final truong in [
          'examId',
          'exam_id',
          'maBaiKiemTra',
          'ma_bai_kiem_tra',
          'ma_bai_thi',
        ]) {
          final legacySnapshot = await _coSoDuLieu
              .collection(collection)
              .where(truong, isEqualTo: examId)
              .get();
          for (final banGhi in legacySnapshot.docs) {
            dsCauHoi.add(CauHoiModel.fromMap(banGhi.data(), banGhi.id));
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

  Future<List<CauHoiModel>> getQuestionsByIds(List<String> dsMaCauHoi) async {
    final dsCauHoi = <CauHoiModel>[];
    try {
      for (String ma in dsMaCauHoi) {
        for (final collection in ['questions', 'CAU_HOI']) {
          final banGhi = await _coSoDuLieu.collection(collection).doc(ma).get();
          if (banGhi.exists && banGhi.data() != null) {
            dsCauHoi.add(CauHoiModel.fromMap(banGhi.data()!, banGhi.id));
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

  // QUẢN LÝ BÀI THI
  Stream<QuerySnapshot<Map<String, dynamic>>> getExamsStream() {
    return _coSoDuLieu.collection('exams').snapshots();
  }

  Future<String> addExam({
    required String title,
    required int durationMinutes,
    int? maxAttempts,
    String? courseId,
  }) async {
    if (title.trim().isEmpty ||
        durationMinutes < 1 ||
        durationMinutes > 1440 ||
        (maxAttempts != null && maxAttempts < 1)) {
      throw ArgumentError('Thông tin bài thi không hợp lệ.');
    }
    final thamChieu = _coSoDuLieu.collection('exams').doc();
    await thamChieu.set({
      'title': title,
      'duration': '$durationMinutes phút',
      'durationMinutes': durationMinutes,
      'questions': 0,
      'maxAttempts': maxAttempts,
      'courseId': courseId ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return thamChieu.id;
  }

  Future<void> updateExamPolicy(String ma, Map<String, dynamic> policy) async {
    await _coSoDuLieu.collection('exams').doc(ma).update(policy);
  }

  // QUẢN LÝ CÂU HỎI
  Stream<QuerySnapshot<Map<String, dynamic>>> getQuestionsStream(
    String examId,
  ) {
    return _coSoDuLieu
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
        options.any((giaTri) => giaTri.trim().isEmpty) ||
        correctAnswerIndex < 0 ||
        correctAnswerIndex >= options.length) {
      throw ArgumentError('Câu hỏi hoặc đáp án không hợp lệ.');
    }
    final collection = _coSoDuLieu
        .collection('exams')
        .doc(examId)
        .collection('questions');
    final giaTri = <String, dynamic>{
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation.trim(),
      if (questionId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (questionId == null) {
      await collection.add(giaTri);
      await _dongBoSoCauHoi(examId);
    } else {
      await collection.doc(questionId).update(giaTri);
    }
  }

  /// Lưu nhiều câu hỏi trong một lô để nhập từ nội dung dán nhanh.
  Future<void> addQuestions(
    String examId,
    List<Map<String, dynamic>> questions,
  ) async {
    if (questions.isEmpty || questions.length > 499) {
      throw ArgumentError('Mỗi lần nhập từ 1 đến 499 câu hỏi.');
    }
    final collection = _coSoDuLieu
        .collection('exams')
        .doc(examId)
        .collection('questions');
    final batch = _coSoDuLieu.batch();
    for (final question in questions) {
      final questionText = question['questionText'];
      final rawOptions = question['options'];
      final correctAnswerIndex = question['correctAnswerIndex'];
      if (questionText is! String ||
          questionText.trim().isEmpty ||
          rawOptions is! List ||
          rawOptions.length != 4 ||
          rawOptions.any(
            (option) => option is! String || option.trim().isEmpty,
          ) ||
          correctAnswerIndex is! int ||
          correctAnswerIndex < 0 ||
          correctAnswerIndex > 3) {
        throw ArgumentError('Có câu hỏi hoặc đáp án không hợp lệ.');
      }
      final reference = collection.doc();
      batch.set(reference, {
        'questionText': questionText.trim(),
        'options': rawOptions
            .map((option) => (option as String).trim())
            .toList(),
        'correctAnswerIndex': correctAnswerIndex,
        'explanation': (question['explanation'] ?? '').toString().trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_coSoDuLieu.collection('exams').doc(examId), {
      'questions': FieldValue.increment(questions.length),
    });
    await batch.commit();
  }

  Future<void> deleteQuestion(String examId, String questionId) async {
    await _coSoDuLieu
        .collection('exams')
        .doc(examId)
        .collection('questions')
        .doc(questionId)
        .delete();
    await _dongBoSoCauHoi(examId);
  }

  Future<void> _dongBoSoCauHoi(String examId) async {
    final soLuong = await _coSoDuLieu
        .collection('exams')
        .doc(examId)
        .collection('questions')
        .count()
        .get();
    await _coSoDuLieu.collection('exams').doc(examId).update({
      'questions': soLuong.count ?? 0,
    });
  }
}
