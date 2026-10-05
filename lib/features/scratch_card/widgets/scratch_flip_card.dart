import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

/// The printed scratch card, drawn: a glossy mint face tiled with the Waddy W,
/// floating gently and (when [flips]) turning over every couple of seconds to
/// show what a card can hold. From the Claude Design "Scratch Card" file.
///
/// Everything inside scales with [width]; the design was drawn at 92 wide.
class ScratchFlipCard extends StatefulWidget {
  final double width;
  final double height;

  /// Turn over to show sample outcomes. Off for cards too small to read.
  final bool flips;

  const ScratchFlipCard({
    super.key,
    required this.width,
    required this.height,
    this.flips = true,
  });

  @override
  State<ScratchFlipCard> createState() => _ScratchFlipCardState();
}

/// A sample of what's under the foil. Illustrative only: the codes are
/// placeholders and no amounts are promised (the prize mix is per batch).
class _Outcome {
  final bool win;
  final String bigKey;
  const _Outcome.win(this.bigKey) : win = true;
  const _Outcome.lose(this.bigKey) : win = false;
}

/// The design's card palette, exactly ("brand" in Scratch Card.dc.html). The
/// face is a touch brighter than [WaddyColors.mint] so the gloss reads.
const Color _faceTop = Color(0xFF2EF5A8);
const Color _faceBottom = Color(0xFF0A7A50);
const Color _edge = Color(0xFF9AF8D3);

const List<_Outcome> _outcomes = [
  _Outcome.win('scratch_back_free_delivery'),
  _Outcome.lose('scratch_back_better_luck'),
  _Outcome.win('scratch_back_discount'),
];

class _ScratchFlipCardState extends State<ScratchFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  Timer? _flipTimer;

  /// Half-turns so far: odd shows the back.
  int _turns = 0;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still == _still && (_float.isAnimating || still)) return;
    _still = still;
    _flipTimer?.cancel();
    if (still) {
      _float.stop();
      return;
    }
    _float.repeat();
    if (widget.flips) {
      _flipTimer = Timer.periodic(
        const Duration(milliseconds: 2200),
        (_) => setState(() => _turns++),
      );
    }
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double k = widget.width / 92;
    final _Outcome outcome =
        _outcomes[math.max(0, (_turns - 1) ~/ 2) % _outcomes.length];

    final Widget flipping = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _turns * math.pi),
      duration: const Duration(milliseconds: 800),
      curve: const Cubic(0.45, 0.05, 0.2, 1),
      builder: (context, angle, _) {
        final bool back = math.cos(angle) < 0;
        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 1 / (420 * k))
                ..rotateY(angle),
          child:
              back
                  ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _Face(k: k, child: _Back(k: k, outcome: outcome)),
                  )
                  : _Face(k: k, child: _Front(k: k)),
        );
      },
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _float,
        child: flipping,
        builder: (context, child) {
          // 0 → 1 → 0 over a loop, eased like CSS ease-in-out.
          final double v = (1 - math.cos(2 * math.pi * _float.value)) / 2;
          return Transform.translate(
            offset: Offset(0, -4 * v),
            child: Transform.rotate(
              angle: (-7 + 2 * v) * math.pi / 180,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// The card's outline, shared by both sides.
class _Face extends StatelessWidget {
  final double k;
  final Widget child;
  const _Face({required this.k, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: _edge, width: 1.5 * k),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.ink.withValues(alpha: 0.25),
            blurRadius: 14 * k,
            offset: Offset(0, 6 * k),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Front extends StatelessWidget {
  final double k;
  const _Front({required this.k});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        // CSS 160deg: down and a little to the right.
        gradient: LinearGradient(
          begin: Alignment(-0.36, -1),
          end: Alignment(0.36, 1),
          colors: [_faceTop, _faceBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Pattern(k: k),
          // Gloss from the top corner.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                stops: [0, 0.42],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Waddy W (assets/image/waddy.png) tiled across the face, tilted, faint.
class _Pattern extends StatelessWidget {
  final double k;
  const _Pattern({required this.k});

  @override
  Widget build(BuildContext context) {
    final double cell = 26 * k;
    return LayoutBuilder(
      builder: (context, box) {
        // Oversized so the tilt never shows a bare corner.
        final double w = box.maxWidth * 1.4, h = box.maxHeight * 1.4;
        final int cols = (w / cell).ceil(), rows = (h / cell).ceil();
        return OverflowBox(
          maxWidth: w,
          maxHeight: h,
          child: Transform.rotate(
            angle: -8 * math.pi / 180,
            child: Opacity(
              opacity: 0.28,
              child: Wrap(
                children: [
                  for (int i = 0; i < cols * rows; i++)
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: Center(
                        child: Image.asset(
                          Images.waddyLogo,
                          width: cell * 0.55,
                          // Deep teal at 28 %: reads as a darker mint
                          // watermark, as in the design.
                          color: WaddyColors.primary,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Back extends StatelessWidget {
  final double k;
  final _Outcome outcome;
  const _Back({required this.k, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final List<Widget> lines =
        outcome.win
            ? [
              Text(
                'scratch_back_you_won'.tr,
                style: waddyBold.copyWith(
                  fontSize: 8 * k,
                  fontWeight: FontWeight.w900,
                  color: WaddyColors.mintInk,
                ),
              ),
              Text(
                outcome.bigKey.tr,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 13 * k,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  color: WaddyColors.primary,
                ),
              ),
              CustomPaint(
                painter: _DashedBorder(radius: 5 * k, width: k),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5 * k,
                    vertical: 2 * k,
                  ),
                  child: Text(
                    'XXXX-XXXX',
                    textDirection: TextDirection.ltr,
                    style: waddyBold.copyWith(
                      fontSize: 7.5 * k,
                      letterSpacing: 0.45 * k,
                      color: WaddyColors.mintInk,
                    ),
                  ),
                ),
              ),
              Text(
                'scratch_back_use_before'.tr,
                style: waddyMedium.copyWith(
                  fontSize: 6.5 * k,
                  color: WaddyColors.inkLight,
                ),
              ),
            ]
            : [
              Text(
                outcome.bigKey.tr,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 12 * k,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: WaddyColors.inkMid,
                ),
              ),
              Text(
                'scratch_back_next_one'.tr,
                style: waddyBold.copyWith(
                  fontSize: 7.5 * k,
                  color: WaddyColors.inkLight,
                ),
              ),
            ];

    return ColoredBox(
      color: outcome.win ? WaddyColors.surface : WaddyColors.surfaceWarm,
      child: Padding(
        padding: EdgeInsets.all(6 * k),
        // Card composition is fixed: the text must not grow with the
        // system text size and push out of the card.
        child: MediaQuery.withNoTextScaling(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < lines.length; i++) ...[
                  if (i > 0) SizedBox(height: 4 * k),
                  lines[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final double radius;
  final double width;
  const _DashedBorder({required this.radius, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = WaddyColors.mintInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = width;
    final Path outline =
        Path()..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        );
    final double dash = 3 * width, gap = 2 * width;
    for (final PathMetric metric in outline.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.radius != radius || old.width != width;
}
