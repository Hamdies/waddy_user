import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/home/widgets/ramadan/ramadan_string_light_wrapper.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class RamadanStallView extends StatefulWidget {
  const RamadanStallView({super.key});

  @override
  State<RamadanStallView> createState() => _RamadanStallViewState();
}

class _RamadanStallViewState extends State<RamadanStallView> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late ScrollController _scrollController;
  
  // Brand Colors
  final Color _brandTeal = const Color(0xFF134E4A);
  final Color _brandNeon = const Color(0xFF1EF2A0);
  final Color _ramadanGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        final nextScroll = currentScroll + 160; 
        
        if (nextScroll >= maxScroll) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOutQuart,
          );
        } else {
          _scrollController.animateTo(
            nextScroll,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
        _startAutoScroll();
      }
    });
  }

  List<Item>? _getGroceryItems(ItemController itemController) {
    List<Item>? allItems = itemController.ramadanFeaturedItemList;
    if (allItems == null || allItems.isEmpty) allItems = itemController.popularItemList;
    if (allItems == null || allItems.isEmpty) allItems = itemController.reviewedItemList;
    if (allItems == null || allItems.isEmpty) allItems = itemController.discountedItemList;
    if (allItems == null || allItems.isEmpty) allItems = itemController.recommendedItemList;
    
    return (allItems != null && allItems.isNotEmpty) ? allItems : null;
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return GetBuilder<HomeController>(
      builder: (homeController) {
        if (!homeController.isRamadanCelebrationActive) return const SizedBox.shrink();
        
        return GetBuilder<ItemController>(
          builder: (itemController) {
            final groceryItems = _getGroceryItems(itemController);

            if (groceryItems == null || groceryItems.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              height: 350, 
              margin: EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeDefault,
                horizontal: isSmallScreen ? 4 : 8,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Column(
                    children: [
                      // 1. The Classic Awning
                      _buildTentAwning(context, isSmallScreen),
                      
                      // 2. The Main Body with Light Borders
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E8).withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            border: Border(
                              left: BorderSide(color: _ramadanGold.withValues(alpha: 0.5), width: 1.5),
                              right: BorderSide(color: _ramadanGold.withValues(alpha: 0.5), width: 1.5),
                              bottom: BorderSide(color: _ramadanGold.withValues(alpha: 0.5), width: 1.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              const RamadanStringLightWrapper(
                                showTopString: true,
                                alwaysOn: true,
                                child: SizedBox(height: 8),
                              ),

                              Expanded(
                                child: RepaintBoundary(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                                    itemCount: groceryItems.length > 12 ? 12 : groceryItems.length,
                                    itemExtent: 150,
                                    itemBuilder: (context, index) {
                                      return _RamadanItemCard(
                                        item: groceryItems[index],
                                        brandTeal: _brandTeal,
                                        brandNeon: _brandNeon,
                                        ramadanGold: _ramadanGold,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTentAwning(BuildContext context, bool isSmallScreen) {
    return SizedBox(
      height: 45,
      width: double.infinity,
      child: CustomPaint(
        painter: _TentAwningPainter(color1: _brandTeal, color2: const Color(0xFF0A3F3A)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 8),
            Text(
              "Ramadan Essentials",
              style: robotoBold.copyWith(
                fontSize: isSmallScreen ? 13 : 15,
                color: Colors.white,
                shadows: [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1,1))]
              ),
            ),
            const SizedBox(width: 8),
            HugeIcon(icon: HugeIcons.strokeRoundedRamadhan01, color: _brandNeon, size: 22),
          ],
        ),
      ),
    );
  }
}

class _TentAwningPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  
  _TentAwningPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color1, color2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
    final path = Path();
    path.moveTo(0, 8);
    path.quadraticBezierTo(size.width / 2, 0, size.width, 8);
    path.lineTo(size.width, size.height - 10);
    
    double scallopWidth = size.width / 10;
    for (int i = 0; i < 10; i++) {
      path.relativeQuadraticBezierTo(-scallopWidth / 2, 10, -scallopWidth, 0);
    }
    path.close();
    
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);
    
    final borderPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --------------------------------------------------------------------------
// UPDATED RAMADAN ITEM CARD
// --------------------------------------------------------------------------

class _RamadanItemCard extends StatelessWidget {
  final Item item;
  final Color brandTeal;
  final Color brandNeon;
  final Color ramadanGold;

  const _RamadanItemCard({
    required this.item,
    required this.brandTeal,
    required this.brandNeon,
    required this.ramadanGold,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.find<ItemController>().navigateToItemPage(item, context),
      child: Container(
        margin: const EdgeInsets.only(right: 12, bottom: 4), 
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: _IslamicCardShape(
            borderColor: ramadanGold.withValues(alpha: 0.2), 
            width: 1
          ),
          shadows: [
            BoxShadow(
              color: const Color(0xFF134E4A).withValues(alpha: 0.06),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // IMAGE SECTION
            SizedBox(
              height: 125,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipPath(
                    clipper: const _IslamicArchClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
                      child: CustomImage(
                        image: '${item.imageFullUrl}',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  CustomPaint(
                    painter: _RamadanOverlayPainter(color: ramadanGold, accent: brandTeal),
                  ),

                  // Discount Badge
                  if (item.discount != null && item.discount! > 0)
                    Positioned(
                      top: 18, 
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandTeal,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: brandNeon, width: 1),
                        ),
                        child: Text(
                          PriceConverter.percentageCalculation(
                            item.price.toString(), 
                            item.discount.toString(), 
                            item.discountType ?? ''
                          ),
                          style: robotoBold.copyWith(fontSize: 9, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // INFO & BUTTON SECTION
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // NEW: "RAMADAN PICK" (Premium Calligraphy Shape)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        // Gold Gradient for premium feel
                        gradient: LinearGradient(
                          colors: [ramadanGold.withValues(alpha: 0.15), ramadanGold.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        // Asymmetric corners (Leaf / Calligraphy style)
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                          topRight: Radius.circular(2),
                          bottomLeft: Radius.circular(2),
                        ),
                        border: Border.all(color: ramadanGold.withValues(alpha: 0.6), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 8, color: ramadanGold), // Solid star
                          const SizedBox(width: 4),
                          Text(
                            "Ramadan Pick",
                            style: robotoBold.copyWith( // Bolder
                              fontSize: 9, 
                              color: const Color(0xFF996515), // Dark Gold
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    Text(
                      item.name ?? '',
                      style: robotoMedium.copyWith(fontSize: 12, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 1),

                    // Price
                    Row(
                      children: [
                        if (item.discount != null && item.discount! > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              PriceConverter.convertPrice(item.price),
                              style: robotoRegular.copyWith(
                                fontSize: 10,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        Text(
                          PriceConverter.convertPrice(
                            PriceConverter.convertWithDiscount(item.price, item.discount, item.discountType)
                          ),
                          style: robotoBold.copyWith(fontSize: 13, color: brandTeal),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // NEW: GEOMETRIC "ADD" BUTTON (Beveled Shape)
                    InkWell(
                      onTap: () => Get.find<ItemController>().itemDirectlyAddToCart(item, context),
                      child: Container(
                        width: double.infinity,
                        height: 28,
                        // ShapeDecoration allows for Beveled borders (Geometric/Gem cut)
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(8), // Cut corners
                            side: BorderSide(color: brandTeal, width: 1.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "ADD",
                              style: robotoBold.copyWith(
                                fontSize: 11,
                                color: brandTeal,
                                letterSpacing: 1.2, // Spaced for modern look
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.add, size: 14, color: brandTeal),
                          ],
                        ),
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
}

// --------------------------------------------------------------------------
// SHAPES & CLIPPERS
// --------------------------------------------------------------------------

class _IslamicCardShape extends ShapeBorder {
  final Color borderColor;
  final double width;

  const _IslamicCardShape({this.borderColor = Colors.grey, this.width = 1.0});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    path.moveTo(rect.left, rect.bottom - 12); 
    path.quadraticBezierTo(rect.left, rect.bottom, rect.left + 12, rect.bottom);
    path.lineTo(rect.right - 12, rect.bottom);
    path.quadraticBezierTo(rect.right, rect.bottom, rect.right, rect.bottom - 12);
    path.lineTo(rect.right, rect.top + 15);
    
    path.quadraticBezierTo(
      rect.left + rect.width * 0.75, rect.top + 15,
      rect.left + rect.width / 2, rect.top
    ); 
    path.quadraticBezierTo(
      rect.left + rect.width * 0.25, rect.top + 15,
      rect.left, rect.top + 15
    );
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

class _IslamicArchClipper extends CustomClipper<Path> {
  const _IslamicArchClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, 15);
    path.quadraticBezierTo(size.width * 0.25, 15, size.width / 2, 0); 
    path.quadraticBezierTo(size.width * 0.75, 15, size.width, 15);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RamadanOverlayPainter extends CustomPainter {
  final Color color;
  final Color accent;
  _RamadanOverlayPainter({required this.color, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final lanternX = size.width - 20;
    final stringPaint = Paint()..color = color.withValues(alpha: 0.5)..strokeWidth = 1;
    canvas.drawLine(Offset(lanternX, 0), Offset(lanternX, 15), stringPaint);
    
    final lanternPaint = Paint()..color = accent;
    final lanternPath = Path();
    lanternPath.moveTo(lanternX, 15);
    lanternPath.lineTo(lanternX - 4, 20);
    lanternPath.lineTo(lanternX - 2, 28);
    lanternPath.lineTo(lanternX + 2, 28);
    lanternPath.lineTo(lanternX + 4, 20);
    lanternPath.close();
    canvas.drawPath(lanternPath, lanternPaint);
    
    canvas.drawCircle(Offset(lanternX, 22), 1.5, Paint()..color = const Color(0xFFFFD700));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}