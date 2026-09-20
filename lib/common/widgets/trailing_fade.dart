import 'package:flutter/material.dart';

/// Softens the trailing edge of a rail so the partially-visible card reads as
/// "there is more" rather than as a rendering fault.
///
/// The peek is deliberate — a sliver of the next card is what tells the eye a
/// rail scrolls. But the viewport cuts everything at the same hard vertical
/// line, and while a hard cut through a *photo* reads as continuation, the
/// identical cut through a word ("Krispy", "2.3 k") reads as text that failed
/// to fit. Same geometry, opposite message. The fade only has to cover the
/// text columns, so it is narrow enough to leave the photo peek intact.
///
/// Shared by the restaurant chart and the grocery shelf. It lived private to
/// the chart first, which is why the shelf spent a while hard-cutting
/// "Metro M…" at the screen edge while the rail directly above it faded
/// cleanly — two rails on one screen disagreeing about what an edge means.
class TrailingFade extends StatelessWidget {
  final Widget child;
  const TrailingFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    return ShaderMask(
      // dstIn keeps the child wherever the gradient is opaque and erases it
      // where the gradient is clear.
      blendMode: BlendMode.dstIn,
      shaderCallback:
          (Rect bounds) => LinearGradient(
            // Mirrored under RTL: the trailing edge is the left one there, and a
            // fade pinned to the physical right would soften the edge the user
            // starts reading from.
            begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            // Opaque until the last few points, then out. Starting the ramp any
            // earlier dims content the user is still meant to read.
            colors: const [Colors.white, Colors.white, Colors.transparent],
            stops: const [0.0, 0.94, 1.0],
          ).createShader(bounds),
      child: child,
    );
  }
}
