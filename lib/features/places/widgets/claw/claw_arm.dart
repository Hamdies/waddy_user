import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/spots_draw_geometry.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/util/images.dart';

/// The claw — carriage, cable, the W housing disc, two prongs.
///
/// A [CustomPainter] rather than nested widgets. Rebuilding this from
/// `Container`s would mean a dozen `Transform`s rebuilt on every frame of a
/// 15-second animation. One painter repaints on one value.
///
/// Painted in a 104-wide design space and scaled by the cabinet, so the claw
/// keeps its proportions at any width.
///
/// ## The v2 claw
///
/// Every measurement here is the design's:
///
/// * a **46 × 11** carriage on the rail, with two 4px lamps — one lit mint,
///   one dimmed — so the carriage reads as powered.
/// * a **4px cable**, which is the part that lengthens on descent.
/// * a **48px dark disc** ringed in 3px mint, carrying the Waddi mark. This
///   is the claw's body and the single most identifying thing about it: the
///   machine is branded, and the brand is on the grabber.
/// * two **8-wide prongs hinged at the disc's own centre**, so their tops are
///   hidden inside the housing and only the arm emerges below its rim — one
///   machined piece rather than a V hanging off a circle. Each ends in an
///   18 × 8 foot that hooks *inward*.
///
/// The prongs swing between **±26° open** and **±6° closed**. Unlike the
/// design they do not converge on the centreline: they are hinged about a
/// ball-width apart so they come down either side of the ball and close onto
/// its outside edge. See `_shoulder` for why.
class ClawArm extends StatefulWidget {
  const ClawArm({
    super.key,
    required this.openAmount,
    this.width = designWidth,
    this.height = 105,
    this.cableLength = 0,
  });

  /// The box the claw is painted in.
  ///
  /// Wider than the design's 76, because the prongs hinge apart on shoulders
  /// about a ball-width across (see `_shoulder`) and still swing outward from
  /// there. At 76 the open prongs were clipped by their own bounds.
  static const double designWidth = 104;

  /// How deep the arm assembly runs below the housing disc.
  ///
  /// The cabinet needs this to seat the held ball between the feet rather
  /// than guessing an offset.
  ///
  /// Unchanged by the move to a centre hinge: the arms now start 24 higher
  /// (inside the housing) and run 18 longer to compensate, so the depth that
  /// actually hangs *below the disc* — bar plus foot — is the same 42 it was.
  /// The ball is seated against that, not against the hinge.
  static const double prongBoxHeight = 42;

  /// 0 shut (±6°), 1 open (±26°).
  final double openAmount;
  final double width;
  final double height;

  /// Distance from the rail down to the carriage.
  final double cableLength;

  @override
  State<ClawArm> createState() => _ClawArmState();
}

class _ClawArmState extends State<ClawArm> {
  /// The Waddi mark, decoded once for the whole app.
  ///
  /// A [CustomPainter] cannot decode a PNG — `drawImage` needs a `ui.Image`
  /// already in memory — so the asset is resolved asynchronously and the claw
  /// repaints when it lands. Cached statically because every claw on every
  /// draw screen wants the same bitmap, and decoding it per widget would cost
  /// a decode on each navigation.
  static ui.Image? _logo;
  static Future<ui.Image>? _loading;

  @override
  void initState() {
    super.initState();
    _ensureLogo();
  }

  void _ensureLogo() {
    if (_logo != null) return;
    _loading ??= _decodeLogo();
    _loading!.then((img) {
      _logo = img;
      if (mounted) setState(() {});
    });
  }

  static Future<ui.Image> _decodeLogo() async {
    final data = await rootBundle.load(Images.waddyLogo);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      // Decoded at the size it is actually drawn at rather than full
      // resolution: the mark renders about 26pt wide inside the housing, and
      // a 2000px source held in memory for that is waste.
      targetWidth: 96,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height + widget.cableLength),
      painter: _ClawPainter(
        openAmount: widget.openAmount.clamp(0.0, 1.0),
        cableLength: widget.cableLength,
        scale: widget.width / ClawArm.designWidth,
        logo: _logo,
      ),
      isComplex: false,
    );
  }
}

class _ClawPainter extends CustomPainter {
  _ClawPainter({
    required this.openAmount,
    required this.cableLength,
    required this.scale,
    required this.logo,
  });

  final double openAmount;
  final double cableLength;

  /// The Waddi mark, or null until it has decoded.
  final ui.Image? logo;

  /// Maps the design's units onto the width this arm was actually given.
  final double scale;

  // ── The design's own numbers ──
  static const double _carriageW = 46;
  static const double _carriageH = 11;
  static const double _cableW = 4;
  static const double _discR = 24; // 48px diameter
  static const double _prongW = 8;

