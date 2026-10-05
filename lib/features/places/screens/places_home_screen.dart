import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/claw_draw_entry_card.dart';
import 'package:waddy_app/features/places/widgets/places_to_visit_section.dart';
import 'package:waddy_app/features/places/widgets/recent_winners_strip.dart';
import 'package:waddy_app/features/places/widgets/round_countdown_bar.dart';
import 'package:waddy_app/features/places/widgets/spots_error_card.dart';
import 'package:waddy_app/features/places/widgets/spots_masthead.dart';
import 'package:waddy_app/features/places/widgets/spots_win_card.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/widgets/top_voters_podium_section.dart';
import 'package:waddy_app/features/places/widgets/weekly_top3_section.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';

/// WADDI Spots home — the live weekly leaderboard experience.
/// Faithful implementation of the "WADDI Spots Design System" Home template:
/// deep-teal masthead over a dot-grid canvas, then the anticipation headline +
/// live countdown, this week's top-3 leaderboard, the top-voters podium with a
/// live movement ticker, and the category-filterable places-to-visit rail.
class PlacesHomeScreen extends StatefulWidget {
  const PlacesHomeScreen({super.key});

  @override
  State<PlacesHomeScreen> createState() => _PlacesHomeScreenState();
}

/// The race half of the home screen — the board, the voters podium and the
/// winners strip — or the error card, when nothing arrived at all.
///
/// Only the error/content swap needs the controller here; each section
/// subscribes for itself and renders its own loading and empty states.
class _RaceSections extends StatelessWidget {
  const _RaceSections({required this.onBrowseSpots});

  final VoidCallback onBrowseSpots;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PlacesController>(
      // The leaderboard id is what every board fetch and `refreshRankDeltas`
      // repaint, so it is the one that knows whether anything landed.
      id: PlacesController.idLeaderboard,
      builder: (controller) {
        if (controller.hasInitError && !controller.hasAnyHomeData) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Spots.sectionGap),
            child: SpotsErrorCard(onRetry: controller.retryInitialize),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Each section owns its own empty state, so none of them is gated
            // on the round's heat.
            //
            // An earlier pass hid the podium and the winners strip below
            // `stage.isHot`, reading `SpotsStage`'s doc comment as a mandate to
            // gate composition. It is not the right cut here: `roundHeat` sums
            // the *venues'* votes, and the podium ranks *people* — a voters
            // board is perfectly real on a week where no single spot has pulled
            // ahead yet. `WeeklyTop3Section` has its "the crown is open" state
            // and `_VotersEmpty` has its own, which is the honest way to handle
            // a quiet round: say so in place, rather than remove the section
            // and leave the screen looking like the feature is missing.
            WeeklyTop3Section(onBrowseSpots: onBrowseSpots),
            const SizedBox(height: Spots.sectionGap),
            const TopVotersPodiumSection(),
            const SizedBox(height: Spots.sectionGap),
            // People who won the prize draw — sits below the podium but
            // styled apart from it, so a ranking and a random draw never
            // read as the same list.
            const RecentWinnersStrip(),
            const SizedBox(height: Spots.sectionGap),
          ],
        );
      },
    );
  }
}

