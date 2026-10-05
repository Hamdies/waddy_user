import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/mccoin_mood.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "Start a new cart?" — the one dialog for an add that would empty the cart:
/// the cart holds another category's items (Groceries → Food), or another
/// store's ([CartModuleConflictDialog.forStore]).
///
/// McCoin wears "Meh" instead of a warning glyph: emptying a cart is a small
/// letdown, not a hazard, and the old orange swap disc and red "Are you sure
/// want to reset?" read as an error the shopper had caused.
class CartModuleConflictDialog extends StatefulWidget {
  /// What's in the cart now, and what the add comes from — bolded in the
  /// copy on a mint highlight. Either null falls back to the generic line.
  final String? currentName;
  final String? newName;

  /// Empties the cart and adds. When it returns a future, the button holds a
  /// spinner until it settles, so a second tap can't clear twice.
  final FutureOr<void> Function() onClearCart;
  final VoidCallback onCancel;

  const CartModuleConflictDialog({
    super.key,
    required String currentModuleName,
    required String newModuleName,
    required this.onClearCart,
    required this.onCancel,
  }) : currentName = currentModuleName,
       newName = newModuleName;

  /// The cart holds another store's items. The current store's name is read
  /// from the cart itself.
  CartModuleConflictDialog.forStore({
    super.key,
    required String? newStoreName,
    required this.onClearCart,
    VoidCallback? onCancel,
  }) : currentName =
           Get.find<CartController>().cartList.firstOrNull?.item?.storeName,
       newName = newStoreName,
       onCancel = onCancel ?? Get.back;

  /// Show the dialog and return true if user chose to clear cart
  static Future<bool> show({
    required BuildContext context,
    required String currentModuleName,
    required String newModuleName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CartModuleConflictDialog(
            currentModuleName: currentModuleName,
            newModuleName: newModuleName,
            onClearCart: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
    );
    return result ?? false;
  }

  @override
  State<CartModuleConflictDialog> createState() =>
      _CartModuleConflictDialogState();
}

class _CartModuleConflictDialogState extends State<CartModuleConflictDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onClearCart();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The body line with both names bolded in teal. The template carries
  /// `@current` and `@next` so each language can order them its own way.
  List<TextSpan> _body() {
    final String? current = widget.currentName?.trim();
    final String? next = widget.newName?.trim();
    if (current == null ||
        current.isEmpty ||
        next == null ||
        next.isEmpty ||
        current == next) {
      return [TextSpan(text: 'cart_conflict_body_generic'.tr)];
    }
    // The square full-mint highlight the app puts on a deal price (teal on
    // mint), painted behind the text so a long name still wraps. The
    // non-breaking spaces are the block's side padding.
    final TextStyle bold = waddyBold.copyWith(
      color: WaddyColors.primary,
      background: Paint()..color = WaddyColors.mint,
    );
    final List<TextSpan> spans = [];
    'cart_conflict_body'.tr.splitMapJoin(
      RegExp(r'@current|@next'),
      onMatch: (m) {
        spans.add(
          TextSpan(
            text: '\u00A0${m[0] == '@current' ? current : next}\u00A0',
            style: bold,
          ),
        );
        return '';
      },
      onNonMatch: (text) {
        if (text.isNotEmpty) spans.add(TextSpan(text: text));
        return '';
      },
    );
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WaddyColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtraLarge,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeExtraLarge,
          Dimensions.paddingSizeLarge,
          Dimensions.paddingSizeLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // McCoin on a mint disc — the brand's colour carries the moment,
            // not a warning orange.
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    WaddyColors.mintSurfaceDeep,
                    WaddyColors.mintSurface,
                  ],
                ),
              ),
              child: const McCoinMoodAnimation(mood: McCoinMood.meh, size: 104),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Text(
              'cart_conflict_title'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: displayTracking(-0.4),
                color: WaddyColors.ink,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text.rich(
              TextSpan(children: _body()),
              textAlign: TextAlign.center,
              style: waddyRegular.copyWith(
                fontSize: 15,
                height: 1.5,
                color: WaddyColors.inkMid,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            // Mint + teal underline: the app's add button, since this one
            // still adds — it just empties the cart first.
            Pressable(
              onTap: _busy ? null : _confirm,
              semanticLabel: 'clear_and_add'.tr,
              scale: WaddyMotion.pressCard,
              child: Container(
                height: 52,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WaddyColors.mint,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: WaddyColors.primary, offset: Offset(0, 2)),
                  ],
                ),
                child:
                    _busy
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: WaddyColors.primary,
                          ),
                        )
                        : Text(
                          'clear_and_add'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: WaddyColors.primary,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Pressable(
              onTap: _busy ? null : widget.onCancel,
              semanticLabel: 'keep_cart'.tr,
              scale: WaddyMotion.pressControl,
              minSize: Dimensions.minTapTarget,
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: Center(
                  child: Text(
                    'keep_cart'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 15,
                      color: WaddyColors.inkLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