  /// The arms hang beside the ball rather than over it, so they have to reach
  /// *past its equator* before the feet turn in — a prong that stops level
  /// with the centre grips nothing and reads as two posts either side.
  ///
  /// Measured from the **disc's centre**, because that is where the arms now
  /// hinge from: the top ~24 of this is hidden inside the housing and only
  /// the rest emerges below the rim. 50 therefore leaves the same ~26 of
  /// visible arm that 32-from-the-rim did, which is what clears a 48 ball's
  /// radius with room for the foot to hook under it.
  static const double _prongH = 50;
  static const double _padW = 18;
  static const double _padH = 8;

  /// `rotate(-26deg)` open, `rotate(-6deg)` closed — the design's swing.
  static const double _openAngle = 26 * math.pi / 180;
  static const double _shutAngle = 6 * math.pi / 180;

  /// How far out from the centreline each prong is hinged.
  ///
  /// ## Why the prongs do not meet at a point
  ///
  /// The design hinges both prongs at the same spot, which is fine in a mock
  /// where nothing is being gripped. Here there is a real ball of
  /// [SpotsDrawGeometry.ballSize] under them: prongs converging on the
  /// centreline close *inside* it, and the claw visibly passed through the
  /// thing it was meant to be holding.
  ///
  /// Widening the swing instead would have needed ~51° shut and ~90° open —
  /// flat enough to read as a spider rather than a claw. So the arms
  /// are hinged apart instead, on shoulders roughly at the ball's edge. Each
  /// prong then hangs nearly vertical and closes the last few degrees onto
  /// the ball's **outside border**, which is how a real claw grips.
  static const double _shoulder = SpotsDrawGeometry.ballSize / 2 - 4;

  /// The foot-pad's own fixed 26° cant.
  static const double _padAngle = 26 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final dark = Paint()..color = ClawTokens.deep;

