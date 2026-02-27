import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/features/wallet/widgets/add_fund_dialogue_widget.dart';

class WalletCardWidget extends StatefulWidget {
  final JustTheController tooltipController;
  const WalletCardWidget({super.key, required this.tooltipController});

  @override
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  bool _isBalanceHidden = false;

  // Theme colors
  static const Color _neonGreen = Color(0xFF1EF2A0);
  static const Color _darkLeather = Color(0xFF1A1A1C);
  static const Color _leatherHighlight = Color(0xFF2A2A2C);

  @override
  Widget build(BuildContext context) {
    bool isDesktop = ResponsiveHelper.isDesktop(context);
    final ScrollController cardScrollController = ScrollController();

    return GetBuilder<ProfileController>(
      builder: (profileController) {
        final userName = profileController.userInfoModel?.fName ?? 'User';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isDesktop
                ? const SizedBox()
                : const SizedBox(height: Dimensions.paddingSizeSmall),

            // Single wallet widget - no extra containers
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background leather texture for entire wallet
                    Container(
                      height: 280,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_darkLeather, Color(0xFF161618)],
                        ),
                      ),
                      child: CustomPaint(
                        size: const Size(double.infinity, 280),
                        painter: FullLeatherTexturePainter(),
                      ),
                    ),

                    // Content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),

                        // User Card - VISA style (no balance)
                        _buildUserCard(context, userName, cardScrollController),

                        // Wallet Pocket
                        _buildWalletPocket(context, profileController),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            isDesktop
                ? const SizedBox()
                : const SizedBox(height: Dimensions.paddingSizeSmall),
            isDesktop
                ? const SizedBox(height: Dimensions.paddingSizeDefault)
                : const SizedBox(),

            isDesktop
                ? Text(
                  'how_to_use'.tr,
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                )
                : const SizedBox(),
            isDesktop
                ? const SizedBox(height: Dimensions.paddingSizeDefault)
                : const SizedBox(),

