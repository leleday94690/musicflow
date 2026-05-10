import 'dart:async';

import 'package:flutter/foundation.dart';

class DelayedLoadingController extends ChangeNotifier {
  DelayedLoadingController({this.delay = const Duration(milliseconds: 280)});

  final Duration delay;
  Timer? _timer;
  int _token = 0;
  bool _active = false;
  bool _visible = false;
  bool _disposed = false;

  bool get active => _active;
  bool get visible => _visible;

  void start() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    final token = ++_token;
    _active = true;
    _visible = false;
    notifyListeners();
    _timer = Timer(delay, () {
      if (!_disposed && _active && token == _token) {
        _visible = true;
        notifyListeners();
      }
    });
  }

  void stop() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _token++;
    if (!_active && !_visible) {
      return;
    }
    _active = false;
    _visible = false;
    notifyListeners();
  }

  Future<T> track<T>(Future<T> Function() task) async {
    start();
    try {
      return await task();
    } finally {
      stop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
