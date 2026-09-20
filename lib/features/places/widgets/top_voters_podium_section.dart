import 'package:flutter/material.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/places/widgets/live_news_bar.dart';
import 'package:waddy_app/features/places/widgets/place_vote_action.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/common/widgets/spots/spots_section_header.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// "Top voters" — a 3-up podium (2nd · 1st crowned & taller · 3rd), a
/// defend-your-crown mission strip, and a live movement ticker.
/// Mirrors the `.vgrid` / `.mission` / `.newsbar` block in Home.dc.html.
class TopVotersPodiumSection extends StatelessWidget {
  const TopVotersPodiumSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      id: PlacesController.idTopVoters,
      builder: (controller) {
        if (controller.isTopVotersLoading && controller.topVoters == null) {
          return const _VotersSkeleton();
        }
        final voters = controller.topVoters;
        if (voters == null || voters.isEmpty) {
          return _VotersEmpty(controller: controller);
        }

        final top3 = voters.take(3).toList();
        // Podium order: 2nd (left), 1st (center, lead), 3rd (right)
        final first = top3.isNotEmpty ? top3[0] : null;
        final second = top3.length > 1 ? top3[1] : null;
        final third = top3.length > 2 ? top3[2] : null;

        // Resolve the logged-in user so their own tile shows their real
        // profile photo/handle even when the leaderboard payload omits them.
        int? meId;
        String? meAvatar;
        String? meName;
        if (AuthHelper.isLoggedIn()) {
          try {
            final me = Get.find<ProfileController>().userInfoModel;
            meId = me?.id;
            meAvatar = me?.imageFullUrl;
            meName =
                [me?.fName, me?.lName]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' ')
                    .trim();
            if (meName.isEmpty) meName = null;
          } catch (e, s) {
            swallow('read own name for podium', e, s);
          }
        }

        _VoterTile tile(TopVoter? v, int rank, {bool lead = false}) {
          final isMe = v != null && meId != null && v.id == meId;
          return _VoterTile(
            voter: v,
            rank: rank,
            lead: lead,
            isMe: isMe,
            // Prefer the API avatar; fall back to the profile photo for "me".
            avatarOverride:
                isMe && (v.avatar == null || v.avatar!.isEmpty)
                    ? meAvatar
                    : null,
            nameOverride: isMe ? (meName ?? v.name) : null,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpotsSectionHeader(
              kicker: 'spots_the_regulars'.tr,
              title: 'spots_top_voters_title'.tr,
              actionLabel: 'spots_leaderboard'.tr,
              // The Spots board, not the XP one — these are different scores
              // and sending people to XP from here was simply the wrong list.
              onAction: () => SpotsTopVotersSheet.show(context, voters),
            ),
            const SizedBox(height: Spots.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 100, child: tile(second, 2)),
                const SizedBox(width: Spots.s12),
                Expanded(flex: 120, child: tile(first, 1, lead: true)),
                const SizedBox(width: Spots.s12),
                Expanded(flex: 100, child: tile(third, 3)),
              ],
            ),
            const _PrizeFairnessNote(),
            const SizedBox(height: Spots.s12),
            LiveNewsBar(leaderName: first?.name),
          ],
        );
      },
    );
  }
}

/// The crown above the lead voter. Keyed on the leader's id upstream, so when the
/// crown changes hands this widget is rebuilt from scratch and its entrance
/// fires: the crown drops from above, overshoots slightly, and settles (a
/// spring on a single element, not the tacky global bounce we avoid elsewhere).
/// At rest it breathes with a slow vertical float so it never feels frozen.
class _LeaderCrown extends StatefulWidget {
  const _LeaderCrown({super.key});

  @override
  State<_LeaderCrown> createState() => _LeaderCrownState();
}

