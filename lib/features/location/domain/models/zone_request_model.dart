/// A pending "launch delivery here" request.
///
/// Kept as a plain serialisable value so an unsent request can be parked in
/// SharedPreferences and replayed on a later launch — the tap is a promise we
/// made to the user, so a network failure must not silently discard it.
class ZoneRequestBody {
  final double latitude;
  final double longitude;
  final String source;
  final String? address;
  final int? storeId;
  final int? moduleId;
  final String? fcmToken;
  final bool hasPush;

  ZoneRequestBody({
    required this.latitude,
    required this.longitude,
    required this.source,
    this.address,
    this.storeId,
    this.moduleId,
    this.fcmToken,
    this.hasPush = false,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude.toString(),
    'longitude': longitude.toString(),
    'source': source,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (storeId != null) 'store_id': storeId,
    if (moduleId != null) 'module_id': moduleId,
    if (fcmToken != null && fcmToken!.isNotEmpty) 'fcm_token': fcmToken,
    'has_push': hasPush,
  };

  factory ZoneRequestBody.fromJson(Map<String, dynamic> json) =>
      ZoneRequestBody(
        latitude: double.tryParse('${json['latitude']}') ?? 0,
        longitude: double.tryParse('${json['longitude']}') ?? 0,
        source: json['source'] ?? 'sheet',
        address: json['address'],
        storeId: json['store_id'],
        moduleId: json['module_id'],
        fcmToken: json['fcm_token'],
        hasPush: json['has_push'] == true,
      );
}

/// Server's answer to a submitted request.
///
/// [totalRequestsInArea] is nullable on purpose: the backend returns null when
/// the count is unavailable, and the UI must then hide the "47 people here are
/// waiting too" line rather than render a zero, which would read as "nobody
/// else wants this" — the opposite of the intended message.
class ZoneRequestResult {
  final bool success;
  final String? message;
  final int? totalRequestsInArea;

  ZoneRequestResult({
    required this.success,
    this.message,
    this.totalRequestsInArea,
  });

  factory ZoneRequestResult.fromJson(Map<String, dynamic> json) =>
      ZoneRequestResult(
        success: true,
        message: json['message'],
        totalRequestsInArea:
            json['total_requests_in_area'] is int
                ? json['total_requests_in_area']
                : int.tryParse('${json['total_requests_in_area']}'),
      );
}
