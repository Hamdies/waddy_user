import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import 'package:waddy_app/features/location/widgets/permission_dialog_widget.dart';
import 'package:waddy_app/features/location/widgets/cairo_location_search_widget.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/custom_validator.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/location/screens/pick_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

class AddAddressScreen extends StatefulWidget {
  final bool fromCheckout;
  final bool fromRide;
  final AddressModel? address;
  final int? zoneId;
  final bool forGuest;
  final bool fromNavBar;
  const AddAddressScreen({super.key, required this.fromCheckout, required this.fromRide, this.address, this.zoneId, this.forGuest = false, this.fromNavBar = false});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactPersonNameController = TextEditingController();
  final TextEditingController _contactPersonNumberController = TextEditingController();
  final TextEditingController _streetNumberController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _addressNode = FocusNode();
  final FocusNode _levelNode = FocusNode();
  final FocusNode _nameNode = FocusNode();
  final FocusNode _numberNode = FocusNode();
  final FocusNode _streetNode = FocusNode();
  final FocusNode _houseNode = FocusNode();
  final FocusNode _floorNode = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  CameraPosition? _cameraPosition;
  late LatLng _initialPosition;
  bool _otherSelect = false;
  String? _countryDialCode = Get.find<AuthController>().getUserCountryCode().isNotEmpty ? Get.find<AuthController>().getUserCountryCode()
      : CountryCode.fromCountryCode(Get.find<SplashController>().configModel!.country!).dialCode;

  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    initCall();

