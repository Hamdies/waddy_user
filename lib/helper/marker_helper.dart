import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/images.dart';

class MarkerHelper {
  /// The helmet's bounds inside rider_w.png. The art carries a halo of spark
  /// lines around it that would shrink the helmet to a speck at marker size.
  static const Rect riderHelmetCrop = Rect.fromLTRB(300, 315, 1030, 1020);

  static final Map<double, Future<BitmapDescriptor>> _riderMarkers = {};

  /// The rider's map marker: the helmet on a white-ringed mint disc, drawn
  /// once per size and shared by every tracking map.
  static Future<BitmapDescriptor> riderMarker({double diameter = 48}) =>
      _riderMarkers[diameter] ??= _drawRiderMarker(diameter);

  static Future<BitmapDescriptor> _drawRiderMarker(double diameter) async {
    const double dpr = 3;
    const double shadowPad = 4;
    final double px = (diameter + shadowPad * 2) * dpr;
    final Offset center = Offset(px / 2, px / 2);
    final double radius = diameter * dpr / 2;
    try {
      final ByteData data = await rootBundle.load(Images.riderHelmet);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.Image helmet = (await codec.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawCircle(
        center.translate(0, 1.5 * dpr),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3 * dpr),
      );
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        radius - 2.5 * dpr,
        Paint()..color = WaddyColors.mintSurface,
      );
      final double side = (radius - 2.5 * dpr) * 1.62;
      canvas.drawImageRect(
        helmet,
        riderHelmetCrop,
        Rect.fromCenter(center: center, width: side, height: side),
        Paint()..filterQuality = FilterQuality.high,
      );

      final ui.Image image = await recorder.endRecording().toImage(
        px.round(),
        px.round(),
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        imagePixelRatio: dpr,
      );
    } catch (e, s) {
      swallow('rider marker bitmap', e, s);
      // Don't cache a failure: the next tracking screen retries.
      _riderMarkers.remove(diameter);
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  static Future<BitmapDescriptor> convertAssetToBitmapDescriptor({
    required final String imagePath,
    final int? width,
    final int? height,
  }) async {
    try {
      final ByteData byteDataFromImage = await rootBundle
          .load(imagePath)
          .timeout(const Duration(seconds: 8));
      final ui.Codec codec = await ui
          .instantiateImageCodec(
            byteDataFromImage.buffer.asUint8List(),
            targetHeight: height,
            targetWidth: width,
          )
          .timeout(const Duration(seconds: 8));
      final ui.FrameInfo frameInfo = await codec.getNextFrame().timeout(
        const Duration(seconds: 8),
      );
      final ByteData? byteDataFromFrame = await frameInfo.image
          .toByteData(format: ui.ImageByteFormat.png)
          .timeout(const Duration(seconds: 8));
      if (byteDataFromFrame != null) {
        final Uint8List uint8List = byteDataFromFrame.buffer.asUint8List();
        //return BitmapDescriptor.fromBytes(uint8List);
        return BitmapDescriptor.bytes(uint8List);
      } else {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// Creates a decorative pin marker with a circular network image inside.
  /// Uses CachedNetworkImageProvider for fast, cached, crisp image loading.
  /// The marker is rendered at 3x device pixel ratio for sharp display.
  ///
  /// [imageUrl] - Network URL of the image (store logo, user avatar, etc.)
  /// [logicalSize] - Logical size of the circle in dp (actual pixels = logicalSize * 3)
  /// [borderColor] - Color of the pin border and pointer
  /// [borderWidth] - Width of the border in logical pixels
  /// [fallbackAsset] - Asset image path to use if network image fails
  static Future<BitmapDescriptor> createPinMarker({
    required String imageUrl,
    double logicalSize = 36,
    Color borderColor = Colors.white,
    double borderWidth = 2.5,
    String? fallbackAsset,
    IconData? fallbackIcon,
    Color? fallbackIconColor,
  }) async {
    try {
      // Render at 3x for crisp display on all devices
      const double dpr = 3.0;
      final double size = logicalSize * dpr;
      final double bw = borderWidth * dpr;
      final double pointerH = size * 0.32;
      final double totalH = size + pointerH;
      final double center = size / 2;
      final double radius = center - bw;
      final double pointerHalfW = size * 0.22;

      // Load the network image via CachedNetworkImageProvider (cached + crisp)
      ui.Image? netImg;
      if (imageUrl.isNotEmpty) {
        try {
          netImg = await _resolveImageProvider(
            CachedNetworkImageProvider(imageUrl),
            size.toInt(),
          ).timeout(const Duration(seconds: 5));
        } catch (e, s) {
          swallow('map marker bitmap', e, s);
        }
      }

      // If network image failed, try fallback asset
      if (netImg == null && fallbackAsset != null) {
        try {
          final bytes = await rootBundle.load(fallbackAsset);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
            targetWidth: size.toInt(),
            targetHeight: size.toInt(),
          );
          final frame = await codec.getNextFrame();
          netImg = frame.image;
        } catch (e, s) {
          swallow('map marker bitmap', e, s);
        }
      }

      // Paint the marker
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Shadow
      canvas.drawCircle(
        Offset(center, center + dpr),
        radius + bw,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Pointer triangle (shadow + fill)
      final pointerPath =
          Path()
            ..moveTo(center - pointerHalfW, size - bw)
            ..lineTo(center, size + pointerH - dpr)
            ..lineTo(center + pointerHalfW, size - bw)
            ..close();
      canvas.drawPath(
        pointerPath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
      );
      canvas.drawPath(pointerPath, Paint()..color = borderColor);

      // White/colored border circle
      canvas.drawCircle(
        Offset(center, center),
        radius + bw,
        Paint()..color = borderColor,
      );

      // Clip to inner circle and draw image
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCircle(center: Offset(center, center), radius: radius),
        ),
      );

      if (netImg != null) {
        final src = Rect.fromLTWH(
          0,
          0,
          netImg.width.toDouble(),
          netImg.height.toDouble(),
        );
        final dst = Rect.fromCircle(
          center: Offset(center, center),
          radius: radius,
        );
        canvas.drawImageRect(
          netImg,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        // Fallback: colored circle with icon
        canvas.drawCircle(
          Offset(center, center),
          radius,
          Paint()
            ..color =
                fallbackIconColor?.withValues(alpha: 0.15) ??
                Colors.grey.shade200,
        );
        if (fallbackIcon != null) {
          final iconPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(fallbackIcon.codePoint),
              style: TextStyle(
                fontSize: radius * 1.0,
                fontFamily: fallbackIcon.fontFamily,
                package: fallbackIcon.fontPackage,
                color: fallbackIconColor ?? Colors.grey,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          iconPainter.paint(
            canvas,
            Offset(
              center - iconPainter.width / 2,
              center - iconPainter.height / 2,
            ),
          );
        }
      }
      canvas.restore();

      // Encode to PNG
      final img = await recorder.endRecording().toImage(
        size.toInt(),
        totalH.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return BitmapDescriptor.bytes(
          byteData.buffer.asUint8List(),
          imagePixelRatio: dpr,
        );
      }
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Resolves an ImageProvider to a ui.Image at the given target pixel size.
  static Future<ui.Image> _resolveImageProvider(
    ImageProvider provider,
    int targetSize,
  ) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        _decodeToSize(
          info.image,
          targetSize,
        ).then(completer.complete).catchError(completer.completeError);
      },
      onError: (exception, stackTrace) {
        stream.removeListener(listener);
        completer.completeError(exception);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Re-encodes a ui.Image to the exact target pixel size for crisp rendering.
  static Future<ui.Image> _decodeToSize(ui.Image source, int targetSize) async {
    final byteData = await source.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return source;
    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
