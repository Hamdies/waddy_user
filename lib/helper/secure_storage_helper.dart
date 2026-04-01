import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'secure_auth_token';
  static const String _passwordKey = 'secure_user_password';
  static const String _walletTokenKey = 'secure_wallet_token';

  // Auth token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // User password (Remember Me)
  static Future<void> savePassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<String> getPassword() async {
    return await _storage.read(key: _passwordKey) ?? '';
  }

  static Future<void> deletePassword() async {
    await _storage.delete(key: _passwordKey);
  }

  // Wallet token
  static Future<void> saveWalletToken(String token) async {
    await _storage.write(key: _walletTokenKey, value: token);
  }

  static Future<String> getWalletToken() async {
    return await _storage.read(key: _walletTokenKey) ?? '';
  }

  static Future<void> deleteWalletToken() async {
    await _storage.delete(key: _walletTokenKey);
  }

  // Clear all secure data on logout
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
