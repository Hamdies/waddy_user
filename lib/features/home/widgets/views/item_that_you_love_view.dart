import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';

/// Redesigned "Items You Love" section matching Yandex Plus style
/// Features:
/// - Dark purple gradient with decorative hanging lights/ornaments
/// - Large centered title with custom styling
/// - 3-card horizontal layout (1 white + 2 purple translucent)
/// - Snowy/wavy bottom edge with action buttons
class ItemThatYouLoveView extends StatefulWidget {
  final bool forShop;
  const ItemThatYouLoveView({super.key, required this.forShop});

  @override
  State<ItemThatYouLoveView> createState() => _ItemThatYouLoveViewState();
}

class _ItemThatYouLoveViewState extends State<ItemThatYouLoveView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Yandex Plus style colors
  static const Color deepPurple = Color(0xFF2D1B4E);
  static const Color midPurple = Color(0xFF4A2C7A);
  static const Color lightPurple = Color(0xFF6B4D9A);
  static const Color cardPurple = Color(0xFF5D3F8E);
  static const Color accentPink = Color(0xFFE91E8C);
  static const Color accentYellow = Color(0xFFFFD93D);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentGreen = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (homeController) {
        return GetBuilder<ItemController>(
          builder: (itemController) {
            List<Item>? recommendItems = itemController.recommendedItemList;

            return recommendItems != null
                ? recommendItems.isNotEmpty
                    ? _buildMainContent(recommendItems)
                    : const SizedBox()
                : const _ItemThatYouLoveShimmerView();
          },
        );
      },
    );
  }

  Widget _buildMainContent(List<Item> items) {
    final title = widget.forShop ? 'top_picks'.tr : 'items_you_love'.tr;
    final subtitle = widget.forShop ? 'best_for_you'.tr : 'your_favorites'.tr;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeDefault,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Main gradient background
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [deepPurple, midPurple, lightPurple],
                ),
              ),
              child: Column(
                children: [
                  // Header with lights
                  _buildHeaderWithLights(title, subtitle),
                  
                  // Three cards section
                  _buildThreeCardsSection(items),
                  
                  // Bottom action buttons
                  _buildBottomActions(),
                  
                  // Snowy bottom edge
                  _buildSnowyEdge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithLights(String title, String subtitle) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // String/wire for lights
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 30),
              painter: _LightStringPainter(),
            ),
          ),
          
          // Hanging ornaments/lights
          ..._buildHangingLights(),
          
          // Title section
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  title,
                  style: robotoBold.copyWith(
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: robotoMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHangingLights() {
    return [
      // Pink ornament (left)
      _buildHangingOrnament(
        left: 30,
        top: 35,
        color: accentPink,
        icon: Icons.add,
        size: 40,
        stringLength: 25,
      ),
      // Yellow star (center-left)
      _buildHangingOrnament(
        left: 100,
        top: 45,
        color: accentYellow,
        isStarShape: true,
        size: 35,
        stringLength: 35,
      ),
      // Red heart (center-right)
      _buildHangingOrnament(
        right: 100,
        top: 40,
        color: accentRed,
        icon: Icons.favorite,
        size: 35,
        stringLength: 30,
      ),
      // Green light (right)
      _buildHangingOrnament(
        right: 30,
        top: 50,
        color: accentGreen,
        size: 30,
        stringLength: 40,
      ),
      // Small decorative lights
      _buildSmallLight(left: 60, top: 25, color: Colors.cyan),
      _buildSmallLight(left: 140, top: 30, color: Colors.orange),
      _buildSmallLight(right: 140, top: 28, color: Colors.pink.shade200),
      _buildSmallLight(right: 60, top: 32, color: Colors.lightGreen),
    ];
  }

  Widget _buildHangingOrnament({
    double? left,
    double? right,
    required double top,
    required Color color,
    IconData? icon,
    bool isStarShape = false,
    required double size,
    required double stringLength,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final swingValue = math.sin(_animationController.value * math.pi) * 3;
          return Transform.rotate(
            angle: swingValue * math.pi / 180,
            child: child,
          );
        },
        child: Column(
          children: [
            // String
            Container(
              width: 2,
              height: stringLength,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            // Ornament
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: isStarShape ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isStarShape ? BorderRadius.circular(8) : null,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: size * 0.5)
                  : isStarShape
                      ? const Center(
                          child: Text('★', style: TextStyle(color: Colors.white, fontSize: 20)),
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallLight({
    double? left,
    double? right,
    required double top,
    required Color color,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeCardsSection(List<Item> items) {
    // Take first 3 items or pad with nulls
    final displayItems = List<Item?>.generate(
      3,
      (i) => i < items.length ? items[i] : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // First card (white/highlighted)
          Expanded(
            flex: 4,
            child: _buildItemCard(
              item: displayItems[0],
              isHighlighted: true,
              index: 0,
            ),
          ),
          const SizedBox(width: 10),
          // Second card (purple translucent)
          Expanded(
            flex: 3,
            child: _buildItemCard(
              item: displayItems[1],
              isHighlighted: false,
              index: 1,
            ),
          ),
          const SizedBox(width: 10),
          // Third card (purple translucent)
          Expanded(
            flex: 3,
            child: _buildItemCard(
              item: displayItems[2],
              isHighlighted: false,
              index: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    Item? item,
    required bool isHighlighted,
    required int index,
  }) {
    if (item == null) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: cardPurple.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, false));
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.white : cardPurple.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                item.name ?? 'Item',
                style: robotoBold.copyWith(
                  fontSize: isHighlighted ? 14 : 12,
                  color: isHighlighted ? deepPurple : Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isHighlighted && item.storeName != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.storeName!,
                  style: robotoRegular.copyWith(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              // Image or icon at bottom
              if (isHighlighted)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CustomImage(
                        image: item.imageFullUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // Avatar stack for non-highlighted cards
                    SizedBox(
                      width: 60,
                      height: 30,
                      child: Stack(
                        children: List.generate(
                          3,
                          (i) => Positioned(
                            left: i * 15.0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cardPurple, width: 2),
                                color: Colors.grey.shade300,
                              ),
                              child: ClipOval(
                                child: CustomImage(
                                  image: item.imageFullUrl ?? '',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'manage'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Right button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Get.toNamed(RouteHelper.getPopularItemRoute(true, false));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accentYellow, accentPink],
                    ),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'view_all'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnowyEdge() {
    return ClipPath(
      clipper: _SnowyEdgeClipper(),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

/// Custom painter for the string/wire connecting lights
class _LightStringPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 15);
    
    // Create a gentle curve across the top
    final controlPoints = [
      Offset(size.width * 0.15, 25),
      Offset(size.width * 0.3, 10),
      Offset(size.width * 0.5, 20),
      Offset(size.width * 0.7, 8),
      Offset(size.width * 0.85, 22),
      Offset(size.width, 12),
    ];
    
    for (int i = 0; i < controlPoints.length; i++) {
      if (i == 0) {
        path.quadraticBezierTo(
          size.width * 0.075, 20,
          controlPoints[i].dx, controlPoints[i].dy,
        );
      } else {
        final prevPoint = controlPoints[i - 1];
        final midX = (prevPoint.dx + controlPoints[i].dx) / 2;
        final midY = (prevPoint.dy + controlPoints[i].dy) / 2;
        path.quadraticBezierTo(
          midX, midY + (i.isEven ? 5 : -5),
          controlPoints[i].dx, controlPoints[i].dy,
        );
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom clipper for snowy/wavy bottom edge
class _SnowyEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Start from bottom left
    path.moveTo(0, size.height);
    path.lineTo(0, 15);
    
    // Create bumpy snow-like top edge
    const bumpCount = 8;
    final bumpWidth = size.width / bumpCount;
    
    for (int i = 0; i < bumpCount; i++) {
      final startX = i * bumpWidth;
      final endX = (i + 1) * bumpWidth;
      final midX = startX + bumpWidth / 2;
      final bumpHeight = (i % 3 == 0) ? 0.0 : (i % 2 == 0 ? 10.0 : 15.0);
      
      path.quadraticBezierTo(
        midX, bumpHeight,
        endX, 15,
      );
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Shimmer loading state for ItemThatYouLoveView
class _ItemThatYouLoveShimmerView extends StatelessWidget {
  const _ItemThatYouLoveShimmerView();

  static const Color primaryPurple = Color(0xFF7B2CBF);
  static const Color darkPurple = Color(0xFF5A189A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeDefault,
      ),
      child: Shimmer(
        duration: const Duration(seconds: 2),
        enabled: true,
        child: Column(
          children: [
            // Header shimmer
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkPurple.withValues(alpha: 0.3),
                    primaryPurple.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Container(
                  width: 200,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Cards shimmer
            Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryPurple.withValues(alpha: 0.3),
                    darkPurple.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    width: 160,
                    height: 220,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
