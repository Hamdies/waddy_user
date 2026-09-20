import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// "THE CLAW" masthead — eyebrow, wordmark, LIVE pill.
///
/// Deliberately not [SpotsMasthead]: that one carries the app's zone filter
/// and "My prizes" badge and belongs to the Spots home. This screen is a
/// single event with a back button, and reusing the home's chrome would offer
/// a zone switcher on a screen where zone means nothing.
class ClawMasthead extends StatefulWidget {
  const ClawMasthead({
    super.key,
    required this.eyebrow,
    this.live = true,
    this.onBack,
    this.soundOn = false,
    this.onToggleSound,
  });

  /// "Maadi · Week 27 · Voter draw" — built by the screen from the payload,
  /// because only it knows the zone and period.
  final String eyebrow;

  /// The LIVE pill shows only while the draw is unwatched. Once the result is
  /// on screen the round is over and "LIVE" would be a lie.
  final bool live;

  /// Leaves the screen. Null only where there is genuinely nowhere to go back
  /// to — the screen decides, because it is the thing that knows whether the
  /// navigator can pop.
  ///
  /// This screen is reachable from a push notification, and until this existed
  /// it had no exit at all: no app bar, no `PopScope`, nothing. On Android the
  /// hardware back saved it; on iOS, arriving from a notification with no
  /// stack to swipe through, the user was simply stuck.
  final VoidCallback? onBack;

  /// Whether the machine's sound is currently on.
  final bool soundOn;

  /// Turns the machine's sound on and off. Null hides the control entirely —
  /// there is no point offering a speaker on a screen that has nothing to
  /// play.
  final VoidCallback? onToggleSound;

  @override
  State<ClawMasthead> createState() => _ClawMastheadState();
}

class _ClawMastheadState extends State<ClawMasthead>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations || !widget.live) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ClawMasthead old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      widget.live ? _pulse.repeat(reverse: true) : _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // The Spots masthead: a deep-teal panel closed by a drawn teal rule.
      //
      // This sat in ink on the bare page, on the reasoning that a dark header
      // would compete with the cabinet. It does not — every other Spots screen
      // opens with this exact block (see `SpotsMasthead`), so on this screen
      // alone the app appeared to lose its header. The competition worry is
      // real but it is answered by *hierarchy*, not by deleting the panel: the
      // masthead is a flat 8pt-tall bar with no shadow, and the cabinet below
      // it is a shadowed object with a mint brow. They do not read alike.
      decoration: const BoxDecoration(
        color: Spots.panel,
        border: Border(
          bottom: BorderSide(color: Spots.border, width: Spots.borderThick),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spots.gutter,
        Spots.s8,
        Spots.gutter,
        Spots.s8,
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            _BackPlate(onTap: widget.onBack!),
            const SizedBox(width: Spots.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayCaps(widget.eyebrow),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Spots.kicker(
                    9,
                    color: Spots.mint.withValues(alpha: 0.75),
                    tracking: 0.24,
                  ),
                ),
                const SizedBox(height: Spots.s4),
                // The wordmark cannot wrap and cannot shrink the layout, so at
                // a large text scale it scales down instead of clipping. This
                // is the `white-space: nowrap` the design relies on, made safe.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'spots_claw_title'.tr,
                    maxLines: 1,
                    style: Spots.display(
                      20,
                      color: Colors.white,
                      tracking: -0.02,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onToggleSound != null) ...[
            const SizedBox(width: Spots.s8),
            _SoundPlate(on: widget.soundOn, onTap: widget.onToggleSound!),
          ],
          if (widget.live) ...[
            const SizedBox(width: Spots.s8),
            _LivePill(pulse: _pulse),
          ],
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    // On the teal masthead the pill can no longer be a dark capsule — it
    // would vanish into the panel. It becomes what a live badge is everywhere
    // else in Spots: a red plate with a drawn teal border and a hard offset,
    // at [Spots.radiusPill], which in this system is boxy rather than oval.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spots.s8, vertical: 5),
      decoration: Spots.card(
        fill: Spots.red,
        radius: Spots.radiusPill,
        borderWidth: Spots.borderThin,
        dx: 2,
        dy: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.2).animate(pulse),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                // White on the red plate. The lamp used to be coral on dark,
                // chosen so it would not read as an alarm; now that the plate
                // itself carries [Spots.red] — the system's own live/urgent
                // colour — the dot only has to be the blinking element on it.
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayCaps('spots_live'.tr),
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: Spots.kicker(9, color: Colors.white, tracking: 0.18),
          ),
        ],
      ),
    );
  }
}

/// The back control — a mint-outlined plate on the dark masthead.
///
/// Paper-on-teal is the pattern the rest of Spots uses (see
/// `spots_prize_details_screen`), but that one sits over a *photo*. Here the
/// plate lands on the panel itself, where a solid white box would punch a hole
/// in the masthead. A mint hairline on panel keeps the block continuous, gives
/// the chevron the accent colour every other Spots control on a dark panel
/// uses, and still clears contrast against the fill.
/// The speaker toggle — the machine's sound, on or off.
///
/// ## Why the sound starts off
///
/// This screen is reachable from a push notification, which is the single
/// most likely moment for someone to open it at a desk, on a bus, or in bed
/// beside someone asleep. A 43-second music bed starting unbidden is how an
/// app gets closed in one second flat, so nothing plays until this is pressed
/// or the user presses RUN THE DRAW — the latter counting as consent, because
/// pressing the big button on an arcade cabinet is asking for the arcade.
///
/// Built to match [_BackPlate] exactly: same tap target, same outlined mint
/// chrome. The two are the only controls in the masthead and a speaker that
/// looked different from the back button would read as content rather than
/// chrome.
class _SoundPlate extends StatelessWidget {
  const _SoundPlate({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // The label states what the control *does next*, not what it currently
      // is: "sound off" on a button that turns sound off is the ambiguity
      // screen-reader users have to tap to resolve.
      label: (on ? 'spots_claw_sound_off' : 'spots_claw_sound_on').tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: Dimensions.minTapTarget,
          height: Dimensions.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Filled once sound is on, so the state is legible at a glance
            // rather than needing the icon to be read. Off is the same
            // outlined chrome as the back plate.
            color: on ? Spots.mint.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(Spots.radiusMd),
            border: Border.all(
              color: Spots.mint.withValues(alpha: on ? 0.85 : 0.5),
              width: Spots.borderThin,
            ),
          ),
          child: Icon(
            on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: 20,
            color: Spots.mint.withValues(alpha: on ? 1 : 0.75),
          ),
        ),
      ),
    );
  }
}

class _BackPlate extends StatelessWidget {
  const _BackPlate({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'back'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // This is the only way off the screen, so it takes the higher of the
          // two platform floors rather than the lower: 44 is the iOS minimum,
          // 48 is Material's, and the control ships on both.
          width: Dimensions.minTapTarget,
          height: Dimensions.minTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Outlined rather than filled: the back control is navigation
            // chrome, and a solid plate would carry more weight than the
            // wordmark beside it.
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Spots.radiusMd),
            border: Border.all(
              color: Spots.mint.withValues(alpha: 0.5),
              width: Spots.borderThin,
            ),
          ),
          child: Icon(
            // Mirrors in RTL: "back" is a reading-direction idea, unlike the
            // shadows, which stay physically down-right.
            Directionality.of(context) == TextDirection.ltr
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 24,
            color: Spots.mint,
          ),
        ),
      ),
    );
  }
}
