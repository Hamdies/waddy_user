import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The mint search header from the "Mart Search" design: a round back button
/// and a white, teal-outlined pill field on a neon-to-mint gradient.
///
/// The gradient runs up under the status bar so the system chrome reads as part
/// of the header rather than a strip above it. Back is a 40pt disc with a 48pt
/// hit box — the disc is the design, the box is the platform minimum.
///
/// Shared by the global search and the in-store search so the two cannot drift.
class MintSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  /// Sits after the field — the store search puts its veg filter here.
  final Widget? trailing;

  static const Color _mintWash = Color(0xFFC9FBE8);

  const MintSearchHeader({
    super.key,
    required this.controller,
    required this.hint,
    required this.onClear,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          Dimensions.paddingSizeDefault,
          MediaQuery.paddingOf(context).top + Dimensions.paddingSizeSmall,
          Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeDefault,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppDesignTokens.secondaryNeon, _mintWash],
          ),
        ),
        child: Row(
          children: [
            Pressable(
              minSize: Dimensions.minTapTarget,
              scale: 0.92,
              semanticLabel: 'back'.tr,
              onTap: () => Get.back(),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppDesignTokens.primaryDark,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium + 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppDesignTokens.primaryDark,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      color: AppDesignTokens.primaryDark,
                      size: 18,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),

                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: autofocus,
                        textInputAction: TextInputAction.search,
                        cursorColor: AppDesignTokens.primaryDark,
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: const Color(0xFF1A1F1E),
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: waddyRegular.copyWith(
                            color: const Color(0xFF6B7876),
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                      ),
                    ),

                    // A filled disc, not a bare glyph: a lone × beside typed text
                    // reads as part of the text.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder:
                          (context, value, _) =>
                              value.text.isEmpty
                                  ? const SizedBox.shrink()
                                  : Pressable(
                                    minSize: Dimensions.minTapTarget,
                                    scale: 0.9,
                                    semanticLabel: 'clear'.tr,
                                    onTap: onClear,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFB8C4C1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                    ),
                  ],
                ),
              ),
            ),

            if (trailing != null) ...[
              const SizedBox(width: Dimensions.paddingSizeSmall),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
