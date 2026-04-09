import 'package:flutter/material.dart';
import 'package:waddy_app/features/order/widgets/games/lucky_day_game_slide.dart';
import 'package:waddy_app/features/order/widgets/games/vote_place_game_slide.dart';
import 'package:waddy_app/util/styles.dart';

const Color _primary = Color(0xFF134E4A);
const Color _accent = Color(0xFF1EF2A0);

/// Delight layer — "Play & Win While You Wait" card with gradient header
/// and the Lucky Day flip-card + Vote-for-Best-Place games inside.
class ZomatoScratchCard extends StatefulWidget {
  const ZomatoScratchCard({super.key});

  @override
  State<ZomatoScratchCard> createState() => _ZomatoScratchCardState();
}

class _ZomatoScratchCardState extends State<ZomatoScratchCard> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int index) {
    if (!_pageController.hasClients || index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primary, Color(0xFF1A6B65)],
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: "Play & Win While You Wait"
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    // Gift icons
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Transform.rotate(
                          angle: -0.18,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.card_giftcard_rounded,
                              size: 18,
                              color: _accent,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: -4,
                          child: Transform.rotate(
                            angle: 0.15,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: _accent.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Play & Win',
                            style: robotoBold.copyWith(
                              fontSize: 16,
                              color: _accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'While You Wait',
                            style: robotoRegular.copyWith(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Swipe hint
                    Row(
                      children: [
                        Icon(
                          Icons.swipe_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'swipe',
                          style: robotoRegular.copyWith(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Game PageView
              SizedBox(
                height: 220,
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (mounted) setState(() => _currentIndex = index);
                  },
                  children: [
                    LuckyDayGameSlide(
                      currentIndex: _currentIndex,
                      onDotTap: _animateToPage,
                    ),
                    VotePlaceGameSlide(
                      currentIndex: _currentIndex,
                      onDotTap: _animateToPage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
