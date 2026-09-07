import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'workbook_picker_error.dart';

/// Opens synchronously within the user's click, without plugin registration.
Future<Uint8List?> pickWorkbookFile() {
  final result = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx'
    ..multiple = false
    ..setAttribute('data-workbook-picker', 'true')
    ..style.display = 'none';
  var reading = false;
  late final JSFunction onChange;
  late final JSFunction onCancel;

  void cleanup() {
    input.removeEventListener('change', onChange);
    input.removeEventListener('cancel', onCancel);
    input.remove();
  }

  onChange = ((web.Event event) {
    if (reading || result.isCompleted) return;
    reading = true;
    unawaited(() async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          result.complete(null);
        } else {
          validateWorkbookFile(file.name, file.size);
          final buffer = await file.arrayBuffer().toDart;
          result.complete(buffer.toDart.asUint8List());
        }
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        cleanup();
      }
    }());
  }).toJS;
  onCancel = ((web.Event event) {
    if (reading || result.isCompleted) return;
    result.complete(null);
    cleanup();
  }).toJS;
  input.addEventListener('change', onChange);
  input.addEventListener('cancel', onCancel);
  try {
    final body = web.document.body;
    if (body == null) throw StateError('document-body-unavailable');
    body.appendChild(input);
    // Keep the input attached until selection/cancellation has finished.
    input.click();
  } catch (error, stack) {
    cleanup();
    result.completeError(error, stack);
  }
  return result.future;
}
