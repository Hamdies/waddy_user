import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/widgets/place_vote_action.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_section_header.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// "This week's top 3" — the live leaderboard hero. A big #01 leader card
/// (mint fill) over a pair of #02/#03 minis, then the screen's one loud vote
/// CTA. Ranked from [PlacesController.liveStandings] (official board when
/// locked, live vote order otherwise). Mirrors `.leader` / `.mini` in
/// Home.dc.html.
///
/// Whether the race is warm enough to show momentum is no longer decided here:
/// it comes from [PlacesController.stage], so this section and the live ticker
/// below it can't reach opposite conclusions about the same board.

class WeeklyTop3Section extends StatelessWidget {
  const WeeklyTop3Section({super.key, this.onBrowseSpots});

  /// Where the empty state sends the user: down to the spots list, which is
  /// the thing that fills this board. Owned by the screen because it owns the
  /// scroll position.
  final VoidCallback? onBrowseSpots;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idLeaderboard,
      builder: (controller) {
        if (controller.isLeaderboardLoading && controller.leaderboard == null) {
          return const _Top3Skeleton();
        }

        final standings = controller.liveStandings;
        if (standings.isEmpty) return _Top3Empty(onTap: onBrowseSpots);

        final zone = controller.selectedZoneName;
        final leader = standings.first;
        final runners = standings.skip(1).take(2).toList();

        // The race hasn't warmed up yet: with only a handful of votes on the
        // whole board, the "LIVE LEADER / ▲ momentum / ▼ behind" theatre reads
        // as a ghost town (a spot "2 behind" a leader with 1 vote looks broken).
        // Below the threshold we reframe the same hero as "just kicked off".
        // The threshold lives on the controller so every section agrees.
        final lowData = !controller.stage.isHot;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpotsSectionHeader(
              kicker: zone ?? 'spots_this_week'.tr,
              title: 'spots_top3_title'.tr,
            ),
            // The leader's "LIVE LEADER / EARLY LEAD" sticker hangs 20px above
            // the card, so the header needs more than the standard s16 or the
            // sticker collides with the section title above it.
            const SizedBox(height: Spots.s24),
            _LeaderCard(
              place: leader,
              delta: controller.rankDeltaFor(leader.id),
              lowData: lowData,
              tied: controller.isTiedAt(leader.id),
            ),
            if (runners.isNotEmpty) ...[
              const SizedBox(height: Spots.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i == 1) const SizedBox(width: Spots.s12),
                    Expanded(
                      child:
                          i < runners.length
                              ? _MiniCard(
                                place: runners[i],
                                // Competition rank, not list position: two
                                // spots on equal votes are tied, and printing
                                // 02/03 would assert an order the votes don't
                                // support.
                                rank:
                                    controller.rankOf(runners[i].id) ?? (i + 2),
                                tied: controller.isTiedAt(runners[i].id),
                                behind:
                                    leader.votesCount - runners[i].votesCount,
                                lowData: lowData,
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: Spots.s12),
            // The one loud action on the screen: vote. It backs the live #1
            // (the spot everyone's watching) so a single tap moves the board
            // the user is looking at.
            _CastVoteButton(
              label:
                  lowData
                      ? 'spots_vote_set_the_pace'.tr
                      : 'spots_vote_for_number_one'.tr,
              onTap: () => openVoteSheet(leader.id),
            ),
          ],
        );
      },
    );
  }
}

/// Rounded-square thumb with a hard border + a monogram logo badge overlapping
/// its corner — the recurring photo treatment across the design.
class _Thumb extends StatelessWidget {
  final Place place;
  final double size;
  final double logoSize;
  final double borderWidth;
  const _Thumb({
    required this.place,
    required this.size,
    required this.logoSize,
    this.borderWidth = Spots.borderThin,
  });

