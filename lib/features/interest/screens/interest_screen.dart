import 'dart:math' as math;
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:waddy_app/common/widgets/web_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InterestScreen extends StatefulWidget {
  const InterestScreen({super.key});

  @override
  State<InterestScreen> createState() => _InterestScreenState();
}

class _InterestScreenState extends State<InterestScreen> with TickerProviderStateMixin {
  final List<_DartAnimation> _dartAnimations = [];
  final GlobalKey _dartboardKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    Get.find<CategoryController>().getCategoryList(true, allCategory: false);
  }

  @override
  void dispose() {
    for (var anim in _dartAnimations) {
      anim.controller.dispose();
    }
    super.dispose();
  }

  GlobalKey _getItemKey(int index) {
    if (!_itemKeys.containsKey(index)) {
      _itemKeys[index] = GlobalKey();
    }
    return _itemKeys[index]!;
  }

  void _onInterestTap(int index) {
    final categoryController = Get.find<CategoryController>();
    final wasSelected = categoryController.interestSelectedList![index];
    
    categoryController.addInterestSelection(index);
    
    // Only animate dart when selecting (not deselecting)
    if (!wasSelected) {
      _throwDart(_getItemKey(index));
    }
  }

  void _throwDart(GlobalKey itemKey) {
    final RenderBox? itemBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? dartboardBox = _dartboardKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (itemBox == null || dartboardBox == null) return;

    final itemPosition = itemBox.localToGlobal(Offset.zero);
    final itemCenter = Offset(
      itemPosition.dx + itemBox.size.width / 2,
      itemPosition.dy + itemBox.size.height / 2,
    );

    final dartboardPosition = dartboardBox.localToGlobal(Offset.zero);
    final dartboardCenter = Offset(
      dartboardPosition.dx + dartboardBox.size.width / 2,
      dartboardPosition.dy + dartboardBox.size.height / 2,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final dartAnim = _DartAnimation(
      controller: controller,
      startPosition: itemCenter,
      endPosition: dartboardCenter,
    );

    setState(() {
      _dartAnimations.add(dartAnim);
    });

    controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _dartAnimations.remove(dartAnim);
          });
          controller.dispose();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isDesktop ? const WebMenuBar() : null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: GetBuilder<CategoryController>(builder: (categoryController) {
          if (categoryController.categoryList == null) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }
          
          if (categoryController.categoryList!.isEmpty) {
            return NoDataScreen(text: 'no_category_found'.tr);
          }

          final selectedCount = categoryController.interestSelectedList
              ?.where((selected) => selected)
              .length ?? 0;

          return Stack(
            children: [
              // Main scrollable content
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with dartboard
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).primaryColor,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Your Interests',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).primaryColor,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'get_personalized_recommendations'.tr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Dartboard - bigger size
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  key: _dartboardKey,
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stuck arrows
                                if (selectedCount >= 1)
                                  Positioned(
                                    left: 0,
                                    top: 50,
                                    child: _StuckArrow(angle: -0.2, primaryColor: Theme.of(context).primaryColor),
                                  ),
                                if (selectedCount >= 2)
                                  Positioned(
                                    left: 10,
                                    top: 80,
                                    child: _StuckArrow(angle: 0.1, primaryColor: Theme.of(context).primaryColor),
                                  ),
                                if (selectedCount >= 3)
                                  Positioned(
                                    right: 5,
                                    top: 55,
                                    child: _StuckArrow(angle: 0.15, primaryColor: Theme.of(context).primaryColor, flipX: true),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Interest items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(
                          categoryController.categoryList!.length,
                          (index) {
                            final isSelected = categoryController.interestSelectedList![index];
                            final itemKey = _getItemKey(index);
                            
                            return _InterestListItem(
                              key: itemKey,
                              category: categoryController.categoryList![index],
                              isSelected: isSelected,
                              onTap: () => _onInterestTap(index),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dart animations overlay
              ..._dartAnimations.map((dartAnim) => _DartWidget(animation: dartAnim)),

              // Bottom button - styled like onboarding Next button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: GestureDetector(
                      onTap: categoryController.isLoading
                          ? null
                          : () {
                              List<int?> interests = [];
                              for (int index = 0; index < categoryController.categoryList!.length; index++) {
                                if (categoryController.interestSelectedList![index]) {
                                  interests.add(categoryController.categoryList![index].id);
                                }
                              }
                              categoryController.saveInterest(interests).then((isSuccess) {
                                if (isSuccess) {
                                  if (ResponsiveHelper.isDesktop(Get.context)) {
                                    Get.offAllNamed(RouteHelper.getInitialRoute());
                                  } else {
                                    Get.back();
                                  }
                                }
                              });
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).secondaryHeaderColor,
                              blurRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Arc shapes inside button
                            Positioned(
                              left: 20,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 20,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Button content
                            categoryController.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'continue'.tr,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _InterestListItem extends StatelessWidget {
  final dynamic category;
  final bool isSelected;
  final VoidCallback onTap;

  const _InterestListItem({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Theme.of(context).primaryColor
                    : const Color(0xFFE8E8E8),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomImage(
                      image: '${category.imageFullUrl}',
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Category name
                Expanded(
                  child: Text(
                    category.name ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).primaryColor
                          : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).primaryColor
                          : const Color(0xFFD0D0D0),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DartAnimation {
  final AnimationController controller;
  final Offset startPosition;
  final Offset endPosition;

  _DartAnimation({
    required this.controller,
    required this.startPosition,
    required this.endPosition,
  });
}

class _DartWidget extends StatelessWidget {
  final _DartAnimation animation;

  const _DartWidget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation.controller,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(animation.controller.value);
        final currentPosition = Offset.lerp(
          animation.startPosition,
          animation.endPosition,
          progress,
        )!;

        // Calculate rotation angle based on direction
        final direction = animation.endPosition - animation.startPosition;
        final angle = math.atan2(direction.dy, direction.dx);

        // Scale effect - starts small, grows, then shrinks at target
        final scale = progress < 0.5 
            ? 0.5 + progress 
            : 1.5 - progress;

        // Opacity - fade in at start, fade out at end
        final opacity = progress < 0.1 
            ? progress * 10 
            : progress > 0.9 
                ? (1 - progress) * 10 
                : 1.0;

        return Positioned(
          left: currentPosition.dx - 30,
          top: currentPosition.dy - 10,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale.clamp(0.5, 1.2),
                child: _FlyingArrow(primaryColor: Theme.of(context).primaryColor),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Flying arrow during animation
class _FlyingArrow extends StatelessWidget {
  final Color primaryColor;
  
  const _FlyingArrow({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 20,
      child: CustomPaint(
        painter: _ArrowPainter(primaryColor: primaryColor),
      ),
    );
  }
}

// Stuck arrow on dartboard
class _StuckArrow extends StatelessWidget {
  final double angle;
  final Color primaryColor;
  final bool flipX;
  
  const _StuckArrow({
    required this.angle,
    required this.primaryColor,
    this.flipX = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scaleX: flipX ? -1 : 1,
        child: SizedBox(
          width: 50,
          height: 16,
          child: CustomPaint(
            painter: _ArrowPainter(primaryColor: primaryColor),
          ),
        ),
      ),
    );
  }
}

// Custom painter for arrow with green feathers
class _ArrowPainter extends CustomPainter {
  final Color primaryColor;
  
  _ArrowPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final featherColor = primaryColor;
    final shaftColor = Colors.grey.shade700;
    
    // Arrow shaft (dark gray line)
    final shaftPaint = Paint()
      ..color = shaftColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(size.width * 0.3, size.height / 2),
      Offset(size.width, size.height / 2),
      shaftPaint,
    );
    
    // Arrow tip (triangle)
    final tipPaint = Paint()
      ..color = shaftColor
      ..style = PaintingStyle.fill;
    
    final tipPath = Path()
      ..moveTo(size.width, size.height / 2)
      ..lineTo(size.width * 0.85, size.height * 0.3)
      ..lineTo(size.width * 0.85, size.height * 0.7)
      ..close();
    
    canvas.drawPath(tipPath, tipPaint);
    
    // Feathers (green leaves at the back)
    final featherPaint = Paint()
      ..color = featherColor
      ..style = PaintingStyle.fill;
    
    // Top feather
    final topFeatherPath = Path()
      ..moveTo(size.width * 0.3, size.height / 2)
      ..quadraticBezierTo(
        size.width * 0.15, size.height * 0.1,
        0, size.height * 0.2,
      )
      ..quadraticBezierTo(
        size.width * 0.1, size.height * 0.4,
        size.width * 0.3, size.height / 2,
      )
      ..close();
    
    canvas.drawPath(topFeatherPath, featherPaint);
    
    // Bottom feather
    final bottomFeatherPath = Path()
      ..moveTo(size.width * 0.3, size.height / 2)
      ..quadraticBezierTo(
        size.width * 0.15, size.height * 0.9,
        0, size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.1, size.height * 0.6,
        size.width * 0.3, size.height / 2,
      )
      ..close();
    
    canvas.drawPath(bottomFeatherPath, featherPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