class _PlacesHomeScreenState extends State<PlacesHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  ScrollDirection _lastDirection = ScrollDirection.idle;

  /// Brings the spots list into view. The list is a lazy sliver item, so on a
  /// tall podium it has no element yet and its key has no context: page down
  /// until it is built, then let [Scrollable.ensureVisible] do the exact stop.
  Future<void> _scrollToSpots() async {
    for (var i = 0; i < 8; i++) {
      if (!mounted || !_scrollController.hasClients) return;
      final ctx = PlacesToVisitSection.anchorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent) return;
      await _scrollController.animateTo(
        math.min(pos.pixels + pos.viewportDimension, pos.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());

    _scrollController.addListener(() {
      _maybeLoadMore();

      final direction = _scrollController.position.userScrollDirection;
      if (direction == _lastDirection) return;
      _lastDirection = direction;

      if (direction == ScrollDirection.reverse) {
        Get.find<HomeController>().onScrollDown();
      } else {
        Get.find<HomeController>().onScrollUp();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Append the next page of spots as the bottom of the list approaches.
  ///
  /// The venue list was one page forever: `getPlaces` is paginated and the
  /// controller merges pages, but nothing on this screen ever asked for page
  /// two — while the section header rendered the server's catalogue count over
  /// it, so it claimed "48 SPOTS" above ten rows. See `S-09`.
  ///
  /// 300px of lead time, matching the store screens. The guards live on the
  /// controller (`isLoadingMorePlaces`, `hasMorePlaces`) because this fires on
  /// every scroll frame inside the trigger zone.
  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 300) return;

    final PlacesController controller = Get.find<PlacesController>();
    if (controller.isPlacesLoading ||
        controller.isLoadingMorePlaces ||
        !controller.hasMorePlaces) {
      return;
    }
    controller.getPlaces(offset: controller.nextPlacesPage);
  }

  Future<void> _loadData() async {
    final controller = Get.find<PlacesController>();
    await controller.initializePlacesData();
    // Last closed round's claw draw. Per-user (`is_me`, `my_prize_id`), so it
    // is re-asked on every open rather than trusted from an earlier session,
    // and it is not part of the init batch: the card is news about last week,
    // and this week's board must not wait on it.
    unawaited(controller.getLatestDraw(reload: true));
    if (AuthHelper.isLoggedIn()) {
      controller.getFavorites();
      // Drives the masthead's prize badge — a won voucher has to be findable
      // even when the push was swiped away.
      await controller.getMyPrizes();
      _offerCelebration();
      try {
        await Get.find<ProfileController>().getUserInfo();
      } catch (e, s) {
        swallow('refresh profile after prize', e, s);
      }
    }
  }

  /// Congratulate a winner where the win actually arrives.
  ///
  /// The home already spends a request on `getMyPrizes` specifically so a
  /// voucher is "findable when the push was swiped away" — but the celebration
  /// only ever fired from the prizes screen. So someone who won while the app
  /// was closed opened Spots, saw a small mint dot on a pill, and got the card
  /// only if they independently decided to tap through. See `S-11`.
  ///
  /// `markPrizeCelebrated` is the once-per-prize gate and it is persisted, so
  /// this cannot nag: whichever surface offers the card first is the only one
  /// that offers it.
  void _offerCelebration() {
    if (!mounted) return;
    final controller = Get.find<PlacesController>();
    final prize = controller.uncelebratedPrize;
    if (prize == null) return;

    controller.markPrizeCelebrated(prize.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SpotsWinCardSheet.show(context, prize);
    });
  }

  Future<void> _refresh() async {
    final controller = Get.find<PlacesController>();
    await controller.initializePlacesData(reload: true);
    await Future.wait([
      controller.getLatestDraw(reload: true),
      if (AuthHelper.isLoggedIn())
        controller.getMyPrizes(reload: true, notify: false),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Masthead is fixed — it no longer scrolls with the content.
          const SpotsMasthead(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: Spots.teal,
              backgroundColor: Spots.mint,
              // A CustomScrollView, not a SingleChildScrollView + Column: the
              // latter builds and lays out every section on the first frame,
              // including the podium and the full places list far below the
              // fold. Slivers build lazily, so opening the screen only pays
              // for what is actually on screen. This mirrors the food home.
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Spots.gutter,
                      Spots.gutter,
                      Spots.gutter,
                      MediaQuery.of(context).padding.bottom + Spots.s24,
                    ),
                    sliver: SliverList.list(
                      children: [
                        // The countdown is client-side — it survives outages.
                        const RoundCountdownBar(),
                        const SizedBox(height: Spots.sectionGap),
                        // Last week's champion's voters, through the claw.
                        // Collapses to nothing until a round has a draw.
                        const ClawDrawEntryCard(),
                        // Everything between the countdown and the venue list
                        // is earned, not fixed. See [_RaceSections].
                        _RaceSections(onBrowseSpots: _scrollToSpots),
                        const PlacesToVisitSection(),
                        // Extra room so the last card clears the floating
                        // bottom nav bar once it slides back in at rest.
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
