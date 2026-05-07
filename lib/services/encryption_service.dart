import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256 Encryption Service
///
/// Provides AES-256-CBC encryption/decryption for sensitive data.
/// Master key is generated once and stored in platform secure storage
/// (Android Keystore / iOS Keychain).
class EncryptionService {
  static const _keyStorageKey = 'myleads_master_key_v1';
  static const _ivStorageKey = 'myleads_master_iv_v1';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static enc.Encrypter? _encrypter;
  static enc.IV? _iv;

  /// Initialize encryption service. Must be called before any other method.
  static Future<void> init() async {
    String? keyB64 = await _secureStorage.read(key: _keyStorageKey);
    String? ivB64 = await _secureStorage.read(key: _ivStorageKey);

    if (keyB64 == null || ivB64 == null) {
      // Generate new 256-bit key and 128-bit IV
      final keyBytes = _randomBytes(32);
      final ivBytes = _randomBytes(16);
      keyB64 = base64Encode(keyBytes);
      ivB64 = base64Encode(ivBytes);
      await _secureStorage.write(key: _keyStorageKey, value: keyB64);
      await _secureStorage.write(key: _ivStorageKey, value: ivB64);
    }

    final key = enc.Key.fromBase64(keyB64);
    _iv = enc.IV.fromBase64(ivB64);
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  /// Encrypt a plain text string using AES-256-CBC.
  static String encryptText(String plain) {
    if (plain.isEmpty) return '';
    if (_encrypter == null || _iv == null) {
      throw StateError('EncryptionService not initialized. Call init() first.');
    }
    final encrypted = _encrypter!.encrypt(plain, iv: _iv!);
    return encrypted.base64;
  }

  /// Decrypt an encrypted string using AES-256-CBC.
  static String decryptText(String? cipher) {
    if (cipher == null || cipher.isEmpty) return '';
    if (_encrypter == null || _iv == null) {
      throw StateError('EncryptionService not initialized. Call init() first.');
    }
    try {
      return _encrypter!.decrypt(enc.Encrypted.fromBase64(cipher), iv: _iv!);
    } catch (_) {
      return '';
    }
  }

  /// Hash a password using SHA-256 with salt.
  /// Returns "salt:hash" format.
  static String hashPassword(String password) {
    final salt = base64Encode(_randomBytes(16));
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  /// Verify a password against a stored hash ("salt:hash").
  static bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final hash = parts[1];
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString() == hash;
  }

  /// Generate a session token for the current device.
  static String generateSessionToken() {
    return base64Url.encode(_randomBytes(32));
  }

  static List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  @visibleForTesting
  static void initForTest({required String keyB64, required String ivB64}) {
    final key = enc.Key.fromBase64(keyB64);
    _iv = enc.IV.fromBase64(ivB64);
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }
}
