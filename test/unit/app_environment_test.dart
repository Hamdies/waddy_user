import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/app_environment.dart';

/// The build must know which backend it talks to, and must not be able to
/// change its mind at runtime.
///
/// These assertions hold under the default (no `--dart-define`) build. The
/// per-flavor values are verified in CI by `flavor-guard`, which runs this file
/// again with `--dart-define-from-file=env/prod.json` and checks the production
/// host comes through.
void main() {
  group('flavor parsing', () {
    test('recognised names map to their flavor', () {
      expect(AppFlavor.fromName('prod'), AppFlavor.prod);
      expect(AppFlavor.fromName('production'), AppFlavor.prod);
      expect(AppFlavor.fromName('staging'), AppFlavor.staging);
      expect(AppFlavor.fromName('stage'), AppFlavor.staging);
      expect(AppFlavor.fromName('dev'), AppFlavor.dev);
    });

    test('case and whitespace do not matter', () {
      expect(AppFlavor.fromName('  PROD '), AppFlavor.prod);
      expect(AppFlavor.fromName('Staging'), AppFlavor.staging);
    });

    test('an unknown or empty flavor falls back to dev, never prod', () {
      // A build-configuration mistake must not silently point a debug build at
      // live customer data.
      expect(AppFlavor.fromName('typo'), AppFlavor.dev);
      expect(AppFlavor.fromName(''), AppFlavor.dev);
    });
  });

  group('the build is pinned to one backend', () {
    test('a prod build reaches production', () {
      if (AppEnvironment.isProd) {
        expect(AppEnvironment.baseUrl, 'https://waddyapp.com');
      }
    });

    test('the default is honest about where it points', () {
      // While there is no staging backend, a no-flag build talks to production
      // — and must therefore report itself as prod rather than dev. A default
      // that lies about its backend is worse than one that points at
      // production openly.
      //
      // FLIP THIS when staging exists: set defaultIsProduction to false, point
      // env/dev.json and env/staging.json at the staging host, and this test
      // starts asserting the safe default instead.
      if (AppEnvironment.defaultIsProduction) {
        expect(
          AppEnvironment.baseUrl,
          'https://waddyapp.com',
          reason: 'the default must match what the flavor claims',
        );
      } else {
        expect(AppEnvironment.baseUrl, isNot('https://waddyapp.com'));
        expect(AppEnvironment.isNonProduction, isTrue);
      }
    });

    test('the base url is a real https host', () {
      final uri = Uri.parse(AppEnvironment.baseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
      // No trailing slash: every endpoint constant starts with one, so a
      // trailing slash here produces '//api/v1/...'.
      expect(AppEnvironment.baseUrl.endsWith('/'), isFalse);
    });
  });

  group('AppConstants delegates to the environment', () {
    test('base and web urls come from the build, not a literal', () {
      expect(AppConstants.baseUrl, AppEnvironment.baseUrl);
      expect(AppConstants.webHostedUrl, AppEnvironment.webHostedUrl);
    });
  });

  group('developer affordances', () {
    test('the banner names the backend outside production, and is silent in it', () {
      if (AppEnvironment.isProd) {
        // A customer must never see a build banner.
        expect(AppEnvironment.banner, isEmpty);
      } else {
        expect(AppEnvironment.banner, contains(AppEnvironment.baseUrl));
        // A non-prod build pointed at production is the dangerous case; the
        // banner must say so out loud.
        expect(AppEnvironment.banner, contains(AppEnvironment.flavor.name.toUpperCase()));
      }
    });

    test('exactly one flavor predicate is true', () {
      final flags = <bool>[
        AppEnvironment.isDev,
        AppEnvironment.isStaging,
        AppEnvironment.isProd,
      ];
      expect(flags.where((f) => f).length, 1);
    });
  });
}
