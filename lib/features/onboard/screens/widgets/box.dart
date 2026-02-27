// import 'dart:ui' as ui;
// import 'package:flutter_svg/flutter_svg.dart' as svg_pkg;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class DeliveryBoxWidget extends StatefulWidget {
//   const DeliveryBoxWidget({super.key});

//   @override
//   State<DeliveryBoxWidget> createState() => _DeliveryBoxWidgetState();
// }

// class _DeliveryBoxWidgetState extends State<DeliveryBoxWidget> {
//   ui.Picture? _svgPicture;
//   Size? _svgSize;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadSvg();
//   }

// Future<void> _loadSvg() async {
//   try {
//     final rawSvg = await rootBundle.loadString('assets/box_icon.svg');

//     // ✅ Correct new API
//     final drawableRoot = await svg_pkg.fromSvgString(rawSvg, rawSvg);

//     // Capture viewport size (fallback to 120x120 if missing)
//     Size size;
//     try {
//       final vb = drawableRoot.viewport.viewBox;
//       size = Size(vb.width == 0 ? 120 : vb.width, vb.height == 0 ? 120 : vb.height);
//     } catch (_) {
//       size = const Size(120, 120);
//     }

//     // Convert to picture
//     final picture = drawableRoot.toPicture(size: size);

//     setState(() {
//       _svgPicture = picture;
//       _svgSize = size;
//       _loading = false;
//     });
//   } catch (e, st) {
//     debugPrint('SVG load failed: $e\n$st');
//     setState(() {
//       _svgPicture = null;
//       _svgSize = null;
//       _loading = false;
//     });
//   }
// }


//   @override
//   void dispose() {
//     _svgPicture?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // set a reasonable size for the CustomPaint
//     return SizedBox(
//       width: 420,
//       height: 360,
//       child: CustomPaint(
//         painter: DeliveryBoxPainter(
//           primaryColor: const Color(0xFF0c1e36),
//           accentColor: const Color(0xFFFFB205),
//           contentOpacity: 1.0,
//           svgPicture: _svgPicture,
//           svgSize: _svgSize,
//           svgScale: 1.0,
//         ),
//         child: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : const SizedBox.shrink(),
//       ),
//     );
//   }
// }

// /// CustomPainter that draws a stylized delivery box.
// /// Accepts an optional [svgPicture] and its [svgSize] for drawing an SVG inside the icon tile.
// class DeliveryBoxPainter extends CustomPainter {
//   final Color primaryColor;
//   final Color accentColor;
//   final double contentOpacity;
//   final ui.Picture? svgPicture;
//   final Size? svgSize;
//   final double svgScale;

//   DeliveryBoxPainter({
//     required this.primaryColor,
//     required this.accentColor,
//     required this.contentOpacity,
//     this.svgPicture,
//     this.svgSize,
//     this.svgScale = 1.0,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint();

//     // Box layout (tweakable)
//     final boxWidth = size.width - 100;
//     final boxHeight = 260.0;
//     final boxLeft = 40.0;
//     final boxTop = (size.height - boxHeight) / 2;

//     // Outer drop shadow
//     final shadowRect = RRect.fromRectAndRadius(
//       Rect.fromLTWH(boxLeft + 6, boxTop + 8, boxWidth, boxHeight),
//       const Radius.circular(32),
//     );
//     paint
//       ..color = Colors.black.withOpacity(0.12)
//       ..style = PaintingStyle.fill;
//     canvas.drawRRect(shadowRect, paint);

//     // Body gradient for a more illustrated look
//     final bodyRect = Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight);
//     paint.shader = LinearGradient(
//       begin: Alignment.topLeft,
//       end: Alignment.bottomRight,
//       colors: [
//         _brighten(primaryColor, 0.06),
//         primaryColor,
//         _darken(primaryColor, 0.08),
//       ],
//       stops: const [0.0, 0.5, 1.0],
//     ).createShader(bodyRect);
//     paint.style = PaintingStyle.fill;
//     final boxRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(30));
//     canvas.drawRRect(boxRect, paint);

//     // subtle inner highlight (top edge)
//     final highlightPaint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//         colors: [Colors.white.withOpacity(0.12), Colors.transparent],
//       ).createShader(Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight * 0.35))
//       ..blendMode = ui.BlendMode.screen;
//     canvas.drawRRect(boxRect, highlightPaint);

//     // Flaps - left and right with folds
//     const flapHeight = 36.0;
//     final leftFlap = Path()
//       ..moveTo(boxLeft + 18, boxTop)
//       ..lineTo(boxLeft + boxWidth * 0.35, boxTop - flapHeight)
//       ..lineTo(boxLeft + boxWidth * 0.5, boxTop - flapHeight + 6)
//       ..lineTo(boxLeft + boxWidth * 0.15, boxTop)
//       ..close();
//     final rightFlap = Path()
//       ..moveTo(boxLeft + boxWidth - 18, boxTop)
//       ..lineTo(boxLeft + boxWidth * 0.65, boxTop - flapHeight)
//       ..lineTo(boxLeft + boxWidth * 0.5, boxTop - flapHeight + 6)
//       ..lineTo(boxLeft + boxWidth * 0.85, boxTop)
//       ..close();

