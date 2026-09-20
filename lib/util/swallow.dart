import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Deliberately ignoring a failure — with the reason recorded.
///
/// ## Why this exists
///
/// There were 50 bare `catch (_) {}` blocks. Some were correct: an analytics
/// call must never break a checkout, and a best-effort cleanup of a temp file
/// has nothing useful to do on failure. Others were not, and one of them is
/// documented in `location_controller.dart`: *"a bare `catch (_) {}` here hid a
/// hanging zone lookup for a long time"*.
///
/// The problem with `catch (_) {}` is that those two cases look identical. A
/// reader cannot tell whether the silence is a considered decision or an
/// oversight, and neither can a reviewer.
///
/// [swallow] makes the decision explicit and leaves a trail:
///
/// ```dart
/// try {
///   await file.delete();
/// } catch (e, s) {
///   swallow('temp recording cleanup', e, s);
/// }
/// ```
///
/// In debug it prints. In release it is silent unless [report] is set, in which
/// case it reaches Crashlytics as a **non-fatal** — visible in the dashboard,
/// invisible to the user.
///
/// ## When to use which
///
/// - **`swallow(reason, e, s)`** — the failure genuinely does not matter to the
///   user or to correctness. Telemetry, analytics, cosmetic fallbacks, cleanup
///   of something already unreachable.
/// - **`swallow(reason, e, s, report: true)`** — the flow can continue, but the
///   failure means something is wrong and you want to know how often. A cache
///   write that failed, a permission probe that threw, an acknowledge call the
///   server rejected.
/// - **Neither** — if the user's next action depends on it, do not swallow.
///   Surface it. A silent failure that changes what the user gets is a bug,
///   and that is the case `catch (_) {}` was hiding.
void swallow(
  String reason,
  Object error, [
  StackTrace? stack,
  bool report = false,
]) {
  if (kDebugMode) {
    debugPrint('[swallowed] $reason: $error');
  }
  if (report) {
    // Fire-and-forget, and itself swallowed: a telemetry failure must not
    // become the exception that escapes the handler it was called from.
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (_) {
      // Nothing left to do — Crashlytics is the thing that reports failures.
    }
  }
}
