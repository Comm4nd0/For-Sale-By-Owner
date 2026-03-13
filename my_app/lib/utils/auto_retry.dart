import 'package:flutter/widgets.dart';

/// Mixin that provides automatic retry with exponential backoff for data loading.
///
/// Add this mixin to any [State] class to get access to [withRetry],
/// which wraps a future-returning function with automatic retries.
mixin AutoRetryMixin<T extends StatefulWidget> on State<T> {
  static const int _maxRetries = 3;
  static const List<int> _retryDelaysMs = [2000, 4000, 8000];

  /// Wraps [fn] with automatic retry logic using exponential backoff.
  /// Retries up to [_maxRetries] times with delays of 2s, 4s, 8s.
  /// Stops retrying if the widget is no longer mounted.
  Future<R> withRetry<R>(Future<R> Function() fn) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == _maxRetries || !mounted) rethrow;
        await Future.delayed(Duration(milliseconds: _retryDelaysMs[attempt]));
        if (!mounted) rethrow;
      }
    }
    throw StateError('Unreachable');
  }
}
