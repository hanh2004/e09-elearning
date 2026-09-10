import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/question_bank_arguments.dart';
import '../../models/account_identity.dart';

class AdminQuestionBankScreen extends StatefulWidget {
  final QuestionBankArguments args;

  const AdminQuestionBankScreen({super.key, required this.args, this.service});
  final FirestoreService? service;

  @override
  State<AdminQuestionBankScreen> createState() =>
      _AdminQuestionBankScreenState();
}

class _AdminQuestionBankScreenState extends State<AdminQuestionBankScreen> {
  late final FirestoreService _firestoreService =
      widget.service ?? FirestoreService();
  final Color primaryColor = const Color(0xFFB51F24);

  Future<void> _showAddQuestionDialog({
    String? questionId,
    Map<String, dynamic>? question,
  }) async {
    final questionController = TextEditingController(
      text: question?['questionText'] ?? '',
    );
    final explanationController = TextEditingController(
      text: question?['explanation'] ?? '',
    );
    final existing = List<String>.from(
      question?['options'] ?? ['', '', '', ''],
    );
    final optionControllers = existing
        .map((s) => TextEditingController(text: s))
        .toList();
    int selectedCorrectIndex = question?['correctAnswerIndex'] ?? 0;
    bool busy = false;

    final dialogRoute = DialogRoute<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(
              questionId == null ? 'Thêm câu hỏi mới' : 'Chỉnh sửa câu hỏi',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung câu hỏi',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(
                      labelText: 'Lời giải (tùy chọn)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Chọn đáp án đúng',
                            onPressed: () => setModalState(
                              () => selectedCorrectIndex = index,
                            ),
                            icon: Icon(
                              selectedCorrectIndex == index
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selectedCorrectIndex == index
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              decoration: InputDecoration(
                                labelText:
                                    'Đáp án ${String.fromCharCode(65 + index)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  if (busy) return;
                  final options = optionControllers
                      .map((e) => e.text.trim())
                      .toList();
                  if (questionController.text.isNotEmpty &&
                      options.every((e) => e.isNotEmpty)) {
                    setModalState(() => busy = true);
                    try {
                      await _firestoreService.addQuestion(
                        widget.args.examId,
                        questionText: questionController.text.trim(),
                        options: options,
                        correctAnswerIndex: selectedCorrectIndex,
                        explanation: explanationController.text,
                        questionId: questionId,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        setModalState(() => busy = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Không lưu được câu hỏi. Vui lòng thử lại.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vui lòng điền đầy đủ câu hỏi và 4 đáp án!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Lưu', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
    questionController.dispose();
    explanationController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Câu hỏi: ${widget.args.examTitle}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getQuestionsStream(widget.args.examId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Có lỗi xảy ra'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                AccountSession.current?.isRoot == true
                    ? 'Chưa có câu hỏi nào. Bấm nút + để thêm.'
                    : 'Chưa có câu hỏi nào.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final q = docs[index].data();
              final options = List<String>.from(q['options'] ?? []);
              final correctIndex = q['correctAnswerIndex'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Câu ${index + 1}: ${q['questionText']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (AccountSession.current?.isRoot == true)
                            IconButton(
                              tooltip: 'Sửa câu hỏi',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showAddQuestionDialog(
                                questionId: docs[index].id,
                                question: q,
                              ),
                            ),
                          if (AccountSession.current?.isRoot == true)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _firestoreService.deleteQuestion(
                                widget.args.examId,
                                docs[index].id,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(options.length, (optIndex) {
                        final isCorrect = optIndex == correctIndex;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green[50]
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${String.fromCharCode(65 + optIndex)}. ',
                                style: TextStyle(
                                  color: isCorrect
                                      ? Colors.green[800]
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  options[optIndex],
                                  style: TextStyle(
                                    color: isCorrect
                                        ? Colors.green[800]
                                        : Colors.black87,
                                    fontWeight: isCorrect
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isCorrect)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: AccountSession.current?.isRoot == true
          ? FloatingActionButton(
              backgroundColor: primaryColor,
              onPressed: _showAddQuestionDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
