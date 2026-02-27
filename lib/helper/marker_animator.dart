import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for smooth marker animation between positions
class MarkerAnimator {
  LatLng? _lastPosition;
  bool _isAnimating = false;
  final List<VoidCallback> _pendingCallbacks = [];

  /// Animate marker from current position to target position
  void animateTo({
    required LatLng target,
    required Function(LatLng position, double rotation) onUpdate,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    // If no previous position, just set it directly
    if (_lastPosition == null) {
      _lastPosition = target;
      onUpdate(target, 0);
      return;
    }

    // Skip if already at target (within tolerance)
    if (_isAtPosition(_lastPosition!, target)) {
      return;
    }

    // Calculate bearing for rotation
    final bearing = calculateBearing(_lastPosition!, target);
    final from = _lastPosition!;

    // If already animating, queue this animation
    if (_isAnimating) {
      _pendingCallbacks.add(
        () => animateTo(target: target, onUpdate: onUpdate, duration: duration),
      );
      return;
    }

    _isAnimating = true;
    const steps = 30;
    final interval = duration.inMilliseconds ~/ steps;

    for (int i = 0; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: i * interval), () {
        if (!_isAnimating && i > 0) return; // Animation was cancelled

        final t = i / steps;
        // Use ease-out for smoother deceleration
        final easedT = 1 - pow(1 - t, 3);

        final lat = from.latitude + (target.latitude - from.latitude) * easedT;
        final lng =
            from.longitude + (target.longitude - from.longitude) * easedT;

        onUpdate(LatLng(lat, lng), bearing);

        if (i == steps) {
          _lastPosition = target;
          _isAnimating = false;

          // Process any pending animations
          if (_pendingCallbacks.isNotEmpty) {
            final nextCallback = _pendingCallbacks.removeAt(0);
            nextCallback();
          }
        }
      });
    }
  }

  /// Calculate bearing/heading between two points in degrees
  static double calculateBearing(LatLng from, LatLng to) {
    final dLon = (to.longitude - from.longitude) * pi / 180;
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// Check if two positions are close enough to be considered the same
  bool _isAtPosition(LatLng a, LatLng b, {double tolerance = 0.00001}) {
    return (a.latitude - b.latitude).abs() < tolerance &&
        (a.longitude - b.longitude).abs() < tolerance;
  }

  /// Reset animator state
  void reset() {
    _lastPosition = null;
    _isAnimating = false;
    _pendingCallbacks.clear();
  }

  /// Cancel any ongoing animation
  void cancel() {
    _isAnimating = false;
    _pendingCallbacks.clear();
  }

  /// Get last known position
  LatLng? get lastPosition => _lastPosition;
}
