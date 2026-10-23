class CauHoiNhapNhieu {
  const CauHoiNhapNhieu({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  Map<String, dynamic> toMap() => {
    'questionText': questionText,
    'options': options,
    'correctAnswerIndex': correctAnswerIndex,
    'explanation': explanation,
  };
}

class KetQuaPhanTichCauHoi {
  const KetQuaPhanTichCauHoi({
    this.questions = const [],
    this.errors = const [],
  });

  const KetQuaPhanTichCauHoi.empty() : this();

  final List<CauHoiNhapNhieu> questions;
  final List<String> errors;
}

class BoPhanTichCauHoi {
  static KetQuaPhanTichCauHoi parse(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const KetQuaPhanTichCauHoi.empty();
    final lines = normalized
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isNotEmpty && lines.every((line) => line.contains('\t'))) {
      return _parseTabSeparated(lines);
    }

    final blocks = normalized
        .split(RegExp(r'\n[ \t]*---+[ \t]*\n|\n[ \t]*\n+'))
        .where((block) => block.trim().isNotEmpty)
        .toList();
    final questions = <CauHoiNhapNhieu>[];
    final errors = <String>[];
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final parsed = _parseBlock(blocks[blockIndex], blockIndex + 1);
      if (parsed.question != null) questions.add(parsed.question!);
      errors.addAll(parsed.errors);
    }
    if (questions.length > 499 && errors.isEmpty) {
      errors.add('Mỗi lần nhập tối đa 499 câu hỏi.');
    }
    return KetQuaPhanTichCauHoi(questions: questions, errors: errors);
  }

  static KetQuaPhanTichCauHoi _parseTabSeparated(List<String> lines) {
    final questions = <CauHoiNhapNhieu>[];
    final errors = <String>[];
    var firstRow = 0;
    final firstCells = lines.first.split('\t');
    final firstCell = firstCells.first.trim().toLowerCase();
    if (firstCell == 'câu hỏi' || firstCell == 'question') firstRow = 1;

    for (var rowIndex = firstRow; rowIndex < lines.length; rowIndex++) {
      final cells = lines[rowIndex]
          .split('\t')
          .map((cell) => cell.trim())
          .toList();
      final rowNumber = rowIndex - firstRow + 1;
      if (cells.length < 6) {
        errors.add('Dòng $rowNumber cần có câu hỏi, 4 đáp án và đáp án đúng.');
        continue;
      }
      final answerIndex = _answerIndex(cells[5]);
      if (cells[0].isEmpty ||
          cells.take(5).skip(1).any((option) => option.isEmpty) ||
          answerIndex == null) {
        errors.add('Dòng $rowNumber thiếu nội dung hoặc đáp án đúng A-D.');
        continue;
      }
      questions.add(
        CauHoiNhapNhieu(
          questionText: cells[0],
          options: cells.sublist(1, 5),
          correctAnswerIndex: answerIndex,
          explanation: cells.length > 6 ? cells[6] : '',
        ),
      );
    }
    if (questions.length > 499 && errors.isEmpty) {
      errors.add('Mỗi lần nhập tối đa 499 câu hỏi.');
    }
    return KetQuaPhanTichCauHoi(questions: questions, errors: errors);
  }

  static ({CauHoiNhapNhieu? question, List<String> errors}) _parseBlock(
    String block,
    int blockNumber,
  ) {
    final questionLines = <String>[];
    final options = <int, String>{};
    final errors = <String>[];
    var correctAnswerIndex = -1;
    var explanation = '';
    var readingExplanation = false;
    int? lastOptionIndex;

    for (final rawLine in block.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lineWithoutNumber = line.replaceFirst(
        RegExp(r'^\d+\s*[.)]\s*'),
        '',
      );
      final optionMatch = RegExp(
        r'^([A-D])\s*[.):：-]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      final questionMatch = RegExp(
        r'^(?:câu hỏi|question|q)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(lineWithoutNumber);
      final answerMatch = RegExp(
        r'^(?:đáp án(?:\s+đúng)?|correct(?:\s+answer)?|answer)\s*[:：]\s*([A-D1-4])\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final explanationMatch = RegExp(
        r'^(?:giải thích|lời giải|explanation)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);

      if (questionMatch != null) {
        questionLines.add(questionMatch.group(1)!.trim());
        readingExplanation = false;
      } else if (optionMatch != null) {
        final index = optionMatch.group(1)!.toUpperCase().codeUnitAt(0) - 65;
        if (options.containsKey(index)) {
          errors.add(
            'Câu $blockNumber có đáp án ${String.fromCharCode(65 + index)} bị lặp.',
          );
        } else {
          options[index] = optionMatch.group(2)!.trim();
        }
        lastOptionIndex = index;
        readingExplanation = false;
      } else if (answerMatch != null) {
        correctAnswerIndex = _answerIndex(answerMatch.group(1)!) ?? -1;
        readingExplanation = false;
      } else if (explanationMatch != null) {
        explanation = explanationMatch.group(1)!.trim();
        readingExplanation = true;
        lastOptionIndex = null;
      } else if (readingExplanation) {
        explanation = [
          explanation,
          line,
        ].where((text) => text.isNotEmpty).join('\n');
      } else if (lastOptionIndex != null) {
        options[lastOptionIndex] = '${options[lastOptionIndex]} $line'.trim();
      } else {
        questionLines.add(lineWithoutNumber);
      }
    }

    final questionText = questionLines.join(' ').trim();
    if (questionText.isEmpty) {
      errors.add('Câu $blockNumber thiếu nội dung câu hỏi.');
    }
    for (var index = 0; index < 4; index++) {
      if ((options[index] ?? '').isEmpty) {
        errors.add(
          'Câu $blockNumber thiếu đáp án ${String.fromCharCode(65 + index)}.',
        );
      }
    }
    if (correctAnswerIndex < 0 || correctAnswerIndex > 3) {
      errors.add('Câu $blockNumber cần ghi đáp án đúng A, B, C hoặc D.');
    }
    if (errors.isNotEmpty) return (question: null, errors: errors);
    return (
      question: CauHoiNhapNhieu(
        questionText: questionText,
        options: [for (var index = 0; index < 4; index++) options[index]!],
        correctAnswerIndex: correctAnswerIndex,
        explanation: explanation,
      ),
      errors: errors,
    );
  }

  static int? _answerIndex(String answer) {
    final match = RegExp(
      r'^(?:(?:đáp án(?:\s+đúng)?|correct(?:\s+answer)?|answer)\s*[:：]?\s*)?([A-D1-4])[.)]?$',
      caseSensitive: false,
    ).firstMatch(answer.trim());
    if (match == null) return null;
    final value = match.group(1)!.toUpperCase();
    final number = int.tryParse(value);
    return number != null ? number - 1 : value.codeUnitAt(0) - 65;
  }
}
