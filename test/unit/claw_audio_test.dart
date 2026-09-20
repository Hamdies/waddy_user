import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/claw_audio.dart';

/// Audio is the one part of this screen that talks to a platform plugin, and
/// the plugin is absent in tests, in widget previews, and on any device that
/// will not hand over an audio session.
///
/// The failure mode being guarded here is specific and was real: constructing
/// `AudioPlayer()` in a field initialiser starts `ensureInitialized()`, which
/// completes *with an error* when the plugin is missing. Nothing awaits that
/// future, so it surfaces as an unhandled async exception and fails whatever
/// happens to be running — not at the call site, and not with a useful stack.
///
/// So the contract this locks in is simply: a machine with no working audio
/// is a quiet machine. Every method is safe to call, in any order, and none
/// of them can take the screen down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts muted', () {
    expect(ClawAudio().enabled, isFalse);
  });

  test('every call is safe with no platform plugin', () async {
    final audio = ClawAudio();

    // Cues before enabling are no-ops rather than errors.
    await audio.start();
    await audio.result(won: true);

    await audio.enable();
    expect(audio.enabled, isTrue);

    await audio.start();
    await audio.result(won: true);
    await audio.result(won: false);
    await audio.stopAll();

    await audio.disable();
    expect(audio.enabled, isFalse);

    await audio.dispose();
  });

  test('enable(playBed: false) still turns sound on', () async {
    // The path taken when RUN THE DRAW is what enables sound: the press sting
    // must play, but the 43s bed must not start underneath it.
    final audio = ClawAudio();
    await audio.enable(playBed: false);
    expect(audio.enabled, isTrue);
    await audio.dispose();
  });

  test('a disposed player stays off', () async {
    // `dispose` is fire-and-forget from `State.dispose`, so a late callback
    // can land after it. Re-enabling then would claim an audio session for a
    // screen that no longer exists.
    final audio = ClawAudio();
    await audio.enable();
    await audio.dispose();

    await audio.enable();
    expect(audio.enabled, isFalse);

    await audio.start();
    await audio.result(won: true);
    expect(audio.enabled, isFalse);
  });
}