  @override
  Widget build(BuildContext context) {
    final cover = place.coverImage ?? place.image ?? '';
    final logo = place.image ?? '';
    final mono = place.title.isNotEmpty ? displayCaps(place.title[0]) : '?';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Spots.canvasDot,
              border: Border.all(color: Spots.border, width: borderWidth),
              borderRadius: BorderRadius.circular(Spots.radiusLg),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                cover.isNotEmpty
                    ? CustomImage(image: cover, fit: BoxFit.cover)
                    : Center(
                      child: Text(
                        mono,
                        style: Spots.display(size * 0.4, color: Spots.teal),
                      ),
                    ),
          ),
          PositionedDirectional(
            end: -logoSize * 0.24,
            bottom: -logoSize * 0.24,
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: Spots.paper,
                border: Border.all(
                  color: Colors.white,
                  width: Spots.borderThin,
                ),
                borderRadius: BorderRadius.circular(logoSize * 0.3),
                boxShadow: Spots.shadow(dx: 2, dy: 2),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child:
                  logo.isNotEmpty
                      // Fill the badge: a single small inset for the border, and
                      // cover (not contain) so the mark isn't floating in white.
                      ? Padding(
                        padding: EdgeInsets.all(logoSize * 0.06),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(logoSize * 0.24),
                          child: CustomImage(
                            image: logo,
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      : Text(
                        mono,
                        style: waddyBlack.copyWith(
                          fontSize: logoSize * 0.45,
                          color: Spots.teal,
                          height: 1,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final Place place;
  final int? delta;
  final bool lowData;

  /// The "leader" is level with at least one other spot. There is no lead to
  /// claim, so the sticker announces a tie instead of inventing an order.
  final bool tied;
  const _LeaderCard({
    required this.place,
    this.delta,
    this.lowData = false,
    this.tied = false,
  });

  @override
  Widget build(BuildContext context) {
    final zone = place.zone?.displayName ?? place.zone?.name ?? place.address;
    final cat = place.categoryName;
    final held = place.titlesCount > 0;
    // While the board is warming up a rank delta is noise (everyone's tied near
    // zero), so we hide it and let the invitation line carry the moment.
    final showDelta = !lowData && delta != null && delta != 0;
    final rising = delta != null && delta! > 0;

    return SpotsPressable(
      onTap:
          () => Get.toNamed(
            RouteHelper.getPlaceDetailsRoute(place.id),
            arguments: place,
          ),
      dx: 5,
      dy: 5,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: Spots.card(fill: Spots.mint, dx: 0, dy: 0),
            padding: const EdgeInsets.all(Spots.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '01',
                            style: Spots.display(46, color: Spots.teal),
                          ),
                          const SizedBox(width: Spots.s12),
                          Expanded(
                            child: Text(
                              place.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Spots.display(22, color: Spots.teal),
                            ),
                          ),
                        ],
                      ),
                      if (zone != null || cat != null) ...[
                        const SizedBox(height: Spots.s8),
                        _MetaLine(
                          cat: cat,
                          zone: zone,
                          color: Spots.teal.withValues(alpha: 0.85),
                          fontSize: 11.5,
                        ),
                      ],
                      if (held) ...[
                        const SizedBox(height: Spots.s8),
                        _HeldPill(weeks: place.titlesCount),
                      ],
                      const SizedBox(height: Spots.s12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            fmtCount(place.votesCount),
                            style: Spots.display(20, color: Spots.teal),
                          ),
                          const SizedBox(width: Spots.s4),
                          Text(
                            displayCaps(
                              place.votesCount == 1
                                  ? 'spots_votes_label_one'.tr
                                  : 'spots_votes_label_other'.tr,
                            ),
                            style: waddyBold.copyWith(
                              fontSize: 11,
                              color: Spots.teal,
                              letterSpacing: displayTracking(0.06 * 11),
                            ),
                          ),
                          if (showDelta) ...[
                            const SizedBox(width: Spots.s8),
                            Text(
                              rising
                                  ? '▲ +${delta!.abs()}'
                                  : '▼ ${delta!.abs()}',
                              style: waddyBlack.copyWith(
                                fontSize: 11,
                                color: Spots.teal.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Only claim a close race when one exists: a tie, or a
                      // board warm enough for the gap to mean something.
                      if (tied) ...[
                        const SizedBox(height: Spots.s8),
                        Text(
                          'spots_tied_hint'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 11,
                            color: Spots.teal.withValues(alpha: 0.8),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Spots.s12),
                _Thumb(
                  place: place,
                  size: 98,
                  logoSize: 38,
                  borderWidth: Spots.borderThick,
                ),
              ],
            ),
          ),
          // Leader sticker, tilted (mirrored in RTL), top-end. A hot red
          // "LIVE LEADER" once the race is real; a calmer teal "EARLY LEAD"
          // while the board's warming up, so a 1-vote lead never overclaims.
          PositionedDirectional(
            top: -20,
            end: -2,
            child: SpotsSticker(
              label: displayCaps(
                tied
                    ? 'spots_tied_at_top'.tr
                    : lowData
                    ? 'spots_early_lead'.tr
                    : 'spots_live_leader'.tr,
              ),
              mark: (tied || lowData) ? SpotsMark.bolt : SpotsMark.flame,
              fill: (tied || lowData) ? Spots.teal : Spots.red,
              // Only a real live lead earns the breathing pulse; an early lead
              // is a fact, not an event — and a tie is not a lead at all.
              live: !lowData && !tied,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldPill extends StatelessWidget {
  final int weeks;
  const _HeldPill({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final label =
        weeks == 1
            ? 'spots_reigning_champion'.tr
            : 'spots_weekly_crowns'.trParams({'count': fmtCount(weeks)});
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s8,
        vertical: Spots.s4,
      ),
      decoration: BoxDecoration(
        color: Spots.teal,
        borderRadius: BorderRadius.circular(Spots.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpotsDiamondGlyph(size: 11),
          const SizedBox(width: Spots.s4),
          Text(
            displayCaps(label),
            style: waddyBlack.copyWith(
              fontSize: 10,
              color: Colors.white,
              letterSpacing: displayTracking(0.05 * 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final Place place;
  final int rank;

  /// Another place on the board holds this same vote count. Rendered "T2"
  /// instead of "02" — a shared rank, stated as one.
  final bool tied;
  final int behind;
  final bool lowData;
  const _MiniCard({
    required this.place,
    required this.rank,
    required this.behind,
    this.tied = false,
    this.lowData = false,
  });

  @override
  Widget build(BuildContext context) {
    final zone = place.zone?.displayName ?? place.zone?.name ?? place.address;

    return SpotsPressable(
      onTap:
          () => Get.toNamed(
            RouteHelper.getPlaceDetailsRoute(place.id),
            arguments: place,
          ),
      child: Container(
        decoration: Spots.card(fill: Spots.paper, dx: 0, dy: 0),
        padding: const EdgeInsets.all(Spots.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  tied ? 'T$rank' : '0$rank',
                  style: Spots.display(26, color: Spots.teal),
                ),
                const Spacer(),
                _Thumb(place: place, size: 62, logoSize: 28),
              ],
            ),
            const SizedBox(height: Spots.s12),
            Text(
              place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Spots.display(16, color: Spots.ink),
            ),
            if (zone != null) ...[
              const SizedBox(height: Spots.s4),
              _MetaLine(zone: zone, color: Spots.ink3, fontSize: 10),
            ],
            const SizedBox(height: Spots.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmtCount(place.votesCount),
                  style: Spots.display(14, color: Spots.teal),
                ),
                const SizedBox(width: Spots.s4),
                Text(
                  displayCaps(
                    place.votesCount == 1
                        ? 'spots_votes_label_one'.tr
                        : 'spots_votes_label_other'.tr,
                  ),
                  style: waddyBold.copyWith(
                    fontSize: 10,
                    color: Spots.ink3,
                    letterSpacing: displayTracking(0.06 * 10),
                  ),
                ),
                // A "▼ 2 behind" gap only means something once the race is
                // real; while warming up we drop it so a near-tie doesn't read
                // as a hopeless deficit.
                if (!lowData && behind > 0) ...[
                  const SizedBox(width: Spots.s8),
                  Text(
                    '▼ ${fmtCount(behind)}',
                    style: waddyBlack.copyWith(fontSize: 12, color: Spots.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen's single loud action. Mint fill so it owns the visual weight the
/// three duplicate "leaderboard" links used to fight over — vote is the verb
/// this whole board is built to provoke.
class _CastVoteButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CastVoteButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SpotsPressable(
      onTap: onTap,
      radius: Spots.radiusMd,
      child: Container(
        width: double.infinity,
        decoration: Spots.card(
          fill: Spots.mint,
          radius: Spots.radiusMd,
          dx: 0,
          dy: 0,
        ),
        padding: const EdgeInsets.symmetric(vertical: Spots.s16),
        alignment: Alignment.center,
        child: Text(
          displayCaps(label),
          style: waddyBlack.copyWith(
            fontSize: 15,
            color: Spots.teal,
            letterSpacing: displayTracking(0.03 * 15),
          ),
        ),
      ),
    );
  }
}

/// Category · 📍zone meta line. The location pin is a drawn glyph, not an emoji,
/// so the load-bearing "where is this" marker renders identically on every
/// device and sits in the neubrutalist system; category is plain text.
class _MetaLine extends StatelessWidget {
  final String? cat;
  final String? zone;
  final Color color;
  final double fontSize;
  const _MetaLine({
    this.cat,
    this.zone,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final style = waddyBold.copyWith(
      fontSize: fontSize,
      color: color,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cat != null)
          Flexible(
            child: Text(
              cat!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        if (cat != null && zone != null) Text(' · ', style: style),
        if (zone != null) ...[
          Icon(Icons.place_rounded, size: fontSize + 2, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              zone!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Loading & empty ──

class _Top3Skeleton extends StatelessWidget {
  const _Top3Skeleton();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpotsSkeleton(height: 130),
        SizedBox(height: Spots.s12),
        Row(
          children: [
            Expanded(child: SpotsSkeleton(height: 120)),
            SizedBox(width: Spots.s12),
            Expanded(child: SpotsSkeleton(height: 120)),
          ],
        ),
        SizedBox(height: Spots.s12),
        SpotsSkeleton(height: 52, radius: Spots.radiusMd),
      ],
    );
  }
}

class _Top3Empty extends StatelessWidget {
  const _Top3Empty({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      decoration: Spots.card(fill: Spots.paper),
      padding: const EdgeInsets.symmetric(
        vertical: Spots.s16,
        horizontal: Spots.s16,
      ),
      child: Column(
        children: [
          const SpotsTrophyGlyph(size: 123),
          const SizedBox(height: Spots.s8),
          Text(
            displayCaps('spots_crown_open_title'.tr),
            style: Spots.kicker(15, color: Spots.ink, tracking: 0.06),
          ),
          const SizedBox(height: Spots.s8),
          Text(
            'spots_crown_open_body'.tr,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: 11,
              color: Spots.ink3,
              height: 1.4,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: Spots.s12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayCaps('spots_crown_open_cta'.tr),
                  style: Spots.kicker(12, color: Spots.teal, tracking: 0.06),
                ),
                const SizedBox(width: Spots.s4),
                Icon(
                  Get.locale?.languageCode == 'ar'
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 16,
                  color: Spots.teal,
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return SpotsPressable(onTap: onTap, child: card);
  }
}