    // ── Carriage on the rail ──
    //
    // Square at the top where it meets the rail, rounded at the bottom —
    // `border-radius: 0 0 6px 6px`. It is a block hanging off a track, not a
    // floating pill.
    final carriageW = _carriageW * scale;
    final carriageH = _carriageH * scale;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - carriageW / 2, 0, carriageW, carriageH),
        bottomLeft: Radius.circular(6 * scale),
        bottomRight: Radius.circular(6 * scale),
      ),
      dark,
    );

    // Two lamps on the carriage face: one lit, one at 30%. A pair where only
    // one is on reads as a status panel; two identical dots read as eyes.
    final lampR = 2 * scale;
    final lampStep = lampR + 2.5 * scale;
    canvas.drawCircle(
      Offset(cx - lampStep, carriageH / 2),
      lampR,
      Paint()..color = ClawTokens.mint,
    );
    canvas.drawCircle(
      Offset(cx + lampStep, carriageH / 2),
      lampR,
      Paint()..color = ClawTokens.mint.withValues(alpha: 0.3),
    );

    // ── Cable ──
    //
    // The one element that visibly lengthens as the claw descends, so it is
    // drawn from the carriage's underside down to the housing disc.
    if (cableLength > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          cx - (_cableW * scale) / 2,
          carriageH - 0.5,
          _cableW * scale,
          cableLength + 1,
        ),
        dark,
      );
    }

    final discCentre = Offset(cx, carriageH + cableLength + _discR * scale);

    // ── Prongs ──
    //
    // Drawn before the disc so their shoulders tuck *behind* it: the prongs
    // hinge off the housing, and a hinge you can see the top of is a stick
    // lying on a circle.
    //
    // The hinge sits at the housing's **centre**, not below its edge.
    //
    // The arms used to pivot from `_discR - 6` — just inside the lower rim —
    // with a separate shoulder beam bridging them. Two problems, both visible
    // on a phone: the beam read as a bar lying under the circle, and the arms
    // read as a detached V hanging off the bottom of it rather than as jaws
    // belonging to the same object.
    //
    // Pivoting from the centre means each bar's top half is *inside* the
    // disc, which is drawn immediately after this and covers it. What emerges
    // below the rim is only the part that should be visible: the arm. The
    // housing and the jaws become one machined piece with the arms coming out
    // of it, which is what a claw actually looks like.
    //
    // The shoulder beam is gone with it. It existed to join two arms that
    // started below the housing; arms that start inside it are already
    // joined, by the housing.
    final hingeY = discCentre.dy;

    _paintProng(canvas, Offset(cx, hingeY), mirrored: false);
    _paintProng(canvas, Offset(cx, hingeY), mirrored: true);

    // ── The housing disc ──
    //
    // Dark fill and a 3px mint ring. The ring is what separates the claw from
    // the pile behind it: without it a dark disc over dark balls in a pale
    // glass loses its edge.
    //
    // **No drop shadow.** There was a blurred one here — `deep` at 50% under
    // a 9px blur — and it was off-system twice over. Spots shadows are hard,
    // zero-blur offsets; the *one* sanctioned blur in the whole screen is the
    // cabinet's own drop, which exists because the cabinet is a moulded
    // object standing on the page (see [ClawTokens.shell]). The claw is not
    // standing on anything. It hangs inside the glass, where a soft shadow
    // read as a smudge under the disc rather than as depth, and where the
    // mint ring is already doing the separating.
    canvas.drawCircle(discCentre, _discR * scale, dark);
    canvas.drawCircle(
      discCentre,
      _discR * scale + 1.5 * scale,
      Paint()
        ..color = ClawTokens.mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale,
    );

    // ── The mark ──
    //
    // The real Waddi logo, not a letter `W` set in the display face.
    //
    // The two are not the same shape: the brand mark is a rounded double-U
    // with a dot in its left bowl, and a typographic W has neither. The
    // housing is the one place on this screen that carries the brand — it is
    // the badge on the front of the machine — so it has to be the mark.
    //
    // The bitmap was already decoded and handed to this painter and then
    // never drawn; the letter was left behind as its stand-in.
    //
    // Cost is not a reason to keep the letter: the image is decoded **once**
    // into a static, at a `targetWidth` of 96 for a mark drawn ~26pt wide, so
    // the run's ~60 frames a second are compositing an already-decoded
    // texture rather than decoding anything.
    final image = logo;
    if (image != null) {
      // `drawImageRect` rather than `drawImage`: the source is ~2000px and
      // the destination is a couple of dozen, so the scale has to be
      // explicit. `filterQuality` medium keeps the curve edges clean at that
      // reduction — the default sharpens them into stair-steps.
      final markW = 26 * scale;
      final markH = markW * (image.height / image.width);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        Rect.fromCenter(center: discCentre, width: markW, height: markH),
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      // The first frame or two before the decode lands. A `W` in the display
      // face is close enough in colour and weight that the swap is not a
      // visible pop, and an empty housing would be.
      final mark = TextPainter(
        text: TextSpan(
          text: 'W',
          style: Spots.display(20 * scale, color: ClawTokens.mint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mark.paint(canvas, discCentre - Offset(mark.width / 2, mark.height / 2));
    }
  }

  /// One prong: a bar hinged on its shoulder, with a canted foot-pad.
  ///
  /// [hinge] is the *centre* of the shoulder beam; each arm is hinged
  /// `_shoulder` out from it, so the pair straddle the ball rather than
  /// converging on its middle. They then swing a few degrees outward to clear
  /// it on the way down and back in to grip its outside edge.
  ///
  /// The rotation happens about each arm's own shoulder, not the centreline —
  /// rotating about the centre would swing the whole assembly like a pendulum
  /// instead of opening it like a pincer.
  void _paintProng(Canvas canvas, Offset hinge, {required bool mirrored}) {
    // Interpolated between the two states rather than snapped, so the jaw
    // closes *through* its range — the timeline hands this a curve and the
    // motion is the whole point of the grab.
    final angle = _shutAngle + (_openAngle - _shutAngle) * openAmount;
    final sign = mirrored ? 1.0 : -1.0;

    canvas.save();
    canvas.translate(hinge.dx + sign * _shoulder * scale, hinge.dy);
    canvas.rotate(sign * angle);

    final dark = Paint()..color = ClawTokens.deep;
    final w = _prongW * scale;
    final h = _prongH * scale;

    // The bar, drawn from the hinge at the disc's centre down past its rim.
    //
    // Fully rounded now, both ends. The square top was there because the bar
    // used to butt against a shoulder beam, where a rounded end would have
    // left a visible notch; hinged from inside the housing, that end is
    // covered by the disc and the rounding costs nothing — while the rod that
    // emerges reads as machined rather than cut.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2, 0, w, h),
        Radius.circular(w / 2),
      ),
      dark,
    );

    // The foot — the hook that actually does the gripping.
    //
    // It turns *inward*, toward the centreline, and overhangs the bar's inner
    // face. That is the whole mechanism: the arms come down outside the ball
    // and these two hooks curl under its edge. Canted outward (which is what
    // the design does, because its arms converge from above) the feet pointed
    // away from the ball and the claw looked like it was pushing it apart.
    canvas.save();
    canvas.translate(-sign * w / 2, h - 2 * scale);
    canvas.rotate(-sign * _padAngle);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          -(_padW * scale) / 2,
          -(_padH * scale) / 2,
          _padW * scale,
          _padH * scale,
        ),
        topLeft: Radius.circular(5 * scale),
        topRight: Radius.circular(3 * scale),
        bottomRight: Radius.circular(4 * scale),
        bottomLeft: Radius.circular(6 * scale),
      ),
      dark,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClawPainter old) =>
      old.openAmount != openAmount ||
      old.cableLength != cableLength ||
      old.scale != scale ||
      // The logo arrives asynchronously, one or two frames after the first
      // paint. Without it here the painter had no reason to run again, so on
      // an idle machine — nothing open, nothing moving — the housing would
      // hold its placeholder until some *other* change forced a repaint.
      old.logo != logo;
}
