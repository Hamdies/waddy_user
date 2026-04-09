import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:scratcher/scratcher.dart';
import 'package:waddy_app/features/coupon/domain/models/coupon_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';

void showScratchCardDialog(BuildContext context, CouponModel coupon) {
  showGeneralDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.7),
    barrierDismissible: true,
    barrierLabel: 'Scratch Card',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) => ScratchCardDialog(coupon: coupon),
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: anim1.value,
        child: Opacity(opacity: anim1.value, child: child),
      );
    },
  );
}

class ScratchCardDialog extends StatefulWidget {
  final CouponModel coupon;

  const ScratchCardDialog({super.key, required this.coupon});

  @override
  State<ScratchCardDialog> createState() => _ScratchCardDialogState();
}

class _ScratchCardDialogState extends State<ScratchCardDialog>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  double _progress = 0.0;
  final _scratchKey = GlobalKey<ScratcherState>();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onProgress(double value) => setState(() => _progress = value);

  void _onRevealed() {
    if (!_isRevealed) {
      setState(() => _isRevealed = true);
      HapticFeedback.mediumImpact();
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.coupon.code ?? ''));
    showCustomSnackBar('coupon_code_copied'.tr, isError: false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary; // 0xFF134E4A
    final accentColor = theme.colorScheme.secondary; // 0xFF1EF2A0

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Transform.translate(
        offset: const Offset(3, 3),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Transform.translate(
            offset: const Offset(-3, -3),
            child: Container(
              width: size.width,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor, width: 2.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primaryColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _isRevealed ? '🎉 YOU WON!' : '🎁 SCRATCH TO WIN',
                      style: robotoBold.copyWith(
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _isRevealed
                        ? 'Your discount is ready'
                        : 'Reveal your discount',
                    style: robotoRegular.copyWith(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scratch card
                  _buildScratchCard(size, primaryColor, accentColor),
                  const SizedBox(height: 14),

                  // Bottom action
                  if (_isRevealed)
                    _buildCopyButton(primaryColor, accentColor)
                  else
                    _buildProgressIndicator(primaryColor, accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScratchCard(
    Size screenSize,
    Color primaryColor,
    Color accentColor,
  ) {
    final cardWidth = screenSize.width - 100;
    final cardHeight = screenSize.height * 0.35;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 2.5),
        boxShadow: [BoxShadow(color: primaryColor, offset: const Offset(4, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Scratcher layer
            Scratcher(
              key: _scratchKey,
              brushSize: 50,
              threshold: 40,
              accuracy: ScratchAccuracy.medium,
              color: accentColor,
              onChange: _onProgress,
              onThreshold: _onRevealed,
              child: _buildRevealContent(
                cardWidth,
                cardHeight,
                primaryColor,
                accentColor,
              ),
            ),
            // Overlay with logo and icons grid (fades as you scratch)
            IgnorePointer(
              child: Opacity(
                opacity: 1.0 - (_progress / 100).clamp(0.0, 1.0),
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Stack(
                    children: [
                      // Background grid of icons
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: 36,
                        itemBuilder: (context, index) {
                          final icons = [
                            Icons.percent,
                            Icons.local_offer,
                            Icons.card_giftcard,
                            Icons.confirmation_num,
                            Icons.savings,
                            Icons.redeem,
                            Icons.star,
                            Icons.monetization_on,
                            Icons.sell,
                          ];
                          return Icon(
                            icons[index % icons.length],
                            size: 18,
                            color: primaryColor.withOpacity(0.35),
                          );
                        },
                      ),
                      // Center logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            Images.scratchCardLogo,
                            width: 40,
                            height: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealContent(
    double width,
    double height,
    Color primaryColor,
    Color accentColor,
  ) {
    final currency =
        Get.find<SplashController>().configModel?.currencySymbol ?? '\$';
    final discount =
        widget.coupon.discountType == 'percent'
            ? '${widget.coupon.discount?.toStringAsFixed(0)}%'
            : '$currency${widget.coupon.discount?.toStringAsFixed(0)}';
    final type =
        widget.coupon.couponType == 'free_delivery'
            ? 'FREE DELIVERY'
            : 'DISCOUNT';
    final expiry =
        widget.coupon.expireDate != null
            ? DateConverter.stringToReadableString(widget.coupon.expireDate!)
            : 'No expiry';

    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 2),
              boxShadow: [
                BoxShadow(color: primaryColor, offset: const Offset(2, 2)),
              ],
            ),
            child: const Text('🎉', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 12),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: robotoBold.copyWith(
                fontSize: 10,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Discount value
          Text(
            discount,
            style: robotoBold.copyWith(
              fontSize: 44,
              color: primaryColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'OFF',
            style: robotoMedium.copyWith(
              fontSize: 14,
              color: accentColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),

          // Details
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Min. ${PriceConverter.convertPrice(widget.coupon.minPurchase)}',
                  style: robotoMedium.copyWith(
                    fontSize: 11,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expires: $expiry',
                  style: robotoRegular.copyWith(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Color primaryColor, Color accentColor) {
    if (_progress == 0) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.5 + (_pulseController.value * 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  'Swipe to reveal',
                  style: robotoMedium.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Text(
          '${_progress.toInt()}%',
          style: robotoBold.copyWith(fontSize: 14, color: primaryColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: 120,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 120 * (_progress / 100),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyButton(Color primaryColor, Color accentColor) {
    return GestureDetector(
      onTap: _copyCode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryColor, width: 2),
          boxShadow: [
            BoxShadow(color: primaryColor, offset: const Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Copy: ${widget.coupon.code}',
              style: robotoBold.copyWith(fontSize: 13, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
