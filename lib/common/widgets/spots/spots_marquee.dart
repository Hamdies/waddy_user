import 'package:flutter/material.dart';

/// Seamlessly-looping text marquee.
///
/// Measures the run once per text/style/scale change with a [TextPainter],
/// lays out two copies inside an [OverflowBox] so it never overflows its slot,
/// and slides in the reading direction by `t * (width + gap)` so the second
/// copy takes over exactly as the first exits.
///
/// Extracted from `live_news_bar.dart` for `CLAW-06`. The claw draw's ticker
/// needs the same behaviour, and the three things this already gets right —
/// RTL direction, the faded edge, and the short-run guard — are precisely the
/// things a second implementation would get wrong first. The source design
/// duplicates its content and translates `-50%`; that is the same trick, but
/// this version also handles the cases CSS never had to.
///
/// The caller owns the [AnimationController] so it can stop it under reduced
/// motion, and off-screen, without this widget knowing why.
class SpotsMarquee extends StatefulWidget {
  const SpotsMarquee({
    super.key,
    required this.controller,
    required this.text,
    required this.style,
    this.gap = 40,
  });

  final AnimationController controller;
  final String text;
  final TextStyle style;

  /// Blank space between the two copies, in logical pixels.
  final double gap;

  @override
  State<SpotsMarquee> createState() => _SpotsMarqueeState();
}

class _SpotsMarqueeState extends State<SpotsMarquee> {
  double _width = 0;
  double _height = 16;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(SpotsMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _measure();
    }
  }

  void _measure() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    _width = tp.width;
    _height = tp.height;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      style: widget.style,
    );

    // A run that already fits its slot must not scroll. Two copies separated by
    // `gap` are laid out unconditionally, so on a short run the second copy is
    // inside the visible slot from the first frame — it reads as text bleeding
    // under the adjacent element, not as motion. Motion here is meant to carry
    // overflow; with nothing to overflow there is nothing for it to carry.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width <= constraints.maxWidth) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return _buildMarquee(rtl, label);
      },
    );
  }

  Widget _buildMarquee(bool rtl, Widget label) {
    // A marquee cut dead-flat at the panel edge reads as a text-overflow bug,
    // not as motion. Fading both edges makes the run visibly *pass through*
    // the slot instead of being sliced by it.
    //
    // The two edges fade by the same amount. They were 4% and 12%, on the
    // reasoning that the trailing edge is the one text exits through — but
    // both edges are in view at once, and on a 32pt strip 4% is about a pixel
    // and a half, which reads as a hard cut next to a visible fade opposite
    // it. Symmetry is what makes the slot look like a window.
    return ShaderMask(
      shaderCallback:
          (rect) => LinearGradient(
            begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
            end: rtl ? Alignment.centerLeft : Alignment.centerRight,
            stops: const [0.0, 0.09, 0.91, 1.0],
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
          ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: SizedBox(
          height: _height,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder:
                  (context, _) => Transform.translate(
                    offset: Offset(
                      (rtl ? 1 : -1) *
                          widget.controller.value *
                          (_width + widget.gap),
                      0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [label, SizedBox(width: widget.gap), label],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
