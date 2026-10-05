import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/images.dart';

/// The rider, as the Waddi helmet on a mint disc. Used as the rider's avatar
/// and as the "finding a rider" glyph, so the person and the map marker read
/// as the same thing.
class RiderHelmet extends StatelessWidget {
  final double size;
  const RiderHelmet({super.key, this.size = 48});

  // The helmet fills ~54% of rider_w.png's width and sits a touch low and
  // right of centre; the spark halo around it is cropped by the circle.
  static const double _zoom = 1.6;
  static const Offset _recentre = Offset(-0.02, -0.04);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: WaddyColors.mintSurface,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: size * _zoom,
          maxHeight: size * _zoom,
          child: FractionalTranslation(
            translation: _recentre,
            child: Image.asset(
              Images.riderHelmet,
              width: size * _zoom,
              height: size * _zoom,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
