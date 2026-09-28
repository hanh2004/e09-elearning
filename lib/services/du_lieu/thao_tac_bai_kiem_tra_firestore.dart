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

  // --- 1. LƯỢT LÀM BÀI VÀ NỘP BÀI THI ---
  Future<ExamAttemptSession> getOrCreateAttempt({
    required String userId,
    required String examId,
    required int durationMinutes,
    int? maxAttempts,
    String? courseId,
    String? lessonId,
  }) async {
    if (courseId == null ||
        lessonId == null ||
        courseId.contains('/') ||
        lessonId.contains('/')) {
      throw StateError(
        'Hãy học xong nội dung trong mục Kiểm tra trước khi làm bài.',
      );
    }
    final khoaHoc = (await _coSoDuLieu.doc('courses/$courseId').get()).data();
    final baiHoc =
        (await _coSoDuLieu.doc('courses/$courseId/lessons/$lessonId').get())
            .data();
    final tienDo =
        (await _coSoDuLieu
                .doc('users/$userId/learning/${courseId}_$lessonId')
                .get())
            .data();
    final hienTai = DateTime.now();
    final phatHanhLuc = LearningPolicy.readDateTime(khoaHoc?['publishedAt']);
    final batDauLuc = LearningPolicy.readDateTime(khoaHoc?['startsAt']);
    if (khoaHoc?['published'] != true ||
        (phatHanhLuc != null && phatHanhLuc.isAfter(hienTai)) ||
        (batDauLuc != null && batDauLuc.isAfter(hienTai))) {
      throw StateError('Khóa học chưa đến thời gian phát hành.');
    }
    if (khoaHoc?['learningMode'] == 'study_only') {
      throw StateError('Khóa học này chỉ dùng để học.');
    }
    final courseExam = khoaHoc?['learningMode'] == 'study_exam';
    var studyAllowed =
        baiHoc?['learningMode'] == 'study_exam' &&
        baiHoc?['examId'] == examId &&
        LearningPolicy.hasCompletedStudy(tienDo ?? {}) &&
        tienDo?['courseId'] == courseId &&
        tienDo?['lessonId'] == lessonId;
    if (courseExam) {
      if (baiHoc == null || khoaHoc?['examId'] != examId) {
        throw StateError('Bài kiểm tra không thuộc khóa học này.');
      }
      final cacBaiHoc = await _coSoDuLieu
          .collection('courses')
          .doc(courseId)
          .collection('lessons')
          .get();
      final cacMauTin = await _coSoDuLieu
          .collection('users')
          .doc(userId)
          .collection('learning')
          .where('courseId', isEqualTo: courseId)
          .get();
      final completedIds = cacMauTin.docs
          .where((banGhi) => LearningPolicy.hasCompletedStudy(banGhi.data()))
          .map((banGhi) => banGhi.data()['lessonId']?.toString())
          .whereType<String>()
          .toSet();
      studyAllowed =
          cacBaiHoc.docs.isNotEmpty &&
          cacBaiHoc.docs.every((banGhi) => completedIds.contains(banGhi.id));
    }
    if (!studyAllowed) {
      throw StateError('Bạn cần học xong nội dung trước khi làm bài kiểm tra.');
    }
    final examSnapshot = await _coSoDuLieu
        .collection('exams')
        .doc(examId)
        .get();
    final baiThi = examSnapshot.data();
    if (baiThi == null || baiThi['isOpen'] != true) {
      throw StateError('Bài thi hiện đang đóng.');
    }
    durationMinutes =
        (baiThi['durationMinutes'] as num?)?.toInt() ?? durationMinutes;
    maxAttempts = (baiThi['maxAttempts'] as num?)?.toInt();
    if (durationMinutes <= 0) {
      throw StateError('Thời gian bài thi không hợp lệ.');
    }
    final closesAt = baiThi['closesAt'];
    final closingTime = closesAt is Timestamp ? closesAt.toDate() : null;
    final courseEnd = LearningPolicy.readDateTime(khoaHoc?['endsAt']);
    final effectiveClosing = [closingTime, courseEnd]
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (hienHanh, giaTri) =>
              hienHanh == null || giaTri.isBefore(hienHanh) ? giaTri : hienHanh,
        );
    if (effectiveClosing != null && !effectiveClosing.isAfter(DateTime.now())) {
      throw StateError('Bài thi đã hết hạn nộp bài.');
    }
    final cacLuotThi = await _coSoDuLieu
        .collection('exam_attempts')
        .where('userId', isEqualTo: userId)
        .get();

    final examAttempts = cacLuotThi.docs
        .where((banGhi) => banGhi.data()['examId'] == examId)
        .toList();

    for (final banGhi in examAttempts) {
      final duLieu = banGhi.data();
      if (duLieu['examId'] == examId && duLieu['status'] == 'in_progress') {
        DateTime endsAt;
        DateTime? startedAt;
        final rawEndsAt = duLieu['endsAt'];
        final rawStartedAt = duLieu['startedAt'];
        if (rawStartedAt is Timestamp) startedAt = rawStartedAt.toDate();
        if (rawEndsAt is Timestamp) {
          endsAt = rawEndsAt.toDate();
        } else {
          final batDau = startedAt ?? DateTime.now();
          endsAt = batDau.add(Duration(minutes: durationMinutes));
          await banGhi.reference.update({'endsAt': Timestamp.fromDate(endsAt)});
          startedAt ??= batDau;
        }

        final selectedAnswers = <int, int>{};
        final rawAnswers = duLieu['selectedAnswers'];
        if (rawAnswers is Map) {
          for (final capDuLieu in rawAnswers.entries) {
            final questionIndex = int.tryParse(capDuLieu.key.toString());
            final optionIndex = capDuLieu.value is int
                ? capDuLieu.value as int
                : int.tryParse(capDuLieu.value.toString());
            if (questionIndex != null && optionIndex != null) {
              selectedAnswers[questionIndex] = optionIndex;
            }
          }
        }

        return ExamAttemptSession(
          attemptId: banGhi.id,
          startedAt: startedAt,
          endsAt: endsAt,
          selectedAnswers: selectedAnswers,
          currentQuestionIndex:
              (duLieu['currentQuestionIndex'] as num?)?.toInt() ?? 0,
        );
      }
    }

    var attemptCount = 0;
    var bestScore = -1.0;
    QueryDocumentSnapshot<Map<String, dynamic>>? keeper;
    for (final banGhi in examAttempts) {
      final duLieu = banGhi.data();
      final soLuong =
          (duLieu['attemptCount'] as num?)?.toInt() ??
          (duLieu['status'] == 'completed' ? 1 : 0);
      attemptCount += soLuong;
      final diem =
          (duLieu['bestScore'] as num?)?.toDouble() ??
          (duLieu['diemSo'] as num?)?.toDouble() ??
          -1;
      if (keeper == null || diem > bestScore) {
        keeper = banGhi;
        bestScore = diem;
      }
    }

    if (maxAttempts != null && attemptCount >= maxAttempts) {
      throw StateError('Bạn đã sử dụng hết $maxAttempts lượt làm bài.');
    }

    final startedAt = DateTime.now();
    final durationEnd = startedAt.add(Duration(minutes: durationMinutes));
    final endsAt = closingTime != null && closingTime.isBefore(durationEnd)
        ? closingTime
        : durationEnd;
    late final DocumentReference<Map<String, dynamic>> attemptRef;
    if (keeper == null) {
      attemptRef = await _coSoDuLieu.collection('exam_attempts').add({
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
      final loGhi = _coSoDuLieu.batch();
      loGhi.update(attemptRef, {
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'endsAt': Timestamp.fromDate(endsAt),
        'selectedAnswers': <String, int>{},
        'currentQuestionIndex': 0,
      });
      await loGhi.commit();
    }
    return ExamAttemptSession(
      attemptId: attemptRef.id,
      startedAt: startedAt,
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
    return _coSoDuLieu.collection('exam_attempts').doc(attemptId).update({
      'selectedAnswers': selectedAnswers.map(
        (cauHoi, luaChon) => MapEntry(cauHoi.toString(), luaChon),
      ),
      'currentQuestionIndex': currentQuestionIndex,
      'lastSavedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<CauHoiModel>> getQuestionsByIds(List<String> dsMaCauHoi) async {
    List<CauHoiModel> dsCauHoi = [];
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

  Future<void> submitExam({
    required String maLuot,
    required double diemSo,
    required List<CauTraLoiModel> dsCauTraLoi,
    required String examTitle,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    final thamChieu = _coSoDuLieu.collection('exam_attempts').doc(maLuot);
    await _coSoDuLieu.runTransaction((transaction) async {
      final duLieuNhan = await transaction.get(thamChieu);
      final duLieu = duLieuNhan.data() ?? <String, dynamic>{};
      if (duLieu['status'] == 'completed') return;
      final runNumber = ((duLieu['attemptCount'] as num?)?.toInt() ?? 0) + 1;
      transaction.set(thamChieu.collection('runs').doc(runNumber.toString()), {
        'userId': duLieu['userId'],
        'examId': duLieu['examId'],
        'examTitle': examTitle,
        'score': diemSo,
        'correctAnswers': correctAnswers,
        'totalQuestions': totalQuestions,
        'answers': dsCauTraLoi.map((dapAn) => dapAn.toMap()).toList(),
        'runNumber': runNumber,
        'completedAt': FieldValue.serverTimestamp(),
      });
      final oldBest =
          (duLieu['bestScore'] as num?)?.toDouble() ??
          (duLieu['diemSo'] as num?)?.toDouble() ??
          -1;
      final isNewBest = diemSo > oldBest;
      final cacCapNhat = <String, dynamic>{
        'examTitle': examTitle,
        'status': 'completed',
        'attemptCount': ((duLieu['attemptCount'] as num?)?.toInt() ?? 0) + 1,
        'lastAttemptAt': FieldValue.serverTimestamp(),
        'selectedAnswers': FieldValue.delete(),
        'currentQuestionIndex': FieldValue.delete(),
      };
      if (isNewBest) {
        cacCapNhat.addAll({
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
      transaction.update(thamChieu, cacCapNhat);
    });
  }

  // --- 2. QUẢN LÝ BÀI THI ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getExamsStream() {
    return _coSoDuLieu.collection('exams').snapshots();
  }

  Future<String> addExam({
    required String title,
    required int durationMinutes,
    required bool isOpen,
    int? maxAttempts,
    DateTime? closesAt,
    String? courseId,
  }) async {
    if (title.trim().isEmpty ||
        durationMinutes < 1 ||
        durationMinutes > 1440 ||
        (maxAttempts != null && maxAttempts < 1)) {
      throw ArgumentError('Thông tin bài thi không hợp lệ.');
    }
    if (closesAt != null) {
      LearningPolicy.requireFutureDateTime(closesAt, 'Thời gian đóng đề');
    }
    final thamChieu = _coSoDuLieu.collection('exams').doc();
    await thamChieu.set({
      'title': title,
      'duration': '$durationMinutes phút',
      'durationMinutes': durationMinutes,
      'questions': 0,
      'isOpen': isOpen,
      'maxAttempts': maxAttempts,
      'closesAt': closesAt == null ? null : Timestamp.fromDate(closesAt),
      'courseId': courseId ?? '',
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return thamChieu.id;
  }

  Future<void> updateExamPolicy(String ma, Map<String, dynamic> policy) async {
    final reference = _coSoDuLieu.collection('exams').doc(ma);
    final snapshot = await reference.get();
    final previous = snapshot.data() ?? <String, dynamic>{};
    for (final field in ['opensAt', 'closesAt']) {
      if (!policy.containsKey(field)) continue;
      final next = LearningPolicy.readDateTime(policy[field]);
      final old = LearningPolicy.readDateTime(previous[field]);
      if (next != null && !LearningPolicy.sameMinute(old, next)) {
        LearningPolicy.requireFutureDateTime(
          next,
          field == 'opensAt' ? 'Thời gian mở đề' : 'Thời gian đóng đề',
        );
      }
    }
    final nextStart = policy.containsKey('opensAt')
        ? LearningPolicy.readDateTime(policy['opensAt'])
        : LearningPolicy.readDateTime(previous['opensAt']);
    final nextEnd = policy.containsKey('closesAt')
        ? LearningPolicy.readDateTime(policy['closesAt'])
        : LearningPolicy.readDateTime(previous['closesAt']);
    if (nextStart != null && nextEnd != null && !nextEnd.isAfter(nextStart)) {
      throw ArgumentError('Thời gian đóng đề phải sau thời gian mở đề.');
    }
    await reference.update(policy);
  }

  Future<void> updateExamStatus(String docId, bool isOpen) async {
    await _coSoDuLieu.collection('exams').doc(docId).update({
      'isOpen': isOpen,
      'status': isOpen ? 'Đang mở' : 'Đã đóng',
    });
  }

  Future<void> deleteExam(String docId) async {
    if (_apiTaiKhoan.hasTransport) {
      await _apiTaiKhoan.call('examDelete', {'examId': docId});
      return;
    }
    final cacCauHoi = await _coSoDuLieu
        .collection('exams')
        .doc(docId)
        .collection('questions')
        .get();
    final cacLuotThi = await _coSoDuLieu
        .collection('exam_attempts')
        .where('examId', isEqualTo: docId)
        .get();
    await _xoaCacLuotThi(cacLuotThi.docs);
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...cacCauHoi.docs.map((cauHoi) => cauHoi.reference),
      ...cacLuotThi.docs.map((luotThi) => luotThi.reference),
      _coSoDuLieu.collection('exams').doc(docId),
    ];

    await deleteFirestoreDocuments(_coSoDuLieu, references, batchSize: 500);
  }

  // --- 3. QUẢN LÝ CÂU HỎI ---
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

  // --- 4. QUẢN LÝ TÀI KHOẢN ---
}
