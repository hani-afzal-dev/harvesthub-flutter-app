import 'package:cloud_firestore/cloud_firestore.dart';

const Set<String> _retryableCodes = {'unavailable', 'deadline-exceeded'};

Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } on FirebaseException catch (e) {
      final canRetry =
          _retryableCodes.contains(e.code) && attempt < maxAttempts;
      if (!canRetry) rethrow;
      await Future.delayed(baseDelay * (1 << (attempt - 1)));
    }
  }
}

Future<QuerySnapshot<T>> getWithCacheFallback<T>(Query<T> query) async {
  try {
    return await retryWithBackoff(() => query.get());
  } on FirebaseException catch (e) {
    if (!_retryableCodes.contains(e.code)) rethrow;
    return query.get(const GetOptions(source: Source.cache));
  }
}
