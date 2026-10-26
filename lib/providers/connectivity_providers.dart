import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> _hasInternet() async {
  try {
    final result = await InternetAddress.lookup('firebase.google.com')
        .timeout(const Duration(seconds: 4));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}

final connectivityProvider = StreamProvider.autoDispose<bool>((ref) async* {
  bool? last;
  while (true) {
    final online = await _hasInternet();
    if (online != last) {
      last = online;
      yield online;
    }
    await Future.delayed(const Duration(seconds: 8));
  }
});
