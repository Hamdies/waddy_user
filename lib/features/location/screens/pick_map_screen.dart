import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart/features/location/widgets/cairo_location_search_widget.dart';

class PickMapScreen extends StatefulWidget {
  final bool fromSignUp;
  final bool fromAddAddress;
  final bool canRoute;
  final String? route;
  final GoogleMapController? googleMapController;
  final Function(AddressModel address)? onPicked;
  final bool fromLandingPage;
  const PickMapScreen({super.key,
    required this.fromSignUp, required this.fromAddAddress, required this.canRoute,
    required this.route, this.googleMapController, this.onPicked, this.fromLandingPage = false,
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

    if(widget.fromAddAddress) {
      Get.find<LocationController>().setPickData();
    }
    _initialPosition = LatLng(
      double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lat ?? '0'),
      double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lng ?? '0'),
    );
    _checkAlreadyLocationEnable();
  }

  _checkAlreadyLocationEnable() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.whileInUse) {
      locationAlreadyAllow = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: GetBuilder<LocationController>(builder: (locationController) {
        return ResponsiveHelper.isDesktop(context)
            ? _buildDesktopLayout(locationController)
            : _buildMobileLayout(locationController);
      }),
    );
  }

  Widget _buildMobileLayout(LocationController locationController) {
    return Stack(
      children: [
        // Full-screen map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.fromAddAddress
                ? LatLng(locationController.position.latitude, locationController.position.longitude)
                : _initialPosition,
            zoom: 16,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
          myLocationButtonEnabled: false,
          onMapCreated: (GoogleMapController mapController) {
            _mapController = mapController;
            if (!widget.fromAddAddress && widget.route != RouteHelper.onBoarding) {
              Get.find<LocationController>().getCurrentLocation(false, mapController: mapController);
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
            Get.find<LocationController>().updatePosition(_cameraPosition, false);
          },
          style: Get.isDarkMode ? Get.find<ThemeController>().darkMap : Get.find<ThemeController>().lightMap,
        ),

        // Center pin marker with logo
        Center(
          child: !locationController.loading
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
                            color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
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
              : CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),

        // Top section with back and close buttons
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
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

      

        // Bottom card with address and confirm button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomCard(locationController),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(LocationController locationController) {
    return Center(
      child: Container(
        height: 600,
        width: 700,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.fromAddAddress ? 'pick_address'.tr : 'pick_location'.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: CairoLocationSearchWidget(
                  mapController: _mapController,
                  pickedAddress: locationController.pickAddress,
                ),
              ),
              // Map
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: widget.fromAddAddress
                                ? LatLng(locationController.position.latitude, locationController.position.longitude)
                                : _initialPosition,
                            zoom: 16,
                          ),
                          minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
                          myLocationButtonEnabled: false,
                          onMapCreated: (GoogleMapController mapController) async {
                            _mapController = mapController;
                            if (!widget.fromAddAddress && widget.route != 'splash') {
                              Get.find<LocationController>().getCurrentLocation(false, mapController: mapController).then((value) async {
                                if (widget.fromLandingPage && !locationAlreadyAllow && await _locationCheck()) {
                                  _onPickAddressButtonPressed(locationController);
                                }
                              });
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
                            Get.find<LocationController>().updatePosition(_cameraPosition, false);
                          },
                          style: Get.isDarkMode ? Get.find<ThemeController>().darkMap : Get.find<ThemeController>().lightMap,
                        ),
                        Center(
                          child: !locationController.loading
                              ? Image.asset(Images.pickMarker, height: 50, width: 50)
                              : CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: _buildCircularButton(
                            icon: Icons.my_location_rounded,
                            onTap: () => Get.find<LocationController>().checkPermission(() {
                              Get.find<LocationController>().getCurrentLocation(false, mapController: _mapController);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom section
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildConfirmButton(locationController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(50),
      elevation: 4,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(LocationController locationController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          padding: const EdgeInsets.all(20),
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
              if (locationController.pickAddress != null && locationController.pickAddress!.contains(','))
                Text(
                  locationController.pickAddress!.split(',').skip(1).join(',').trim(),
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
    final bool isEnabled = !locationController.isLoading &&
        !locationController.buttonDisabled &&
        !locationController.loading;
    final bool inZone = locationController.inZone;

    return CustomButton(
      buttonText: inZone
          ? 'select_location_here'.tr.toUpperCase()
          : 'service_not_available_in_this_area'.tr,
      onPressed: isEnabled
          ? () => _onPickAddressButtonPressed(locationController)
          : null,
      isLoading: locationController.isLoading,
      height: 56,
      radius: 50,
    );
  }

  void _onPickAddressButtonPressed(LocationController locationController) {
    if(locationController.pickPosition.latitude != 0 && locationController.pickAddress!.isNotEmpty) {
      if(widget.onPicked != null) {
        AddressModel address = AddressModel(
          latitude: locationController.pickPosition.latitude.toString(),
          longitude: locationController.pickPosition.longitude.toString(),
          addressType: 'others', address: locationController.pickAddress,
          contactPersonName: AddressHelper.getUserAddressFromSharedPref()!.contactPersonName,
          contactPersonNumber: AddressHelper.getUserAddressFromSharedPref()!.contactPersonNumber,
        );
        widget.onPicked!(address);
        Get.back();
      }else if(widget.fromAddAddress) {
        if(widget.googleMapController != null) {
          widget.googleMapController!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(
            locationController.pickPosition.latitude, locationController.pickPosition.longitude,
          ), zoom: 16)));
          locationController.setAddAddressData();
        }
        Get.back();
      }else {
        AddressModel address = AddressModel(
          latitude: locationController.pickPosition.latitude.toString(),
          longitude: locationController.pickPosition.longitude.toString(),
          addressType: 'others', address: locationController.pickAddress,
        );

        if(widget.fromLandingPage) {
          if(!AuthHelper.isLoggedIn()) {
            Get.find<AuthController>().guestLogin().then((response) {
              if(response.isSuccess) {
                Get.find<ProfileController>().setForceFullyUserEmpty();
                Get.back();
                locationController.saveAddressAndNavigate(
                  address, widget.fromSignUp, widget.route, widget.canRoute, ResponsiveHelper.isDesktop(Get.context),
                );
              }
            });
          } else {
            Get.back();
            locationController.saveAddressAndNavigate(
              address, widget.fromSignUp, widget.route, widget.canRoute, ResponsiveHelper.isDesktop(context),
            );
          }
        }else {
          locationController.saveAddressAndNavigate(
            address, widget.fromSignUp, widget.route, widget.canRoute, ResponsiveHelper.isDesktop(context),
          );
        }
      }
    }else {
      showCustomSnackBar('pick_an_address'.tr);
    }
  }

  Future<bool> _locationCheck() async {
    bool locationServiceEnabled = true;
    LocationPermission permission = await Geolocator.checkPermission();

    if(permission == LocationPermission.denied) {
      locationServiceEnabled = false;
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.deniedForever) {
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 - 10, 0)
      ..lineTo(size.width / 2 + 10, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
