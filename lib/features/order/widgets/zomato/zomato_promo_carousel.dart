import 'package:flutter/material.dart';
import 'package:waddy_app/util/styles.dart';

const Color _primary = Color(0xFF134E4A);
const Color _accent = Color(0xFF1EF2A0);

class ZomatoPromoCarousel extends StatefulWidget {
  const ZomatoPromoCarousel({super.key});

  @override
  State<ZomatoPromoCarousel> createState() => _ZomatoPromoCarouselState();
}

class _ZomatoPromoCarouselState extends State<ZomatoPromoCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 128,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: 3,
              padEnds: false,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) => _buildPromoCard(context, index),
            ),
          ),
          const SizedBox(height: 10),
          // Pagination dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final bool active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: active ? _primary : Colors.grey.shade300,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'WADDI',
                        style: robotoBold.copyWith(
                          fontSize: 9,
                          color: _accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'REWARDS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: robotoBold.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF333333),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '10% cashback on all orders',
                  style: robotoBold.copyWith(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Extraordinary Rewards | Zero Joining Fee\n| T&C apply',
                  style: robotoRegular.copyWith(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Apply now',
                      style: robotoMedium.copyWith(
                        fontSize: 13,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: _accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent.withValues(alpha: 0.15),
                  _primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              size: 32,
              color: _primary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
