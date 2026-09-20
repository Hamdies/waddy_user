import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';

/// ─── Spots marks ────────────────────────────────────────────────────────────
/// Hand-built glyphs for the Spots system: a crown, a flame, a trophy, a bolt
/// and a map pin, drawn as flat vector paths.
///
/// These replace the emoji that used to sit in badges and stickers. Emoji are
/// a foreign visual system — they render as full-colour, rounded, vendor-drawn
/// artwork that ignores this design's palette, its hard geometry and its 2–3px
/// teal stroke, and they re-draw themselves differently on every OS. A flat
/// path in `Spots.teal` / `Spots.mint` sits *inside* the design instead of on
/// top of it, scales cleanly, and stays identical on every device.

enum SpotsMark { crown, flame, trophy, bolt, pin, star, rising }

class SpotsGlyph extends StatelessWidget {
  const SpotsGlyph(
    this.mark, {
    super.key,
    this.size = 14,
    this.color = Spots.teal,
  });

  final SpotsMark mark;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(mark, color)),
    );
  }
}

/// A live Rive diamond, sized like [SpotsGlyph], for "weekly champion" marks
/// (repeat title-holders) where the win deserves more than a flat vector.
class SpotsDiamondGlyph extends StatefulWidget {
  const SpotsDiamondGlyph({super.key, this.size = 14});

  final double size;

  @override
  State<SpotsDiamondGlyph> createState() => _SpotsDiamondGlyphState();
}

class _SpotsDiamondGlyphState extends State<SpotsDiamondGlyph> {
  static const String _asset = 'assets/animation/diamond.riv';

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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: rive.RiveWidgetBuilder(
        fileLoader: _fileLoader,
        onFailed:
            (error, stackTrace) =>
                debugPrint('SpotsDiamondGlyph failed to load $_asset: $error'),
        builder:
            (context, state) => switch (state) {
              rive.RiveLoaded() => rive.RiveWidget(
                controller: state.controller,
                fit: rive.Fit.contain,
              ),
              _ => const SizedBox.shrink(),
            },
      ),
    );
  }
}

/// A live Rive trophy (Artboard 4 of the shared stickers sheet), sized like
/// [SpotsGlyph], for empty/celebratory states where the flat vector trophy
/// isn't expressive enough (e.g. "the crown is wide open").
class SpotsTrophyGlyph extends StatefulWidget {
  const SpotsTrophyGlyph({super.key, this.size = 14});

  final double size;

  @override
  State<SpotsTrophyGlyph> createState() => _SpotsTrophyGlyphState();
}

class _SpotsTrophyGlyphState extends State<SpotsTrophyGlyph> {
  static const String _asset = 'assets/animation/stickers.riv';

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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: rive.RiveWidgetBuilder(
        fileLoader: _fileLoader,
        artboardSelector: const rive.ArtboardNamed('Artboard 4'),
        onFailed:
            (error, stackTrace) =>
                debugPrint('SpotsTrophyGlyph failed to load $_asset: $error'),
        builder:
            (context, state) => switch (state) {
              rive.RiveLoaded() => rive.RiveWidget(
                controller: state.controller,
                fit: rive.Fit.contain,
              ),
              _ => const SizedBox.shrink(),
            },
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark, this.color);

  final SpotsMark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint fill =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

