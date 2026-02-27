import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/xp/controllers/xp_controller.dart';
import 'package:sixam_mart/features/dashboard/screens/dashboard_screen.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';

class LetterDialogWidget extends StatefulWidget {
  const LetterDialogWidget({super.key});

  @override
  State<LetterDialogWidget> createState() => _LetterDialogWidgetState();
}

class _LetterDialogWidgetState extends State<LetterDialogWidget>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _hintAnimation;

  @override
  void initState() {
    super.initState();

    // Main opening animation - simplified and lighter
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Pulse animation to indicate clickability - lighter
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _hintAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    _pulseController.stop();
    _animationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isOpen = true;
          });
        }
      });
    });
  }

  void _claimFoundingBadge() async {
    final xpController = Get.find<XpController>();

    // User is automatically Level 1 (0 XP = Level 1)
    // Just refresh level data to confirm and show success
    await xpController.getCurrentLevel(reload: true);

    // Show success snackbar
    Get.snackbar(
      '🎉 ${'congratulations'.tr}',
      'founding_badge_claimed'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Theme.of(context).primaryColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    // Close dialog and navigate to levels screen
    Navigator.of(context).pop();
    Get.offAll(() => const DashboardScreen(pageIndex: 1));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxLetterHeight = screenHeight * 0.75;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          color: Colors.black.withOpacity(
            _isOpen ? 0.5 : _animationController.value * 0.3,
          ),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isOpen)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Opacity(
                                  opacity:
                                      1.0 - (_animationController.value * 0.3),
                                  child: _buildEnvelope(context),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Opacity(
                                opacity:
                                    _hintAnimation.value *
                                    (1.0 - _animationController.value),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app_rounded,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tap to open',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    if (_isOpen) _buildLetterContent(context, maxLetterHeight),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnvelope(BuildContext context) {
    // Theme colors - teal and neon green mix
    final Color primaryColor = Theme.of(context).primaryColor; // Dark teal
    final Color secondaryColor =
        Theme.of(context).colorScheme.secondary; // Neon green
    final Color envelopeColor =
        Color.lerp(primaryColor, secondaryColor, 0.3)!; // Mix of teal and green
    final Color envelopeDarker = primaryColor; // Dark teal for depth
    const Color goldColor = Color(0xFFFFD93D); // Golden yellow
    const Color goldDarker = Color(0xFFE6B800); // Darker gold for depth

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _toggleOpen,
            child: Container(
              width: 280,
              height: 350,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [envelopeColor, envelopeDarker],
                ),
                boxShadow: [
                  BoxShadow(
                    color: envelopeColor.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Subtle inner highlight at top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Curved fold line (letter flap) - simplified
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(280, 120),
                      painter: EnvelopeFlapPainter(
                        flapColor: envelopeDarker,
                        lineColor: goldColor,
                      ),
                    ),
                  ),

                  // Golden seal with SVG asset (positioned on top of the fold line)
                  Positioned(
                    top: 40,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          colors: [
                            Color(0xFFFFE066), // Light gold highlight
                            goldColor,
                            goldDarker,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: goldColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: goldDarker.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              "assets/on_boarding/Asset 11.svg",
                              width: 30,
                              height: 30,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFCC8800),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Date and From/To text
                  Positioned(
                    top: 118,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM d, y').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Reward text
                  Positioned(
                    bottom: 140,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '🎁 ${'letter_reward_inside'.tr}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Stamps at the bottom center
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Center(
                          child: Transform.scale(
                            scale: 0.95,
                            child: _buildModernStamp(),
                          ),
                        ),
                        GetBuilder<ProfileController>(
                          builder: (profileController) {
                            final userName =
                                profileController.userInfoModel?.fName ?? 'You';
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ' ${'Waddy Team'.tr}',
                                    style: TextStyle(
                                      color: Color(0xFFE6B800),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${'To'.tr} $userName',
                                    style: TextStyle(
                                      color: Color(0xFFE6B800),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetterContent(BuildContext context, double maxHeight) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 500),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: PaperTexturePainter())),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        "assets/on_boarding/Asset 11.svg",
                        height: 24,
                        width: 24,
                        colorFilter: ColorFilter.mode(
                          secondaryColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'letter_team_name'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.black38,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'letter_founding_member_title'.tr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Body Text
                      Text(
                        'letter_founding_member_body'.tr,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Color(0xFF4A4A4A),
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Signature
                      Text(
                        'letter_signature'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // CTA Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              Color.lerp(primaryColor, secondaryColor, 0.2)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _claimFoundingBadge,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Text(
                                'letter_claim_badge'.tr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary Action
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black45,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'letter_got_it_thanks'.tr,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
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
  }

  Widget _buildModernStamp() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("assets/image/mail1.png", height: 80, width: 80),
        const SizedBox(width: 2),
        Transform.rotate(
          angle: -0.3,
          child: Image.asset("assets/image/mail2.png", height: 70, width: 70),
        ),
      ],
    );
  }
}

class EnvelopeFlapPainter extends CustomPainter {
  final Color flapColor;
  final Color lineColor;

  EnvelopeFlapPainter({required this.flapColor, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the curved fold line (golden arc across the envelope)
    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    // Create a curved path from left to right
    final path = Path();
    path.moveTo(0, 90); // Start from left edge
    path.quadraticBezierTo(
      size.width / 2, // Control point X (center)
      130, // Control point Y (lower = more curve)
      size.width, // End X (right edge)
      90, // End Y
    );

    canvas.drawPath(path, linePaint);

    // Draw subtle shadow line below
    final shadowPaint =
        Paint()
          ..color = flapColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random(42);

    for (int i = 0; i < 4000; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      paint.color = Colors.black.withOpacity(0.01 + random.nextDouble() * 0.02);
      canvas.drawCircle(Offset(dx, dy), 0.5, paint);
    }

    for (int i = 0; i < 80; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final length = 4 + random.nextDouble() * 6;
      final angle = random.nextDouble() * 2 * 3.14159;

      paint.color = Colors.brown.withOpacity(0.05);
      paint.strokeWidth = 0.5;
      paint.style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx + cos(angle) * length, dy + sin(angle) * length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
