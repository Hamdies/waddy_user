import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/cart/domain/models/cart_model.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/util/app_design_tokens.dart';

/// Expanded cart drawer v4 - COMPACT version
///
/// Fixes from v3:
/// - Much smaller item cards (single row layout)
/// - Reduced padding and margins throughout
/// - More items visible without scrolling
/// - XP section collapsed by default
class ExpandedCartDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const ExpandedCartDrawer({super.key, required this.onClose});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              ExpandedCartDrawer(onClose: () => Navigator.of(context).pop()),
    );
  }

  @override
  State<ExpandedCartDrawer> createState() => _ExpandedCartDrawerState();
}

class _ExpandedCartDrawerState extends State<ExpandedCartDrawer> {
  CartModel? _deletedItem;
  int? _deletedIndex;
  bool _showUndo = false;
  bool _xpExpanded = false; // XP section starts collapsed

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cartController) {
        return GetBuilder<XpController>(
          builder: (xpController) {
            final cartItems = cartController.cartList;
            final subTotal = cartController.subTotal;
            final totalItems = cartItems.fold<int>(
              0,
              (sum, item) => sum + (item.quantity ?? 1),
            );

            final totalSavings = _calculateTotalSavings(cartItems);
            final moduleType =
                Get.find<SplashController>().module?.moduleType ?? 'grocery';
            final estimatedXp = xpController.calculateEstimatedXp(
              subTotal,
              moduleType,
            );

            final currentLevel = xpController.currentLevel;
            final currentXp = currentLevel?.currentXp ?? 0;
            final xpForNextLevel = currentLevel?.xpForNextLevel ?? 100;
            final xpAfterOrder = currentXp + estimatedXp;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  _buildDragHandle(),

                  // Compact header
                  _buildCompactHeader(totalItems, totalSavings, estimatedXp),

                  const Divider(height: 1),

                  // Cart items - COMPACT list
                  Flexible(
                    child:
                        cartItems.isEmpty
                            ? _buildEmptyCart()
                            : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: cartItems.length,
                              separatorBuilder:
                                  (_, __) => const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              itemBuilder:
                                  (context, index) => _buildCompactItem(
                                    cartItems[index],
                                    index,
                                    cartController,
                                    xpController,
                                    moduleType,
                                  ),
                            ),
                  ),

                  if (_showUndo) _buildUndoBanner(cartController),

                  // Compact summary
                  _buildCompactSummary(subTotal, totalSavings),

                  // Collapsible XP section
                  _buildCollapsibleXpSection(
                    estimatedXp,
                    xpController,
                    currentXp,
                    xpAfterOrder,
                    xpForNextLevel,
                  ),

                  // Checkout button
                  _buildCompactCheckoutButton(context, subTotal),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCompactHeader(
    int totalItems,
    double totalSavings,
    int estimatedXp,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Row(
        children: [
          const Text(
            'Your Order',
            style: TextStyle(
              color: AppDesignTokens.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppDesignTokens.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalItems items',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // Compact badges
          if (totalSavings > 0)
            _buildMicroBadge(
              '💰 ${PriceConverter.convertPrice(totalSavings)}',
              AppDesignTokens.successGreen,
            ),
          const SizedBox(width: 6),
          if (estimatedXp > 0)
            _buildMicroBadge(
              '⭐ +$estimatedXp',
              AppDesignTokens.gamificationGold,
            ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 22),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Your cart is empty', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  /// COMPACT item row - single line with inline controls
  Widget _buildCompactItem(
    CartModel item,
    int index,
    CartController cartController,
    XpController xpController,
    String moduleType,
  ) {
    final itemName = item.item?.name ?? 'Item';
    final itemImage = item.item?.imageFullUrl ?? '';
    final quantity = item.quantity ?? 1;
    final unitPrice = item.discountedPrice ?? item.price ?? 0.0;
    final lineTotal = unitPrice * quantity;
    final isLoading = item.isLoading ?? false;

    return Dismissible(
      key: Key('cart_item_${item.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppDesignTokens.errorRed,
        child: const Icon(Icons.delete, color: Colors.white, size: 22),
      ),
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        _handleDelete(cartController, item, index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Small image
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomImage(image: itemImage, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${PriceConverter.convertPrice(unitPrice)} × $quantity',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Compact quantity controls
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniQtyButton(
                    icon: quantity <= 1 ? Icons.delete_outline : Icons.remove,
                    color:
                        quantity <= 1
                            ? AppDesignTokens.errorRed
                            : AppDesignTokens.primaryDark,
                    onTap:
                        isLoading
                            ? null
                            : () {
                              HapticFeedback.selectionClick();
                              if (quantity > 1) {
                                cartController.setQuantity(
                                  false,
                                  index,
                                  item.item?.stock,
                                  item.item?.quantityLimit,
                                );
                              } else {
                                _handleDelete(cartController, item, index);
                              }
                            },
                  ),
                  Container(
                    width: 28,
                    alignment: Alignment.center,
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            )
                            : Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                  _buildMiniQtyButton(
                    icon: Icons.add,
                    color: AppDesignTokens.primaryDark,
                    onTap:
                        isLoading
                            ? null
                            : () {
                              HapticFeedback.selectionClick();
                              cartController.setQuantity(
                                true,
                                index,
                                item.item?.stock,
                                item.item?.quantityLimit,
                              );
                            },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Line total
            SizedBox(
              width: 55,
              child: Text(
                PriceConverter.convertPrice(lineTotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryDark,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniQtyButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 32,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _handleDelete(CartController cartController, CartModel item, int index) {
    setState(() {
      _deletedItem = item;
      _deletedIndex = index;
      _showUndo = true;
    });
    cartController.removeFromCart(index);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showUndo) {
        setState(() {
          _showUndo = false;
          _deletedItem = null;
          _deletedIndex = null;
        });
      }
    });
  }

  Widget _buildUndoBanner(CartController cartController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text(
            'Item removed',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              if (_deletedItem != null) {
                cartController.addToCart(_deletedItem!, _deletedIndex);
                setState(() {
                  _showUndo = false;
                  _deletedItem = null;
                });
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'UNDO',
              style: TextStyle(
                color: AppDesignTokens.secondaryNeon,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(double subTotal, double totalSavings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (totalSavings > 0)
                  Text(
                    'Savings 🎉 -${PriceConverter.convertPrice(totalSavings)}',
                    style: const TextStyle(
                      color: AppDesignTokens.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      'Delivery ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '25-35 min',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                    Text(
                      ' From 45 LE',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                PriceConverter.convertPrice(subTotal),
                style: const TextStyle(
                  color: AppDesignTokens.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleXpSection(
    int estimatedXp,
    XpController xpController,
    int currentXp,
    int xpAfterOrder,
    int xpForNextLevel,
  ) {
    if (estimatedXp <= 0) return const SizedBox.shrink();

    final willLevelUp = xpAfterOrder >= xpForNextLevel;
    final currentLevelNum = xpController.currentLevel?.currentLevel ?? 1;

    return GestureDetector(
      onTap: () => setState(() => _xpExpanded = !_xpExpanded),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppDesignTokens.gamificationGoldLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppDesignTokens.gamificationGold.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            // Always visible row
            Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  "+$estimatedXp XP",
                  style: const TextStyle(
                    color: AppDesignTokens.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (willLevelUp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.successGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Level ${currentLevelNum + 1}! 🎉',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  _xpExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.5),
                ),
              ],
            ),
            // Expandable content
            if (_xpExpanded) ...[
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (currentXp / xpForNextLevel).clamp(0.0, 1.0),
                  backgroundColor: AppDesignTokens.gamificationGold.withValues(
                    alpha: 0.2,
                  ),
                  valueColor: const AlwaysStoppedAnimation(
                    AppDesignTokens.gamificationGold,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$currentXp XP',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  Text(
                    '→ $xpAfterOrder XP',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.gamificationGold,
                    ),
                  ),
                  Text(
                    '$xpForNextLevel XP',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCheckoutButton(BuildContext context, double subTotal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop();
            Get.toNamed(RouteHelper.getCartRoute());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDesignTokens.primaryDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Checkout',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  PriceConverter.convertPrice(subTotal),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateTotalSavings(List<CartModel> cartItems) {
    double savings = 0.0;
    for (final item in cartItems) {
      final originalPrice = item.price ?? 0.0;
      final discountedPrice = item.discountedPrice ?? originalPrice;
      final quantity = item.quantity ?? 1;
      if (discountedPrice < originalPrice) {
        savings += (originalPrice - discountedPrice) * quantity;
      }
    }
    return savings;
  }
}