    switch (mark) {
      case SpotsMark.crown:
        // Five-point crown: three peaks, two valleys, a solid band beneath.
        final p =
            Path()
              ..moveTo(w * 0.04, h * 0.30)
              ..lineTo(w * 0.26, h * 0.56)
              ..lineTo(w * 0.50, h * 0.20)
              ..lineTo(w * 0.74, h * 0.56)
              ..lineTo(w * 0.96, h * 0.30)
              ..lineTo(w * 0.88, h * 0.76)
              ..lineTo(w * 0.12, h * 0.76)
              ..close();
        canvas.drawPath(p, fill);
        // Band — a separate bar reads as a crown even at 10px.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.82, w * 0.76, h * 0.13),
            Radius.circular(w * 0.04),
          ),
          fill,
        );

      case SpotsMark.flame:
        // Teardrop flame with an inner notch at the base.
        final p =
            Path()
              ..moveTo(w * 0.50, h * 0.04)
              ..cubicTo(
                w * 0.86,
                h * 0.34,
                w * 0.92,
                h * 0.56,
                w * 0.80,
                h * 0.74,
              )
              ..cubicTo(
                w * 0.70,
                h * 0.92,
                w * 0.30,
                h * 0.96,
                w * 0.19,
                h * 0.76,
              )
              ..cubicTo(
                w * 0.08,
                h * 0.56,
                w * 0.22,
                h * 0.34,
                w * 0.42,
                h * 0.20,
              )
              ..cubicTo(
                w * 0.40,
                h * 0.40,
                w * 0.46,
                h * 0.48,
                w * 0.56,
                h * 0.42,
              )
              ..cubicTo(
                w * 0.58,
                h * 0.26,
                w * 0.54,
                h * 0.14,
                w * 0.50,
                h * 0.04,
              )
              ..close();
        canvas.drawPath(p, fill);

      case SpotsMark.trophy:
        // Cup + stem + base, with two side handles. The cup is deliberately
        // wide and the stem short: at 11px in a sticker a slender trophy just
        // reads as a smudge, so mass beats fidelity here.
        final cup =
            Path()
              ..moveTo(w * 0.20, h * 0.08)
              ..lineTo(w * 0.80, h * 0.08)
              ..lineTo(w * 0.75, h * 0.42)
              ..cubicTo(
                w * 0.70,
                h * 0.62,
                w * 0.30,
                h * 0.62,
                w * 0.25,
                h * 0.42,
              )
              ..close();
        canvas.drawPath(cup, fill);
        final Paint stroke =
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.11
              ..isAntiAlias = true;
        // Handles — arcs springing off each side of the cup rim.
        canvas.drawArc(
          Rect.fromLTWH(w * 0.01, h * 0.10, w * 0.26, h * 0.32),
          -1.1,
          2.5,
          false,
          stroke,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * 0.73, h * 0.10, w * 0.26, h * 0.32),
          -2.0,
          -2.5,
          false,
          stroke,
        );
        // Stem + base.
        canvas.drawRect(
          Rect.fromLTWH(w * 0.42, h * 0.58, w * 0.16, h * 0.18),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.20, h * 0.78, w * 0.60, h * 0.16),
            Radius.circular(w * 0.05),
          ),
          fill,
        );

      case SpotsMark.bolt:
        final p =
            Path()
              ..moveTo(w * 0.56, h * 0.02)
              ..lineTo(w * 0.16, h * 0.56)
              ..lineTo(w * 0.44, h * 0.56)
              ..lineTo(w * 0.38, h * 0.98)
              ..lineTo(w * 0.84, h * 0.42)
              ..lineTo(w * 0.54, h * 0.42)
              ..close();
        canvas.drawPath(p, fill);

      case SpotsMark.star:
        // Five-point star, drawn from unit-circle points.
        final Path p = Path();
        const int points = 5;
        final double cx = w / 2, cy = h * 0.52;
        final double rOuter = w * 0.48, rInner = w * 0.20;
        for (int i = 0; i < points * 2; i++) {
          final double r = i.isEven ? rOuter : rInner;
          final double a = -1.5707963 + i * 3.1415926 / points;
          final double x = cx + r * math.cos(a);
          final double y = cy + r * math.sin(a);
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        p.close();
        canvas.drawPath(p, fill);

      case SpotsMark.rising:
        // An upward trend arrow — the "on the board" mark.
        final Paint stroke =
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.13
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..isAntiAlias = true;
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.08, h * 0.76)
            ..lineTo(w * 0.38, h * 0.44)
            ..lineTo(w * 0.58, h * 0.62)
            ..lineTo(w * 0.92, h * 0.24),
          stroke,
        );
        // Arrow head at the top-right terminal.
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.96, h * 0.20)
            ..lineTo(w * 0.62, h * 0.22)
            ..lineTo(w * 0.94, h * 0.54)
            ..close(),
          fill,
        );

      case SpotsMark.pin:
        final p =
            Path()
              ..moveTo(w * 0.50, h * 0.98)
              ..cubicTo(
                w * 0.14,
                h * 0.58,
                w * 0.10,
                h * 0.40,
                w * 0.20,
                h * 0.24,
              )
              ..cubicTo(
                w * 0.34,
                h * 0.02,
                w * 0.66,
                h * 0.02,
                w * 0.80,
                h * 0.24,
              )
              ..cubicTo(
                w * 0.90,
                h * 0.40,
                w * 0.86,
                h * 0.58,
                w * 0.50,
                h * 0.98,
              )
              ..close();
        // Punched-out centre, so the pin reads at small sizes. The hole is cut
        // with an even-odd fill rather than BlendMode.clear, which would need
        // its own saveLayer and would erase whatever sits behind the glyph.
        p.addOval(
          Rect.fromCircle(center: Offset(w * 0.50, h * 0.36), radius: w * 0.15),
        );
        p.fillType = PathFillType.evenOdd;
        canvas.drawPath(p, fill);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}

