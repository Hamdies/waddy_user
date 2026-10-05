import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';

/// Live cart widget - floating green pill with stacked item images,
/// "View cart" text, item count, and chevron arrow.
/// Matches the Swiggy-style "View cart" floating bar design.
class LiveCartWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const LiveCartWidget({super.key, this.onTap});

  @override
  State<LiveCartWidget> createState() => _LiveCartWidgetState();
}

class _LiveCartWidgetState extends State<LiveCartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _pulseController.forward().then((_) => _pulseController.reverse());
    Get.toNamed(RouteHelper.getCartRoute());
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cartController) {
        final cartItems = cartController.cartList;
        if (cartItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final totalItems = cartItems.fold<int>(
          0,
          (sum, item) => sum + (item.quantity ?? 1),
        );

        // Calculate total price
        final double totalPrice = cartController.calculationCart();

        // Calculate estimated XP from line items so it matches the backend's
        // per-item floor (a whole-total estimate reads a few XP high).
        final String? moduleType =
            cartItems.isNotEmpty ? cartItems.first.item?.moduleType : null;
        int estimatedXp = 0;
        if (Get.isRegistered<XpController>()) {
          estimatedXp = Get.find<XpController>().estimateForCart(
            cartItems,
            moduleType,
          );
        }

        final Color primaryColor = Theme.of(context).primaryColor;
        final Color accentColor = Theme.of(context).secondaryHeaderColor;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),

                    // Stacked item images
                    SizedBox(
                      width: _calculateImageStackWidth(cartItems),
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _buildItemImageStack(cartItems),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Next reward + XP info
                    Expanded(
                      child: _buildCartInfo(
                        totalItems: totalItems,
                        estimatedXp: estimatedXp,
                        accentColor: accentColor,
                      ),
                    ),

                    // Arrow badge with total
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeMedium,
                      ),
                      margin: const EdgeInsets.only(
                        right: Dimensions.paddingSizeSmall,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            PriceConverter.convertPrice(totalPrice),
                            style: waddyBold.copyWith(
                              color: primaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartInfo({
    required int totalItems,
    required int estimatedXp,
    required Color accentColor,
  }) {
    // First line: estimated XP from this order
    final xpRow =
        estimatedXp > 0
            ? Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text(
                  '+$estimatedXp XP',
                  style: waddyBold.copyWith(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalItems ${'items'.tr}',
                  style: waddyRegular.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            )
            : Text(
              '$totalItems ${'items'.tr}',
              style: waddyBold.copyWith(color: Colors.white, fontSize: 14),
            );

    // Second line: next reward info
    Widget? rewardRow;
    if (Get.isRegistered<XpController>()) {
      final xpController = Get.find<XpController>();
      final nextReward = xpController.nextReward;

      if (nextReward != null) {
        final rewardTitle =
            nextReward.title.isNotEmpty
                ? nextReward.title
                : nextReward.kind.label;

        rewardRow = Text(
          // One parameterised string: the old concatenation read
          // "التالي Prize: Free Delivery" in Arabic (X-08).
          'xp_next_prize'.trParams({'reward': rewardTitle}),
          style: waddyMedium.copyWith(color: accentColor, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        xpRow,
        if (rewardRow != null) ...[const SizedBox(height: 2), rewardRow],
      ],
    );
  }

  double _calculateImageStackWidth(List<CartModel> cartItems) {
    final itemCount = cartItems.length.clamp(1, 3);
    // 44px images with 18px overlap
    return 44.0 + ((itemCount - 1) * 18);
  }

  // Tilt angles for stacked images: alternating left/right tilt
  static const List<double> _tiltAngles = [-0.08, 0.06, -0.05];

  List<Widget> _buildItemImageStack(List<CartModel> cartItems) {
    final displayItems = cartItems.take(3).toList();
    final List<Widget> stack = [];

    for (int i = 0; i < displayItems.length; i++) {
      final double angle = i < _tiltAngles.length ? _tiltAngles[i] : 0;

      stack.add(
        Positioned(
          left: i * 18.0,
          top: 0,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                child: CustomImage(
                  image: displayItems[i].item?.imageFullUrl ?? '',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return stack;
  }
}
