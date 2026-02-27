import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/xp/domain/models/xp_level_model.dart';

class LevelClaimCelebrationWidget extends StatefulWidget {
  final int level;
  final String levelName;
  final String? badgeImage;
  final String? description;
  final List<Map<String, dynamic>> gifts;
  final List<LevelPrize> prizes;
  final Future<bool> Function(int levelNumber)? onClaimPrizes;
  final bool hasPrizesToClaim;

  const LevelClaimCelebrationWidget({
    super.key,
    required this.level,
    required this.levelName,
    this.badgeImage,
    this.description,
    this.gifts = const [],
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

  // Neo-pop color palette
  static const _neoBlack = Color(0xFF121212);
  static const _brandTeal = Color(0xFF134E4A);
  static const _accentGreen = Color(0xFF1EF2A0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _spinAnimation = Tween<double>(begin: pi * 5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutQuart),
      ),
    );

    _particleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.95, curve: Curves.easeOut),
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
      decoration: BoxDecoration(
        color: _brandTeal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row with handle and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ANIMATION SECTION
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Particle Burst
                      Opacity(
                        opacity:
                            _particleAnimation.value <= 0.8
                                ? 1
                                : (1 - _particleAnimation.value) * 5,
                        child: CustomPaint(
                          size: const Size(180, 180),
                          painter: ConfettiBurstPainter(
                            progress: _particleAnimation.value,
                            color: _accentGreen,
                          ),
                        ),
                      ),

                      // Neo-pop Spinning Badge
                      Transform(
                        alignment: Alignment.center,
                        transform:
                            Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_spinAnimation.value),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: _buildNeoBadge(),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              // Neo-pop Title Card
              _buildAnimatedText(
                delay: 0.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _neoBlack, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: _neoBlack,
                        offset: Offset(5, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.levelName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _neoBlack,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _accentGreen,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _neoBlack, width: 2),
                        ),
                        child: Text(
                          '${'level'.tr} ${widget.level}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _neoBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (widget.description != null &&
                  widget.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAnimatedText(
                  delay: 0.65,
                  child: Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Prizes Section
              if (widget.prizes.isNotEmpty) ...[
                _buildAnimatedText(
                  delay: 0.75,
                  child: _buildNeoPrizesSection(),
                ),
                const SizedBox(height: 14),
              ],

              // Status indicator
              _buildAnimatedText(
                delay: 0.9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _hasClaimed
                            ? _accentGreen
                            : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _hasClaimed
                              ? _neoBlack
                              : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasClaimed ? Icons.check_circle : Icons.lock_open,
                        color: _hasClaimed ? _neoBlack : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasClaimed
                            ? 'prizes_claimed'.tr
                            : 'level_unlocked'.tr,
                        style: TextStyle(
                          fontSize: 15,
                          color: _hasClaimed ? _neoBlack : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Neo-pop Action Button
              _buildAnimatedText(delay: 1.0, child: _buildNeoActionButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeoBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Neo-pop badge container
        Container(
          width: 160,
          height: 160,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child:
                widget.badgeImage != null
                    ? CustomImage(
                      image: widget.badgeImage!,
                      height: 140,
                      width: 140,
                      fit: BoxFit.contain,
                    )
                    : Center(
                      child: Text(
                        widget.level.toString(),
                        style: const TextStyle(
                          color: _brandTeal,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ),
        ),

        // Corner accent
      ],
    );
  }

  Widget _buildNeoPrizesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neoBlack, width: 2.5),
        boxShadow: const [
          BoxShadow(color: _neoBlack, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _accentGreen,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _neoBlack, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard, color: _neoBlack, size: 18),
                const SizedBox(width: 8),
                Text(
                  'level_prizes'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _neoBlack,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Prizes grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children:
                widget.prizes
                    .map((prize) => _buildNeoPrizeChip(prize))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoPrizeChip(LevelPrize prize) {
    final color = _getPrizeColor(prize.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPrizeIcon(prize.type), color: color, size: 18),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              prize.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
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

  Widget _buildNeoActionButton() {
    final showClaimButton = widget.hasPrizesToClaim && !_hasClaimed;

    return GestureDetector(
      onTap:
          showClaimButton
              ? (_isClaimingPrizes ? null : _claimPrizes)
              : () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: showClaimButton ? _accentGreen : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _neoBlack, width: 3),
          boxShadow: const [
            BoxShadow(color: _neoBlack, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Center(
          child:
              _isClaimingPrizes
                  ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(_neoBlack),
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        showClaimButton
                            ? Icons.card_giftcard
                            : Icons.check_circle,
                        size: 24,
                        color: _neoBlack,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        showClaimButton
                            ? 'claim_prizes'.tr
                            : 'awesome'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _neoBlack,
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

    setState(() {
      _isClaimingPrizes = true;
    });

    try {
      final success = await widget.onClaimPrizes!(widget.level);
      if (success && mounted) {
        setState(() {
          _hasClaimed = true;
          _isClaimingPrizes = false;
        });
      } else if (mounted) {
        setState(() {
          _isClaimingPrizes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaimingPrizes = false;
        });
      }
    }
  }

  IconData _getPrizeIcon(String type) {
    switch (type) {
      case 'badge':
        return Icons.military_tech;
      case 'free_delivery':
        return Icons.local_shipping;
      case 'discount':
        return Icons.discount;
      case 'wallet_credit':
        return Icons.account_balance_wallet;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _getPrizeColor(String type) {
    switch (type) {
      case 'badge':
        return _brandTeal;
      case 'free_delivery':
        return Colors.blue.shade600;
      case 'discount':
        return Colors.green.shade600;
      case 'wallet_credit':
        return Colors.purple.shade600;
      default:
        return _brandTeal;
    }
  }

  Widget _buildAnimatedText({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double start = delay;
        final double end = (delay + 0.3).clamp(0.0, 1.0);
        final double rawValue = ((_controller.value - start) / (end - start))
            .clamp(0.0, 1.0);
        final curveValue = Curves.easeOut.transform(rawValue);

        return Opacity(
          opacity: curveValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curveValue)),
            child: child,
          ),
        );
      },
    );
  }
}

// --- PAINTERS & CLIPPERS ---

class ConfettiBurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Random random = Random(42);

  ConfettiBurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    final int particleCount = 20;
    final double maxRadius = size.width / 1.1;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount)) * (pi / 180);
      final distance = maxRadius * progress * 1.2;

      final randomOffset = (random.nextDouble() - 0.5) * 40;
      final currentDistance = distance + (progress * randomOffset);

      final x = center.dx + cos(angle) * currentDistance;
      final y = center.dy + sin(angle) * currentDistance;

      final particleSize = 10.0 * (1 - progress * 0.7);

      if (i % 4 == 0)
        paint.color = color;
      else if (i % 4 == 1)
        paint.color = color.withValues(alpha: 0.8);
      else if (i % 4 == 2)
        paint.color = Color.lerp(color, Colors.white, 0.3)!;
      else
        paint.color = Color.lerp(color, Colors.cyan, 0.2)!;

      paint.color = paint.color.withValues(
        alpha: (1 - progress * 0.8).clamp(0.0, 1.0),
      );

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 2);

      final shapeType = i % 3;
      if (shapeType == 0) {
        _drawStar(canvas, paint, particleSize);
      } else if (shapeType == 1) {
        canvas.drawCircle(Offset.zero, particleSize / 2, paint);
      } else {
        _drawDiamond(canvas, paint, particleSize);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final outerRadius = size / 2;
    final innerRadius = size / 4;

    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 2 * pi / 5) - pi / 2;
      final innerAngle = ((i + 0.5) * 2 * pi / 5) - pi / 2;

      if (i == 0) {
        path.moveTo(
          cos(outerAngle) * outerRadius,
          sin(outerAngle) * outerRadius,
        );
      } else {
        path.lineTo(
          cos(outerAngle) * outerRadius,
          sin(outerAngle) * outerRadius,
        );
      }
      path.lineTo(cos(innerAngle) * innerRadius, sin(innerAngle) * innerRadius);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final halfSize = size / 2;
    path.moveTo(0, -halfSize);
    path.lineTo(halfSize, 0);
    path.lineTo(0, halfSize);
    path.lineTo(-halfSize, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
