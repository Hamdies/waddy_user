import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The token moved from plaintext SharedPreferences into encrypted storage.
///
/// `flutter_secure_storage` has no platform implementation under `flutter
/// test`, so these tests cover the parts that do run on the Dart side: the
/// synchronous cache contract that 18 call sites depend on, and the migration
/// decision — specifically that hydrate() adopts a legacy plaintext token
/// rather than silently signing the user out on upgrade.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthTokenStore.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('synchronous read contract', () {
    test('returns empty string, never null, when signed out', () {
      // getUserToken()'s signature is String. Callers interpolate it straight
      // into a Bearer header, so null would render as "Bearer null".
      expect(AuthTokenStore.token, '');
      expect(AuthTokenStore.hasToken, isFalse);
    });

    test('reads back synchronously once seeded', () {
      AuthTokenStore.resetForTest(token: 'abc123', hydrated: true);
      expect(AuthTokenStore.token, 'abc123');
      expect(AuthTokenStore.hasToken, isTrue);
    });

    test('an empty token counts as signed out', () {
      AuthTokenStore.resetForTest(token: '', hydrated: true);
      expect(AuthTokenStore.hasToken, isFalse);
    });
  });

  group('migration from plaintext', () {
    test('adopts a legacy token instead of logging the user out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.token: 'legacy-token-from-old-build',
      });
      final prefs = await SharedPreferences.getInstance();

      await AuthTokenStore.hydrate(prefs);

      // The user stays signed in across the upgrade — this is the whole point
      // of the migration path.
      expect(AuthTokenStore.token, 'legacy-token-from-old-build');
      expect(AuthTokenStore.isHydrated, isTrue);
    });

    test('hydrating with nothing stored leaves the user signed out', () async {
      final prefs = await SharedPreferences.getInstance();
      await AuthTokenStore.hydrate(prefs);

      expect(AuthTokenStore.token, '');
      expect(AuthTokenStore.hasToken, isFalse);
      expect(AuthTokenStore.isHydrated, isTrue);
    });

    test('an empty legacy value is not adopted as a token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.token: '',
      });
      final prefs = await SharedPreferences.getInstance();

      await AuthTokenStore.hydrate(prefs);

      expect(AuthTokenStore.hasToken, isFalse);
    });
  });

  group('sign out', () {
    test('clear() empties the synchronous cache', () async {
      AuthTokenStore.resetForTest(token: 'live-token', hydrated: true);
      final prefs = await SharedPreferences.getInstance();

      await AuthTokenStore.clear(prefs);

      expect(AuthTokenStore.token, '');
      expect(AuthTokenStore.hasToken, isFalse);
    });

    test('clear() removes any legacy plaintext copy', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.token: 'legacy-token',
      });
      final prefs = await SharedPreferences.getInstance();

      await AuthTokenStore.clear(prefs);

      expect(prefs.getString(AppConstants.token), isNull);
    });
  });
}