/// ─── Sticker ────────────────────────────────────────────────────────────────
/// The loud little label that hangs off a card corner ("LIVE LEADER",
/// "CURRENT CHAMPION", "5× WEEKLY CROWN").
///
/// Three things make it read as a *sticker* rather than a chip:
///  1. a real tilt — stickers are slapped on, never perfectly square;
///  2. a double-drop shadow (a mint/red under-plate peeking out past the teal
///     one) which fakes a thick die-cut edge in a system with no blur;
///  3. an optional breathing pulse for genuinely live state.
///
/// The tilt mirrors in RTL so the sticker always leans away from the card's
/// nearest corner instead of into it.
class SpotsSticker extends StatefulWidget {
  const SpotsSticker({
    super.key,
    required this.label,
    this.mark,
    this.markWidget,
    this.fill = Spots.red,
    this.fg = Colors.white,
    this.underlay,
    this.tilt = -0.045,
    this.live = false,
    this.fontSize = 11,
  });

  final String label;
  final SpotsMark? mark;

  /// Overrides [mark] with a custom widget (e.g. [SpotsDiamondGlyph]) when a
  /// flat vector glyph isn't expressive enough for what's being marked.
  final Widget? markWidget;
  final Color fill;
  final Color fg;

  /// The die-cut edge colour peeking under the teal shadow. Defaults to a
  /// lightened [fill] so every sticker gets the effect for free.
  final Color? underlay;
  final double tilt;
  final bool live;
  final double fontSize;

  @override
  State<SpotsSticker> createState() => _SpotsStickerState();
}

class _SpotsStickerState extends State<SpotsSticker>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool wants = widget.live && !MediaQuery.of(context).disableAnimations;
    if (wants && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat(reverse: true);
    } else if (!wants) {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Color under =
        widget.underlay ??
        Color.alphaBlend(Colors.white.withValues(alpha: 0.45), widget.fill);

    Widget body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.fontSize * 0.72,
        vertical: widget.fontSize * 0.38,
      ),
      decoration: BoxDecoration(
        color: widget.fill,
        border: Border.all(color: Spots.border, width: Spots.borderThin),
        borderRadius: BorderRadius.circular(Spots.radiusPill),
        boxShadow: [
          // Die-cut edge first, then the hard teal drop over it.
          BoxShadow(color: under, offset: const Offset(2, 2), blurRadius: 0),
          const BoxShadow(
            color: Spots.border,
            offset: Offset(3.5, 3.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.markWidget != null) ...[
            SizedBox(
              width: widget.fontSize * 1.05,
              height: widget.fontSize * 1.05,
              child: widget.markWidget,
            ),
            SizedBox(width: widget.fontSize * 0.42),
          ] else if (widget.mark != null) ...[
            SpotsGlyph(
              widget.mark!,
              size: widget.fontSize * 1.05,
              color: widget.fg,
            ),
            SizedBox(width: widget.fontSize * 0.42),
          ],
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Spots.kicker(
              widget.fontSize,
              color: widget.fg,
              tracking: 0.04,
            ).copyWith(height: 1),
          ),
        ],
      ),
    );

    if (_pulse != null) {
      body = AnimatedBuilder(
        animation: _pulse!,
        builder: (context, child) {
          final double t = Curves.easeInOut.transform(_pulse!.value);
          return Transform.scale(scale: 1 + t * 0.035, child: child);
        },
        child: body,
      );
    }

    return Transform.rotate(
      angle: rtl ? -widget.tilt : widget.tilt,
      child: body,
    );
  }
}
