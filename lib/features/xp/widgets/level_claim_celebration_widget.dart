import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/xp/domain/models/xp_level_model.dart';

class LevelClaimCelebrationWidget extends StatefulWidget {
  final int level;
  final String levelName;
  final String? badgeImage;
  final String? description;
  final List<LevelPrize> prizes;
  final Future<bool> Function(int levelNumber)? onClaimPrizes;
  final bool hasPrizesToClaim;

  const LevelClaimCelebrationWidget({
    super.key,
    required this.level,
    required this.levelName,
    this.badgeImage,
    this.description,
    this.prizes = const [],
    this.onClaimPrizes,
    this.hasPrizesToClaim = false,
  });

  @override
  State<LevelClaimCelebrationWidget> createState() =>
      _LevelClaimCelebrationWidgetState();
}

class _LevelClaimCelebrationWidgetState
    extends State<LevelClaimCelebrationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _spinAnimation;
  late Animation<double> _particleAnimation;

  bool _isClaimingPrizes = false;
  bool _hasClaimed = false;

  // Neubrutalism palette
  static const _ink = Color(0xFF0D0D0D);
  static const _canvas = Color(0xFFF5F0E8); // warm off-white
  static const _teal = Color(0xFF134E4A);
  static const _neon = Color(0xFF1EF2A0);
  static const _coral = Color(0xFFFF5C5C);
  static const _gold = Color(0xFFFFD166);
  static const _sky = Color(0xFF5BC4FF);
  static const _violet = Color(0xFFB97FFF);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _spinAnimation = Tween<double>(begin: pi * 4, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutQuart),
      ),
    );

    _particleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.92, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: _ink, width: 3),
          left: BorderSide(color: _ink, width: 3),
          right: BorderSide(color: _ink, width: 3),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle + close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _ink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _ink,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: _ink,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: _canvas,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Badge + confetti
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Confetti burst — white + neon against canvas background
                      Opacity(
                        opacity: _particleAnimation.value <= 0.75
                            ? 1.0
                            : (1 - _particleAnimation.value) * 4,
                        child: CustomPaint(
                          size: const Size(200, 200),
                          painter: _ConfettiBurstPainter(
                            progress: _particleAnimation.value,
                            seed: widget.level,
                          ),
                        ),
                      ),

                      // Spinning badge
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_spinAnimation.value),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: _buildBadge(),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Title card
              _fadeSlide(
                delay: 0.45,
                child: _buildTitleCard(),
              ),

              if (widget.description != null &&
                  widget.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _fadeSlide(
                  delay: 0.55,
                  child: Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _ink.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              if (widget.prizes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _fadeSlide(
                  delay: 0.65,
                  child: _buildPrizesSection(),
                ),
              ],

              const SizedBox(height: 20),

              // Action button
              _fadeSlide(
                delay: 0.80,
                child: _buildActionButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ink, width: 3),
        boxShadow: const [
          BoxShadow(color: _ink, offset: Offset(6, 6), blurRadius: 0),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: widget.badgeImage != null
            ? CustomImage(
                image: widget.badgeImage!,
                height: 160,
                width: 160,
                fit: BoxFit.contain,
              )
            : Center(
                child: Text(
                  widget.level.toString(),
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _neon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ink, width: 3),
        boxShadow: const [
          BoxShadow(color: _ink, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.levelName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${'level'.tr} ${widget.level}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _neon,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: _ink, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _ink, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, color: _ink, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'level_prizes'.tr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.prizes.map(_buildPrizeChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeChip(LevelPrize prize) {
    final color = _prizeColor(prize.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_prizeIcon(prize.type), color: color, size: 16),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              prize.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final showClaim = widget.hasPrizesToClaim && !_hasClaimed;

    return GestureDetector(
      onTap: showClaim
          ? (_isClaimingPrizes ? null : _claimPrizes)
          : () => Navigator.of(context).pop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          color: _hasClaimed ? _neon : (showClaim ? _teal : _ink),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [
            BoxShadow(color: _ink, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Center(
          child: _isClaimingPrizes
              ? SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                      showClaim ? Colors.white : _ink,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasClaimed
                          ? Icons.check_circle_rounded
                          : (showClaim
                              ? Icons.card_giftcard_rounded
                              : Icons.celebration_rounded),
                      size: 22,
                      color: _hasClaimed ? _ink : Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _hasClaimed
                          ? 'prizes_claimed'.tr
                          : (showClaim ? 'claim_prizes'.tr : 'awesome'.tr),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _hasClaimed ? _ink : Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _claimPrizes() async {
    if (widget.onClaimPrizes == null) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isClaimingPrizes = true;
    });

    try {
      final success = await widget.onClaimPrizes!(widget.level);
      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        setState(() {
          _hasClaimed = true;
          _isClaimingPrizes = false;
        });
      } else {
        setState(() {
          _isClaimingPrizes = false;
        });
        Get.snackbar(
          'error'.tr,
          'claim_failed'.tr,
          backgroundColor: _coral,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isClaimingPrizes = false;
      });
      Get.snackbar(
        'error'.tr,
        'claim_failed'.tr,
        backgroundColor: _coral,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
    }
  }

  IconData _prizeIcon(String type) {
    switch (type) {
      case 'badge':
        return Icons.military_tech_rounded;
      case 'free_delivery':
        return Icons.local_shipping_rounded;
      case 'discount':
        return Icons.discount_rounded;
      case 'wallet_credit':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  Color _prizeColor(String type) {
    switch (type) {
      case 'badge':
        return _violet;
      case 'free_delivery':
        return _sky;
      case 'discount':
        return const Color(0xFF16A34A);
      case 'wallet_credit':
        return _coral;
      default:
        return _teal;
    }
  }

  Widget _fadeSlide({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final end = (delay + 0.25).clamp(0.0, 0.99);
        final t = ((_controller.value - delay) / (end - delay)).clamp(0.0, 1.0);
        final v = Curves.easeOut.transform(t);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

// ── Confetti Painter ─────────────────────────────────────────────────────────

class _ConfettiBurstPainter extends CustomPainter {
  final double progress;
  final int seed;

  _ConfettiBurstPainter({required this.progress, required this.seed});

  static const _colors = [
    Color(0xFF1EF2A0), // neon green
    Colors.white,
    Color(0xFFFFD166), // gold
    Color(0xFFFF5C5C), // coral
    Color(0xFF5BC4FF), // sky
    Color(0xFFB97FFF), // violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final random = Random(seed * 31 + 7);
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    const particleCount = 24;
    final maxRadius = size.width / 1.05;

    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (i * (360 / particleCount)) * (pi / 180);
      final angleJitter = (random.nextDouble() - 0.5) * 0.4;
      final angle = baseAngle + angleJitter;

      final distanceJitter = (random.nextDouble() - 0.5) * 30;
      final distance = maxRadius * progress * 1.15 + distanceJitter * progress;

      final x = center.dx + cos(angle) * distance;
      final y = center.dy + sin(angle) * distance;

      final particleSize = 9.0 * (1 - progress * 0.65);
      final alpha = (1 - progress * 0.85).clamp(0.0, 1.0);

      paint.color = _colors[i % _colors.length].withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 3 + i * 0.4);

      switch (i % 3) {
        case 0:
          _star(canvas, paint, particleSize);
          break;
        case 1:
          canvas.drawCircle(Offset.zero, particleSize * 0.5, paint);
          break;
        case 2:
          _diamond(canvas, paint, particleSize);
          break;
      }

      canvas.restore();
    }
  }

  void _star(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final outer = size / 2;
    final inner = size / 4;
    for (int i = 0; i < 5; i++) {
      final oa = (i * 2 * pi / 5) - pi / 2;
      final ia = ((i + 0.5) * 2 * pi / 5) - pi / 2;
      if (i == 0) {
        path.moveTo(cos(oa) * outer, sin(oa) * outer);
      } else {
        path.lineTo(cos(oa) * outer, sin(oa) * outer);
      }
      path.lineTo(cos(ia) * inner, sin(ia) * inner);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _diamond(Canvas canvas, Paint paint, double size) {
    final h = size / 2;
    final path = Path()
      ..moveTo(0, -h)
      ..lineTo(h * 0.6, 0)
      ..lineTo(0, h)
      ..lineTo(-h * 0.6, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConfettiBurstPainter old) => old.progress != progress;
}
