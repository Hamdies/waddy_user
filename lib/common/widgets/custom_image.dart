import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:waddy_app/common/models/image_variants.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/images.dart';

/// Network image with a local asset placeholder.
///
/// Used to take an `isHovered` flag and wrap every image in an `AnimatedScale`
/// that scaled to 1.1 on mouse-over. Every call site passed the hover state of
/// a `TextHover`/`OnHover` wrapper, and `MouseRegion` never fires on a
/// touch-only build — so the scale was pinned at 1.0 and the animation layer
/// was pure overhead on every image in every list. Both are gone.
///
/// The URL also used to route through `\$baseUrl/image-proxy?url=` behind a
/// web-only platform check, to dodge canvas CORS. There is no web build.
///
/// ## Decode size
///
/// This widget is used in 115 files, and until now none of them capped the
/// decode. `CachedNetworkImage` with no `memCacheWidth` decodes at whatever
/// resolution the server sent, so a 1200×1200 merchant logo rendered into a
/// 40×40 circle still expanded to roughly 5.7 MB of bitmap in the image cache.
/// A home screen full of those is hundreds of megabytes of avoidable memory,
/// which on the 2–3 GB Android devices that make up most of the Egyptian market
/// means GC pressure, dropped frames, and the OS killing the app in the
/// background.
///
/// The cap is derived, not configured, so it applies everywhere without
/// touching a single call site: the layout width (or the screen width when the
/// image is unbounded) times the device pixel ratio. Passing [decodeWidth]
/// overrides the derivation for the cases where the laid-out width is not the
/// displayed width — inside a `Transform.scale`, say.
class CustomImage extends StatelessWidget {
  final String image;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final bool isNotification;
  final String placeholder;
  final Color? color;

  /// The `*_variants` map from the API, when the caller has one. Given it, this
  /// widget downloads a right-sized WebP instead of the full-resolution
  /// original — the bytes-on-the-wire half of the saving, where [decodeWidth]
  /// is the bytes-in-memory half. Null is always safe: [image] is used as-is.
  final ImageVariants? variants;

  /// Overrides the derived decode width, in logical pixels. Only needed when
  /// the constraints this widget is laid out under do not match how large it
  /// actually appears.
  final double? decodeWidth;

  /// Replaces the shared placeholder while loading and on error.
  ///
  /// The default is a grey tile carrying the Waddy mark, so a missing photo
  /// reads as "no photo yet, still Waddy" rather than a generic broken-image
  /// glyph in a colour that appears nowhere in the palette. On surfaces with a
  /// committed visual world (Spots), three of those in a row still reads as
  /// "this app is broken", so those callers pass a tile drawn in their own
  /// tokens instead.
  final Widget? fallback;

  /// Rounds the image without a `ClipRRect`.
  ///
  /// A `ClipRRect` forces a `saveLayer`: the subtree renders to an offscreen
  /// buffer, gets masked, then composites back. That is one of the more
  /// expensive things a mid-range GPU does, and these cards do it per image in
  /// a scrolling rail — the Mi 9T baseline has raster at 9.8-14.5ms against a
  /// 16.7ms budget (docs/performance_baseline.md §9).
  ///
  /// Given a radius, the loaded image is painted as a `DecorationImage` on a
  /// rounded `BoxDecoration` instead. The renderer rounds the corners while
  /// drawing rather than masking afterwards, so there is no offscreen pass and
  /// the result is identical.
  ///
  /// Only the loaded image is drawn this way; the placeholder and error tile
  /// keep their own shape, which is what they already did inside a clip.
  final BorderRadius? borderRadius;

  const CustomImage({
    super.key,
    required this.image,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.isNotification = false,
    this.placeholder = '',
    this.color,
    this.variants,
    this.decodeWidth,
    this.fallback,
    this.borderRadius,
  });

  /// Hard ceiling on decode width in device pixels.
  ///
  /// A full-bleed image on a 3x phone asks for ~1300 px, which is more detail
  /// than any of these photographs carry and a 6.8 MB bitmap. Nothing in this
  /// app renders an image where the difference above this is visible.
  static const double _maxDecodeWidth = 1080;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    // Logical width this image occupies. `width` is frequently
    // `double.infinity` (full-bleed cards, banners); the screen width is the
    // true upper bound in that case, and is still far below the source images.
    final double logicalWidth =
        decodeWidth ??
        ((width != null && width!.isFinite && width! > 0)
            ? width!
            : media.size.width);

    final double physicalWidth = math.min(
      logicalWidth * media.devicePixelRatio,
      _maxDecodeWidth,
    );

    // Prefer a right-sized variant when the caller passed one. Falling back to
    // `image` covers three real cases: no variant map (old cached payload, or
    // an endpoint not yet emitting them), a map with no rung large enough, and
    // an image whose upload predates the backfill.
    final String? variantUrl = variants?.urlFor(physicalWidth);
    final String url = variantUrl ?? image;

    // Never ask for more pixels than the chosen file contains — decoding a
    // 150 px thumb at 400 px is upscaling in the decoder, which costs memory
    // and looks worse than letting the widget scale it.
    final int? variantIntrinsic =
        variantUrl == null ? null : variants!.intrinsicWidthFor(physicalWidth);
    final int memCacheWidth =
        variantIntrinsic == null
            ? physicalWidth.round()
            : math.min(physicalWidth.round(), variantIntrinsic);

    return CachedNetworkImage(
      color: color,
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: memCacheWidth,
      // Bounds what the on-disk cache holds too, so a merchant uploading a
      // 4000 px logo cannot evict the rest of the cache on its own.
      maxWidthDiskCache: memCacheWidth,
      placeholder: (context, url) => _fallback(),
      errorWidget: (context, url, error) => _fallback(),
      // Rounded by the decoration rather than by a clip — see [borderRadius].
      imageBuilder:
          borderRadius == null
              ? null
              : (BuildContext context, ImageProvider provider) => Container(
                height: height,
                width: width,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  image: DecorationImage(
                    image: provider,
                    fit: fit ?? BoxFit.cover,
                    colorFilter:
                        color == null
                            ? null
                            : ColorFilter.mode(color!, BlendMode.srcIn),
                  ),
                ),
              ),
    );
  }

  Widget _fallback() {
    if (fallback != null) return fallback!;
    if (placeholder.isNotEmpty) {
      return Image.asset(
        placeholder,
        height: height,
        width: width,
        fit: fit,
        color: color,
      );
    }
    return _LogoPlaceholder(height: height, width: width);
  }
}

/// Grey tile carrying the Waddy mark, shown while a network image loads or
/// fails. Scales the mark to a fraction of the tile instead of filling it —
/// filling made small avatars/thumbnails look like a solid grey W rather than
/// an empty-state glyph.
class _LogoPlaceholder extends StatelessWidget {
  final double? height;
  final double? width;

  const _LogoPlaceholder({this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: WaddyColors.surfaceRaised,
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.4,
        heightFactor: 0.4,
        child: Image.asset(
          Images.logoMarkTransparent,
          color: WaddyColors.inkMuted,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
