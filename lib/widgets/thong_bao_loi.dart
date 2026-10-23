// GIAO DIỆN DÙNG CHUNG: Hiển thị lỗi tải hoặc thao tác với hướng khắc phục.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/thong_bao_loi_ung_dung.dart';

class AppErrorNotice extends StatelessWidget {
  const AppErrorNotice({
    super.key,
    required this.error,
    required this.feature,
    this.fallbackAction,
    this.padding = EdgeInsets.zero,
    this.centered = true,
    this.style,
    this.onRetry,
  });

  final Object error;
  final String feature;
  final String? fallbackAction;
  final EdgeInsetsGeometry padding;
  final bool centered;
  final TextStyle? style;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final notice = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (onRetry != null) ...[
            Text(
              'Không tải được dữ liệu',
              textAlign: centered ? TextAlign.center : null,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            AppErrorMessage.from(
              error,
              feature: feature,
              fallbackAction: fallbackAction,
            ),
            textAlign: centered ? TextAlign.center : null,
            style: style,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ],
      ),
    );
    return centered ? Center(child: notice) : notice;
  }
}

/// Tải lại một truy vấn khi lỗi, giới hạn thời gian đợi dữ liệu ban đầu.
/// Sau khi đã nhận dữ liệu, luồng có thể yên lặng mà không bị báo quá hạn.
class ReloadableStreamBuilder<T> extends StatefulWidget {
  const ReloadableStreamBuilder({
    super.key,
    this.stream,
    this.streamFactory,
    required this.feature,
    required this.builder,
    this.isUsableData,
  }) : assert((stream == null) != (streamFactory == null));

  final Stream<T>? stream;
  final Stream<T> Function()? streamFactory;
  final String feature;
  final AsyncWidgetBuilder<T> builder;
  final bool Function(T)? isUsableData;

  @override
  State<ReloadableStreamBuilder<T>> createState() =>
      _ReloadableStreamBuilderState<T>();
}

class _ReloadableStreamBuilderState<T>
    extends State<ReloadableStreamBuilder<T>> {
  StreamSubscription<T>? _subscription;
  Timer? _initialTimer;
  var _generation = 0;
  var _received = false;
  AsyncSnapshot<T> _snapshot = AsyncSnapshot<T>.nothing();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant ReloadableStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream ||
        oldWidget.streamFactory != widget.streamFactory) {
      _listen();
    }
  }

  void _listen() {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _initialTimer?.cancel();
    _received = false;
    _snapshot = AsyncSnapshot<T>.waiting();
    _initialTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || generation != _generation || _received) return;
      _showError(TimeoutException('Chưa nhận được dữ liệu từ máy chủ.'));
    });
    try {
      final stream = widget.streamFactory?.call() ?? widget.stream!;
      _subscription = stream.listen(
        (data) {
          if (!mounted || generation != _generation) return;
          if (widget.isUsableData?.call(data) == false) return;
          _received = true;
          _initialTimer?.cancel();
          setState(() {
            _snapshot = AsyncSnapshot<T>.withData(ConnectionState.active, data);
          });
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted || generation != _generation) return;
          _showError(error, stack);
        },
        onDone: () {
          if (!mounted ||
              generation != _generation ||
              _received ||
              _snapshot.hasError) {
            return;
          }
          _showError(StateError('Máy chủ chưa trả về dữ liệu. Hãy tải lại.'));
        },
      );
    } catch (error, stack) {
      _showError(error, stack);
    }
  }

  void _showError(Object error, [StackTrace? stack]) {
    _initialTimer?.cancel();
    setState(() {
      _snapshot = AsyncSnapshot<T>.withError(
        ConnectionState.active,
        error,
        stack ?? StackTrace.empty,
      );
    });
  }

  void _retry() => setState(_listen);

  @override
  void dispose() {
    _generation++;
    _initialTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _snapshot.hasError
      ? AppErrorNotice(
          error: _snapshot.error!,
          feature: widget.feature,
          fallbackAction: 'Kiểm tra kết nối Internet rồi bấm Tải lại.',
          padding: const EdgeInsets.all(24),
          onRetry: _retry,
        )
      : widget.builder(context, _snapshot);
}