//     paint
//       ..style = PaintingStyle.fill
//       ..color = _darken(primaryColor, 0.12);
//     canvas.drawPath(leftFlap, paint);
//     paint.color = _darken(primaryColor, 0.06);
//     canvas.drawPath(rightFlap, paint);

//     // fold line
//     paint
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.2
//       ..color = Colors.black.withOpacity(0.12);
//     canvas.drawLine(
//       Offset(boxLeft + boxWidth * 0.5, boxTop - flapHeight + 6),
//       Offset(boxLeft + boxWidth * 0.5, boxTop + 6),
//       paint,
//     );

//     // Tape (accent stripe)
//     final tapeTop = boxTop + boxHeight * 0.38;
//     const tapeHeight = 44.0;
//     final tapeRect = Rect.fromLTWH(boxLeft + 6, tapeTop, boxWidth - 12, tapeHeight);
//     paint
//       ..shader = LinearGradient(
//         colors: [_darken(accentColor, 0.08), accentColor, _brighten(accentColor, 0.04)],
//       ).createShader(tapeRect)
//       ..style = PaintingStyle.fill;
//     canvas.drawRRect(RRect.fromRectAndRadius(tapeRect, const Radius.circular(8)), paint);

//     // tape dashed marks
//     final dashPaint = Paint()
//       ..color = Colors.white.withOpacity(0.22)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2;
//     for (double i = tapeRect.left + 12; i < tapeRect.right - 12; i += 22) {
//       canvas.drawLine(Offset(i, tapeRect.top + 12), Offset(i + 12, tapeRect.top + 12), dashPaint);
//       canvas.drawLine(Offset(i, tapeRect.bottom - 12), Offset(i + 12, tapeRect.bottom - 12), dashPaint);
//     }

//     // stitched box edges (dashed)
//     final stitchPaint = Paint()
//       ..color = Colors.black.withOpacity(0.12)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1;
//     _drawDashedRRect(canvas, RRect.fromRectAndRadius(bodyRect.deflate(6), const Radius.circular(24)), stitchPaint,
//         dashLength: 6, gapLength: 8);

//     // shipping label
//     const labelW = 140.0;
//     const labelH = 64.0;
//     final labelLeft = boxLeft + boxWidth - labelW - 18;
//     final labelTop = boxTop + 18;
//     paint
//       ..style = PaintingStyle.fill
//       ..shader = LinearGradient(
//         colors: [Colors.white, Colors.grey.shade200],
//       ).createShader(Rect.fromLTWH(labelLeft, labelTop, labelW, labelH));
//     final labelR = RRect.fromRectAndRadius(Rect.fromLTWH(labelLeft, labelTop, labelW, labelH), const Radius.circular(10));
//     canvas.drawRRect(labelR, paint);

//     // barcode-ish lines
//     paint.shader = null;
//     paint.color = Colors.black.withOpacity(0.8);
//     for (int i = 0; i < 5; i++) {
//       final bw = 6.0 + (i % 2) * 4;
//       final bx = labelLeft + 10.0 + i * 16.0;
//       canvas.drawRect(Rect.fromLTWH(bx, labelTop + 12, bw, 36), paint);
//     }

//     // sticker / badge
//     final badgeLeft = boxLeft + 18;
//     final badgeTop = boxTop + boxHeight - 70;
//     const badgeWidth = 120.0;
//     const badgeHeight = 44.0;
//     paint
//       ..style = PaintingStyle.fill
//       ..color = Colors.white.withOpacity(contentOpacity);
//     final badgeR = RRect.fromRectAndRadius(Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight), const Radius.circular(14));
//     canvas.drawRRect(badgeR, paint);

//     // purple dot
//     paint.color = Colors.purple.withOpacity(contentOpacity);
//     canvas.drawCircle(Offset(badgeLeft + 18, badgeTop + badgeHeight / 2), 9, paint);

//     // badge text
//     if (contentOpacity > 0) {
//       final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.left);
//       tp.text = TextSpan(
//         text: 'FREE BIZ\nREPORT',
//         style: TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w800,
//           color: Colors.purple.withOpacity(contentOpacity),
//           height: 1.05,
//         ),
//       );
//       tp.layout(maxWidth: badgeWidth - 46);
//       tp.paint(canvas, Offset(badgeLeft + 34, badgeTop + 8));
//     }

//     // accent border
//     paint
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.2
//       ..shader = null
//       ..color = accentColor.withOpacity(0.95);
//     canvas.drawRRect(RRect.fromRectAndRadius(bodyRect.deflate(3), const Radius.circular(28)), paint);

//     // center icon tile and svg draw
//     const iconSize = 76.0;
//     final iconLeft = boxLeft + (boxWidth - iconSize) / 2;
//     final iconTop = boxTop + 28;
//     final iconRect = RRect.fromRectAndRadius(Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize), const Radius.circular(12));

