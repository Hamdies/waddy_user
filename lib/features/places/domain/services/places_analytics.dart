import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/util/app_constants.dart';

/// Fire-and-forget KPI events (§5 of PLACES_TO_VISIT.md).
/// Vote events are logged server-side; this covers view/share behavior.
/// Must never throw or block UI.
class PlacesAnalytics {
  PlacesAnalytics._();

  static final Set<String> _seenThisSession = {};

  static void log(
    String event, {
    int? placeId,
    int? zoneId,
    bool oncePerSession = false,
  }) {
    if (oncePerSession) {
      final key = '$event:${placeId ?? ''}:${zoneId ?? ''}';
      if (!_seenThisSession.add(key)) return;
    }
    try {
      Get.find<ApiClient>()
          .postData('${AppConstants.placesUri}/events', {
            'event': event,
            if (placeId != null) 'place_id': placeId,
            if (zoneId != null) 'zone_id': zoneId,
          }, handleError: false)
          .catchError((Object e) {
            debugPrint('analytics drop ($event): $e');
            return const Response();
          });
    } catch (e) {
      debugPrint('analytics drop ($event): $e');
    }
  }
}