class _LeaderCrownState extends State<_LeaderCrown>
    with TickerProviderStateMixin {
  static const String _asset = 'assets/animation/crown.riv';

  late final AnimationController _drop;
  late final AnimationController _float;
  late final FileLoader _fileLoader = FileLoader.fromAsset(
    _asset,
    riveFactory: Factory.rive,
  );

  @override
  void initState() {
    super.initState();
    _drop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drop.dispose();
    _float.dispose();
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      return _riveCrown();
    }
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drop, _float]),
        builder: (context, child) {
          // Drop-in: slide down from above + scale up, easing out with a tiny
          // settle. elasticOut gives the "landed" feel on this one glyph only.
          final drop = Curves.easeOutExpo.transform(_drop.value);
          final settle = Curves.elasticOut.transform(_drop.value);
          final dropDy = (1 - drop) * -32; // starts 32px high, falls into place
          final scale = 0.6 + 0.4 * settle;
          // Idle float once landed, faded in by the drop progress.
          final floatDy = (_float.value - 0.5) * 4 * drop;
          return Transform.translate(
            offset: Offset(0, dropDy + floatDy),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: _riveCrown(),
      ),
    );
  }

  Widget _riveCrown() {
    return SizedBox(
      width: 40,
      height: 40,
      child: RiveWidgetBuilder(
        fileLoader: _fileLoader,
        onFailed:
            (error, stackTrace) =>
                debugPrint('_LeaderCrown failed to load $_asset: $error'),
        builder:
            (context, state) => switch (state) {
              RiveLoaded() => RiveWidget(
                controller: state.controller,
                fit: Fit.contain,
              ),
              _ => const SizedBox.shrink(),
            },
      ),
    );
  }
}

