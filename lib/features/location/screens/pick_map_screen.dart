import 'package:geolocator/geolocator.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/widgets/cairo_location_search_widget.dart';
import 'package:waddy_app/util/dimensions.dart';

class PickMapScreen extends StatefulWidget {
  final bool fromSignUp;
  final bool fromAddAddress;
  final bool canRoute;
  final String? route;
  final GoogleMapController? googleMapController;
  final Function(AddressModel address)? onPicked;
  final bool fromLandingPage;

  /// When true this screen IS the app-entry location gate: the user has no
  /// usable address and declined the permission prompt, so picking a spot is
  /// the only way forward. Back button and back gesture are disabled — there
  /// is no valid screen behind this one. Defaults to false so every existing
  /// entry point keeps its normal, dismissible behaviour.
  final bool isMandatory;

  const PickMapScreen({
    super.key,
    required this.fromSignUp,
    required this.fromAddAddress,
    required this.canRoute,
    required this.route,
    this.googleMapController,
    this.onPicked,
    this.fromLandingPage = false,
    this.isMandatory = false,
  });

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  GoogleMapController? _mapController;
  CameraPosition? _cameraPosition;
  late LatLng _initialPosition;
  bool locationAlreadyAllow = false;

  @override
  void initState() {
    super.initState();

    if (widget.fromAddAddress) {
      Get.find<LocationController>().setPickData();
    }
    _initialPosition = LatLng(
      double.parse(
        Get.find<SplashController>().configModel.defaultLocation?.lat ?? '0',
      ),
      double.parse(
        Get.find<SplashController>().configModel.defaultLocation?.lng ?? '0',
      ),
    );
    _checkAlreadyLocationEnable();
  }

