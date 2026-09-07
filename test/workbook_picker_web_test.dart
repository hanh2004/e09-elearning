@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:e09_elearning/services/workbook_picker_web.dart';
import 'package:e09_elearning/services/workbook_picker_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late JSFunction suppressDialog;

  setUp(() {
    // Test browser file events without opening an interactive OS dialog.
    suppressDialog = ((web.Event event) => event.preventDefault()).toJS;
    web.document.addEventListener('click', suppressDialog, true.toJS);
  });
  tearDown(() {
    web.document.removeEventListener('click', suppressDialog, true.toJS);
    expect(web.document.querySelector('[data-workbook-picker]'), isNull);
  });

  web.HTMLInputElement input() =>
      web.document.querySelector('[data-workbook-picker]')!
          as web.HTMLInputElement;

  void select(String name, Uint8List bytes) {
    final transfer = web.DataTransfer();
    transfer.items.add(web.File([bytes.toJS].toJS, name));
    input().files = transfer.files;
    input().dispatchEvent(web.Event('change'));
  }

  test('reads selected local bytes without FilePicker registration', () async {
    final pending = pickWorkbookFile();
    expect(input().accept, '.xlsx');
    expect(input().multiple, isFalse);
    select('users.XLSX', Uint8List.fromList([80, 75, 3, 4]));
    expect(await pending, [80, 75, 3, 4]);
  });

  test('cancel cleans up and allows choosing again', () async {
    final first = pickWorkbookFile();
    input().dispatchEvent(web.Event('cancel'));
    expect(await first, isNull);
    final second = pickWorkbookFile();
    select('users.xlsx', Uint8List.fromList([1]));
    expect(await second, [1]);
  });

  test('rejects wrong extension before reading bytes', () async {
    final pending = pickWorkbookFile();
    final assertion = expectLater(
      pending,
      throwsA(isA<WorkbookPickerException>()),
    );
    select('users.csv', Uint8List.fromList([1]));
    await assertion;
  });

  test('rejects file above two MB', () async {
    final pending = pickWorkbookFile();
    final assertion = expectLater(
      pending,
      throwsA(isA<WorkbookPickerException>()),
    );
    select('users.xlsx', Uint8List(2 * 1024 * 1024 + 1));
    await assertion;
  });
}
