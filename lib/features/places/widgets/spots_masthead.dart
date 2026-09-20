import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/area_filter_tabs.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// The WADDI Spots masthead — deep-teal panel with the logo/wordmark, the
/// "My prizes" badge, and a tap-through area (zone) filter. Mirrors the
/// `.apphd` block from templates/home/Home.dc.html.
class SpotsMasthead extends StatelessWidget {
  const SpotsMasthead({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idMasthead,
      builder: (controller) {
        final zoneName = controller.selectedZoneName;

        return Container(
          decoration: const BoxDecoration(
            color: Spots.panel,
            border: Border(
              bottom: BorderSide(color: Spots.border, width: Spots.borderThick),
            ),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spots.gutter,
            Spots.s8,
            Spots.gutter,
            Spots.s8,
          ),
          child: Row(
            children: [
              // ── Brand + wordmark (brand mark — intentionally un-localized) ──
              Image.asset(
                'assets/image/waddy.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: Spots.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'WADDY',
                          style: waddyBlack.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: displayTracking(0.03 * 18),
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: Spots.s4),
                        Text(
                          'SPOTS',
                          style: waddyBlack.copyWith(
                            fontSize: 18,
                            color: Spots.mint,
                            letterSpacing: displayTracking(0.03 * 18),
                            height: 1,
                          ),
                        ),
                      ],
                    ),

                    // Area filter trigger — reads as a quiet sub-line, but the
                    // hit box is padded up to a ≥44px touch target.
                    _AreaTrigger(
                      zoneName: zoneName,
                      onTap: () => _openAreaSheet(context),
                    ),
                  ],
                ),
              ),

              // ── My Prizes (mint outline pill, shimmering) ──
              _PrizeButton(hasLivePrize: controller.featuredPrize != null),
            ],
          ),
        );
      },
    );
  }

  static void _openPrizes() => Get.toNamed(RouteHelper.getSpotsPrizesRoute());

  void _openAreaSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Spots.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spots.radiusLg),
        ),
      ),
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spots.s20,
                  Spots.s16,
                  Spots.s20,
                  Spots.s12,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Spots.border,
                      width: Spots.borderThick,
                    ),
                  ),
                ),
                child: Text(
                  displayCaps('spots_select_area'.tr),
                  style: Spots.kicker(13, color: Spots.ink),
                ),
              ),
              const AreaFilterTabs(),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + Spots.s16,
              ),
            ],
          ),
    );
  }
}

/// The area (zone) filter trigger — the quiet sub-line under the wordmark.
///
/// This is the module's only way into zone scoping, and it went missing: the
/// masthead computed [PlacesController.selectedZoneName] and defined the sheet,
/// but nothing rendered a control between them, so `_openAreaSheet` had no call
/// sites and five downstream mechanisms (the zone refetch, the FCM topic swap,
/// the per-zone rank snapshots, the zone chips themselves, and the top-3
/// section's zone kicker) could never run. See `S-01` in
/// `docs/spots_module_plan.md`.
///
/// Deliberately quiet: it is a scope indicator, not an action. The mint marks
/// it as interactive without competing with the "MY PRIZES" pill opposite.
class _AreaTrigger extends StatelessWidget {
  const _AreaTrigger({required this.zoneName, required this.onTap});

  /// Null means no zone filter — the board is showing everywhere at once.
  final String? zoneName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = zoneName ?? 'spots_all_areas'.tr;

    return Semantics(
      button: true,
      label: 'spots_select_area'.tr,
      value: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The line itself is ~14px tall. The padding takes the hit box to a
        // ≥44px target without stretching the masthead, which is why it is
        // vertical padding on the gesture target rather than height on the row.
        child: Padding(
          padding: const EdgeInsets.only(top: Spots.s4, bottom: Spots.s8 + 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 12,
                color: Spots.mint,
              ),
              const SizedBox(width: Spots.s4),
              // The zone name can be long and the masthead is a fixed row;
              // let it ellipsize rather than push the prizes pill off-screen.
              Flexible(
                child: Text(
                  displayCaps(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: Spots.mint,
                    letterSpacing: displayTracking(0.05 * 10),
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: Spots.s4 - 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: Spots.mint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "MY PRIZES" pill — mint outline with a mint shimmer sweep, sitting where the
/// week badge used to. The mint dot only appears while a voucher is actually
/// live: a badge that's always lit stops meaning anything. The shimmer is
/// decoration only, so it's dropped entirely under reduced motion.
class _PrizeButton extends StatelessWidget {
  const _PrizeButton({required this.hasLivePrize});

  final bool hasLivePrize;

  @override
  Widget build(BuildContext context) {
    final Widget pill = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spots.s8,
        Spots.s4 + 2,
        Spots.s8,
        Spots.s4 + 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Spots.mint, width: Spots.borderThin),
        borderRadius: BorderRadius.circular(Spots.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedGift,
            size: 14,
            color: Spots.mint,
          ),
          const SizedBox(width: Spots.s4 + 2),
          Text(
            displayCaps('spots_my_prizes'.tr),
            style: waddyBlack.copyWith(
              fontSize: 11,
              color: Spots.mint,
              letterSpacing: displayTracking(0.05 * 11),
              height: 1,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: SpotsMasthead._openPrizes,
      child: Semantics(
        button: true,
        label: 'spots_my_prizes'.tr,
        // The pill is shorter than 44px on its own — pad the hit box up to it
        // without letting the vertical padding stretch the masthead.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spots.s8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (MediaQuery.of(context).disableAnimations)
                pill
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(Spots.radiusPill),
                  child: Shimmer(
                    interval: const Duration(seconds: 2),
                    color: Spots.mint,
                    colorOpacity: 0.28,
                    child: pill,
                  ),
                ),
              if (hasLivePrize)
                PositionedDirectional(
                  top: -3,
                  end: -3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Spots.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Spots.panel, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
