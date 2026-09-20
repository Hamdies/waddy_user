import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_category_model.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class PlaceSubmissionScreen extends StatefulWidget {
  const PlaceSubmissionScreen({super.key});

  @override
  State<PlaceSubmissionScreen> createState() => _PlaceSubmissionScreenState();
}

class _PlaceSubmissionScreenState extends State<PlaceSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  int? _selectedCategoryId;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    Get.find<PlacesController>().getCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On the Spots palette, not the app theme — this screen is part of the
    // Spots surface, so it must not drift when the app theme changes.
    const primary = Spots.teal;
    const neon = Spots.mint;

    return Scaffold(
      backgroundColor: Spots.canvas,
      appBar: AppBar(
        title: Text(
          displayCaps('submit_hidden_gem'.tr),
          style: waddyBlack.copyWith(
            fontSize: 16,
            color: Spots.ink,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Spots.canvas,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Spots.border, width: Spots.borderThin),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Spots.teal),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<PlacesController>(
        builder: (controller) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── NEO HEADER ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                    decoration: BoxDecoration(
                      color: neon,
                      border: Border.all(
                        color: Spots.border,
                        width: Spots.borderThin,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Spots.radiusMd),
                      ),
                      boxShadow: Spots.shadow(dx: 4, dy: 4),
                    ),
                    child: Column(
                      children: [
                        const SpotsGlyph(
                          SpotsMark.pin,
                          size: 36,
                          color: Spots.teal,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayCaps('share_your_discovery'.tr),
                          style: waddyBlack.copyWith(
                            fontSize: 17,
                            color: Spots.ink,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'help_others_find_hidden_gems'.tr,
                          style: waddyMedium.copyWith(
                            fontSize: 12,
                            color: primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Name
                  _buildLabel('place_name'.tr, neon, required: true),
                  _buildTextField(
                    _nameController,
                    'enter_place_name'.tr,
                    primary,
                    neon,
                    validator:
                        (v) => v == null || v.isEmpty ? 'required'.tr : null,
                  ),

                  // Category
                  _buildLabel('category'.tr, neon),
                  _buildCategoryDropdown(controller, primary, neon),

                  // Description
                  _buildLabel('description'.tr, neon),
                  _buildTextField(
                    _descriptionController,
                    'describe_this_place'.tr,
                    primary,
                    neon,
                    maxLines: 3,
                  ),

                  // Address
                  _buildLabel('address'.tr, neon),
                  _buildTextField(
                    _addressController,
                    'enter_address'.tr,
                    primary,
                    neon,
                  ),

                  // Phone
                  _buildLabel('phone'.tr, neon),
                  _buildTextField(
                    _phoneController,
                    'enter_phone'.tr,
                    primary,
                    neon,
                    keyboardType: TextInputType.phone,
                  ),

                  // Website
                  _buildLabel('website'.tr, neon),
                  _buildTextField(
                    _websiteController,
                    'enter_website'.tr,
                    primary,
                    neon,
                    keyboardType: TextInputType.url,
                  ),

                  // Instagram
                  _buildLabel('instagram'.tr, neon),
                  _buildTextField(
                    _instagramController,
                    'instagram_handle'.tr,
                    primary,
                    neon,
                    prefix: '@',
                  ),

                  // Photo
                  _buildLabel('photo'.tr, neon),
                  _buildPhotoUpload(primary, neon),

                  const SizedBox(height: 28),

                  // ─── NEO SUBMIT BUTTON ───
                  SpotsPressable(
                    onTap: controller.isSubmitting ? null : _submit,
                    dx: 4,
                    dy: 4,
                    shadowColor: neon,
                    radius: Spots.radiusMd,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Spots.teal,
                        border: Border.all(
                          color: Spots.border,
                          width: Spots.borderThin,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(Spots.radiusMd),
                        ),
                      ),
                      child: Center(
                        child:
                            controller.isSubmitting
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  displayCaps('submit_for_review'.tr),
                                  style: waddyBlack.copyWith(
                                    fontSize: 14,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'submission_review_note'.tr,
                      style: waddyRegular.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).disabledColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text, Color neon, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Dimensions.paddingSizeDefault,
        bottom: 6,
      ),
      child: Row(
        children: [
          Text(text, style: waddyMedium.copyWith(fontSize: 13)),
          if (required)
            Text(' *', style: waddyMedium.copyWith(fontSize: 13, color: neon)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    Color primary,
    Color neon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    // Gumroad field: white fill, 1.5px black outline, tight radius,
    // thicker black outline on focus
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: waddyRegular.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle: waddyRegular.copyWith(
          fontSize: 14,
          color: Theme.of(context).disabledColor,
        ),
        filled: true,
        fillColor: Spots.paper,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
          borderSide: BorderSide(color: Spots.border, width: Spots.borderThin),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
          borderSide: BorderSide(color: Spots.border, width: Spots.borderThin),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
          borderSide: BorderSide(color: Spots.border, width: Spots.borderThick),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
          borderSide: BorderSide(color: Spots.red, width: Spots.borderThin),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
          borderSide: BorderSide(color: Spots.red, width: Spots.borderThick),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
          vertical: Dimensions.paddingSizeMedium,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(
    PlacesController controller,
    Color primary,
    Color neon,
  ) {
    final categories = controller.categories ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
      ),
      decoration: BoxDecoration(
        color: Spots.paper,
        border: Border.all(color: Spots.border, width: Spots.borderThin),
        borderRadius: const BorderRadius.all(Radius.circular(Spots.radiusMd)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCategoryId,
          isExpanded: true,
          hint: Text(
            'select_category'.tr,
            style: waddyRegular.copyWith(
              fontSize: 14,
              color: Theme.of(context).disabledColor,
            ),
          ),
          items:
              categories.map((PlaceCategory cat) {
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Text(
                    cat.name,
                    style: waddyRegular.copyWith(fontSize: 14),
                  ),
                );
              }).toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
        ),
      ),
    );
  }

  Widget _buildPhotoUpload(Color primary, Color neon) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(Spots.radiusMd)),
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child:
            _imagePath != null
                ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Spots.radiusMd),
                      ),
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePath = null),
                        child: Container(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeExtraSmall,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      size: 26,
                      color: Spots.ink3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'tap_to_add_photo'.tr,
                      style: waddyMedium.copyWith(fontSize: 12, color: neon),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Backend expects `title`; keep `name` for older server builds
    final fields = <String, String>{
      'title': _nameController.text.trim(),
      'name': _nameController.text.trim(),
    };
    if (_descriptionController.text.trim().isNotEmpty) {
      fields['description'] = _descriptionController.text.trim();
    }
    if (_selectedCategoryId != null) {
      fields['category_id'] = _selectedCategoryId.toString();
    }
    if (_addressController.text.trim().isNotEmpty) {
      fields['address'] = _addressController.text.trim();
    }
    if (_phoneController.text.trim().isNotEmpty) {
      fields['phone'] = _phoneController.text.trim();
    }
    if (_websiteController.text.trim().isNotEmpty) {
      fields['website'] = _websiteController.text.trim();
    }
    if (_instagramController.text.trim().isNotEmpty) {
      fields['instagram'] = _instagramController.text.trim();
    }

    final success = await Get.find<PlacesController>().submitNewPlace(
      fields,
      imagePath: _imagePath,
    );

    if (success) {
      Get.back();
    }
  }
}
