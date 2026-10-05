import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/widgets/place_vote_action.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_section_header.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// "Places to visit" — category filter chips over a vertical, story-first list
/// of spots. Stays in the neubrutalist system (teal border, hard offset shadow)
/// but pitched quieter than the leaderboard hero — thinner border and a smaller
/// shadow — so the loud board above stays the hero. Mirrors `.chips` / `.places`.
class PlacesToVisitSection extends StatelessWidget {
  const PlacesToVisitSection({super.key});

  /// Scroll target for "pick a spot" affordances elsewhere on the screen.
  static final GlobalKey anchorKey = GlobalKey(debugLabel: 'spotsList');

  @override
  Widget build(BuildContext context) {
    // Two builders, not one: the chip rail reads the category list and the
    // card list reads the places list, and those arrive from different calls.
    // Sharing a builder meant the categories response rebuilt every place
    // card and vice versa.
    return Column(
      key: anchorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GetBuilder<PlacesController>(
          id: PlacesController.idFilters,
          builder: (controller) {
            final categories = controller.categories ?? [];
            final count =
                controller.totalPlaces ?? controller.places?.length ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpotsSectionHeader(
                  kicker: 'spots_not_just_voting'.tr,
                  title: 'spots_places_to_visit_title'.tr,
                  // A stat, not a link — there is no places-list screen to open.
                  stat: trPlural('spots_count_spots', count),
                ),
                // ── Category chips ──
                //
                // A filter needs at least two things to filter between. With
                // one real category every spot matches both chips, so "ALL /
                // CAFES" is a control that cannot change anything — decoration
                // charging 48px of vertical space above the content.
                if (categories.length < 2)
                  const SizedBox(height: Spots.s4)
                else ...[
                  const SizedBox(height: Spots.s16),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      // End padding keeps the last chip's hard shadow from
                      // clipping at the viewport edge.
                      padding: const EdgeInsetsDirectional.only(end: Spots.s4),
                      children: [
                        _Chip(
                          label: displayCaps('spots_all_chip'.tr),
                          mark: SpotsMark.flame,
                          selected: controller.selectedCategoryId == null,
                          onTap: () => controller.setSelectedCategory(null),
                        ),
                        ...categories.map(
                          (c) => Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: Spots.s8,
                            ),
                            child: _Chip(
                              label: displayCaps(c.name),
                              selected: controller.selectedCategoryId == c.id,
                              onTap: () => controller.setSelectedCategory(c.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Sort sits outside the category rail on purpose: that rail
                // is hidden when there are fewer than two categories, and
                // sorting is useful either way.
                const SizedBox(height: Spots.s12),
                const _SortRow(),
              ],
            );
          },
        ),
        const SizedBox(height: Spots.s4),

        // ── Place cards ──
        GetBuilder<PlacesController>(
          id: PlacesController.idPlaces,
          builder: (controller) {
            final places = controller.places ?? [];
            if (controller.isPlacesLoading && places.isEmpty) {
              return const _PlacesSkeleton();
            }
            if (places.isEmpty) return const _PlacesEmpty();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in places)
                  Padding(
                    padding: const EdgeInsets.only(top: Spots.s12),
                    child: RepaintBoundary(child: _PlaceCard(place: p)),
                  ),
                // The append spinner. Without a visible row the list simply
                // stops at the bottom for the length of a round trip, which
                // reads as the end of the catalogue rather than as loading.
                if (controller.isLoadingMorePlaces)
                  const Padding(
                    padding: EdgeInsets.only(top: Spots.s16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Spots.teal,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                // End of the rail: the user has seen what we have, so this is
                // where asking for a spot we don't have makes sense (`S-02`).
                // Only once there is no more to load, or it sits mid-list.
                if (!controller.hasMorePlaces)
                  const Padding(
                    padding: EdgeInsets.only(top: Spots.s16),
                    child: SubmitSpotCta(),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sort control for the venue list.
///
/// `setSortBy` and the whole `sort` → `sort_by` query path were already built
/// and wired end to end — the backend accepts `votes`, `rating`, `featured`,
/// `distance` and `newest` — but nothing in the app called it, so `_sortBy`
/// sat on its `'rating'` default forever. On a screen whose premise is a
/// weekly vote race, "most voted" was the one order you could not ask for.
/// See `S-06`.
///
/// Three options, not five: `featured` duplicates the board above, and
/// `distance` needs a location the Spots home does not ask for.
class _SortRow extends StatelessWidget {
  const _SortRow();

  static const List<({String key, String label})> _options = [
    (key: 'votes', label: 'spots_sort_votes'),
    (key: 'rating', label: 'spots_sort_rating'),
    (key: 'newest', label: 'spots_sort_newest'),
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idFilters,
      builder: (controller) {
        return SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsetsDirectional.only(end: Spots.s4),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Spots.s8),
                child: Center(
                  child: Text(
                    displayCaps('spots_sort_label'.tr),
                    style: Spots.kicker(10, color: Spots.ink3, tracking: 0.08),
                  ),
                ),
              ),
              for (final option in _options)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Spots.s8),
                  child: _SortChip(
                    label: displayCaps(option.label.tr),
                    selected: controller.sortBy == option.key,
                    onTap: () => controller.setSortBy(option.key),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Quieter than [_Chip] — sorting reorders what is already there, so it should
/// not compete with the category filter that changes what is there at all.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Spots.s12),
        decoration: BoxDecoration(
          color: selected ? Spots.mint : Spots.paper,
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          borderRadius: BorderRadius.circular(Spots.radiusPill),
        ),
        child: Text(
          label,
          style: waddyBold.copyWith(
            fontSize: 11,
            color: Spots.teal,
            letterSpacing: displayTracking(0.04 * 11),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final SpotsMark? mark;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.mark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: Spots.s12,
          vertical: Spots.s12,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Spots.teal : Spots.paper,
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          borderRadius: BorderRadius.circular(Spots.radiusPill),
          boxShadow: Spots.shadow(dx: 2, dy: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mark != null) ...[
              SpotsGlyph(
                mark!,
                size: 13,
                color: selected ? Spots.mint : Spots.teal,
              ),
              const SizedBox(width: Spots.s4),
            ],
            Text(
              label,
              style: waddyBlack.copyWith(
                fontSize: 12,
                color: selected ? Colors.white : Spots.teal,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  const _PlaceCard({required this.place});

  static final TextStyle _metaStyle = waddyBold.copyWith(
    fontSize: 11,
    color: Spots.ink3,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    final cover = place.coverImage ?? place.image ?? '';
    final logo = place.image ?? '';
    final mono = place.title.isNotEmpty ? displayCaps(place.title[0]) : '?';
    final zone = place.zone?.displayName ?? place.zone?.name;
    final cat = place.categoryName;
    final badge = _badge(place);
    final crowns = place.titlesCount;
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    // "New this week" means never seen before. A spot with weekly crowns to
    // its name has been here for weeks, so claiming both at once (which the
    // card did — "6× 🏆" beside "New this week") is simply false. With no
    // votes yet and a history behind it, say nothing about novelty.
    final today =
        place.votesCount > 0
            ? '▲ ${trPlural('spots_vote_count', place.votesCount)}'
            : (crowns > 0 ? null : 'spots_new_this_week'.tr);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SpotsPressable(
          onTap:
              () => Get.toNamed(
                RouteHelper.getPlaceDetailsRoute(place.id),
                arguments: place,
              ),
          dx: 3,
          dy: 3,
          child: Container(
            // Quieter than the leaderboard hero (3px border, dx/dy 4–5 shadow) but
            // unmistakably in the same neubrutalist system: teal border + a small
            // hard offset shadow. Hierarchy comes from shadow *size*, not from
            // switching to a soft, blurred, foreign card language.
            decoration: Spots.card(
              fill: Spots.paper,
              borderWidth: Spots.borderThin,
              dx: 0,
              dy: 0,
            ),
            padding: const EdgeInsets.all(Spots.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo + logo badge — fixed size, so the row needs no
                // IntrinsicHeight double-layout pass.
                SizedBox(
                  width: 104,
                  height: 112,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Spots.canvasDot,
                            border: Border.all(
                              color: Spots.border,
                              width: Spots.borderThin,
                            ),
                            borderRadius: BorderRadius.circular(Spots.radiusMd),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              cover.isNotEmpty
                                  ? CustomImage(image: cover, fit: BoxFit.cover)
                                  : Center(
                                    child: Text(
                                      mono,
                                      style: Spots.display(
                                        34,
                                        color: Spots.teal,
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                      PositionedDirectional(
                        end: -7,
                        bottom: -7,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Spots.paper,
                            border: Border.all(
                              color: Spots.border,
                              width: Spots.borderThin,
                            ),
                            borderRadius: BorderRadius.circular(
                              Spots.radiusSm + 3,
                            ),
                            boxShadow: Spots.shadow(dx: 2, dy: 2),
                          ),
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          child:
                              logo.isNotEmpty
                                  // Fills the badge — the container already clips to
                                  // its rounded rect, so the mark reads as the tile.
                                  ? CustomImage(
                                    image: logo,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                  )
                                  : Text(
                                    mono,
                                    style: waddyBlack.copyWith(
                                      fontSize: 15,
                                      color: Spots.teal,
                                      height: 1,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spots.s12),

                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reserved slot: the badge is optional per spot, but without a
                      // fixed-height row the title of a badge-less card rides up and
                      // the list loses its shared baseline (see Dunkin vs Starbucks).
                      //
                      // The badge itself went missing: `_badge(place)` was still
                      // computed on every card and dropped on the floor, so
                      // "CURRENT CHAMPION" / "TOP 3" / "FIRST APPEARANCE" were
                      // classified per spot and never drawn. Same shape as `S-01`
                      // — a comment describing a control, and an empty slot where
                      // it should be. See `S-13`.
                      SizedBox(
                        height: 18,
                        child:
                            badge == null
                                ? null
                                : Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: _BadgeChip(badge: badge),
                                ),
                      ),
                      const SizedBox(height: Spots.s8),
                      Text(
                        place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Spots.display(
                          18,
                          color: Spots.ink,
                        ).copyWith(height: 1),
                      ),
                      const SizedBox(height: Spots.s4),
                      Row(
                        children: [
                          if (cat != null)
                            Flexible(
                              child: Text(
                                cat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _metaStyle,
                              ),
                            ),
                          if (cat != null && zone != null)
                            Text(' · ', style: _metaStyle),
                          if (zone != null) ...[
                            const Icon(
                              Icons.place_rounded,
                              size: 13,
                              color: Spots.ink3,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                zone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _metaStyle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Spots.s12),
                      Row(
                        children: [
                          // Nothing truthful to say about this spot's week —
                          // the Spacer still holds the vote button at the end.
                          if (today == null)
                            const Spacer()
                          else
                            Expanded(
                              child: Text(
                                today,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: waddyBlack.copyWith(
                                  fontSize: 13,
                                  color:
                                      place.votesCount > 0
                                          ? Spots.green
                                          : Spots.ink3,
                                ),
                              ),
                            ),
                          SpotsPressable(
                            onTap: () => openVoteSheet(place.id),
                            dx: 2,
                            dy: 2,
                            radius: Spots.radiusMd,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Spots.teal,
                                border: Border.all(
                                  color: Spots.border,
                                  width: Spots.borderThin,
                                ),
                                borderRadius: BorderRadius.circular(
                                  Spots.radiusMd,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spots.s16,
                                vertical: Spots.s8,
                              ),
                              child: Text(
                                '${displayCaps('spots_vote_cta'.tr)} ${isLtr ? '→' : '←'}',
                                style: waddyBlack.copyWith(
                                  fontSize: 12,
                                  color: Colors.white,
                                  letterSpacing: displayTracking(0.03 * 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (crowns > 0)
          PositionedDirectional(
            top: Spots.s8,
            end: Spots.s8,
            child: _WeeklyCrownBadge(count: crowns),
          ),
      ],
    );
  }

  _Badge? _badge(Place p) {
    if (p.isCurrentChampion) {
      return _Badge(
        displayCaps('spots_badge_current_champion'.tr),
        Spots.teal,
        Spots.mint,
        SpotsMark.trophy,
      );
    }
    if (p.votesCount > 0 && (p.rank ?? 99) <= 3) {
      return _Badge(
        displayCaps('spots_badge_top3'.tr),
        Spots.red,
        Colors.white,
        SpotsMark.flame,
      );
    }
    // Only a spot with no votes *and* no history is a first appearance.
    if (p.votesCount == 0 && p.titlesCount == 0) {
      return _Badge(
        displayCaps('spots_badge_first_appearance'.tr),
        Spots.mint,
        Spots.teal,
        SpotsMark.bolt,
      );
    }
    return null;
  }
}

class _Badge {
  final String label;
  final Color color;
  final Color fg;
  final SpotsMark? mark;
  const _Badge(this.label, this.color, this.fg, this.mark);
}

/// The per-spot status chip — champion / top 3 / first appearance.
///
/// Small and flat on purpose: it sits above the spot's own name inside a card
/// that already carries a border and a hard shadow, so giving it a shadow of
/// its own would put three stacked frames in one 80px row.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s8,
        vertical: Spots.s4 - 2,
      ),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(Spots.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.mark != null) ...[
            SpotsGlyph(badge.mark!, size: 10, color: badge.fg),
            const SizedBox(width: Spots.s4 - 1),
          ],
          Text(
            badge.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: waddyBlack.copyWith(
              fontSize: 9,
              color: badge.fg,
              letterSpacing: displayTracking(0.06 * 9),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "N× weekly crown" count, as a compact corner chip on the photo
/// instead of a full-width sticker — the count plus the trophy sticker say
/// enough on their own at this size, so the label text is dropped.
class _WeeklyCrownBadge extends StatelessWidget {
  final int count;
  const _WeeklyCrownBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spots.s4),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${fmtCount(count)}×',
            style: waddyBlack.copyWith(
              fontSize: 18,
              color: Spots.teal,
              height: 1,
            ),
          ),
          const SizedBox(height: 40, child: SpotsTrophyGlyph(size: 40)),
        ],
      ),
    );
  }
}

class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(top: Spots.s12),
          child: SpotsSkeleton(height: 136),
        ),
      ),
    );
  }
}

class _PlacesEmpty extends StatelessWidget {
  const _PlacesEmpty();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spots.s12),
      padding: const EdgeInsets.symmetric(
        vertical: Spots.s24,
        horizontal: Spots.s16,
      ),
      width: double.infinity,
      decoration: Spots.card(
        fill: Spots.paper,
        borderWidth: Spots.borderThin,
        dx: 3,
        dy: 3,
      ),
      child: Column(
        children: [
          const SpotsGlyph(SpotsMark.pin, size: 30, color: Spots.ink3),
          const SizedBox(height: Spots.s8),
          Text(
            'spots_no_spots_in_category'.tr,
            style: waddyBlack.copyWith(fontSize: 13, color: Spots.ink),
          ),
          // An empty board is the strongest possible moment to ask for a
          // submission, and until now it was a dead end: the form exists and
          // nothing in the app navigated to it. See `S-02`.
          const SizedBox(height: Spots.s16),
          const SubmitSpotCta(),
        ],
      ),
    );
  }
}

/// "Know a spot we're missing?" — the entry point to [PlaceSubmissionScreen].
///
/// The submission flow is 492 lines of working form behind a registered route
/// that nothing navigated to: `getPlaceSubmitRoute()` had no callers, so the
/// user-generated half of a hidden-gems board was switched off. This is the
/// way in. See `S-02` in `docs/spots_module_plan.md`.
///
/// Quiet on purpose. It sits below the venue list and inside the empty state,
/// where a user has just failed to find what they wanted — it should read as
/// an offer, not as the screen's main action (that is the vote CTA above).
class SubmitSpotCta extends StatelessWidget {
  const SubmitSpotCta({super.key});

  @override
  Widget build(BuildContext context) {
    return SpotsPressable(
      onTap: () => Get.toNamed(RouteHelper.getPlaceSubmitRoute()),
      dx: 3,
      dy: 3,
      radius: Spots.radiusMd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: Spots.s12,
          horizontal: Spots.s16,
        ),
        decoration: Spots.card(
          fill: Spots.paperWarm,
          radius: Spots.radiusMd,
          borderWidth: Spots.borderThin,
          dx: 3,
          dy: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SpotsGlyph(SpotsMark.pin, size: 16, color: Spots.teal),
            const SizedBox(width: Spots.s8),
            Flexible(
              child: Text(
                displayCaps('submit_hidden_gem'.tr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: waddyBlack.copyWith(
                  fontSize: 12,
                  color: Spots.teal,
                  letterSpacing: displayTracking(0.05 * 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
