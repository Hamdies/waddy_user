import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/services.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waddy_app/helper/custom_validator.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';
import 'package:waddy_app/features/location/screens/pick_map_screen.dart';
import 'package:waddy_app/features/address/widgets/address_voice_directions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

/// Address details form: the location is already chosen (map strip up top,
/// "Change" reopens the picker), so this screen only collects what the rider
/// needs at the door — building/street, floor, apartment, directions, label.
class AddAddressScreen extends StatefulWidget {
  final bool fromCheckout;
  final bool fromRide;
  final AddressModel? address;
  final int? zoneId;
  final bool forGuest;
  final bool fromNavBar;
  const AddAddressScreen({
    super.key,
    required this.fromCheckout,
    required this.fromRide,
    this.address,
    this.zoneId,
    this.forGuest = false,
    this.fromNavBar = false,
  });

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  static const int _directionsMaxLength = 200;

  /// The map band between the header and the sheet. The sheet's rounded top
  /// overlaps its lower [_sheetOverlap]; the pin centres in what's left.
  static const double _mapHeight = 148;
  static const double _sheetOverlap = Dimensions.radiusLarge;

  static const double _pinSize = 36;
  static const double _pinTailHeight = 8;

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactPersonNameController =
      TextEditingController();
  final TextEditingController _contactPersonNumberController =
      TextEditingController();
  final TextEditingController _streetNumberController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _directionsController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _streetNode = FocusNode();
  final FocusNode _floorNode = FocusNode();
  final FocusNode _houseNode = FocusNode();
  final FocusNode _directionsNode = FocusNode();
  final FocusNode _nameNode = FocusNode();
  final FocusNode _numberNode = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  CameraPosition? _cameraPosition;
  late LatLng _initialPosition;
  bool _prefilledFromProfile = false;

  /// Latched, not derived live: deriving it from the controllers unmounted
  /// the receiver section under the keyboard the moment its last empty field
  /// got its first character.
  bool _showReceiverFields = false;

  /// Voice directions: a fresh recording on this device, or the saved note
  /// on the address being edited. [_voiceRemoved] clears the saved one.
  String? _voicePath;
  String? _voiceRemoteUrl;
  bool _voiceRemoved = false;

  /// Inline errors, set on save and cleared as soon as the field is edited.
  String? _streetError;
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _countryDialCode =
      Get.find<AuthController>().getUserCountryCode().isNotEmpty
          ? Get.find<AuthController>().getUserCountryCode()
          : CountryCode.fromCountryCode(
            Get.find<SplashController>().configModel.country!,
          ).dialCode;

  GoogleMapController? _mapController;

  /// The strip's native map view sometimes never draws on iOS: no tiles, no
  /// logo, just the screen behind it. Every gesture is off here, so the touch
  /// that would wake it never comes. [_mapGeneration] rebuilds the view when
  /// it hasn't reported in; [_mapNudge] forces the relayout a touch would.
  int _mapGeneration = 0;
  bool _mapCreated = false;
  double _mapNudge = 0;
  Timer? _mapWatchdog;
  static const int _maxMapRebuilds = 2;
  static const Duration _mapReportDeadline = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    initCall();
    _armMapWatchdog();

