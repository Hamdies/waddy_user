import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/widgets/order_eta_badge.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class OrderMapSection extends StatelessWidget {
  final OrderModel order;
  final bool ongoing;
  final bool parcel;
  final int? liveEtaMinutes;
  final int? prepMinutes;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController) onMapCreated;

  const OrderMapSection({
    super.key,
    required this.order,
    required this.ongoing,
    required this.parcel,
    required this.liveEtaMinutes,
    required this.prepMinutes,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final int? displayEta = liveEtaMinutes ?? prepMinutes;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map
        SizedBox(
          height: ResponsiveHelper.isMobile(context) ? 200 : 220,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            markers: markers,
            polylines: polylines,
            style:
                Get.isDarkMode
                    ? Get.find<ThemeController>().darkMap
                    : Get.find<ThemeController>().lightMap,
            onMapCreated: onMapCreated,
          ),
        ),

        // ETA + Delivering to section
        if (ongoing && !parcel)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [Center(child: OrderEtaBadge(minutes: displayEta))],
              ),
              Positioned(
                top: ResponsiveHelper.isMobile(context) ? 90 : 110,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order.deliveryAddress != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${'delivering_to'.tr} ${(order.deliveryAddress?.addressType ?? 'home').tr.capitalizeFirst}',
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (order.deliveryAddress?.address != null &&
                          order.deliveryAddress!.address!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          order.deliveryAddress!.address!,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )
        else if (!parcel)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.deliveryAddress != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${'delivering_to'.tr} ',
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        (order.deliveryAddress?.addressType ?? 'home')
                                .tr
                                .capitalizeFirst ??
                            '',
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.black87,
                        ),
                      ),
                      if (order.deliveryAddress?.address != null &&
                          order.deliveryAddress!.address!.isNotEmpty)
                        Flexible(
                          child: Text(
                            ' - ${order.deliveryAddress!.address!}',
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
