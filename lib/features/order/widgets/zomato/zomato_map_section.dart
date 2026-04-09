import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';

/// Minimal map style JSON — hides POIs, transit, labels for a clean look.
const String _minimalMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"lightness":40}]}
]
''';

class ZomatoMapSection extends StatelessWidget {
  final OrderModel order;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback? onExpand;

  const ZomatoMapSection({
    super.key,
    required this.order,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
    final bool showMap = status != null && !status.isTerminal;

    if (!showMap) return const SizedBox.shrink();

    LatLng initialTarget;
    if (order.deliveryAddress?.latitude != null &&
        order.deliveryAddress?.longitude != null) {
      initialTarget = LatLng(
        double.tryParse(order.deliveryAddress!.latitude!) ?? 0,
        double.tryParse(order.deliveryAddress!.longitude!) ?? 0,
      );
    } else if (order.store?.latitude != null &&
        order.store?.longitude != null) {
      initialTarget = LatLng(
        double.tryParse(order.store!.latitude!) ?? 0,
        double.tryParse(order.store!.longitude!) ?? 0,
      );
    } else {
      initialTarget = const LatLng(0, 0);
    }

    // Use minimal style unless dark mode provides its own
    final String mapStyle = Get.isDarkMode
        ? Get.find<ThemeController>().darkMap
        : _minimalMapStyle;

    return Stack(
      children: [
        SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            liteModeEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            markers: markers,
            polylines: polylines,
            style: mapStyle,
            onMapCreated: onMapCreated,
          ),
        ),

        // Expand / fullscreen button
        if (onExpand != null)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: onExpand,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
