import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class NewsVoiceSearch extends StatefulWidget {
  const NewsVoiceSearch({
    super.key,
    required this.onResult,
    this.active = true,
  });
  final ValueChanged<String> onResult;
  final bool active;
  @override
  State<NewsVoiceSearch> createState() => _TrangThaiTimTinBangGiongNoi();
}

class _TrangThaiTimTinBangGiongNoi extends State<NewsVoiceSearch>
    with WidgetsBindingObserver {
  final speech = SpeechToText();
  bool listening = false, busy = false, initialized = false;
  @override
  void didUpdateWidget(covariant NewsVoiceSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && initialized) {
      unawaited(speech.cancel());
      listening = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && initialized) {
      unawaited(speech.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (initialized) unawaited(speech.cancel());
    super.dispose();
  }

  void error(String thongDiep) {
    if (!mounted) return;
    setState(() => listening = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(thongDiep)));
  }

  Future<void> toggle() async {
    if (busy || !widget.active) return;
    setState(() => busy = true);
    try {
      if (listening) {
        await speech.stop();
        if (mounted) setState(() => listening = false);
        return;
      }
      initialized = await speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => listening = status == 'listening');
        },
        onError: (_) => error(
          'Không nhận được giọng nói. Bạn có thể thử lại hoặc nhập từ khóa.',
        ),
      );
      if (!mounted || !widget.active) {
        if (initialized) await speech.cancel();
        return;
      }
      if (!initialized) {
        error(
          'Chưa dùng được micro. Hãy cho phép truy cập micro hoặc nhập từ khóa để tìm kiếm.',
        );
        return;
      }
      await speech.listen(
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (ketQua) {
          if (mounted && widget.active) widget.onResult(ketQua.recognizedWords);
        },
      );
    } catch (_) {
      error(
        'Thiết bị chưa hỗ trợ tìm kiếm bằng giọng nói. Vui lòng nhập từ khóa.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: listening ? 'Dừng nghe' : 'Tìm bằng giọng nói',
    onPressed: busy ? null : toggle,
    color: listening ? Colors.red : Colors.blueGrey,
    icon: Icon(listening ? Icons.mic : Icons.mic_none),
  );
}
