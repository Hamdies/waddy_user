import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Where the live map looks while the rider is close.
///
/// The map only shows once the rider is within a couple of kilometres of home
/// (see the order screen's distance gate), so the pair always fits at a useful
/// zoom: no follow-the-rider mode is needed.
class RiderCamera {
  /// Closest the map may go when both points are next to each other.
  static const double maxZoom = 18;

  static CameraUpdate frame(LatLng rider, LatLng home, {double padding = 72}) {
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          math.min(rider.latitude, home.latitude),
          math.min(rider.longitude, home.longitude),
        ),
        northeast: LatLng(
          math.max(rider.latitude, home.latitude),
          math.max(rider.longitude, home.longitude),
        ),
      ),
      padding,
    );
  }

  static double meters(LatLng a, LatLng b) {
    const double r = 6371000;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