class _VoterTile extends StatelessWidget {
  final TopVoter? voter;
  final int rank;
  final bool lead;
  final bool isMe;
  final String? avatarOverride;
  final String? nameOverride;
  const _VoterTile({
    required this.voter,
    required this.rank,
    this.lead = false,
    this.isMe = false,
    this.avatarOverride,
    this.nameOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (voter == null) return const SizedBox.shrink();
    final v = voter!;

    final avatar =
        (avatarOverride != null && avatarOverride!.isNotEmpty)
            ? avatarOverride!
            : (v.avatar ?? '');
    final name =
        (nameOverride != null && nameOverride!.isNotEmpty)
            ? nameOverride!
            : v.name;

    // Medal colours: 1st mint, 2nd paper, 3rd bronze (from `.rankt` variants).
    // Third place used Spots.red, the token reserved for live/urgent/slipping
    // — it badged a standing as an error state.
    final Color medalBg =
        rank == 1
            ? Spots.mint
            : rank == 2
            ? Spots.paper
            : Spots.bronze;
    final Color medalFg = rank == 3 ? Colors.white : Spots.teal;
    final double medal = lead ? 36 : 28;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Spots.canvasDot,
                  border: Border.all(
                    color: Spots.border,
                    width: lead ? Spots.borderThick : Spots.borderThin,
                  ),
                  borderRadius: BorderRadius.circular(Spots.radiusLg),
                  boxShadow: Spots.shadow(
                    dx: lead ? 5 : 3,
                    dy: lead ? 5 : 3,
                    color: lead ? Spots.mint : Spots.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    avatar.isNotEmpty
                        ? CustomImage(image: avatar, fit: BoxFit.cover)
                        : Center(
                          child: Text(
                            _initial(name),
                            style: Spots.display(
                              lead ? 30 : 22,
                              color: Spots.teal,
                            ),
                          ),
                        ),
              ),
            ),
            if (isMe)
              PositionedDirectional(
                top: lead ? -13 : -11,
                start: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spots.s8,
                    vertical: Spots.s4,
                  ),
                  decoration: BoxDecoration(
                    color: Spots.teal,
                    border: Border.all(
                      color: Spots.border,
                      width: Spots.borderThin,
                    ),
                    borderRadius: BorderRadius.circular(Spots.radiusSm),
                  ),
                  child: Text(
                    displayCaps('spots_you'.tr),
                    style: waddyBlack.copyWith(
                      fontSize: 8,
                      color: Colors.white,
                      letterSpacing: displayTracking(0.08 * 8),
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (lead)
              Positioned(
                top: -35,
                left: 0,
                right: 0,
                // Keyed on the leader's identity: when the crown changes hands,
                // it drops onto the new leader and settles — the signature beat.
                child: _LeaderCrown(key: ValueKey(v.id)),
              ),
            PositionedDirectional(
              end: lead ? -9 : -7,
              bottom: lead ? -11 : -9,
              child: Container(
                width: medal,
                height: medal,
                decoration: BoxDecoration(
                  color: medalBg,
                  border: Border.all(
                    color: Spots.border,
                    width: Spots.borderThin,
                  ),
                  borderRadius: BorderRadius.circular(Spots.radiusSm + 3),
                  boxShadow: Spots.shadow(dx: 2, dy: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  fmtCount(rank),
                  style: waddyBlack.copyWith(
                    fontSize: lead ? 17 : 13,
                    color: medalFg,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: lead ? Spots.s16 : Spots.s12),
        Text(
          _handle(name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyBlack.copyWith(
            fontSize: lead ? 16 : 12,
            color: lead ? Spots.ink : Spots.ink3,
            letterSpacing: displayTracking(0.02 * (lead ? 16 : 12)),
          ),
        ),
        const SizedBox(height: Spots.s4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmtCount(v.votesCount),
              style: Spots.display(lead ? 19 : 13, color: Spots.teal),
            ),
            const SizedBox(width: Spots.s4),
            Text(
              displayCaps(
                v.votesCount == 1
                    ? 'spots_points_label_one'.tr
                    : 'spots_points_label_other'.tr,
              ),
              style: waddyBold.copyWith(
                fontSize: 9,
                color: Spots.ink3,
                letterSpacing: displayTracking(0.05 * 9),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _initial(String name) {
    final s = name.replaceAll('@', '').trim();
    return s.isNotEmpty ? displayCaps(s[0]) : '?';
  }

  static String _handle(String name) {
    final s = name.trim();
    if (s.startsWith('@')) return displayCaps(s);
    // A multi-word value is a real display name — show it as-is (uppercased in
    // Latin scripts only); a single token reads as a handle, so prefix '@'.
    return s.contains(' ') ? displayCaps(s) : '@${displayCaps(s)}';
  }
}

/// Empty podium — rendered instead of silently collapsing the whole section,
/// which used to leave a dead 68px band between its neighbours.
class _VotersEmpty extends StatelessWidget {
  final PlacesController controller;
  const _VotersEmpty({required this.controller});

  @override
  Widget build(BuildContext context) {
    final standings = controller.liveStandings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpotsSectionHeader(
          kicker: 'spots_the_regulars'.tr,
          title: 'spots_top_voters_title'.tr,
        ),
        const SizedBox(height: Spots.s16),
        Container(
          width: double.infinity,
          decoration: Spots.card(fill: Spots.paper),
          padding: const EdgeInsets.symmetric(
            vertical: Spots.s24,
            horizontal: Spots.s16,
          ),
          child: Column(
            children: [
              const SpotsGlyph(SpotsMark.trophy, size: 34, color: Spots.teal),
              const SizedBox(height: Spots.s8),
              Text(
                displayCaps('spots_voters_empty_title'.tr),
                style: Spots.kicker(15, color: Spots.ink, tracking: 0.06),
              ),
              const SizedBox(height: Spots.s8),
              Text(
                'spots_voters_empty_body'.tr,
                textAlign: TextAlign.center,
                style: waddyBold.copyWith(
                  fontSize: 11,
                  color: Spots.ink3,
                  height: 1.4,
                ),
              ),
              if (standings.isNotEmpty) ...[
                const SizedBox(height: Spots.s16),
                SpotsPressable(
                  onTap: () => openVoteSheet(standings.first.id),
                  dx: 3,
                  dy: 3,
                  radius: Spots.radiusMd,
                  child: Container(
                    decoration: Spots.card(
                      fill: Spots.mint,
                      radius: Spots.radiusMd,
                      borderWidth: Spots.borderThin,
                      dx: 0,
                      dy: 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spots.s20,
                      vertical: Spots.s8,
                    ),
                    child: Text(
                      displayCaps('spots_vote_cta'.tr),
                      style: Spots.display(13, tracking: 0.02),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VotersSkeleton extends StatelessWidget {
  const _VotersSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget tile(int flex) => Expanded(
      flex: flex,
      child: const AspectRatio(aspectRatio: 1, child: SpotsSkeleton()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            tile(100),
            const SizedBox(width: Spots.s12),
            tile(120),
            const SizedBox(width: Spots.s12),
            tile(100),
          ],
        ),
        const SizedBox(height: Spots.s20),
        const SpotsSkeleton(height: 84),
      ],
    );
  }
}

/// Preempts "I have the most points, why didn't I win?".
///
/// The leaderboard and the prize draw are separate mechanics that happen to
/// sit next to each other; without this line, adjacency implies causation.
class _PrizeFairnessNote extends StatelessWidget {
  const _PrizeFairnessNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Spots.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: Spots.s12,
        vertical: Spots.s8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF6),
        border: Border.all(color: Spots.border, width: Spots.borderThin),
        borderRadius: BorderRadius.circular(Spots.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Spots.teal),
          const SizedBox(width: Spots.s8),
          Expanded(
            child: Text(
              'spots_prize_random_note'.tr,
              style: waddyRegular.copyWith(
                fontSize: 11,
                color: Spots.ink2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full cumulative board behind the top-3 podium.
///
/// A sheet rather than a screen: it's one list with no actions on it, and
/// pushing a route for that would put a back stack between the user and the
/// race they came to watch.
class SpotsTopVotersSheet extends StatelessWidget {
  const SpotsTopVotersSheet({super.key, required this.voters});

  final List<TopVoter> voters;

  static Future<void> show(BuildContext context, List<TopVoter> voters) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Spots.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spots.radiusLg),
        ),
      ),
      builder: (_) => SpotsTopVotersSheet(voters: voters),
    );
  }

  @override
  Widget build(BuildContext context) {
    int? meId;
    try {
      meId = Get.find<ProfileController>().userInfoModel?.id;
    } catch (e, s) {
      swallow('read own id for podium', e, s);
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayCaps('spots_top_voters_title'.tr),
                  style: Spots.kicker(13, color: Spots.ink),
                ),
                const SizedBox(height: Spots.s4),
                Text(
                  'spots_top_voters_points_hint'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: 11,
                    color: Spots.ink3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: Spots.s20,
                vertical: Spots.s12,
              ),
              itemCount: voters.length,
              separatorBuilder: (_, __) => const SizedBox(height: Spots.s8),
              itemBuilder: (_, i) {
                final voter = voters[i];
                final isMe = meId != null && voter.id == meId;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spots.s12,
                    vertical: Spots.s8,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFF0FBF6) : Colors.transparent,
                    border: Border.all(
                      color: isMe ? Spots.teal : Spots.canvasDot,
                      width: Spots.borderThin,
                    ),
                    borderRadius: BorderRadius.circular(Spots.radiusMd),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${voter.position ?? i + 1}',
                          textDirection: TextDirection.ltr,
                          style: waddyBlack.copyWith(
                            fontSize: 14,
                            color: Spots.ink3,
                            height: 1,
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Spots.canvas,
                          border: Border.all(
                            color: Spots.border,
                            width: Spots.borderThin,
                          ),
                          borderRadius: BorderRadius.circular(Spots.radiusSm),
                        ),
                        child:
                            (voter.avatar != null && voter.avatar!.isNotEmpty)
                                ? CustomImage(
                                  image: voter.avatar!,
                                  height: 32,
                                  width: 32,
                                  fit: BoxFit.cover,
                                )
                                : const Icon(
                                  Icons.person_rounded,
                                  size: 16,
                                  color: Spots.ink3,
                                ),
                      ),
                      const SizedBox(width: Spots.s12),
                      Expanded(
                        child: Text(
                          isMe ? 'spots_you'.tr : voter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: waddyBold.copyWith(
                            fontSize: 13,
                            color: Spots.ink,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        trPlural('spots_points', voter.points),
                        style: Spots.kicker(11, color: Spots.ink2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spots.s8),
        ],
      ),
    );
  }
}
