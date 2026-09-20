import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The claw machine's sound, as one object the screen can hand off to.
///
/// ## Why this is not four `AudioPlayer()` calls at the call sites
///
/// The pattern already in this app — `AudioPlayer().play(AssetSource(...))`
/// in `notifiation_popup_dialog_widget` — is fine for a dialog that fires
/// once and is gone. This screen is not that: it plays a 43-second bed, a
/// press sting, and a result sting across a fifteen-second performance the
/// user can leave at any point, including mid-run via SKIP or the back
/// button. Four ad-hoc players would be four things to stop, four things to
/// dispose, and four chances to leave music playing over the screen the user
/// navigated to.
///
/// So: two players with fixed roles. [_bed] loops the ambience and is the
/// only one that is ever long-lived; [_sting] is reused for every one-shot,
/// which also gives the right behaviour for free — a new sting cuts off the
/// previous one rather than layering, because two stings overlapping reads as
/// a glitch rather than as a machine.
///
/// ## Muted by default, and why
///
/// Nothing plays until [enable] is called. A screen that starts a 43-second
/// track the moment it opens is a screen people close in public, and this one
/// is reachable from a push notification — the single most likely moment for
/// someone to open it at a desk or on a bus. The masthead carries a speaker
/// toggle, and pressing RUN THE DRAW also counts as consent, because someone
/// who taps the big button on an arcade cabinet has asked for the arcade.
///
/// ## Every failure here is silent, on purpose
///
/// Audio fails for reasons the user already understands and the app cannot
/// fix: a phone on silent, a codec the device dislikes, another app holding
/// the session, a file that did not ship in the bundle. None of those are
/// worth an error state on a prize draw, and none of them should be able to
/// take the screen down — so every call is guarded and a failure only means
/// the machine is quiet. The haptics are deliberately *not* routed through
/// here: they are a separate channel that still works with the ringer off.
class ClawAudio {
  ClawAudio();

  /// The looping ambience. Long-lived, so it is the one that must be stopped.
  AudioPlayer? _bed;

  /// Every one-shot cue. Reused so a new sting replaces the last.
  AudioPlayer? _sting;

  /// Both players are created on first use, not in the field initialisers.
  ///
  /// `AudioPlayer()`'s constructor kicks off `GlobalAudioScope
  /// .ensureInitialized()`, which completes with an error when the platform
  /// plugin is missing — under `flutter test`, on a device where the audio
  /// session cannot be claimed, or in a widget preview. Because that happens
  /// asynchronously *inside the constructor*, a `try` around the call site
  /// does not catch it: the error surfaces later as an unhandled async
  /// exception and fails whatever is running.
  ///
  /// Constructing lazily, from inside [_guard]'s callback, puts that failure
  /// on a future something is awaiting: the `await bed.play(...)` that follows
  /// carries the initialisation error, and [_guard] catches it there. A screen
  /// built in a test, or on a device that refuses audio, is then simply a
  /// quiet screen rather than a broken one.
  ///
  /// The `try` here is belt-and-braces for a constructor that throws
  /// synchronously; it is [_guard] around the awaited call that catches the
  /// async case, which is the one that actually happens.
  AudioPlayer? _player(bool bed) {
    try {
      if (bed) return _bed ??= AudioPlayer();
      return _sting ??= AudioPlayer();
    } catch (e) {
      debugPrint('ClawAudio: player unavailable: $e');
      return null;
    }
  }

  bool _enabled = false;
  bool _disposed = false;

  /// Whether sound is currently on. The masthead's toggle reads this.
  bool get enabled => _enabled;

  /// Paths are relative to `assets/`, which is what [AssetSource] expects —
  /// passing the full `assets/animation/...` path silently resolves to
  /// nothing.
  /// How loud the ambience sits under everything else. The stings play at 1.
  static const double _bedVolume = 0.10;