//     // tile background
//     paint
//       ..style = PaintingStyle.fill
//       ..shader = RadialGradient(
//         center: const Alignment(-0.2, -0.6),
//         radius: 1.1,
//         colors: [
//           Colors.white.withOpacity(0.06),
//           accentColor.withOpacity(0.06),
//           Colors.transparent,
//         ],
//         stops: const [0.0, 0.4, 1.0],
//       ).createShader(Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize));
//     canvas.drawRRect(iconRect, paint);

//     // icon border
//     paint
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2
//       ..color = accentColor.withOpacity(0.9);
//     canvas.drawRRect(iconRect, paint);

//     // Draw SVG picture if available
//     if (svgPicture != null && svgSize != null) {
//       final bounds = svgSize!;
//       final scaleX = (iconSize * 0.74) / bounds.width * svgScale;
//       final scaleY = (iconSize * 0.74) / bounds.height * svgScale;
//       final scale = scaleX < scaleY ? scaleX : scaleY;

//       final dx = iconLeft + (iconSize - bounds.width * scale) / 2;
//       final dy = iconTop + (iconSize - bounds.height * scale) / 2;

//       canvas.save();
//       canvas.translate(dx, dy);
//       canvas.scale(scale, scale);
//       canvas.drawPicture(svgPicture!);
//       canvas.restore();
//     } else {
//       // fallback decorative package lines
//       paint
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 3
//         ..color = accentColor;
//       final cx = iconLeft + iconSize / 2;
//       final cy = iconTop + iconSize / 2;
//       canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: iconSize * 0.6, height: iconSize * 0.6), paint);
//       canvas.drawLine(Offset(cx, iconTop + 8), Offset(cx, iconTop + iconSize - 8), paint);
//       canvas.drawLine(Offset(iconLeft + 8, cy), Offset(iconLeft + iconSize - 8, cy), paint);
//     }

//     // Headline text
//     if (contentOpacity > 0) {
//       final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
//       tp.text = TextSpan(
//         text: 'ONE',
//         style: TextStyle(
//           fontSize: 44,
//           fontWeight: FontWeight.w900,
//           color: Colors.white.withOpacity(0.95 * contentOpacity),
//           letterSpacing: 2,
//         ),
//       );
//       tp.layout();
//       tp.paint(canvas, Offset(boxLeft + (boxWidth - tp.width) / 2, boxTop + 120));

//       tp.text = TextSpan(
//         text: 'PLATFORM',
//         style: TextStyle(
//           fontSize: 34,
//           fontWeight: FontWeight.w900,
//           color: Colors.white.withOpacity(0.95 * contentOpacity),
//           letterSpacing: 2,
//         ),
//       );
//       tp.layout();
//       tp.paint(canvas, Offset(boxLeft + (boxWidth - tp.width) / 2, boxTop + 168));

//       tp.text = TextSpan(
//         text: 'TO RULE',
//         style: TextStyle(
//           fontSize: 28,
//           fontWeight: FontWeight.w900,
//           color: Colors.white.withOpacity(0.95 * contentOpacity),
//           letterSpacing: 2,
//         ),
//       );
//       tp.layout();
//       tp.paint(canvas, Offset(boxLeft + (boxWidth - tp.width) / 2, boxTop + 210));
//     }
//   }

//   @override
//   bool shouldRepaint(DeliveryBoxPainter oldDelegate) {
//     return oldDelegate.contentOpacity != contentOpacity ||
//         oldDelegate.primaryColor != primaryColor ||
//         oldDelegate.accentColor != accentColor ||
//         oldDelegate.svgPicture != svgPicture ||
//         oldDelegate.svgScale != svgScale ||
//         oldDelegate.svgSize != svgSize;
//   }

//   // helper - draw dashed rounded rect (approx)
//   void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint, {double dashLength = 6, double gapLength = 6}) {
//     final path = Path()..addRRect(rrect);
//     final metrics = path.computeMetrics();
//     for (final metric in metrics) {
//       double distance = 0.0;
//       while (distance < metric.length) {
//         final next = distance + dashLength;
//         final extract = metric.extractPath(distance, next.clamp(0.0, metric.length));
//         canvas.drawPath(extract, paint);
//         distance = next + gapLength;
//       }
//     }
//   }

//   // tiny color helpers
//   static Color _darken(Color c, double amount) {
//     final f = (1 - amount).clamp(0.0, 1.0);
//     return Color.fromARGB(c.alpha, (c.red * f).round(), (c.green * f).round(), (c.blue * f).round());
//   }

//   static Color _brighten(Color c, double amount) {
//     int r = (c.red + ((255 - c.red) * amount)).round();
//     int g = (c.green + ((255 - c.green) * amount)).round();
//     int b = (c.blue + ((255 - c.blue) * amount)).round();
//     return Color.fromARGB(c.alpha, r, g, b);
//   }
// }