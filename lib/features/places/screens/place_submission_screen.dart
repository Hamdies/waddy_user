import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/domain/models/place_category_model.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

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
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('submit_hidden_gem'.tr,
            style: robotoBold.copyWith(fontSize: 18, color: Colors.white)),
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primary, primary.withValues(alpha: 0.85)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: neon.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text('🗺️', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text('share_your_discovery'.tr,
                            style: robotoBold.copyWith(fontSize: 18, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('help_others_find_hidden_gems'.tr,
                            style: robotoRegular.copyWith(fontSize: 12, color: neon.withValues(alpha: 0.9)),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Name
                  _buildLabel('place_name'.tr, neon, required: true),
                  _buildTextField(_nameController, 'enter_place_name'.tr, primary, neon,
                      validator: (v) => v == null || v.isEmpty ? 'required'.tr : null),

                  // Category
                  _buildLabel('category'.tr, neon),
                  _buildCategoryDropdown(controller, primary, neon),

                  // Description
                  _buildLabel('description'.tr, neon),
                  _buildTextField(_descriptionController, 'describe_this_place'.tr, primary, neon,
                      maxLines: 3),

                  // Address
                  _buildLabel('address'.tr, neon),
                  _buildTextField(_addressController, 'enter_address'.tr, primary, neon),

                  // Phone
                  _buildLabel('phone'.tr, neon),
                  _buildTextField(_phoneController, 'enter_phone'.tr, primary, neon,
                      keyboardType: TextInputType.phone),

                  // Website
                  _buildLabel('website'.tr, neon),
                  _buildTextField(_websiteController, 'enter_website'.tr, primary, neon,
                      keyboardType: TextInputType.url),

                  // Instagram
                  _buildLabel('instagram'.tr, neon),
                  _buildTextField(_instagramController, 'instagram_handle'.tr, primary, neon,
                      prefix: '@'),

                  // Photo
                  _buildLabel('photo'.tr, neon),
                  _buildPhotoUpload(primary, neon),

                  const SizedBox(height: 28),

                  // ─── NEO SUBMIT BUTTON ───
                  GestureDetector(
                    onTap: controller.isSubmitting ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [neon, neon.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: neon.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: controller.isSubmitting
                            ? SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                              )
                            : Text('submit_for_review'.tr,
                                style: robotoBold.copyWith(fontSize: 15, color: primary)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'submission_review_note'.tr,
                      style: robotoRegular.copyWith(
                          fontSize: 11, color: Theme.of(context).disabledColor),
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
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Text(text, style: robotoMedium.copyWith(fontSize: 13)),
          if (required)
            Text(' *', style: robotoMedium.copyWith(fontSize: 13, color: neon)),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: robotoRegular.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle: robotoRegular.copyWith(fontSize: 14, color: Theme.of(context).disabledColor),
        filled: true,
        fillColor: primary.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neon, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  Widget _buildCategoryDropdown(PlacesController controller, Color primary, Color neon) {
    final categories = controller.categories ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.03),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCategoryId,
          isExpanded: true,
          hint: Text('select_category'.tr,
              style: robotoRegular.copyWith(fontSize: 14, color: Theme.of(context).disabledColor)),
          items: categories.map((PlaceCategory cat) {
            return DropdownMenuItem<int>(
              value: cat.id,
              child: Text(cat.name, style: robotoRegular.copyWith(fontSize: 14)),
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
          color: primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: neon.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: neon.withValues(alpha: 0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: _imagePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagePath = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📸', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 6),
                  Text('tap_to_add_photo'.tr,
                      style: robotoMedium.copyWith(fontSize: 12, color: neon)),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final fields = <String, String>{
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
