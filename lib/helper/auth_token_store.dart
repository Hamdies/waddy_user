import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/helper/secure_storage_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The auth token's storage, with the encrypted store as the source of truth.
///
/// ## Why this exists
///
/// The bearer token used to live in SharedPreferences as plain text, readable
/// by anything with filesystem access on a rooted or jailbroken device.
/// `SecureStorageHelper` — which wraps `flutter_secure_storage` with
/// `encryptedSharedPreferences: true`, i.e. Keystore on Android and Keychain on
/// iOS — already had `saveToken`/`getToken`/`deleteToken`, and nothing ever
/// called them. The infrastructure was built and left unwired.
///
/// ## Why there is a synchronous cache
///
/// Secure storage is inherently async (it crosses a platform channel), but the
/// token is read synchronously in 18 places across 9 files — including
/// `ApiClient`'s constructor, which builds the auth header, and
/// `AuthRepository.getUserToken()`, whose signature is `String`, not
/// `Future<String>`. Making those async would ripple through the repository and
/// service interfaces and every caller, which is a large change to make while
/// also changing where the secret lives.
///
/// So: secure storage is the durable store, and [_cached] is a synchronous
/// view of it that is hydrated once during `di.init()` (before `runApp`, so
/// before any screen or `ApiClient` can read it) and kept in step on every
/// write. Reads stay synchronous and cost nothing; the plaintext copy is gone.
///
/// ## Migration
///
/// [hydrate] moves an existing plaintext token into secure storage on first run
/// after upgrade and then deletes it, so users are not silently logged out.
/// Once shipped for long enough that essentially everyone has launched the new
/// build, [_migrateLegacyToken] and the `AppConstants.token` key can go.
class AuthTokenStore {
  AuthTokenStore._();

  static String? _cached;
  static bool _hydrated = false;

  /// True once [hydrate] has run. Reads before this point return null, which is
  /// why hydration belongs in `di.init()` rather than at first use.
  static bool get isHydrated => _hydrated;

  /// Loads the token into memory and migrates any legacy plaintext copy.
  ///
  /// Call exactly once, from `di.init()`, after SharedPreferences is available
  /// and before `ApiClient` is constructed.
  static Future<void> hydrate(SharedPreferences prefs) async {
    try {
      _cached = await SecureStorageHelper.getToken();
    } catch (e, s) {
      // A failed read must not brick the launch: treat it as "no token" and let
      // the user sign in again rather than crashing on a cold start.
      debugPrint('[AuthTokenStore] secure read failed: $e\n$s');
      _cached = null;
    }

    if (_cached == null || _cached!.isEmpty) {
      await _migrateLegacyToken(prefs);
    } else {
      // Secure storage won. If a stale plaintext copy is still lying around
      // from before the migration, remove it.
      await _removeLegacyToken(prefs);
    }

    _hydrated = true;
  }

  /// The current token, or empty string when signed out.
  ///
  /// Synchronous by design — see the class doc.
  static String get token => _cached ?? '';

  static bool get hasToken => (_cached ?? '').isNotEmpty;

  /// Persists [token] to secure storage and updates the synchronous cache.
  static Future<void> save(String token) async {
    _cached = token;
    try {
      await SecureStorageHelper.saveToken(token);
    } catch (e, s) {
      // The in-memory cache still holds it, so the current session works. The
      // user would have to sign in again after a cold start.
      debugPrint('[AuthTokenStore] secure write failed: $e\n$s');
    }
  }

  /// Clears the token from memory, secure storage and any legacy copy.
  static Future<void> clear(SharedPreferences prefs) async {
    _cached = null;
    try {
      await SecureStorageHelper.deleteToken();
    } catch (e, s) {
      debugPrint('[AuthTokenStore] secure delete failed: $e\n$s');
    }
    await _removeLegacyToken(prefs);
  }

  /// Moves a pre-upgrade plaintext token into secure storage.
  static Future<void> _migrateLegacyToken(SharedPreferences prefs) async {
    final String? legacy = prefs.getString(AppConstants.token);
    if (legacy == null || legacy.isEmpty) return;

    _cached = legacy;
    try {
      await SecureStorageHelper.saveToken(legacy);
      await _removeLegacyToken(prefs);
      debugPrint('[AuthTokenStore] migrated token to secure storage');
    } catch (e, s) {
      // Keep the plaintext copy if the secure write failed — being logged out
      // is worse for the user than the status quo, and the next launch retries.
      debugPrint('[AuthTokenStore] migration failed, keeping legacy: $e\n$s');
    }
  }

  static Future<void> _removeLegacyToken(SharedPreferences prefs) async {
    if (prefs.containsKey(AppConstants.token)) {
      await prefs.remove(AppConstants.token);
    }
  }

  /// Test seam: resets the in-memory state between tests.
  @visibleForTesting
  static void resetForTest({String? token, bool hydrated = false}) {
    _cached = token;
    _hydrated = hydrated;
  }
}
