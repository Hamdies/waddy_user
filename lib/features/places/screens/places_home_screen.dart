import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/features/places/widgets/places_category_view.dart';
import 'package:sixam_mart/features/places/widgets/places_list_view.dart';
import 'package:sixam_mart/features/places/widgets/leaderboard_section.dart';
import 'package:sixam_mart/features/places/widgets/trending_places_view.dart';
import 'package:sixam_mart/features/places/widgets/tag_filter_view.dart';
import 'package:sixam_mart/features/places/widgets/places_search_bar.dart';
import 'package:sixam_mart/features/places/widgets/places_sort_chips.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

class PlacesHomeScreen extends StatefulWidget {
  const PlacesHomeScreen({super.key});

  @override
  State<PlacesHomeScreen> createState() => _PlacesHomeScreenState();
}

class _PlacesHomeScreenState extends State<PlacesHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final controller = Get.find<PlacesController>();
    await controller.initializePlacesData();
    if (AuthHelper.isLoggedIn()) {
      controller.getFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<PlacesController>(
      builder: (placesController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 8),

            // ─── HERO HEADER ───
            _buildHeroHeader(context, primary, neon),

            const SizedBox(height: 20),

            // ─── SEARCH ───
            const PlacesSearchBar(),

            const SizedBox(height: 18),

            // ─── MOOD / VIBE CATEGORIES ───
            const PlacesCategoryView(),

            const SizedBox(height: 20),

            // ─── TRENDING / HOT RIGHT NOW ───
            const TrendingPlacesView(),

            const SizedBox(height: 6),

            // ─── VIBE TAGS ───
            const TagFilterView(),

            const SizedBox(height: 20),

            // ─── TOP GEMS LEADERBOARD ───
            const LeaderboardSection(),

            const SizedBox(height: 20),

            // ─── SORT + DISCOVER ───
            const PlacesSortChips(),

            const SizedBox(height: 10),

            // ─── ALL GEMS LIST ───
            const PlacesListView(),

            // ─── SUBMIT CTA ───
            if (AuthHelper.isLoggedIn()) _buildSubmitCTA(context, primary, neon),

            const SizedBox(height: 120),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO HEADER — gradient welcome with emoji sparkle
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeroHeader(BuildContext context, Color primary, Color neon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: neon.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'discover_hidden_gems'.tr,
                  style: robotoBold.copyWith(
                    fontSize: 22,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'explore_best_vibes'.tr,
            style: robotoRegular.copyWith(
              fontSize: 13,
              color: neon.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildHeroStat('🔥', 'trending_now'.tr, neon),
              const SizedBox(width: 10),
              _buildHeroStat('⭐', 'top_rated'.tr, neon),
              const SizedBox(width: 10),
              _buildHeroStat('📍', 'near_you'.tr, neon),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String emoji, String label, Color neon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: neon.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neon.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: robotoMedium.copyWith(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUBMIT CTA — neon-style card
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSubmitCTA(BuildContext context, Color primary, Color neon) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeDefault,
      ),
      child: GestureDetector(
        onTap: () => Get.toNamed(RouteHelper.getPlaceSubmitRoute()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, primary.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: neon.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neon.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('🗺️', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'know_a_hidden_gem'.tr,
                      style: robotoBold.copyWith(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'submit_your_favorite_spot'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: 12,
                        color: neon.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: neon.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.arrow_forward_rounded, color: neon, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