    if(widget.address != null) {
      splitPhoneNumber(widget.address!.contactPersonNumber!);
      _contactPersonNameController.text = widget.address!.contactPersonName ?? '';
      _emailController.text = widget.address!.email ?? '';
      _streetNumberController.text = widget.address!.streetNumber ?? '';
      _houseController.text = widget.address!.house ?? '';
      _floorController.text = widget.address!.floor ?? '';
    } else if(Get.find<ProfileController>().userInfoModel != null && _contactPersonNameController.text.isEmpty) {
      _contactPersonNameController.text = '${Get.find<ProfileController>().userInfoModel!.fName} ${Get.find<ProfileController>().userInfoModel!.lName}';
      splitPhoneNumber(Get.find<ProfileController>().userInfoModel!.phone!);
    }
  }

  @override
  void dispose() {
    _levelController.dispose();
    _addressController.dispose();
    _contactPersonNameController.dispose();
    _contactPersonNumberController.dispose();
    _streetNumberController.dispose();
    _houseController.dispose();
    _floorController.dispose();
    _emailController.dispose();
    _addressNode.dispose();
    _levelNode.dispose();
    _nameNode.dispose();
    _numberNode.dispose();
    _streetNode.dispose();
    _houseNode.dispose();
    _floorNode.dispose();
    _emailFocus.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void initCall() {
    Get.find<LocationController>().setAddressTypeIndex(0, isUpdate: false);
    if(AuthHelper.isLoggedIn() && Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }
    if(widget.address == null) {
      _initialPosition = LatLng(
        double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lat ?? '0'),
        double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lng ?? '0'),
      );
    } else {
      Get.find<LocationController>().setUpdateAddress(widget.address!);
      _initialPosition = LatLng(
        double.parse(widget.address!.latitude ?? '0'),
        double.parse(widget.address!.longitude ?? '0'),
      );

      if(widget.address!.addressType == 'home') {
        Get.find<LocationController>().setAddressTypeIndex(0, isUpdate: false);
      } else if (widget.address!.addressType == 'office') {
        Get.find<LocationController>().setAddressTypeIndex(1, isUpdate: false);
      } else {
        Get.find<LocationController>().setAddressTypeIndex(2, isUpdate: false);
        _levelController.text = widget.address!.addressType!;
        _otherSelect = true;
      }
    }
  }

  void splitPhoneNumber(String number) async {
    try {
      PhoneNumber phoneNumber = PhoneNumber.parse(number);
      _countryDialCode = '+${phoneNumber.countryCode}';
      _contactPersonNumberController.text = phoneNumber.international.substring(_countryDialCode!.length);
    } catch (e) {
      debugPrint('number can\'t parse : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      appBar: ResponsiveHelper.isDesktop(context) ? CustomAppBar(
        title: widget.forGuest ? 'set_address'.tr : widget.address == null ? 'add_new_address'.tr : 'update_address'.tr,
      ) : null,
      body: GetBuilder<ProfileController>(builder: (profileController) {
        return GetBuilder<LocationController>(builder: (locationController) {
          _addressController.text = locationController.address!;

          return ResponsiveHelper.isDesktop(context)
              ? _buildDesktopLayout(locationController)
              : _buildMobileLayout(locationController);
        });
      }),
    );
  }

  // ──────────────────────────────────────────────
  // MOBILE LAYOUT — Map-first with draggable sheet
  // ──────────────────────────────────────────────

  Widget _buildMobileLayout(LocationController locationController) {
    return Stack(
      children: [
        // Layer 1: Full-screen Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 16),
          minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
          zoomControlsEnabled: false,
          compassEnabled: false,
          indoorViewEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          onCameraIdle: () {
            locationController.updatePosition(_cameraPosition, true);
          },
          onCameraMove: ((position) => _cameraPosition = position),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            locationController.setMapController(controller);
            if (widget.address == null) {
              locationController.getCurrentLocation(true, mapController: controller);
            }
          },
          style: Get.isDarkMode ? Get.find<ThemeController>().darkMap : Get.find<ThemeController>().lightMap,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
            Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
          },
        ),

        // Layer 2: Center pin marker
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: !locationController.loading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
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
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              Images.scratchCardLogo,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      CustomPaint(
                        size: const Size(16, 16),
                        painter: _PinTailPainter(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  )
                : CircularProgressIndicator(color: Theme.of(context).primaryColor),
          ),
        ),

        // Layer 3: Top search bar + back button
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back_rounded, color: Theme.of(context).textTheme.bodyLarge?.color, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Search bar
                  Expanded(
                    child: CairoLocationSearchWidget(
                      mapController: _mapController ?? locationController.mapController,
                      pickedAddress: locationController.address,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Layer 4: "Use current location" button — positioned above the sheet
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.45 + 12,
          right: 16,
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            child: InkWell(
              onTap: () => _checkPermission(() {
                locationController.getCurrentLocation(true, mapController: _mapController ?? locationController.mapController);
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedGps01,
                      color: Theme.of(context).primaryColor,
                      size: 18,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'use_current_location'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer 5: Draggable bottom sheet with form
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.45,
          maxChildSize: 0.90,
          snap: true,
          snapSizes: const [0.45, 0.90],
          controller: _sheetController,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle
                  _buildDragHandle(),

                  // Delivery details header
                  _buildSectionHeader('delivery_details'.tr),

                  // Address display card
                  _buildAddressDisplayCard(locationController),

                  const SizedBox(height: 16),

                  // Street number
                  _buildSheetTextField(
                    controller: _streetNumberController,
                    focusNode: _streetNode,
                    nextFocus: _houseNode,
                    label: '${'street_number'.tr} (${'optional'.tr})',
                    hint: 'write_street_number'.tr,
                    inputType: TextInputType.streetAddress,
                  ),

                  const SizedBox(height: 12),

                  // House & Floor row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInlineFieldCard(
                            child: CustomTextField(
                              labelText: '${'house'.tr} (${'optional'.tr})',
                              titleText: 'write_house_number'.tr,
                              inputType: TextInputType.text,
                              focusNode: _houseNode,
                              nextFocus: _floorNode,
                              controller: _houseController,
                              showBorder: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInlineFieldCard(
                            child: CustomTextField(
                              labelText: "${'floor'.tr} (${'optional'.tr})",
                              titleText: 'write_floor_number'.tr,
                              inputType: TextInputType.text,
                              focusNode: _floorNode,
                              nextFocus: _nameNode,
                              inputAction: TextInputAction.next,
                              controller: _floorController,
                              showBorder: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Receiver details header
                  _buildSectionHeader('receiver_details'.tr),

                  // Contact person name
                  _buildSheetTextField(
                    controller: _contactPersonNameController,
                    focusNode: _nameNode,
                    nextFocus: _numberNode,
                    label: 'contact_person_name'.tr,
                    hint: 'write_name'.tr,
                    inputType: TextInputType.name,
                    capitalization: TextCapitalization.words,
                  ),

                  const SizedBox(height: 12),

                  // Phone with country code
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildInlineFieldCard(
                      child: CustomTextField(
                        labelText: 'contact_person_number'.tr,
                        titleText: 'write_number'.tr,
                        controller: _contactPersonNumberController,
                        focusNode: _numberNode,
                        nextFocus: widget.forGuest ? _emailFocus : _streetNode,
                        inputType: TextInputType.phone,
                        isPhone: true,
                        onCountryChanged: (CountryCode countryCode) {
                          _countryDialCode = countryCode.dialCode;
                        },
                        countryDialCode: _countryDialCode ?? Get.find<LocalizationController>().locale.countryCode,
                        showBorder: false,
                      ),
                    ),
                  ),

                  // Email (guest only)
                  if (widget.forGuest) ...[
                    const SizedBox(height: 12),
                    _buildSheetTextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      nextFocus: _streetNode,
                      label: 'email'.tr,
                      hint: 'enter_email'.tr,
                      inputType: TextInputType.emailAddress,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Save address as header
                  _buildSectionHeader('label_as'.tr),

                  // Address type chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAddressTypeChips(locationController),
                  ),

                  // Custom label field (when Other selected)
                  if (_otherSelect) ...[
                    const SizedBox(height: 12),
                    _buildSheetTextField(
                      controller: _levelController,
                      focusNode: _levelNode,
                      nextFocus: _addressNode,
                      label: '${'level_name'.tr}(${'optional'.tr})',
                      hint: 'write_level_name'.tr,
                      inputType: TextInputType.text,
                      capitalization: TextCapitalization.words,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Save button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: GetBuilder<AddressController>(
                      builder: (addressController) {
                        return CustomButton(
                          isLoading: addressController.isLoading,
                          buttonText: widget.forGuest ? 'done'.tr : widget.address == null ? 'save_location'.tr : 'update_address'.tr,
                          onPressed: () async => _onSaveOrUpdateButtonPressed(locationController),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // SHEET HELPER WIDGETS
  // ──────────────────────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: robotoBold.copyWith(
          fontSize: Dimensions.fontSizeLarge,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildAddressDisplayCard(LocationController locationController) {
    final fullAddress = _addressController.text;
    String shortName = fullAddress;
    String detailAddress = '';

    if (fullAddress.contains(',')) {
      final parts = fullAddress.split(',');
      shortName = parts.first.trim();
      detailAddress = parts.skip(1).join(',').trim();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          Get.toNamed(
            RouteHelper.getPickMapRoute('add-address', false),
            arguments: PickMapScreen(
              fromAddAddress: true, fromSignUp: false,
              googleMapController: _mapController ?? locationController.mapController,
              route: null, canRoute: false,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortName.isNotEmpty ? shortName : 'searching_address'.tr,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detailAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detailAddress,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).disabledColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Theme.of(context).disabledColor,
                size: 18,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required TextInputType inputType,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction? inputAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildInlineFieldCard(
        child: CustomTextField(
          labelText: label,
          titleText: hint,
          inputType: inputType,
          controller: controller,
          focusNode: focusNode,
          nextFocus: nextFocus,
          capitalization: capitalization,
          inputAction: inputAction ?? TextInputAction.next,
          showBorder: false,
        ),
      ),
    );
  }

  Widget _buildInlineFieldCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }

  // ──────────────────────────────────────────────
  // ADDRESS TYPE CHIPS
  // ──────────────────────────────────────────────

  Widget _buildAddressTypeChips(LocationController locationController) {
    final List<String> labels = ['home'.tr, 'office'.tr, 'others'.tr];
    final List<List<List<dynamic>>> icons = [
      HugeIcons.strokeRoundedHome01,
      HugeIcons.strokeRoundedBriefcase01,
      HugeIcons.strokeRoundedMoreHorizontal,
    ];

    return Row(
      children: List.generate(3, (index) {
        final isSelected = locationController.addressTypeIndex == index;
        return Padding(
          padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
          child: InkWell(
            onTap: () {
              _otherSelect = index == 2;
              locationController.setAddressTypeIndex(index);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected
                    ? Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).secondaryHeaderColor
                      : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: icons[index],
                    size: 16,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).disabledColor,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[index],
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────
  // DESKTOP LAYOUT (preserved from original)
  // ──────────────────────────────────────────────

  Widget _buildDesktopLayout(LocationController locationController) {
    return SingleChildScrollView(
      child: FooterView(
        child: Column(
          children: [
            Container(
              height: 64,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
              child: Center(child: Text('address'.tr, style: robotoMedium)),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Center(
              child: SizedBox(
                width: Dimensions.webMaxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                        color: Theme.of(context).cardColor,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 680, height: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                              border: Border.all(width: 2, color: Theme.of(context).primaryColor),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                              child: Stack(clipBehavior: Clip.none, children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 16),
                                  minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
                                  onTap: (latLng) {
                                    if (ResponsiveHelper.isDesktop(Get.context)) {
                                    } else {
                                      Get.toNamed(
                                        RouteHelper.getPickMapRoute('add-address', false),
                                        arguments: PickMapScreen(
                                          fromAddAddress: true, fromSignUp: false,
                                          googleMapController: locationController.mapController,
                                          route: null, canRoute: false,
                                        ),
                                      );
                                    }
                                  },
                                  zoomControlsEnabled: false, compassEnabled: false,
                                  indoorViewEnabled: true, mapToolbarEnabled: false,
                                  onCameraIdle: () {
                                    locationController.updatePosition(_cameraPosition, true);
                                  },
                                  onCameraMove: ((position) => _cameraPosition = position),
                                  onMapCreated: (GoogleMapController controller) {
                                    locationController.setMapController(controller);
                                    if (widget.address == null) {
                                      locationController.getCurrentLocation(true, mapController: controller);
                                    }
                                  },
                                  style: Get.isDarkMode ? Get.find<ThemeController>().darkMap : Get.find<ThemeController>().lightMap,
                                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                                    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                                    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                                    Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                                    Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                                  },
                                ),
                                locationController.loading ? const Center(child: CircularProgressIndicator()) : const SizedBox(),
                                Center(child: !locationController.loading
                                    ? Image.asset(Images.pickMarker, height: 50, width: 50)
                                    : const CircularProgressIndicator()),
                                Positioned(
                                  bottom: 10, right: 0,
                                  child: InkWell(
                                    onTap: () => _checkPermission(() {
                                      locationController.getCurrentLocation(true, mapController: locationController.mapController);
                                    }),
                                    child: Container(
                                      width: 30, height: 30,
                                      margin: const EdgeInsets.only(right: Dimensions.paddingSizeLarge),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusSmall), color: Colors.white),
                                      child: Icon(Icons.my_location, color: Theme.of(context).primaryColor, size: 20),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10, right: 0,
                                  child: InkWell(
                                    onTap: () {
                                      if (ResponsiveHelper.isDesktop(Get.context)) {
                                        showGeneralDialog(context: context, pageBuilder: (_, __, ___) {
                                          return SizedBox(
                                            height: 300, width: 300,
                                            child: PickMapScreen(fromSignUp: false, canRoute: false, fromAddAddress: true, route: null, googleMapController: locationController.mapController),
                                          );
                                        });
                                      } else {
                                        Get.toNamed(
                                          RouteHelper.getPickMapRoute('add-address', false),
                                          arguments: PickMapScreen(
                                            fromAddAddress: true, fromSignUp: false,
                                            googleMapController: locationController.mapController,
                                            route: null, canRoute: false,
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      width: 30, height: 30,
                                      margin: const EdgeInsets.only(right: Dimensions.paddingSizeLarge),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusSmall), color: Colors.white),
                                      child: Icon(Icons.fullscreen, color: Theme.of(context).primaryColor, size: 20),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          Text('label_as'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyMedium!.color)),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          SizedBox(height: 50, child: ListView.builder(
                            shrinkWrap: true, scrollDirection: Axis.horizontal,
                            itemCount: locationController.addressTypeList.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                              child: InkWell(
                                onTap: () {
                                  _otherSelect = index == 2;
                                  locationController.setAddressTypeIndex(index);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge, vertical: Dimensions.paddingSizeSmall),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                                    color: locationController.addressTypeIndex == index ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                                    boxShadow: const [BoxShadow(color: Colors.black12, spreadRadius: 1, blurRadius: 5)],
                                  ),
                                  child: Row(children: [
                                    SizedBox(height: 24, width: 24,
                                      child: Image.asset(
                                        index == 0 ? Images.homeIcon : index == 1 ? Images.workIcon : Images.otherIcon,
                                        color: locationController.addressTypeIndex == index ? Theme.of(context).cardColor : Theme.of(context).disabledColor,
                                      ),
                                    ),
                                    const SizedBox(width: Dimensions.paddingSizeSmall),
                                    Text(index == 0 ? 'home'.tr : index == 1 ? 'office'.tr : 'others'.tr,
                                      style: robotoRegular.copyWith(color: locationController.addressTypeIndex == index ? Theme.of(context).cardColor : Theme.of(context).disabledColor),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          )),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          _otherSelect ? SizedBox(height: 90, width: 680,
                            child: CustomTextField(
                              titleText: '${'level_name'.tr}(${'optional'.tr})',
                              hintText: 'write_level_name'.tr, showTitle: true,
                              inputType: TextInputType.text,
                              controller: _levelController, focusNode: _levelNode,
                              nextFocus: _addressNode, capitalization: TextCapitalization.words,
                            ),
                          ) : const SizedBox(),

                          const SizedBox(height: Dimensions.paddingSizeLarge),
                          SizedBox(height: 90, width: 680,
                            child: CustomTextField(
                              suffixIcon: Icons.my_location, showTitle: true,
                              titleText: 'delivery_address'.tr,
                              hintText: 'write_delivery_address'.tr,
                              inputType: TextInputType.streetAddress,
                              controller: _addressController, focusNode: _addressNode,
                              nextFocus: _nameNode,
                              onChanged: (text) => locationController.setPlaceMark(text),
                            ),
                          ),
                          const SizedBox(height: Dimensions.paddingSizeLarge),
                        ],
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeLarge),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                          color: Theme.of(context).cardColor,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
                        ),
                        child: Column(children: [
                          CustomTextField(
                            showTitle: true, titleText: 'contact_person_name'.tr,
                            hintText: 'write_name'.tr, showLabelText: false,
                            inputType: TextInputType.name,
                            controller: _contactPersonNameController,
                            focusNode: _nameNode, nextFocus: _numberNode,
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          CustomTextField(
                            showTitle: true, titleText: 'contact_person_number'.tr,
                            hintText: 'write_number'.tr, showLabelText: false,
                            controller: _contactPersonNumberController,
                            focusNode: _numberNode,
                            nextFocus: widget.forGuest ? _emailFocus : _streetNode,
                            inputType: TextInputType.phone, isPhone: true,
                            onCountryChanged: (CountryCode countryCode) {
                              _countryDialCode = countryCode.dialCode;
                            },
                            countryDialCode: _countryDialCode ?? Get.find<LocalizationController>().locale.countryCode,
                          ),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          widget.forGuest ? CustomTextField(
                            showTitle: true, titleText: 'email'.tr,
                            hintText: 'email'.tr, showLabelText: false,
                            controller: _emailController, focusNode: _emailFocus,
                            nextFocus: _streetNode, inputType: TextInputType.emailAddress,
                          ) : const SizedBox(),
                          SizedBox(height: widget.forGuest ? Dimensions.paddingSizeLarge : 0),

                          CustomTextField(
                            showTitle: true, hintText: 'street_number'.tr,
                            titleText: '${'street_number'.tr} (${'optional'.tr})',
                            showLabelText: false, inputType: TextInputType.streetAddress,
                            focusNode: _streetNode, nextFocus: _houseNode,
                            controller: _streetNumberController,
                          ),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          Row(children: [
                            Expanded(child: CustomTextField(
                              showTitle: true, hintText: 'house_name'.tr,
                              titleText: '${'house'.tr} (${'optional'.tr})',
                              showLabelText: false, inputType: TextInputType.text,
                              focusNode: _houseNode, nextFocus: _floorNode,
                              controller: _houseController,
                            )),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Expanded(child: CustomTextField(
                              hintText: 'floor_number'.tr, showLabelText: false,
                              showTitle: true,
                              titleText: "${'floor'.tr} (${'optional'.tr})",
                              inputType: TextInputType.text, focusNode: _floorNode,
                              inputAction: TextInputAction.done,
                              controller: _floorController,
                            )),
                          ]),
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          button(locationController),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SHARED LOGIC
  // ──────────────────────────────────────────────

  void _checkPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onTap();
    }
  }

  Widget button(LocationController locationController) {
    return GetBuilder<AddressController>(
      builder: (addressController) {
        return Container(
          width: Dimensions.webMaxWidth,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: CustomButton(
            radius: Dimensions.radiusSmall,
            isBold: false,
            isLoading: addressController.isLoading,
            buttonText: widget.forGuest ? 'done'.tr : widget.address == null ? 'save_location'.tr : 'update_address'.tr,
            onPressed: () async => _onSaveOrUpdateButtonPressed(locationController),
          ),
        );
      },
    );
  }

  void _onSaveOrUpdateButtonPressed(LocationController locationController) async {
    String numberWithCountryCode = _countryDialCode! + _contactPersonNumberController.text;
    PhoneValid phoneValid = await CustomValidator.isPhoneValid(numberWithCountryCode);
    numberWithCountryCode = phoneValid.phone;

    AddressModel? addressModel = _prepareAddressModel(locationController, phoneValid.isValid, numberWithCountryCode);
    if (addressModel == null) return;

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

  AddressModel? _prepareAddressModel(LocationController locationController, bool isValid, String numberWithCountryCode) {
    String? addressType = locationController.addressTypeList[locationController.addressTypeIndex];
    if (locationController.addressTypeIndex == 2) {
      addressType = _levelController.text.isNotEmpty ? _levelController.text.trim() : locationController.addressTypeList[locationController.addressTypeIndex];
    }
    if (_addressController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_delivery_address'.tr);
    } else if (_contactPersonNameController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_contact_person_name'.tr);
    } else if (_contactPersonNumberController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_phone_number'.tr);
    } else if (!isValid) {
      showCustomSnackBar('invalid_phone_number'.tr);
    } else if (widget.forGuest && _emailController.text.isEmpty) {
      showCustomSnackBar('please_enter_contact_person_email'.tr);
    } else {
      return AddressModel(
        id: widget.address?.id,
        addressType: addressType,
        contactPersonName: _contactPersonNameController.text,
        contactPersonNumber: _countryDialCode! + _contactPersonNumberController.text,
        address: _addressController.text,
        latitude: locationController.position.latitude.toString(),
        longitude: locationController.position.longitude.toString(),
        zoneId: locationController.zoneID,
        streetNumber: _streetNumberController.text,
        house: _houseController.text,
        floor: _floorController.text,
      );
    }
    return null;
  }

  void _addAddress(AddressModel addressModel) {
    Get.find<AddressController>().addAddress(addressModel, widget.fromCheckout, widget.zoneId).then((response) {
      if (response.isSuccess && !widget.fromCheckout) {
        widget.fromNavBar ? Get.back() : Get.offNamed(RouteHelper.getAddressRoute());
        showCustomSnackBar('new_address_added_successfully'.tr, isError: false);
      } else if (response.isSuccess && widget.fromCheckout) {
        AddressModel? addressModel;
        try {
          addressModel = Get.find<AddressController>().addressList![0];
        } catch (_) {}
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
    Get.find<AddressController>().updateAddress(addressModel, widget.address!.id).then((response) {
      if (response.isSuccess) {
        Get.back();
        showCustomSnackBar(response.message, isError: false);
      } else {
        showCustomSnackBar(response.message);
      }
    });
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
