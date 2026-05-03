/// Utility class for calculating estimated time of arrival
class ETACalculator {
  /// Calculate ETA based on distance and time of day
  static ETAResult calculate(double distanceKm) {
    if (distanceKm <= 0) {
      return ETAResult(
        minMinutes: 0,
        maxMinutes: 0,
        speedUsed: 0,
        displayText: 'Arriving now',
      );
    }

    final hour = DateTime.now().hour;
    final speedKmH = _getSpeedForTime(hour);

    final minutes = (distanceKm / speedKmH * 60).round();
    final buffer = (minutes * 0.2).round().clamp(
      1,
      10,
    ); // 20% buffer, min 1, max 10

    return ETAResult(
      minMinutes: minutes,
      maxMinutes: minutes + buffer,
      speedUsed: speedKmH,
    );
  }

  /// Get estimated speed based on time of day
  static double _getSpeedForTime(int hour) {
    // Rush hours (7-9 AM, 5-7 PM): slower due to traffic
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 12.0;
    }
    // Night hours (10 PM - 6 AM): faster, less traffic
    if (hour >= 22 || hour <= 6) {
      return 35.0;
    }
    // Normal daytime hours
    return 20.0;
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // Math helpers to avoid import conflicts
  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => _sinApprox(x);
  static double _cos(double x) => _sinApprox(x + 3.141592653589793 / 2);
  static double _sqrt(double x) => x <= 0 ? 0 : _sqrtNewton(x);
  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _sinApprox(double x) {
    // Normalize to -π to π
    while (x > 3.141592653589793) {
      x -= 2 * 3.141592653589793;
    }
    while (x < -3.141592653589793) {
      x += 2 * 3.141592653589793;
    }
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _sqrtNewton(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan(double x) {
    // Taylor series for atan
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.141592653589793 / 2 - _atan(1 / x));
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}

/// Result of ETA calculation
class ETAResult {
  final int minMinutes;
  final int maxMinutes;
  final double speedUsed;
  final String? _customDisplayText;

  ETAResult({
    required this.minMinutes,
    required this.maxMinutes,
    required this.speedUsed,
    String? displayText,
  }) : _customDisplayText = displayText;

  /// Get formatted display text
  String get displayText {
    if (_customDisplayText != null) return _customDisplayText;

    if (minMinutes < 1) return 'Arriving now';
    if (minMinutes == maxMinutes) return '$minMinutes min';
    return '$minMinutes-$maxMinutes min';
  }

  /// Check if driver is very close
  bool get isArriving => minMinutes < 2;

  /// Check if driver is nearby (under 5 minutes)
  bool get isNearby => minMinutes < 5;

  /// Format as a clock-time window: "3:45 – 4:00"
  /// Uses the current time + min/max minutes.
  String get clockWindow {
    if (minMinutes < 1) return 'Arriving now';
    final now = DateTime.now();
    final lo = now.add(Duration(minutes: minMinutes));
    final hi = now.add(Duration(minutes: maxMinutes));
    final loStr = fmtTime(lo);
    final hiStr = fmtTime(hi);
    if (loStr == hiStr) return loStr;
    return '$loStr\u2013$hiStr';
  }

  static String fmtTime(DateTime t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m $period';
  }
}