  _checkAlreadyLocationEnable() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      locationAlreadyAllow = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // As the entry gate there is no valid screen behind this one — backing out
    // would land on a home with no delivery address. Picking is the only exit.
    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        endDrawer: const MenuDrawer(),
        endDrawerEnableOpenDragGesture: false,
        body: GetBuilder<LocationController>(
          builder: (locationController) {
            return _buildMobileLayout(locationController);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(LocationController locationController) {
    return Stack(
      children: [
        // Full-screen map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target:
                widget.fromAddAddress
                    ? LatLng(
                      locationController.position.latitude,
                      locationController.position.longitude,
                    )
                    : _initialPosition,
            zoom: 16,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
          myLocationButtonEnabled: false,
          onMapCreated: (GoogleMapController mapController) {
            _mapController = mapController;
            if (!widget.fromAddAddress &&
                widget.route != RouteHelper.onBoarding) {
              Get.find<LocationController>().getCurrentLocation(
                false,
                mapController: mapController,
              );
            }
          },
          scrollGesturesEnabled: !(Get.isDialogOpen ?? false),
          zoomControlsEnabled: false,
          onCameraMove: (CameraPosition cameraPosition) {
            _cameraPosition = cameraPosition;
          },
          onCameraMoveStarted: () {
            locationController.disableButton();
          },
          onCameraIdle: () {
            Get.find<LocationController>().updatePosition(
              _cameraPosition,
              false,
            );
          },
          style:
              Get.isDarkMode
                  ? Get.find<ThemeController>().darkMap
                  : Get.find<ThemeController>().lightMap,
        ),

        // Center pin marker with logo
        Center(
          child:
              !locationController.loading
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(
                              'assets/image/Group 3.png',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      CustomPaint(
                        size: const Size(20, 20),
                        painter: _PinTailPainter(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                          vertical: Dimensions.paddingSizeSmall,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraLarge,
                          ),
                        ),
                        child: Text(
                          'deliver_here'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  )
                  : CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
        ),

        // Top section with back and close buttons
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Column(
                children: [
                  CairoLocationSearchWidget(
                    mapController: _mapController,
                    pickedAddress: locationController.pickAddress,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom card with address and confirm button, with the my-location
        // button floating just above it so it never overlaps the card.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  right: Dimensions.paddingSizeDefault,
                  bottom: Dimensions.paddingSizeDefault,
                ),
                child: _buildCircularButton(
                  icon: Icons.my_location_rounded,
                  size: 48,
                  onTap:
                      () => Get.find<LocationController>().checkPermission(() {
                        Get.find<LocationController>().getCurrentLocation(
                          false,
                          mapController: _mapController,
                        );
                      }),
                ),
              ),
              _buildBottomCard(locationController),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 40,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(50),
      elevation: 4,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(50)),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: size / 2,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(LocationController locationController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Distance indicator

              // Address text
              Text(
                locationController.pickAddress ?? 'searching_address'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              // City, State, Zip - using a simplified version of the address
              if (locationController.pickAddress != null &&
                  locationController.pickAddress!.contains(','))
                Text(
                  locationController.pickAddress!
                      .split(',')
                      .skip(1)
                      .join(',')
                      .trim(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 12),
              // Near text

              // Select Location row

              // Confirm button
              _buildConfirmButton(locationController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(LocationController locationController) {
    // An out-of-zone spot is still selectable: the user has to be able to save
    // where they actually live, see the OUT OF ZONE treatment and browse.
    // Previously `buttonDisabled` (set from the zone check) made the button
    // dead here, so someone outside every zone could never leave this screen.
    // Ordering is gated later, at checkout, which is the right boundary.
    // Enabled as soon as the map has resolved an address for the pin. The
    // zone/geocode lookups re-fire on every pan, so gating on their loading
    // flags left the button permanently grey — the user could see their own
    // street and still not select it.
    final bool hasPin =
        locationController.pickPosition.latitude != 0 &&
        (locationController.pickAddress?.isNotEmpty ?? false);

    return CustomButton(
      // Always an ACTION, never a verdict. The old label read
      // "Service not available in this area" — indistinguishable from a
      // disabled dead end, even though selecting is allowed and out-of-zone
      // browsing is the intended experience. Coverage is communicated after
      // saving, by the OUT OF ZONE badge and the coming-soon banner.
      buttonText: 'select_location_here'.tr.toUpperCase(),
      onPressed:
          hasPin ? () => _onPickAddressButtonPressed(locationController) : null,
      isLoading: locationController.isLoading,
      height: 56,
      radius: 50,
    );
  }

  void _onPickAddressButtonPressed(LocationController locationController) {
    if (locationController.pickPosition.latitude != 0 &&
        locationController.pickAddress!.isNotEmpty) {
      if (widget.onPicked != null) {
        // No saved address yet is the NORMAL case on the entry gate — the `!`
        // here threw every time, which is the "Null check operator used on a
        // null value" spam in the logs.
        final AddressModel? existing =
            AddressHelper.getUserAddressFromSharedPref();
        AddressModel address = AddressModel(
          latitude: locationController.pickPosition.latitude.toString(),
          longitude: locationController.pickPosition.longitude.toString(),
          addressType: 'others',
          address: locationController.pickAddress,
          contactPersonName: existing?.contactPersonName,
          contactPersonNumber: existing?.contactPersonNumber,
        );
        widget.onPicked!(address);
        Get.back();
      } else if (widget.fromAddAddress) {
        if (widget.googleMapController != null) {
          widget.googleMapController!.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  locationController.pickPosition.latitude,
                  locationController.pickPosition.longitude,
                ),
                zoom: 16,
              ),
            ),
          );
          locationController.setAddAddressData();
        }
        Get.back();
      } else {
        AddressModel address = AddressModel(
          latitude: locationController.pickPosition.latitude.toString(),
          longitude: locationController.pickPosition.longitude.toString(),
          addressType: 'others',
          address: locationController.pickAddress,
        );

        if (widget.fromLandingPage) {
          if (!AuthHelper.isLoggedIn()) {
            Get.find<AuthController>().guestLogin().then((response) {
              if (response.isSuccess) {
                Get.find<ProfileController>().setForceFullyUserEmpty();
                Get.back();
                locationController.saveAddressAndNavigate(
                  address,
                  widget.fromSignUp,
                  widget.route,
                  widget.canRoute,
                  false,
                );
              }
            });
          } else {
            Get.back();
            locationController.saveAddressAndNavigate(
              address,
              widget.fromSignUp,
              widget.route,
              widget.canRoute,
              false,
            );
          }
        } else {
          locationController.saveAddressAndNavigate(
            address,
            widget.fromSignUp,
            widget.route,
            widget.canRoute,
            false,
          );
        }
      }
    } else {
      showCustomSnackBar('pick_an_address'.tr);
    }
  }

  Future<bool> _locationCheck() async {
    bool locationServiceEnabled = true;
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      locationServiceEnabled = false;
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      locationServiceEnabled = false;
    }
    return locationServiceEnabled;
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(size.width / 2, size.height)
          ..lineTo(size.width / 2 - 10, 0)
          ..lineTo(size.width / 2 + 10, 0)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
