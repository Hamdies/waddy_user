import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Read-only map of the serving-zone polygons ("we currently serve Maadi").
/// Opened from the out-of-zone hint on home.
class ServingZonesScreen extends StatefulWidget {
  const ServingZonesScreen({super.key});

  @override
  State<ServingZonesScreen> createState() => _ServingZonesScreenState();
}

class _ServingZonesScreenState extends State<ServingZonesScreen> {
  GoogleMapController? _mapController;
  Set<Polygon> _polygons = HashSet<Polygon>();
  List<LatLng> _allPoints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.log('serving_zones_viewed');
    _loadZones();
  }

  Future<void> _loadZones() async {
    final List<ZoneDataModel>? zones =
        await Get.find<LocationController>().getServiceZoneList();
    if (!mounted) return;

    final List<Polygon> polygonList = [];
    final List<LatLng> allPoints = [];
    for (final ZoneDataModel zone in zones ?? []) {
      final List<LatLng> points = [];
      zone.formatedCoordinates?.forEach((coordinate) {
        if (coordinate.lat != null && coordinate.lng != null) {
          points.add(LatLng(coordinate.lat!, coordinate.lng!));
        }
      });
      if (points.isEmpty) continue;
      allPoints.addAll(points);
      polygonList.add(
        Polygon(
          polygonId: PolygonId('${zone.id}'),
          points: points,
          strokeWidth: 2,
          strokeColor: Theme.of(context).primaryColor,
          fillColor: Theme.of(context).primaryColor.withValues(alpha: .2),
        ),
      );
    }

    setState(() {
      _polygons = HashSet<Polygon>.of(polygonList);
      _allPoints = allPoints;
      _loading = false;
    });
    _fitCamera();
  }

  void _fitCamera() {
    if (_mapController == null || _allPoints.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsFromLatLngList(_allPoints), 60),
      );
    });
  }

  static LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1 ?? 0, y1 ?? 0),
      southwest: LatLng(x0 ?? 0, y0 ?? 0),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'our_serving_zones'.tr),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeSmall,
            ),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: Text(
              'we_are_coming_for_you'.tr,
              textAlign: TextAlign.center,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(
                      AppConstants.maadiDefaultLatitude,
                      AppConstants.maadiDefaultLongitude,
                    ),
                    zoom: 12,
                  ),
                  polygons: _polygons,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitCamera();
                  },
                ),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
