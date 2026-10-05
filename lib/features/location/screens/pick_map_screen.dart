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
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository.dart'
    show kUnknownAddressSentinel;
import 'package:waddy_app/features/location/helpers/pick_address_format.dart';
import 'package:waddy_app/features/location/widgets/cairo_location_search_widget.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    // As the entry gate there is no valid screen behind this one — backing out
    // would land on a home with no delivery address. Picking is the only exit.
    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        // No endDrawer. A full MenuDrawer was built here with no opener
        // anywhere in the file — unreachable UI sitting on the right edge,
        // which is where an RTL user's back-swipe lives.
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
          // Was capped at 16, but `LocationController.setLocation` animates a
          // searched result to 17 — the map clamped it straight back, so a
          // search landed less zoomed than the code asked for. 16 is also too
          // far out to tell two adjacent buildings apart on a Cairo side
          // street, which is exactly the precision this screen exists to
          // capture. 19 still stops short of the tile-detail ceiling.
          minMaxZoomPreference: const MinMaxZoomPreference(0, 19),
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

        // Center pin marker with logo.
        //
        // `Center` centers whatever it is given, so centering the WHOLE
        // column (mark + tail + label) put the map's true coordinate at the
        // column's midpoint — roughly 40pt above the tail's tip. The pin
        // pointed at a place the app was not going to select. Everything
        // below the tail tip is therefore translated out of the centered box
        // with a FractionalTranslation, which leaves the tip itself on the
        // exact center point.
        IgnorePointer(
          child: Center(
            child: FractionalTranslation(
              // Shift up by half the stack's own height so the bottom edge
              // (the tail tip) lands on center.
              translation: const Offset(0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'deliver_here'.tr,
                    child: Container(
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
                            // Decorative: the Semantics above already names
                            // the pin, so the raw asset must not be announced
                            // a second time as an unlabeled image.
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  // The pin stays put while the map moves. This used to be
                  // swapped for a CircularProgressIndicator on every pan,
                  // which deleted the subject of the interaction the moment
                  // the user interacted with it. A settling dot under the
                  // tip carries the same "working" signal without removing
                  // the thing the user is aiming.
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _PinTailPainter(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Settling indicator, pinned just below the tail tip.
        if (locationController.loading)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.paddingSizeLarge,
                ),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),

        // Top section: escape hatch (or the gate's own explanation) + search
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back and search share one row: they are both chrome over
                  // the map, and stacking them spent a whole band of vertical
                  // space on a 48pt button. `crossAxisAlignment: start` keeps
                  // the button aligned to the FIELD, not to the field plus its
                  // results dropdown, which grows downward underneath it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 10 of the 11 entry points into this screen are
                      // dismissible, and none of them drew a way out: the old
                      // comment here promised "back and close buttons" that
                      // did not exist, leaving the user to discover the OS
                      // gesture. The single mandatory entry
                      // (location_gate_helper) uses offAllNamed, so there
                      // genuinely is nowhere to go back to — that one drops
                      // the button and lets the search field take the row.
                      if (!widget.isMandatory) ...[
                        _buildCircularButton(
                          icon: Icons.arrow_back_rounded,
                          semanticLabel: 'back'.tr,
                          onTap: () => Get.back(),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                      ],
                      Expanded(
                        child: CairoLocationSearchWidget(
                          mapController: _mapController,
                          pickedAddress: locationController.pickAddress,
                        ),
                      ),
                    ],
                  ),
                  // The gate has no back button, so its explanation sits under
                  // the search row rather than competing with it.
                  if (widget.isMandatory) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeDefault,
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraLarge,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'where_should_we_deliver'.tr,
                        style: waddyBold.copyWith(color: WaddyColors.primary),
                      ),
                    ),
                  ],
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
                // Directional: the Column above aligns to `end`, which DOES
                // flip under RTL, while a physical `right:` does not — so in
                // Arabic the button slid to the left edge and kept its inset
                // stranded on the right.
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                  bottom: Dimensions.paddingSizeDefault,
                ),
                child: _buildCircularButton(
                  icon: Icons.my_location_rounded,
                  semanticLabel: 'use_current_location'.tr,
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
    required String semanticLabel,
    // Was 40, i.e. under the 48pt touch floor for every caller that did not
    // override it. The floor is the default now.
    double size = Dimensions.minTapTarget,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
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
      ),
    );
  }

  Widget _buildBottomCard(LocationController locationController) {
    final String? raw = locationController.pickAddress;
    final bool lookupFailed = raw == kUnknownAddressSentinel;
    final bool hasAddress = raw != null && raw.isNotEmpty && !lookupFailed;
    final split =
        hasAddress
            ? splitPickAddress(raw, fallback: 'searching_address'.tr)
            : null;

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
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusChip(locationController, lookupFailed),

              if (lookupFailed) ...[
                // A failed geocode is a state with a recovery, not a name.
                // Printing the raw sentinel made "Unknown Location Found" the
                // headline — untranslated English, in an Arabic UI, saveable
                // as the permanent label of the user's home.
                Text(
                  'address_lookup_failed'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: WaddyColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  'address_lookup_failed_hint'.tr,
                  style: waddyRegular.copyWith(color: WaddyColors.inkLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(
                  split?.headline ?? 'searching_address'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: WaddyColors.ink,
                  ),
                  // Bounded so a long address cannot push the confirm button
                  // off the bottom of the card at large OS font scales.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (split != null && split.detail.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    split.detail,
                    style: waddyRegular.copyWith(color: WaddyColors.inkLight),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],

              const SizedBox(height: Dimensions.paddingSizeDefault),
              // Confirm button
              _buildConfirmButton(locationController),
            ],
          ),
        ),
      ),
    );
  }

  /// The coverage verdict, which the controller has computed on every pan all
  /// along and the screen rendered nowhere.
  ///
  /// Out of zone was pixel-identical to in zone here, so a user outside the
  /// delivery area confirmed, browsed, built a cart, and only met the refusal
  /// at add-to-cart. Keeping the BUTTON enabled is right — you must be able to
  /// save where you actually live — but that argument was used to justify
  /// showing nothing at all, which is a different and worse decision.
  ///
  /// This is also where mint does structural work on the card: the in-zone
  /// state is a mint-tinted chip with mint ink, so the brand's colour carries
  /// the screen's most important status rather than decorating a panel.
  Widget _buildStatusChip(
    LocationController locationController,
    bool lookupFailed,
  ) {
    final ({Color bg, Color fg, IconData icon, String label})? chip;

    if (lookupFailed) {
      // coralInk on errorSurface is 5.01:1; `error` itself is 3.34:1 there,
      // under the floor for chip-sized text.
      chip = (
        bg: WaddyColors.errorSurface,
        fg: WaddyColors.coralInk,
        icon: Icons.error_outline_rounded,
        label: 'address_lookup_failed_chip'.tr,
      );
    } else if (locationController.loading ||
        locationController.pickAddress == null) {
      chip = null;
    } else if (locationController.inZone) {
      chip = (
        bg: WaddyColors.mintSurface,
        fg: WaddyColors.mintInk,
        icon: Icons.check_circle_rounded,
        label: 'we_deliver_here'.tr,
      );
    } else {
      chip = (
        bg: WaddyColors.errorSurface,
        fg: WaddyColors.coralInk,
        icon: Icons.location_off,
        label: 'out_of_zone_pill'.tr,
      );
    }

    if (chip == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
          vertical: Dimensions.paddingSizeExtraSmall,
        ),
        decoration: BoxDecoration(
          color: chip.bg,
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, size: 16, color: chip.fg),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Flexible(
              child: Text(
                chip.label,
                style: waddyMedium.copyWith(
                  color: chip.fg,
                  fontSize: Dimensions.fontSizeSmall,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
    // A failed geocode returns the untranslated [kUnknownAddressSentinel],
    // which is non-empty — so the old check ENABLED the button on it and let
    // the user save "Unknown Location Found" as the permanent name of where
    // they live. A sentinel is not an address.
    final String? address = locationController.pickAddress;
    final bool hasPin =
        locationController.pickPosition.latitude != 0 &&
        address != null &&
        address.isNotEmpty &&
        address != kUnknownAddressSentinel;

    return CustomButton(
      // Always an ACTION, never a verdict. The old label read
      // "Service not available in this area" — indistinguishable from a
      // disabled dead end, even though selecting is allowed and out-of-zone
      // browsing is the intended experience. Coverage is communicated after
      // saving, by the OUT OF ZONE badge and the coming-soon banner. Coverage
      // now also shows BEFORE saving, on the status chip above.
      //
      // displayCaps() rather than raw toUpperCase(): Arabic has no uppercase,
      // and the project already routes every caps treatment through that
      // helper (121 call sites) so the Arabic locale collapses to plain text.
      buttonText: displayCaps('select_location_here'.tr),
      onPressed:
          hasPin ? () => _onPickAddressButtonPressed(locationController) : null,
      isLoading: locationController.isLoading,
      radius: 50,
    );
  }

  void _onPickAddressButtonPressed(LocationController locationController) {
    // `hasPin` already gates `onPressed` on exactly this condition, so the
    // old `else` here (a "pick an address" snackbar) could never run and the
    // surviving `pickAddress!` bang could never be reached with a null — but
    // it was still a bang in the method whose own comment documents fixing
    // that crash class. Guard and return instead.
    final String? address = locationController.pickAddress;
    if (locationController.pickPosition.latitude == 0 ||
        address == null ||
        address.isEmpty ||
        address == kUnknownAddressSentinel) {
      showCustomSnackBar('pick_an_address'.tr);
      return;
    }

    {
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
        // Commit the pick first, whatever state the address screen's map is
        // in. This used to run only when that map had handed over a
        // controller — so when its map hadn't loaded, the pick was dropped
        // and "Change" changed nothing. The address screen re-centres its own
        // map on return, so this move is only a head start.
        locationController.setAddAddressData();
        widget.googleMapController
            ?.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(
                    locationController.pickPosition.latitude,
                    locationController.pickPosition.longitude,
                  ),
                  zoom: 16,
                ),
              ),
            )
            .catchError((_) {});
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
    }
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
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      // Was an unconditional `false` on a painter that takes a color: the tail
      // would have silently kept its old paint if the pin were ever tinted by
      // state (in-zone vs out-of-zone).
      oldDelegate.color != color;
}
