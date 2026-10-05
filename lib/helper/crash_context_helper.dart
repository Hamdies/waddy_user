import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:waddy_app/util/app_environment.dart';

/// Attaches context to crash reports.
///
/// ## Why this exists
///
/// Crashlytics was wired — 13 references, plus 14 `swallow(report: true)`
/// sites — but every report arrived anonymous. A crash could not say which
/// flavor produced it, which module the user was in, or whether they were
/// signed in. That turns "3 users affected" into a number nobody can act on:
/// you cannot tell a staging crash from a production one, or a guest-path bug
/// from a signed-in one.
///
/// None of this is personal data. The user id is the account id the backend
/// already issues, which Crashlytics uses only to count distinct affected
/// users; no name, phone or email is attached. On sign-out it is cleared.
///
/// ## Why keys and not log lines
///
/// Custom keys are attached to the crash itself, so the console can group and
/// filter by them. A `log()` line only appears in the breadcrumb trail of the
/// one report you happen to open.
class CrashContext {
  CrashContext._();

  /// Records the build's identity. Call once during `di.init()`.
  ///
  /// The flavor is the one that matters most: without it a staging crash and a
  /// production crash are indistinguishable in the console, and the
  /// crash-free-sessions number covers both.
  static Future<void> recordBuild() async {
    await _set(<String, Object>{
      'flavor': AppEnvironment.flavor.name,
      'backend': AppEnvironment.baseUrl,
    });
  }

  /// Ties subsequent reports to an account.
  ///
  /// Only the id — Crashlytics uses it to count distinct affected users, which
  /// is the difference between "one user hitting this 40 times" and "40 users
  /// hitting it once". Those want different responses.
  static Future<void> setUser(int? userId) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(
        userId?.toString() ?? '',
      );
      await _set(<String, Object>{'signed_in': userId != null});
    } catch (e, s) {
      _ignore(e, s);
    }
  }

  /// Clears the identity on sign-out, so a later crash on a shared device is
  /// not attributed to the previous account.
  static Future<void> clearUser() => setUser(null);

  /// Records which module the user is in.
  ///
  /// Food and grocery share most of the code and diverge in exactly the places
  /// that break — a crash report that does not say which one was active costs
  /// a reproduction attempt.
  static Future<void> setModule(String? moduleType, int? moduleId) async {
    await _set(<String, Object>{
      'module_type': moduleType ?? 'none',
      'module_id': moduleId ?? -1,
    });
  }

  /// Records the screen the user is on, as a breadcrumb.
  ///
  /// Cheap enough to call on every route change, and it turns a stack trace
  /// that bottoms out in framework code into something locatable.
  static Future<void> setRoute(String route) async {
    await _set(<String, Object>{'route': route});
  }

  static Future<void> _set(Map<String, Object> keys) async {
    // Never in debug: a developer's crashes are noise in the same dashboard
    // the release numbers are read from, and M11's target is a release metric.
    if (kDebugMode) return;
    try {
      for (final MapEntry<String, Object> entry in keys.entries) {
        await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value);
      }
    } catch (e, s) {
      _ignore(e, s);
    }
  }

  /// Crash reporting that fails must not become the crash.
  static void _ignore(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[CrashContext] $error');
    }
  }
}
