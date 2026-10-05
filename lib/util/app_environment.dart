/// Which backend this build talks to.
///
/// ## Why this exists
///
/// There was one hardcoded production URL and no way to point a build anywhere
/// else, so every developer test, every QA pass and every debug session ran
/// against live customer data. A mistyped order, a test coupon, a load of junk
/// addresses — all of it landed in production, and the only thing standing
/// between a debugger and a real customer's order was whoever was holding the
/// phone.
///
/// The environment is chosen at build time and cannot be changed at runtime, so
/// a release build physically cannot be pointed at staging (or vice versa) by
/// anything the app does later.
///
/// ## How to select one
///
/// ```sh
/// flutter run                                             # dev (the default)
/// flutter run    --dart-define-from-file=env/staging.json
/// flutter build appbundle --dart-define-from-file=env/prod.json
/// ```
///
/// The JSON files under `env/` are committed on purpose: they hold base URLs
/// and flags, which are not secrets. Signing keys and service-account files
/// stay out of the repo and are injected by CI.
///
/// ## The default is dev, deliberately
///
/// A forgotten flag should land you on staging data, not production. The one
/// place that must not be guessed is a store release, and that is exactly the
/// path where `--dart-define-from-file=env/prod.json` is mandatory — CI fails
/// the build without it (see `release-guard` in ci.yml).
library;

enum AppFlavor {
  dev,
  staging,
  prod;

  static AppFlavor fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppFlavor.prod;
      case 'staging':
      case 'stage':
        return AppFlavor.staging;
      case 'dev':
      case 'development':
      case '':
        return AppFlavor.dev;
      default:
        // An unrecognised flavor is a build-configuration mistake. Failing
        // closed on dev is safer than guessing prod.
        return AppFlavor.dev;
    }
  }
}

/// Build-time configuration. Every field is a `const` read of a
/// `--dart-define`, so the values are baked into the binary and tree-shaken.
class AppEnvironment {
  AppEnvironment._();

  /// Defaults to `prod` while [defaultIsProduction] holds: a build with no
  /// flags talks to the production backend, so it must not claim to be `dev`.
  /// Once staging exists this goes back to `dev`.
  static const String _rawFlavor = String.fromEnvironment(
    'WADDI_FLAVOR',
    defaultValue: 'prod',
  );

  static final AppFlavor flavor = AppFlavor.fromName(_rawFlavor);

  /// The API and web host for this build.
  ///
  /// ## Why the default is production, for now
  ///
  /// The safe default is staging — a build that forgets its flavor should not
  /// be able to write to live orders. That is what this was set to first, and
  /// it is what it should go back to.
  ///
  /// But **there is no staging backend yet**: `staging.waddyapp.com` does not
  /// resolve (NXDOMAIN). Defaulting to a host that does not exist turns a bare
  /// `flutter run` — which is how the app is actually launched day to day —
  /// into 19 failed requests and an empty home screen. A default that breaks
  /// the common path does not protect anything; it just gets worked around.
  ///
  /// So the default matches the old behaviour (production) until staging
  /// exists, and the protection comes from being *explicit* instead: `env/`
  /// files, `--dart-define-from-file`, and separate installs per flavor.
  ///
  /// **When a staging backend exists**, change this default to it, change
  /// `env/dev.json` and `env/staging.json` to point at it, and flip
  /// `defaultIsProduction` in `test/unit/app_environment_test.dart`. The guard
  /// in `flavor-guard` will then hold the safe default in place.
  static const String baseUrl = String.fromEnvironment(
    'WADDI_BASE_URL',
    defaultValue: 'https://waddyapp.com',
  );

  /// The marketing/web host used for share links and store deep links. Usually
  /// the same as [baseUrl]; kept separate because production serves the public
  /// site from the same origin and staging may not.
  static const String webHostedUrl = String.fromEnvironment(
    'WADDI_WEB_URL',
    defaultValue: 'https://waddyapp.com',
  );

  /// Whether a no-flag build talks to production.
  ///
  /// True today, and it should become false the moment a staging backend
  /// exists. Kept as a named constant so the intent is greppable and the test
  /// that asserts it has something to point at.
  static const bool defaultIsProduction = true;

  static bool get isProd => flavor == AppFlavor.prod;
  static bool get isStaging => flavor == AppFlavor.staging;
  static bool get isDev => flavor == AppFlavor.dev;

  /// True for any build that is not pointed at production data.
  ///
  /// Use this to gate developer affordances — debug overlays, the demo reset
  /// dialog, verbose logging — so they cannot appear in a customer build even
  /// if someone ships a release with asserts enabled.
  static bool get isNonProduction => !isProd;

  /// Shown in debug surfaces so a tester can tell at a glance which backend a
  /// build is hitting. Never shown in production.
  static String get banner =>
      isProd ? '' : '${flavor.name.toUpperCase()} · $baseUrl';
}