            !isDesktop ? const SizedBox() : const WalletStepper(),
          ],
        );
      },
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    String userName,
    ScrollController cardScrollController,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _neonGreen,
          boxShadow: [
            BoxShadow(
              color: _neonGreen.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User name on left
              Text(
                userName,
                style: robotoBold.copyWith(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // VISA simulation on right
              Row(
                children: [
                  Text(
                    '**** ',
                    style: robotoRegular.copyWith(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'VISA',
                    style: robotoBold.copyWith(
                      color: Colors.black.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  // Add fund button
                  if (Get.find<SplashController>()
                          .configModel!
                          .addFundStatus! &&
                      Get.find<SplashController>()
                          .configModel!
                          .digitalPayment!) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Get.dialog(
                          Dialog(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            child: SizedBox(
                              width: 500,
                              child: SingleChildScrollView(
                                controller: cardScrollController,
                                child: AddFundDialogueWidget(
                                  cardScrollController: cardScrollController,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletPocket(
    BuildContext context,
    ProfileController profileController,
  ) {
    final ScrollController fundScrollController = ScrollController();

    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          // Pocket with curved top
          Positioned.fill(
            child: CustomPaint(
              painter: WalletPocketPainter(
                pocketColor: _leatherHighlight,
                stitchColor: const Color(0xFF4A4A4C),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 55,
                left: 24,
                right: 24,
                bottom: 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hide Balance Row - Improved touch target
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBalanceHidden = !_isBalanceHidden;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isBalanceHidden
                                ? 'show_balance'.tr
                                : 'hide_balance'.tr,
                            style: robotoMedium.copyWith(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isBalanceHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Balance Amount
                  Text(
                    _isBalanceHidden
                        ? '****'
                        : PriceConverter.convertPrice(
                          profileController.userInfoModel!.walletBalance,
                        ),
                    textDirection: TextDirection.ltr,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Total Balance Label
                  Text(
                    'Total Balance',
                    style: robotoRegular.copyWith(
                      color: _neonGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Add Fund Button
                  if (Get.find<SplashController>()
                          .configModel!
                          .addFundStatus! &&
                      Get.find<SplashController>()
                          .configModel!
                          .digitalPayment!) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        Get.dialog(
                          Dialog(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            child: SizedBox(
                              width: 500,
                              child: SingleChildScrollView(
                                controller: fundScrollController,
                                child: AddFundDialogueWidget(
                                  cardScrollController: fundScrollController,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _neonGreen,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: _neonGreen.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'add_fund'.tr,
                              style: robotoBold.copyWith(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom accent tab
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 36,
                height: 6,
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Full leather texture for the entire wallet background
class FullLeatherTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    // Dense cross-hatch pattern
    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03)
          ..strokeWidth = 0.4
          ..style = PaintingStyle.stroke;

    // Diagonal lines (/)
    for (double i = -size.height; i < size.width + size.height; i += 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }

    // Diagonal lines (\)
    for (double i = 0; i < size.width + size.height; i += 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        linePaint,
      );
    }

    // Horizontal texture lines
    final hLinePaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hLinePaint);
    }

    // Leather grain dots
    final dotPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.02)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 300; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(x, y),
        0.3 + random.nextDouble() * 0.5,
        dotPaint,
      );
    }

    // Dark grain dots
    final darkDotPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(x, y),
        0.2 + random.nextDouble() * 0.3,
        darkDotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Wallet pocket painter with curve and stitching
class WalletPocketPainter extends CustomPainter {
  final Color pocketColor;
  final Color stitchColor;

  WalletPocketPainter({required this.pocketColor, required this.stitchColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw pocket shape
    final pocketPaint =
        Paint()
          ..color = pocketColor
          ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, 28);

    // Concave curve
    path.quadraticBezierTo(size.width * 0.05, 18, size.width * 0.15, 22);
    path.quadraticBezierTo(size.width * 0.35, 38, size.width * 0.5, 42);
    path.quadraticBezierTo(size.width * 0.65, 38, size.width * 0.85, 22);
    path.quadraticBezierTo(size.width * 0.95, 18, size.width, 28);

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, pocketPaint);

    // Add leather texture to pocket
    _drawPocketTexture(canvas, size, path);

    // Draw stitching
    _drawStitching(canvas, size);
  }

  void _drawPocketTexture(Canvas canvas, Size size, Path clipPath) {
    canvas.save();
    canvas.clipPath(clipPath);

    final random = Random(123);

    // Cross-hatch
    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.025)
          ..strokeWidth = 0.4
          ..style = PaintingStyle.stroke;

    for (double i = -size.height; i < size.width + size.height; i += 3.5) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }
    for (double i = 0; i < size.width + size.height; i += 3.5) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        linePaint,
      );
    }

    // Horizontal lines
    final hPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..strokeWidth = 0.4
          ..style = PaintingStyle.stroke;

    for (double y = 30; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }

    // Grain dots
    final dotPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.015)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = 30 + random.nextDouble() * (size.height - 30);
      canvas.drawCircle(
        Offset(x, y),
        0.3 + random.nextDouble() * 0.4,
        dotPaint,
      );
    }

    canvas.restore();
  }

  void _drawStitching(Canvas canvas, Size size) {
    final stitchPaint =
        Paint()
          ..color = stitchColor
          ..style = PaintingStyle.fill;

    const offset = 9.0;
    const radius = 1.0;
    const spacing = 7.0;

    // Left side
    for (double y = 38; y < size.height - 10; y += spacing) {
      canvas.drawCircle(Offset(offset, y), radius, stitchPaint);
    }

    // Right side
    for (double y = 38; y < size.height - 10; y += spacing) {
      canvas.drawCircle(Offset(size.width - offset, y), radius, stitchPaint);
    }

    // Bottom
    for (double x = 16; x < size.width - 16; x += spacing) {
      canvas.drawCircle(Offset(x, size.height - offset), radius, stitchPaint);
    }

    // Top curved edge
    for (double t = 0.02; t <= 0.98; t += 0.02) {
      final x = size.width * t;
      double y;

      if (t < 0.15) {
        final localT = t / 0.15;
        y = 28 - 6 * sin(localT * pi * 0.5) + 6;
      } else if (t < 0.5) {
        final localT = (t - 0.15) / 0.35;
        y = 22 + 20 * sin(localT * pi * 0.5) + 6;
      } else if (t < 0.85) {
        final localT = (t - 0.5) / 0.35;
        y = 42 - 20 * sin(localT * pi * 0.5) + 6;
      } else {
        final localT = (t - 0.85) / 0.15;
        y = 22 + 6 * sin(localT * pi * 0.5) + 6;
      }

      canvas.drawCircle(Offset(x, y), radius, stitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WalletStepper extends StatelessWidget {
  const WalletStepper({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'earn_money_to_your_wallet_by_completing_the_offer_challenged'
                      .tr,
                  style: robotoRegular,
                ),
                Text(
                  'convert_your_loyalty_points_into_wallet_money'.tr,
                  style: robotoRegular,
                ),
                Text(
                  'amin_also_reward_their_top_customers_with_wallet_money'.tr,
                  style: robotoRegular,
                ),
                Text(
                  'send_your_wallet_money_while_order'.tr,
                  style: robotoRegular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
