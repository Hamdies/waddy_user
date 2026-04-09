import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/util/app_design_tokens.dart';
import 'package:waddy_app/util/styles.dart';

/// Dialog shown when user tries to add items from a different module
/// while cart already has items from another module.
/// 
/// Example: Cart has "Food" items, user tries to add "Grocery" items.
class CartModuleConflictDialog extends StatelessWidget {
  final String currentModuleName;
  final String newModuleName;
  final VoidCallback onClearCart;
  final VoidCallback onCancel;

  const CartModuleConflictDialog({
    super.key,
    required this.currentModuleName,
    required this.newModuleName,
    required this.onClearCart,
    required this.onCancel,
  });

  /// Show the dialog and return true if user chose to clear cart
  static Future<bool> show({
    required BuildContext context,
    required String currentModuleName,
    required String newModuleName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CartModuleConflictDialog(
        currentModuleName: currentModuleName,
        newModuleName: newModuleName,
        onClearCart: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade400,
                  Colors.orange.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'switch_module'.tr,
            style: robotoBold.copyWith(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Description
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: robotoRegular.copyWith(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                height: 1.5,
              ),
              children: [
                TextSpan(text: 'your_cart_contains_items_from'.tr),
                TextSpan(
                  text: ' $currentModuleName',
                  style: robotoBold.copyWith(
                    fontSize: 14,
                    color: AppDesignTokens.primaryDark,
                  ),
                ),
                TextSpan(text: '. ${'adding_items_from'.tr}'),
                TextSpan(
                  text: ' $newModuleName ',
                  style: robotoBold.copyWith(
                    fontSize: 14,
                    color: AppDesignTokens.primaryDark,
                  ),
                ),
                TextSpan(text: 'will_reset_your_cart'.tr),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Warning note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'this_action_cannot_be_undone'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'keep_cart'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Clear & Add Button
              Expanded(
                child: GestureDetector(
                  onTap: onClearCart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppDesignTokens.primaryDark,
                          Color(0xFF1A5F5A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesignTokens.primaryDark.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'clear_and_add'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
