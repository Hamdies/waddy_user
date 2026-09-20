import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';
import 'package:waddy_app/features/places/domain/spots_draw_demo.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/places/widgets/spots_prize_card.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/widgets/spots_win_card.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// "My Prizes" — the live voucher, its countdown, and the archive.
///
/// Reached from the Spots masthead and from the win push. Everything here is
/// redeemed in person: there is no in-app "use" action by design.
class SpotsPrizesScreen extends StatefulWidget {
  const SpotsPrizesScreen({super.key});

  @override
  State<SpotsPrizesScreen> createState() => _SpotsPrizesScreenState();
}

class _SpotsPrizesScreenState extends State<SpotsPrizesScreen> {
  /// Which tab is showing. Active is the landing tab: a live voucher is the
  /// only thing on this screen anyone is in a hurry to find.
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool reload = false}) async {
    if (!AuthHelper.isLoggedIn()) return;
    await Get.find<PlacesController>().getMyPrizes(reload: reload);
    _offerCelebration();
  }

  /// Pass the object through so details paints without a round trip; the id
  /// in the route is what a push deep-link resolves against.
  void _openDetails(PlacePrize prize) {
    Get.toNamed(
      RouteHelper.getSpotsPrizeDetailsRoute(prize.id),
      arguments: prize,
    );
  }

  /// A freshly-won voucher gets the share card offered once, then never again.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Spots.canvas,
      appBar: CustomAppBar(title: 'spots_my_prizes'.tr),
      body:
          !AuthHelper.isLoggedIn()
              ? const _PrizesSignedOut()
              : RefreshIndicator(
                onRefresh: () => _load(reload: true),
                color: Spots.teal,
                backgroundColor: Spots.mint,
                child: GetBuilder<PlacesController>(
                  builder: (controller) {
                    if (controller.isPrizesLoading &&
                        !controller.hasPrizesLoaded) {
                      return const _PrizesSkeleton();
                    }

                    final active = controller.activePrizes;
                    final history = controller.prizeHistory;
                    // A user with only spent codes still lands on Active; the
                    // tab's own empty state explains why it's blank, and the
                    // History tab is right there with a count-free label.
                    final showing = _showHistory ? history : active;

                    return Column(
                      children: [
                        // Debug-only entry to the claw draw. `kDebugMode` is a
                        // compile-time constant, so this row and everything it
                        // reaches is tree-shaken out of release builds — it
                        // cannot ship, and there is no flag to remember.
                        if (kDebugMode)
                          _ClawDebugBar(
                            prize: active.isNotEmpty ? active.first : null,
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Spots.gutter,
                            Spots.s16,
                            Spots.gutter,
                            Spots.s16,
                          ),
                          child: _PrizeTabs(
                            showHistory: _showHistory,
                            activeCount: active.length,
                            onChanged:
                                (value) => setState(() => _showHistory = value),
                          ),
                        ),
                        Expanded(
                          child:
                              showing.isEmpty
                                  ? _PrizesEmpty(isHistory: _showHistory)
                                  : ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: ClampingScrollPhysics(),
                                        ),
                                    padding: EdgeInsets.fromLTRB(
                                      Spots.gutter,
                                      0,
                                      Spots.gutter,
                                      MediaQuery.of(context).padding.bottom +
                                          Spots.s32,
                                    ),
                                    children: [
                                      for (final prize in showing) ...[
                                        SpotsPrizeCard(
                                          prize: prize,
                                          onTap: () => _openDetails(prize),
                                        ),
                                        const SizedBox(height: Spots.s16),
                                      ],
                                      // if (!_showHistory) const _RedemptionSteps(),
                                    ],
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
    );
  }
}

/// The Active / History segmented control: one hairline-jointed box, mint fill
/// on the selected half. Boxy by design — no pill, no sliding indicator.
class _PrizeTabs extends StatelessWidget {
  const _PrizeTabs({
    required this.showHistory,
    required this.activeCount,
    required this.onChanged,
  });

  final bool showHistory;
  final int activeCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Spots.border, width: Spots.borderThin),
        borderRadius: BorderRadius.circular(Spots.radiusMd),
      ),
      // Keeps the mint fill from bleeding past the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: _PrizeTab(
              label: 'spots_prizes_tab_active'.trParams({
                'count': '$activeCount',
              }),
              selected: !showHistory,
              onTap: () => onChanged(false),
            ),
          ),
          Container(width: Spots.borderThin, height: 40, color: Spots.border),
          Expanded(
            child: _PrizeTab(
              label: 'spots_prizes_tab_history'.tr,
              selected: showHistory,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeTab extends StatelessWidget {
  const _PrizeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          color: selected ? Spots.mint : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: Spots.s4),
          child: Text(
            displayCaps(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Spots.kicker(
              12,
              color: selected ? Spots.teal : Spots.ink3,
              tracking: 0.05,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrizesEmpty extends StatelessWidget {
  const _PrizesEmpty({this.isHistory = false});

  /// The archive tab explains itself in one line and offers nothing to tap —
  /// "Back to Spots" is only useful when there is a vote still to cast.
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(Spots.s32),
      children: [
        const SizedBox(height: Spots.s32),
        const Center(
          child: SpotsGlyph(SpotsMark.trophy, size: 52, color: Spots.teal),
        ),
        const SizedBox(height: Spots.s16),
        Text(
          isHistory
              ? 'spots_prizes_history_empty_title'.tr
              : 'spots_prizes_empty_title'.tr,
          textAlign: TextAlign.center,
          style: waddyBlack.copyWith(
            fontSize: 20,
            color: Spots.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: Spots.s8),
        Text(
          isHistory
              ? 'spots_prizes_history_empty_body'.tr
              : 'spots_prizes_empty_body'.tr,
          textAlign: TextAlign.center,
          style: waddyRegular.copyWith(
            fontSize: 14,
            color: Spots.ink2,
            height: 1.5,
          ),
        ),
        if (!isHistory) ...[
          const SizedBox(height: Spots.s24),
          Center(
            child: SpotsPressable(
              onTap: () => Get.back(),
              dx: 3,
              dy: 3,
              radius: Spots.radiusMd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spots.s24,
                  vertical: Spots.s12,
                ),
                decoration: Spots.card(
                  fill: Spots.mint,
                  radius: Spots.radiusMd,
                  borderWidth: Spots.borderThin,
                  dx: 0,
                  dy: 0,
                ),
                child: Text(
                  displayCaps('spots_prizes_empty_cta'.tr),
                  style: Spots.kicker(12, color: Spots.teal900, tracking: 0.06),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PrizesSignedOut extends StatelessWidget {
  const _PrizesSignedOut();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spots.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpotsGlyph(SpotsMark.trophy, size: 52, color: Spots.teal),
          const SizedBox(height: Spots.s16),
          Text(
            'spots_prizes_signed_out'.tr,
            textAlign: TextAlign.center,
            style: waddyRegular.copyWith(
              fontSize: 14,
              color: Spots.ink2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Spots.s24),
          SpotsPressable(
            onTap:
                () => Get.toNamed(RouteHelper.getSignInRoute(RouteHelper.main)),
            dx: 3,
            dy: 3,
            radius: Spots.radiusMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spots.s24,
                vertical: Spots.s12,
              ),
              decoration: Spots.card(
                fill: Spots.mint,
                radius: Spots.radiusMd,
                borderWidth: Spots.borderThin,
                dx: 0,
                dy: 0,
              ),
              child: Text(
                displayCaps('login'.tr),
                style: Spots.kicker(12, color: Spots.teal900, tracking: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizesSkeleton extends StatelessWidget {
  const _PrizesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spots.gutter),
      children: const [
        SpotsSkeleton(height: 40, radius: Spots.radiusMd),
        SizedBox(height: Spots.s16),
        SpotsSkeleton(height: 240),
        SizedBox(height: Spots.s16),
        SpotsSkeleton(height: 140),
      ],
    );
  }
}

/// Debug-only launcher for the claw draw.
///
/// The live rounds have one prize each, which is not enough balls to judge the
/// screen by — the pile, the overflow plate and the losing balls are all
/// invisible at that size. These open the claw with the round padded out to a
/// realistic size, built entirely in memory: no rows are written, so there is
/// nothing to clean up afterwards.
///
/// Three buttons because there are three outcomes worth seeing, and the two
/// that are not "I won" are the ones more likely to be wrong.
class _ClawDebugBar extends StatelessWidget {
  const _ClawDebugBar({this.prize});

  /// The user's real voucher, when they have one. WIN routes to it for real.
  final PlacePrize? prize;

  /// Name and avatar from the signed-in profile, so the ball the claw picks up
  /// is actually you. Both fall back cleanly: no profile gives "You" and no
  /// photo gives initials.
  ({String name, String? image}) get _me {
    try {
      final u = Get.find<ProfileController>().userInfoModel;
      final name = '${u?.fName ?? ''} ${u?.lName ?? ''}'.trim();
      return (name: name.isEmpty ? 'You' : name, image: u?.imageFullUrl);
    } catch (_) {
      // ProfileController is not always registered; the demo must not be the
      // thing that crashes a debug build.
      return (name: 'You', image: null);
    }
  }

  void _open(SpotsDraw draw) {
    Get.to(
      () => SpotsClawDrawScreen(
        draw: draw,
        zoneName: 'Maadi',
        week: _isoWeek(DateTime.now()),
      ),
    );
  }

  /// The ISO-8601 week number.
  ///
  /// This previously read `toIso8601String().substring(5, 7)`, which slices
  /// out the **month** — the masthead said "Week 9" through September and
  /// would have said "Week 12" all December.
  ///
  /// Still derived from the device clock, which is the real remaining problem:
  /// the week belongs to the *round*, and a phone in another timezone (or with
  /// a wrong clock) will label a round with someone else's week. The payload
  /// has no period field to read yet — when `CLAW-Z2` adds one, this should
  /// take it from there and this helper should go.
  static int _isoWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // ISO weeks run Monday–Sunday and week 1 is the one containing the first
    // Thursday, so counting is done from the Thursday of this day's week.
    final thursday = day.add(Duration(days: 4 - (day.weekday)));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    return 1 + (thursday.difference(firstOfYear).inDays / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        Spots.gutter,
        Spots.s12,
        Spots.gutter,
        0,
      ),
      padding: const EdgeInsets.all(Spots.s12),
      decoration: Spots.card(
        fill: Spots.paperWarm,
        borderWidth: Spots.borderThin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined, size: 14, color: Spots.red),
              const SizedBox(width: Spots.s4),
              Text(
                'DEBUG — THE CLAW',
                style: Spots.kicker(9, color: Spots.red),
              ),
            ],
          ),
          const SizedBox(height: Spots.s8),
          Row(
            children: [
              Expanded(
                child: _ClawDebugButton(
                  label: prize != null ? 'WIN (REAL)' : 'WIN (DEMO)',
                  fill: Spots.mint,
                  onTap: () {
                    final p = prize;
                    final me = _me;
                    _open(
                      p != null
                          // Their real voucher: pull #1, and the winner row
                          // routes into the genuine prize screen.
                          ? SpotsDrawDemo.fromPrize(
                            p,
                            myName: me.name,
                            myImage: me.image,
                          )
                          // No voucher to hand, so the win is built without
                          // one. This used to call `losing()` — which meant
                          // the button labelled WIN produced a loss on any
                          // account with no prize row: no confetti, no win
                          // sting, "NOT THIS WEEK" on the CTA.
                          : SpotsDrawDemo.winning(
                            myName: me.name,
                            myImage: me.image,
                          ),
                    );
                  },
                ),
              ),
              const SizedBox(width: Spots.s8),
              Expanded(
                child: _ClawDebugButton(
                  label: 'LOSE',
                  fill: Spots.paper,
                  onTap:
                      () => _open(
                        SpotsDrawDemo.losing(
                          myName: _me.name,
                          myImage: _me.image,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: Spots.s8),
              Expanded(
                child: _ClawDebugButton(
                  label: 'EMPTY',
                  fill: Spots.paper,
                  onTap:
                      () => _open(
                        SpotsDraw.fromServer(
                          entrants: const [],
                          winnerIds: const [],
                        ),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClawDebugButton extends StatelessWidget {
  const _ClawDebugButton({
    required this.label,
    required this.fill,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpotsPressable(
      onTap: onTap,
      radius: Spots.radiusMd,
      dx: 2,
      dy: 2,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: Spots.card(
          fill: fill,
          radius: Spots.radiusMd,
          borderWidth: Spots.borderThin,
          dx: 0,
          dy: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: Spots.kicker(10, color: Spots.teal)),
        ),
      ),
    );
  }
}