  static const String _introAsset = 'animation/intro_game.mp3';
  static const String _startAsset = 'animation/start_game.mp3';
  static const String _winAsset = 'animation/game_win.mp3';
  static const String _loseAsset = 'animation/loser_gana.mp3';

  /// Turns sound on and starts the idle bed.
  ///
  /// Takes [playBed] because the two ways in differ: the speaker toggle on an
  /// idle machine should start the music, but enabling sound *by pressing RUN
  /// THE DRAW* must not — the draw's own sting is about to play and the bed
  /// would start underneath it for the one moment the screen wants a single
  /// clear sound.
  Future<void> enable({bool playBed = true}) async {
    if (_disposed) return;
    _enabled = true;
    if (playBed) await _startBed();
  }

  /// Turns sound off and stops everything already playing.
  Future<void> disable() async {
    _enabled = false;
    await stopAll();
  }

  Future<void> _startBed() async {
    if (!_enabled || _disposed) return;
    await _guard(() async {
      final bed = _player(true);
      if (bed == null) return;
      await bed.setReleaseMode(ReleaseMode.loop);
      // Well under the stings, which play at full.
      //
      // The bed is the room the machine is in, not an event in it. It now
      // runs *under* the whole fifteen-second performance rather than
      // stopping at the press, so it has to sit far enough back that the
      // press and the result still land on top of it rather than competing
      // with it.
      await bed.setVolume(_bedVolume);
      await bed.play(AssetSource(_introAsset));
    });
  }

  /// The press. The bed **keeps playing** underneath it.
  ///
  /// The run is fifteen seconds of claw travel with no sound of its own, and
  /// cutting the music at the press left that stretch silent — the machine
  /// powered down at the exact moment it started working. Holding the bed
  /// under the performance is what makes the run feel scored rather than
  /// merely animated, and the press sting still lands clearly on top of it
  /// because the bed sits well below it — see [_bedVolume].
  ///
  /// The bed is *started* here when it is not already running, which is the
  /// case where sound was off and pressing RUN turned it on: the press is the
  /// consent, so the music begins with the performance it belongs to.
  Future<void> start() async {
    if (!_enabled || _disposed) return;
    await _play(_startAsset, volume: 1);
    if (_bed == null) await _startBed();
  }

  /// The result — and the moment the bed is cut.
  ///
  /// The music runs from the press to here, then stops dead so the win or
  /// loss sting lands in silence. A result arriving over a continuing loop
  /// reads as one more beat in the background; the same sting with the floor
  /// pulled out from under it reads as the machine announcing something.
  ///
  /// The cut comes first and is awaited, so the two never overlap even by a
  /// frame.
  ///
  /// One call for both outcomes, because the screen knows which it is and the
  /// two stings must never both fire — celebrating a loss is the one
  /// unambiguous bug this screen could ship, and it would be audible from the
  /// next room.
  Future<void> result({required bool won}) async {
    await _guard(() async => _bed?.stop());
    await _play(won ? _winAsset : _loseAsset, volume: 1);
  }

  Future<void> _play(String asset, {required double volume}) async {
    if (!_enabled || _disposed) return;
    await _guard(() async {
      final sting = _player(false);
      if (sting == null) return;
      await sting.setVolume(volume);
      await sting.play(AssetSource(asset));
    });
  }

  /// Stops sound without tearing the players down — for leaving the screen
  /// while the widget may still be rebuilt.
  ///
  /// Null-safe on both: a player that was never created has nothing to stop.
  Future<void> stopAll() async {
    await _guard(() async {
      await _bed?.stop();
      await _sting?.stop();
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _enabled = false;
    await _guard(() async {
      await _bed?.dispose();
      await _sting?.dispose();
      _bed = null;
      _sting = null;
    });
  }

  /// Audio is best-effort. A device that refuses to play a file must not be
  /// able to throw into a widget lifecycle or an animation callback, both of
  /// which is where every one of these is called from.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // Visible when debugging a silent machine, invisible in release.
      debugPrint('ClawAudio: $e');
    }
  }
}
