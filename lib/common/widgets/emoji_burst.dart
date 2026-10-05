import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A one-shot puff of emoji rising from a point: each one pops in, drifts
/// up and sideways with a little wobble, and fades. Drawn in the root
/// overlay so it can float past the widget that launched it; removes
/// itself when done and never takes a tap. Skipped when the system asks
/// for reduced motion.
class EmojiBurst extends StatefulWidget {
  final List<String> emojis;
  final Offset origin;
  final VoidCallback onDone;

  const EmojiBurst({
    super.key,
    required this.emojis,
    required this.origin,
    required this.onDone,
  });

  /// Bursts [emojis] from the centre of [anchor]'s render box.
  static void fromWidget(BuildContext anchor, List<String> emojis) {
    if (emojis.isEmpty) return;
    if (MediaQuery.maybeDisableAnimationsOf(anchor) ?? false) return;
    final RenderObject? box = anchor.findRenderObject();
    final OverlayState? overlay = Overlay.maybeOf(anchor, rootOverlay: true);
    if (box is! RenderBox || !box.hasSize || overlay == null) return;
    final Offset origin = box.localToGlobal(box.size.center(Offset.zero));
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => IgnorePointer(
            child: EmojiBurst(
              emojis: emojis,
              origin: origin,
              onDone: () => entry.remove(),
            ),
          ),
    );
    overlay.insert(entry);
  }

  @override
  State<EmojiBurst> createState() => _EmojiBurstState();
}

class _EmojiBurstState extends State<EmojiBurst>
    with SingleTickerProviderStateMixin {
  static const int _count = 9;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward().whenComplete(widget.onDone);

  // A fresh scatter every tap, so picking again doesn't replay the same
  // shape.
  late final List<_Puff> _puffs = () {
    final math.Random rnd = math.Random();
    return List.generate(
      _count,
      (i) => _Puff(
        emoji: widget.emojis[i % widget.emojis.length],
        dx: (rnd.nextDouble() - 0.5) * 180,
        rise: 140 + rnd.nextDouble() * 160,
        size: 22 + rnd.nextDouble() * 14,
        tilt: (rnd.nextDouble() - 0.5) * 0.9,
        delay: rnd.nextDouble() * 0.18,
      ),
    );
  }();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (_, __) => Stack(
            children: [
              for (final _Puff p in _puffs) _puff(p, _controller.value),
            ],
          ),
    );
  }

  Widget _puff(_Puff p, double t) {
    final double local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    // Fast launch, soft float.
    final double e = 1 - math.pow(1 - local, 3).toDouble();
    // Pop: overshoots to 1.2 in the first fifth, settles to 1.
    final double pop =
        local < 0.2
            ? Curves.easeOutBack.transform(local / 0.2) * 1.2
            : 1.2 - 0.2 * ((local - 0.2) / 0.8);
    final double opacity = local < 0.6 ? 1 : 1 - (local - 0.6) / 0.4;
    final double wobble = math.sin(local * math.pi * 3) * 0.12;

    return Positioned(
      left: widget.origin.dx + p.dx * e - p.size / 2,
      top: widget.origin.dy - p.rise * e - p.size / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: p.tilt * e + wobble,
          child: Transform.scale(
            scale: pop,
            child: Text(
              p.emoji,
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: p.size, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _Puff {
  final String emoji;
  final double dx, rise, size, tilt, delay;

  const _Puff({
    required this.emoji,
    required this.dx,
    required this.rise,
    required this.size,
    required this.tilt,
    required this.delay,
  });
}
