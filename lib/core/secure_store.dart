import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const String _dbKeyName = 'local_db_key';
  static const String _lastRoleKey = 'last_login_role';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String> getOrCreateDbKey() async {
    String? existing;
    try {
      existing = await _storage.read(key: _dbKeyName);
    } on PlatformException {
      await _storage.deleteAll();
    }
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _dbKeyName, value: key);
    return key;
  }

  static Future<String?> readLastRole() async {
    try {
      return await _storage.read(key: _lastRoleKey);
    } on PlatformException {
      return null;
    }
  }

  static Future<void> saveLastRole(String role) async {
    try {
      await _storage.write(key: _lastRoleKey, value: role);
    } on PlatformException {
      return;
    }
  }
}
