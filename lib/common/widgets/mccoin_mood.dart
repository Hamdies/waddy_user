import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

/// The moods McCoin can wear. Each one is its own artboard inside
/// `waddy_mascot.riv`, so the name here IS the artboard name — keep them in
/// sync.
enum McCoinMood {
  sad('Sad'),
  hi('Hi'),
  upset('Upset'),
  meh('Meh'),
  happy('Happy'),
  cool('Cool'),
  thumbUp('ThumbUp');

  const McCoinMood(this.artboard);

  /// The Rive artboard backing this mood.
  final String artboard;
}

/// McCoin — the brand's coin mascot, rendered as a live Rive animation.
///
/// The file ships one artboard per mood plus a composite `Everything` artboard.
/// We mount the mood artboard DIRECTLY: the moods are fixed poses (the only
/// view model in the file exposes two unrelated triggers, no mood property), so
/// there is nothing to drive from Dart and nothing to gain from the composite.
///
/// Each mood artboard carries its own `Idle` state machine, which is also its
/// default — so it loops on its own with no selector or input pushed from here.
/// See [[rive-014-api]].
///
/// ## Why this isn't just a `SizedBox`
///
/// The artboards are mood-sheet cells, not app assets: each is 600x600 with the
/// character floating in the middle and its own name painted underneath as a
/// caption ("Sad" below the sad coin). Rendered as-is, a user reads a stray
/// label and the character comes out roughly half the requested size. So this
/// scales the character up to fill the slot and clips the surplus away.
class McCoinMoodAnimation extends StatefulWidget {
  const McCoinMoodAnimation({super.key, required this.mood, this.size = 80});

  /// Which face McCoin wears.
  final McCoinMood mood;

  /// Rendered edge length. The CHARACTER is fitted to this box (minus a small
  /// margin) — not the artboard, most of which is empty space and caption.
  final double size;

  @override
  State<McCoinMoodAnimation> createState() => _McCoinMoodAnimationState();
}

class _McCoinMoodAnimationState extends State<McCoinMoodAnimation> {
  static const String _asset = 'assets/animation/waddy_mascot.riv';

  /// Where the character sits within the artboard, as a fraction of its height.
  ///
  /// Measured off a render of the `Sad` artboard: the character occupies
  /// 22.3%-77.5%, and the caption sits well below at 87.1%-90%. The moods are
  /// variations on one pose, so these hold for all of them — and
  /// `mccoin_artboards_test.dart` fails loudly if a re-export changes the
  /// artboard set out from under these numbers.
  static const double _inkTop = 0.223;
  static const double _inkBottom = 0.775;

  /// Breathing room left above and below the character, as a fraction of the
  /// slot. Without it the feet sit flush against the clip edge and read as cut
  /// off rather than framed.
  static const double _pad = 0.06;

  late final rive.FileLoader _fileLoader = rive.FileLoader.fromAsset(
    _asset,
    riveFactory: rive.Factory.rive,
  );

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lay the artboard out in a square box big enough that the character alone
    // spans `size` (less the margin), then slide it up so the character's top
    // edge lands at the margin. `ClipRect` takes the rest — empty space above,
    // caption below.
    //
    // The box stays square because `Fit.contain` on a 600x600 artboard scales
    // by whichever axis binds first; a square box makes that unambiguous.
    const double span = (_inkBottom - _inkTop) / (1 - 2 * _pad);
    final double box = widget.size / span;
    final double shiftY = -(_inkTop - _pad * span) * box;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, shiftY),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: box,
            maxWidth: box,
            minHeight: box,
            maxHeight: box,
            child: rive.RiveWidgetBuilder(
              fileLoader: _fileLoader,
              artboardSelector: rive.ArtboardNamed(widget.mood.artboard),
              onFailed:
                  (error, stackTrace) => debugPrint(
                    'McCoinMoodAnimation failed to load $_asset '
                    '(${widget.mood.artboard}): $error',
                  ),
              builder:
                  (context, state) => switch (state) {
                    rive.RiveLoaded() => rive.RiveWidget(
                      controller: state.controller,
                      fit: rive.Fit.contain,
                    ),
                    _ => const SizedBox.shrink(),
                  },
            ),
          ),
        ),
      ),
    );
  }
}