    if (widget.address != null) {
      splitPhoneNumber(widget.address!.contactPersonNumber!);
      _contactPersonNameController.text =
          widget.address!.contactPersonName ?? '';
      _emailController.text = widget.address!.email ?? '';
      _streetNumberController.text = widget.address!.streetNumber ?? '';
      _houseController.text = widget.address!.house ?? '';
      _floorController.text = widget.address!.floor ?? '';
      _directionsController.text = widget.address!.deliveryInstructions ?? '';
      _voiceRemoteUrl = widget.address!.voiceInstructionFullUrl;
      _showReceiverFields = _receiverIncomplete;
    } else {
      _showReceiverFields = widget.forGuest;
      _prefillFromProfile();
    }
    // The directions counter and focus ring read these; the rest only clear
    // their field's error.
    _directionsController.addListener(_refresh);
    _directionsNode.addListener(_refresh);
    _streetNumberController.addListener(() {
      if (_streetError != null) setState(() => _streetError = null);
    });
    _contactPersonNameController.addListener(() {
      if (_nameError != null) setState(() => _nameError = null);
    });
    _contactPersonNumberController.addListener(() {
      if (_phoneError != null) setState(() => _phoneError = null);
    });
    _emailController.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
  }

  void _refresh() => setState(() {});

  /// The receiver defaults to the account holder. The profile can still be
  /// loading on first build, so this also runs from the profile builder.
  void _prefillFromProfile() {
    if (_prefilledFromProfile || widget.address != null) return;
    final user = Get.find<ProfileController>().userInfoModel;
    if (user == null) return;
    _prefilledFromProfile = true;
    if (_contactPersonNameController.text.isEmpty) {
      _contactPersonNameController.text =
          '${user.fName ?? ''} ${user.lName ?? ''}'.trim();
    }
    if (_contactPersonNumberController.text.isEmpty && user.phone != null) {
      splitPhoneNumber(user.phone!);
    }
    if (_receiverIncomplete) _showReceiverFields = true;
  }

  @override
  void dispose() {
    _mapWatchdog?.cancel();
    _addressController.dispose();
    _contactPersonNameController.dispose();
    _contactPersonNumberController.dispose();
    _streetNumberController.dispose();
    _houseController.dispose();
    _floorController.dispose();
    _directionsController.dispose();
    _emailController.dispose();
    _streetNode.dispose();
    _floorNode.dispose();
    _houseNode.dispose();
    _directionsNode.dispose();
    _nameNode.dispose();
    _numberNode.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void initCall() {
    Get.find<LocationController>().setAddressTypeIndex(0, isUpdate: false);
    if (AuthHelper.isLoggedIn() &&
        Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }
    if (widget.address == null) {
      // Start where the user already is in the app, not the server default:
      // that default can be unset (0,0 — open ocean, a blank grey strip) and
      // the map sat on it for as long as GPS took, or for good if GPS failed.
      _initialPosition = _savedLocation ?? _configDefault;
    } else {
      Get.find<LocationController>().setUpdateAddress(widget.address!);
      _initialPosition = LatLng(
        double.parse(widget.address!.latitude ?? '0'),
        double.parse(widget.address!.longitude ?? '0'),
      );

      if (widget.address!.addressType == 'home') {
        Get.find<LocationController>().setAddressTypeIndex(0, isUpdate: false);
      } else if (widget.address!.addressType == 'office') {
        Get.find<LocationController>().setAddressTypeIndex(1, isUpdate: false);
      } else {
        Get.find<LocationController>().setAddressTypeIndex(2, isUpdate: false);
      }
    }
  }

  LatLng get _configDefault => LatLng(
    double.tryParse(
          Get.find<SplashController>().configModel.defaultLocation?.lat ?? '',
        ) ??
        0,
    double.tryParse(
          Get.find<SplashController>().configModel.defaultLocation?.lng ?? '',
        ) ??
        0,
  );

  /// The delivery location the app is currently using, if it has one.
  LatLng? get _savedLocation {
    final AddressModel? saved = AddressHelper.getUserAddressFromSharedPref();
    final double? lat = double.tryParse(saved?.latitude ?? '');
    final double? lng = double.tryParse(saved?.longitude ?? '');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  void splitPhoneNumber(String number) async {
    try {
      PhoneNumber phoneNumber = PhoneNumber.parse(number);
      _countryDialCode = '+${phoneNumber.countryCode}';
      _contactPersonNumberController.text = phoneNumber.international.substring(
        _countryDialCode!.length,
      );
    } catch (e) {
      debugPrint('number can\'t parse : $e');
    }
  }

  /// Guests have no profile to take the receiver from, and a profile without a
  /// name or phone can't satisfy the backend either — only then ask for it.
  bool get _receiverIncomplete =>
      widget.forGuest ||
      _contactPersonNameController.text.trim().isEmpty ||
      _contactPersonNumberController.text.trim().isEmpty;

  bool get _needsReceiverFields => _showReceiverFields;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.surfaceWarm,
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          // Filling controllers fires their setState listeners — not mid-build.
          if (!_prefilledFromProfile &&
              profileController.userInfoModel != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_prefillFromProfile);
            });
          }
          return GetBuilder<LocationController>(
            builder: (locationController) {
              _addressController.text = locationController.address!;
              return _buildLayout(locationController);
            },
          );
        },
      ),
    );
  }

  Widget _buildLayout(LocationController locationController) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double headerHeight = topInset + kToolbarHeight;
    // Keyboard up: the sheet slides over the map so the form gets that room
    // back. The map itself never resizes — a native view resized every frame
    // of an animation stutters.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          Get.isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned(
            top: headerHeight,
            left: 0,
            right: 0,
            height: _mapHeight,
            child: _buildMapStrip(locationController),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            top:
                keyboardOpen
                    ? headerHeight
                    : headerHeight + _mapHeight - _sheetOverlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSheet(locationController, flush: keyboardOpen),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: _buildHeader(topInset),
          ),
        ],
      ),
    );
  }

  /// Solid bar: the back button and the title never sit on map tiles, which
  /// is what made the clock and the back arrow hard to read before.
  Widget _buildHeader(double topInset) {
    final String title =
        widget.address != null ? 'edit_address'.tr : 'address_details'.tr;
    return Material(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: topInset,
          start: Dimensions.paddingSizeExtraSmall,
          end: Dimensions.paddingSizeDefault,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              constraints: const BoxConstraints(
                minWidth: Dimensions.minTapTarget,
                minHeight: Dimensions.minTapTarget,
              ),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: WaddyColors.primary,
                semanticLabel:
                    MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // MAP STRIP
  // ──────────────────────────────────────────────

  /// Read-only preview of the chosen spot. The map stays mounted (not a static
  /// image) because the picker moves this controller's camera when the user
  /// changes the location, and [onCameraIdle] re-geocodes from there.
  Widget _buildMapStrip(LocationController locationController) {
    // The sheet's top edge covers the band's bottom; padding moves the camera
    // target (and so the pin) to the centre of what stays visible.
    const double visible = _mapHeight - _sheetOverlap;
    const double pinHeight = _pinSize + _pinTailHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Stands in while the map loads — or if it never draws — so the strip
        // reads as a place, not a gap.
        const _MapPlaceholder(),
        GoogleMap(
          key: ValueKey(_mapGeneration),
          initialCameraPosition: CameraPosition(
            target: _initialPosition,
            zoom: 16,
          ),
          padding: EdgeInsets.only(bottom: _sheetOverlap + _mapNudge),
          zoomControlsEnabled: false,
          zoomGesturesEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          onTap: (_) => _openPicker(locationController),
          onCameraIdle: () {
            locationController.updatePosition(_cameraPosition, true);
          },
          onCameraMove: ((position) => _cameraPosition = position),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _onStripMapCreated();
            locationController.setMapController(controller);
            if (widget.address == null) {
              locationController.getCurrentLocation(
                true,
                mapController: controller,
                // GPS denied or slow: land on the saved location, not 0,0.
                defaultLatLng: _savedLocation,
              );
            }
          },
          style:
              Get.isDarkMode
                  ? Get.find<ThemeController>().darkMap
                  : Get.find<ThemeController>().lightMap,
        ),
        // Pin tip sits on the camera target — the visible band's centre.
        Positioned(
          top: visible / 2 - pinHeight,
          left: 0,
          right: 0,
          height: pinHeight,
          child: IgnorePointer(
            child: Center(
              child:
                  locationController.loading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: WaddyColors.primary,
                        ),
                      )
                      : _buildPin(),
            ),
          ),
        ),
        // The whole band opens the picker on tap, but nothing said so.
        PositionedDirectional(
          end: Dimensions.paddingSizeSmall,
          bottom: _sheetOverlap,
          child: _AdjustPinChip(onTap: () => _openPicker(locationController)),
        ),
      ],
    );
  }

  void _armMapWatchdog() {
    _mapWatchdog?.cancel();
    _mapWatchdog = Timer(_mapReportDeadline, () {
      if (!mounted || _mapCreated || _mapGeneration >= _maxMapRebuilds) return;
      debugPrint('[Waddy] address map never reported; rebuilding the view');
      setState(() => _mapGeneration++);
      _armMapWatchdog();
    });
  }

  void _onStripMapCreated() {
    _mapCreated = true;
    _mapWatchdog?.cancel();
    // One padding change after first frame pushes a native relayout — the
    // same thing a touch does for a view that came up blank.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _mapNudge = 1);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _mapNudge = 0);
    });
  }

  Widget _buildPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _pinSize,
          height: _pinSize,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: WaddyColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(Images.scratchCardLogo, fit: BoxFit.cover),
          ),
        ),
        CustomPaint(
          size: const Size(12, _pinTailHeight),
          painter: _PinTailPainter(color: WaddyColors.primary),
        ),
      ],
    );
  }

  Future<void> _openPicker(LocationController locationController) async {
    await Get.toNamed(
      RouteHelper.getPickMapRoute('add-address', false),
      arguments: PickMapScreen(
        fromAddAddress: true,
        fromSignUp: false,
        googleMapController: _mapController ?? locationController.mapController,
        route: null,
        canRoute: false,
      ),
    );
    if (!mounted) return;
    // The picker already committed the new spot to the controller; bring this
    // map there too. Its move of our camera happened while we were offscreen,
    // and on iOS that isn't guaranteed to land — or to have happened at all,
    // if this map hadn't been created yet.
    final Position picked = locationController.position;
    if (picked.latitude == 0 && picked.longitude == 0) return;
    final LatLng target = LatLng(picked.latitude, picked.longitude);
    final LatLng? current = _cameraPosition?.target;
    if (current != null &&
        (current.latitude - target.latitude).abs() < 0.00005 &&
        (current.longitude - target.longitude).abs() < 0.00005) {
      return;
    }
    locationController.expectIdleAt(target.latitude, target.longitude);
    _mapController
        ?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16),
          ),
        )
        .catchError((_) {});
  }

  // ──────────────────────────────────────────────
  // SHEET
  // ──────────────────────────────────────────────

  /// [flush]: the sheet has slid up against the header, where rounded
  /// corners would show slivers of map.
  Widget _buildSheet(
    LocationController locationController, {
    bool flush = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      // Scrolled content stays inside the rounded top instead of showing
      // through its corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(flush ? 0 : Dimensions.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            // Tap anywhere off a field to close the keyboard. The directions
            // box and the receiver fields had no other way out on iOS.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeLarge,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeLarge,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _buildLocationCard(locationController),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  _LineField(
                    label: 'address_details'.tr,
                    hint: 'address_details_hint'.tr,
                    controller: _streetNumberController,
                    focusNode: _streetNode,
                    nextFocus: _floorNode,
                    inputType: TextInputType.streetAddress,
                    errorText: _streetError,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LineField(
                          label: 'floor_no'.tr,
                          hint: 'floor_hint'.tr,
                          controller: _floorController,
                          focusNode: _floorNode,
                          nextFocus: _houseNode,
                          // Free text: floors here are also أرضي, روف, ميزانين.
                          inputType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeDefault),
                      Expanded(
                        child: _LineField(
                          label: 'apartment_no'.tr,
                          hint: 'apartment_hint'.tr,
                          controller: _houseController,
                          focusNode: _houseNode,
                          // Last of the quick fields: "Done" closes the
                          // keyboard. It used to jump into the directions box,
                          // which sat under the keyboard with no way out.
                          inputType: TextInputType.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  _buildDirections(),
                  if (_needsReceiverFields) ...[
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                    _buildReceiverFields(),
                  ],
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  _SectionLabel('save_as'.tr),
                  const SizedBox(height: Dimensions.paddingSizeMedium),
                  _buildAddressTypeChips(locationController),
                ],
              ),
            ),
          ),
          _buildSaveBar(locationController),
        ],
      ),
    );
  }

  /// The chosen spot and why the fields below matter, as one mint card: the
  /// tint is the brand's structural colour here, anchoring "where" before
  /// the form asks "which door". The tip used to be an amber box, which read
  /// as a warning and was the loudest colour on the screen.
  Widget _buildLocationCard(LocationController locationController) {
    final fullAddress = _addressController.text;
    String shortName = fullAddress;
    String detailAddress = '';

    // Arabic geocodes separate with "،", not ",".
    final RegExp separator = RegExp('[,،]');
    final int cut = fullAddress.indexOf(separator);
    if (cut > 0) {
      shortName = fullAddress.substring(0, cut).trim();
      detailAddress = fullAddress.substring(cut + 1).trim();
    }

    return Container(
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.mintSurfaceDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Dimensions.paddingSizeMedium,
              Dimensions.paddingSizeMedium,
              Dimensions.paddingSizeExtraSmall,
              Dimensions.paddingSizeMedium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: Dimensions.paddingSizeExtremeLarge,
                  height: Dimensions.paddingSizeExtremeLarge,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: WaddyColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLocation01,
                    color: WaddyColors.mint,
                    size:
                        Dimensions.paddingSizeDefault +
                        Dimensions.paddingSizeExtraSmall,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortName.isNotEmpty
                            ? shortName
                            : 'searching_address'.tr,
                        style: waddyBold.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          color: WaddyColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detailAddress.isNotEmpty) ...[
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        Text(
                          detailAddress,
                          style: waddyMedium.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: WaddyColors.inkLightOnMint,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openPicker(locationController),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeMedium,
                    ),
                    minimumSize: const Size(
                      Dimensions.minTapTarget,
                      Dimensions.minTapTarget,
                    ),
                    foregroundColor: WaddyColors.mintInk,
                  ),
                  child: Text(
                    'change'.tr,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: WaddyColors.mintInk,
                      decoration: TextDecoration.underline,
                      decorationColor: WaddyColors.mintInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: WaddyColors.mintSurfaceDeep),
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: Dimensions.paddingSizeExtremeLarge,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMotorbike02,
                    color: WaddyColors.mintInk,
                    size: Dimensions.paddingSizeLarge,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Text(
                    'detailed_address_helps_rider'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: WaddyColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirections() {
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ?? WaddyColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('${'directions_to_reach'.tr} (${'optional'.tr})'),
        // Guests have no saved address for a voice note to live on.
        if (!widget.forGuest) ...[
          const SizedBox(height: Dimensions.paddingSizeLarge),
          AddressVoiceDirections(
            localPath: _voicePath,
            remoteUrl: _voiceRemoved ? null : _voiceRemoteUrl,
            onRecorded: (path) => setState(() => _voicePath = path),
            onDeleted:
                () => setState(() {
                  _voicePath = null;
                  _voiceRemoved = true;
                }),
          ),
        ],
        const SizedBox(height: Dimensions.paddingSizeMedium),
        Stack(
          children: [
            TextField(
              controller: _directionsController,
              focusNode: _directionsNode,
              minLines: 3,
              maxLines: 3,
              maxLength: _directionsMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              // A "Done" key instead of a newline, so the keyboard can close.
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: WaddyColors.primary,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: ink,
              ),
              decoration: waddyFieldDecoration(
                context,
                hint: 'directions_hint'.tr,
                hintSize: Dimensions.fontSizeDefault,
                filled: _directionsController.text.trim().isNotEmpty,
                // Room under the last line for the counter.
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeExtremeLarge,
                ),
              ),
            ),
            PositionedDirectional(
              end: Dimensions.paddingSizeDefault,
              bottom: Dimensions.paddingSizeMedium,
              child: Text(
                '${_directionsController.text.characters.length}/$_directionsMaxLength',
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.inkLight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiverFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('receiver_details'.tr),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        _withError(
          error: _nameError,
          child: CustomTextField(
            labelText: 'contact_person_name'.tr,
            titleText: 'write_name'.tr,
            inputType: TextInputType.name,
            controller: _contactPersonNameController,
            focusNode: _nameNode,
            nextFocus: _numberNode,
            capitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        _withError(
          error: _phoneError,
          child: CustomTextField(
            labelText: 'contact_person_number'.tr,
            titleText: 'write_number'.tr,
            controller: _contactPersonNumberController,
            focusNode: _numberNode,
            nextFocus: widget.forGuest ? _emailFocus : null,
            inputAction:
                widget.forGuest ? TextInputAction.next : TextInputAction.done,
            inputType: TextInputType.phone,
            isPhone: true,
            onCountryChanged: (CountryCode countryCode) {
              _countryDialCode = countryCode.dialCode;
            },
            countryDialCode:
                _countryDialCode ??
                Get.find<LocalizationController>().locale.countryCode,
          ),
        ),
        if (widget.forGuest) ...[
          const SizedBox(height: Dimensions.paddingSizeMedium),
          _withError(
            error: _emailError,
            child: CustomTextField(
              labelText: 'email'.tr,
              titleText: 'enter_email'.tr,
              inputType: TextInputType.emailAddress,
              controller: _emailController,
              focusNode: _emailFocus,
              inputAction: TextInputAction.done,
            ),
          ),
        ],
      ],
    );
  }

  /// CustomTextField only reports errors through a Form validator, and this
  /// screen has no Form — the error line sits under it instead.
  Widget _withError({required Widget child, String? error}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child, if (error != null) _FieldError(error)],
    );
  }

  // ──────────────────────────────────────────────
  // ADDRESS TYPE CHIPS
  // ──────────────────────────────────────────────

  Widget _buildAddressTypeChips(LocationController locationController) {
    final List<String> labels = [
      'home'.tr,
      'office'.tr,
      'address_label_other'.tr,
    ];
    final List<List<List<dynamic>>> icons = [
      HugeIcons.strokeRoundedHome01,
      HugeIcons.strokeRoundedBriefcase01,
      HugeIcons.strokeRoundedLocation01,
    ];
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ?? WaddyColors.ink;

    return Wrap(
      spacing: Dimensions.paddingSizeSmall,
      runSpacing: Dimensions.paddingSizeSmall,
      children: List.generate(3, (index) {
        final isSelected = locationController.addressTypeIndex == index;
        return Semantics(
          selected: isSelected,
          button: true,
          child: Material(
            color:
                isSelected
                    ? WaddyColors.mintSurface
                    : Theme.of(context).cardColor,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? WaddyColors.primary : WaddyColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => locationController.setAddressTypeIndex(index),
              customBorder: const StadiumBorder(),
              child: Container(
                height: Dimensions.minTapTarget,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: icons[index],
                      size: 16,
                      color: isSelected ? WaddyColors.primary : ink,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(
                      labels[index],
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: isSelected ? WaddyColors.primary : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────
  // SAVE
  // ──────────────────────────────────────────────

  Widget _buildSaveBar(LocationController locationController) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeDefault + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: GetBuilder<AddressController>(
        builder: (addressController) {
          return CustomButton(
            isLoading: addressController.isLoading,
            buttonText:
                widget.forGuest
                    ? 'done'.tr
                    : widget.address == null
                    ? 'save_address_details'.tr
                    : 'update_address'.tr,
            // Always pressable: a tap on an incomplete form points at the
            // field that's missing instead of leaving a dead button to decode.
            onPressed: () => _onSaveOrUpdateButtonPressed(locationController),
          );
        },
      ),
    );
  }

  void _onSaveOrUpdateButtonPressed(
    LocationController locationController,
  ) async {
    if (_addressController.text.isEmpty) {
      // No field to attach this to — the location card is still resolving.
      showCustomSnackBar('please_enter_the_delivery_address'.tr);
      return;
    }
    String numberWithCountryCode =
        _countryDialCode! + _contactPersonNumberController.text;
    PhoneValid phoneValid = await CustomValidator.isPhoneValid(
      numberWithCountryCode,
    );
    numberWithCountryCode = phoneValid.phone;
    if (!mounted) return;
    if (!_validate(phoneValid.isValid)) return;
    FocusScope.of(context).unfocus();

    final AddressModel addressModel = _prepareAddressModel(locationController);

    if (widget.forGuest) {
      addressModel.email = _emailController.text;
      Get.back(result: addressModel);
    } else {
      if (widget.address == null) {
        _addAddress(addressModel);
      } else {
        _updateAddress(addressModel);
      }
    }
  }

  /// Marks every failing field at once, in screen order, and focuses the
  /// first. The receiver section is revealed when a prefilled profile value
  /// is what failed, so the error is never on a field the user can't see.
  bool _validate(bool phoneIsValid) {
    final String name = _contactPersonNameController.text.trim();
    final String phone = _contactPersonNumberController.text.trim();
    final String? streetError =
        _streetNumberController.text.trim().isEmpty
            ? 'enter_building_street'.tr
            : null;
    final String? nameError =
        name.isEmpty ? 'please_enter_the_contact_person_name'.tr : null;
    final String? phoneError =
        phone.isEmpty
            ? 'please_enter_the_phone_number'.tr
            : !phoneIsValid
            ? 'invalid_phone_number'.tr
            : null;
    final String? emailError =
        widget.forGuest && _emailController.text.trim().isEmpty
            ? 'please_enter_contact_person_email'.tr
            : null;

    setState(() {
      _streetError = streetError;
      _nameError = nameError;
      _phoneError = phoneError;
      _emailError = emailError;
      if (nameError != null || phoneError != null || emailError != null) {
        _showReceiverFields = true;
      }
    });

    final FocusNode? first =
        streetError != null
            ? _streetNode
            : nameError != null
            ? _nameNode
            : phoneError != null
            ? _numberNode
            : emailError != null
            ? _emailFocus
            : null;
    if (first == null) return true;
    HapticFeedback.lightImpact();
    // After the frame, so a just-revealed receiver field exists to focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) first.requestFocus();
    });
    return false;
  }

  AddressModel _prepareAddressModel(LocationController locationController) {
    String? addressType =
        locationController.addressTypeList[locationController.addressTypeIndex];
    // A custom label saved by the old form survives an edit that keeps "Other".
    final String? existingType = widget.address?.addressType;
    if (locationController.addressTypeIndex == 2 &&
        existingType != null &&
        !locationController.addressTypeList.contains(existingType)) {
      addressType = existingType;
    }
    final String directions = _directionsController.text.trim();
    return AddressModel(
      id: widget.address?.id,
      addressType: addressType,
      contactPersonName: _contactPersonNameController.text,
      contactPersonNumber:
          _countryDialCode! + _contactPersonNumberController.text,
      address: _addressController.text,
      latitude: locationController.position.latitude.toString(),
      longitude: locationController.position.longitude.toString(),
      zoneId: locationController.zoneID,
      streetNumber: _streetNumberController.text.trim(),
      house: _houseController.text.trim(),
      floor: _floorController.text.trim(),
      deliveryInstructions: directions.isEmpty ? null : directions,
      voiceInstructionPath: _voicePath,
      // A new recording replaces the saved note server-side on its own.
      removeVoiceInstruction:
          _voiceRemoved && _voicePath == null && _voiceRemoteUrl != null,
    );
  }

  void _addAddress(AddressModel addressModel) {
    Get.find<AddressController>()
        .addAddress(addressModel, widget.fromCheckout, widget.zoneId)
        .then((response) {
          if (response.isSuccess && !widget.fromCheckout) {
            widget.fromNavBar
                ? Get.back()
                : Get.offNamed(RouteHelper.getAddressRoute());
            showCustomSnackBar(
              'new_address_added_successfully'.tr,
              isError: false,
            );
          } else if (response.isSuccess && widget.fromCheckout) {
            AddressModel? addressModel;
            try {
              addressModel = Get.find<AddressController>().addressList![0];
            } catch (e, s) {
              swallow('read first saved address', e, s);
            }
            Get.back(result: addressModel);
            showCustomSnackBar(response.message, isError: false);
          } else if (widget.fromRide) {
            Get.back();
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }

  void _updateAddress(AddressModel addressModel) {
    Get.find<AddressController>()
        .updateAddress(addressModel, widget.address!.id)
        .then((response) {
          if (response.isSuccess) {
            Get.back();
            showCustomSnackBar(response.message, isError: false);
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }
}

/// Small bold field caption. Tracking is Latin-only: letter-spacing breaks
/// the joins between Arabic letters.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool isLtr = Get.find<LocalizationController>().isLtr;
    return Text(
      isLtr ? text.toUpperCase() : text,
      style: waddyBold.copyWith(
        fontSize: Dimensions.fontSizeExtraSmall,
        letterSpacing: isLtr ? 0.5 : 0,
        color: WaddyColors.inkLight,
      ),
    );
  }
}

/// Single-line field in the Waddy frame, captioned above.
class _LineField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final TextInputType inputType;
  final String? errorText;

  const _LineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.inputType,
    this.nextFocus,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ?? WaddyColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final bool filled = value.text.trim().isNotEmpty;
            // The visible caption is a sibling Text; without this label a
            // screen reader names the field by its example ("e.g. 3").
            return Semantics(
              label: label,
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: inputType,
                textInputAction:
                    nextFocus != null
                        ? TextInputAction.next
                        : TextInputAction.done,
                onSubmitted: (_) => nextFocus?.requestFocus(),
                cursorColor: WaddyColors.primary,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: ink,
                ),
                decoration: waddyFieldDecoration(
                  context,
                  hint: hint,
                  hintSize: Dimensions.fontSizeLarge,
                  filled: filled,
                  error: errorText != null,
                ),
              ),
            );
          },
        ),
        if (errorText != null) _FieldError(errorText!),
      ],
    );
  }
}

/// Waddy's field frame, the same box as [CustomTextField]: 12 radius, card
/// fill, a faint 1.5 border at rest, a 2.5 teal ring while focused, coral on
/// error. Once a field holds a value its border turns [WaddyColors.mintInk],
/// so a filled form reads as mint, top to bottom.
InputDecoration waddyFieldDecoration(
  BuildContext context, {
  required String hint,
  required double hintSize,
  required bool filled,
  bool error = false,
  EdgeInsetsGeometry padding = const EdgeInsets.all(
    Dimensions.paddingSizeDefault,
  ),
}) {
  OutlineInputBorder frame(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: waddyRegular.copyWith(
      fontSize: hintSize,
      color: WaddyColors.inkMuted,
    ),
    filled: true,
    fillColor: Theme.of(context).cardColor,
    isDense: true,
    counterText: '',
    contentPadding: padding,
    enabledBorder: frame(
      error
          ? WaddyColors.error
          : filled
          ? WaddyColors.mintInk
          : WaddyColors.divider,
      1.5,
    ),
    focusedBorder: frame(error ? WaddyColors.error : WaddyColors.primary, 2.5),
  );
}

/// Coral error line under a field. A live region, so a screen reader hears
/// it when the save tap puts it there.
class _FieldError extends StatelessWidget {
  final String text;
  const _FieldError(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              color: WaddyColors.coralInk,
              size: Dimensions.paddingSizeDefault,
              strokeWidth: 2,
            ),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Expanded(
              child: Text(
                text,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.coralInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Adjust pin" on the map band. Visually compact; the transparent margin
/// around it carries the hit area to the 48 pt floor.
class _AdjustPinChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AdjustPinChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'adjust_pin'.tr,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowDeep,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedLocation01,
                    color: WaddyColors.mintInk,
                    size: Dimensions.paddingSizeDefault,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                  Text(
                    'adjust_pin'.tr,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: WaddyColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mint street sketch behind the live map. Visible while tiles load, and
/// the whole strip if the native view never draws.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: WaddyColors.mintSurface,
      child: CustomPaint(painter: _StreetSketchPainter()),
    );
  }
}

class _StreetSketchPainter extends CustomPainter {
  const _StreetSketchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint road =
        Paint()
          ..color = WaddyColors.surface
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
    final Paint lane =
        Paint()
          ..color = WaddyColors.mintSurfaceDeep
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
    final double w = size.width, h = size.height;
    canvas.drawLine(Offset(-20, h * 0.62), Offset(w + 20, h * 0.48), road);
    canvas.drawLine(Offset(w * 0.68, -10), Offset(w * 0.62, h + 10), road);
    canvas.drawLine(Offset(w * 0.18, -10), Offset(w * 0.3, h + 10), lane);
    canvas.drawLine(Offset(-20, h * 0.25), Offset(w * 0.6, h * 0.18), lane);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          ..lineTo(0, 0)
          ..lineTo(size.width, 0)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
