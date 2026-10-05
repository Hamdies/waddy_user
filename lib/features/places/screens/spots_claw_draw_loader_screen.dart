import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/features/places/screens/spots_claw_draw_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// Fetches one round's claw draw, then hands it to [SpotsClawDrawScreen].
///
/// The claw screen takes a finished [SpotsDraw] and owns a long-running
/// animation keyed to it, so it is never asked to start with nothing and
/// swap its subject mid-flight. Everything that can go wrong before there is
/// a draw — loading, a week with no draw, a dead network — lives here.
///
/// The fetched round is held by this screen, not the controller: a push for
/// week 27 opened over a home card showing week 28 must not repaint the card.
class SpotsClawDrawLoaderScreen extends StatefulWidget {
  const SpotsClawDrawLoaderScreen({super.key, this.period, this.initialRound});

  /// ISO week (`2026-W27`). Null means the last closed round.
  final String? period;

  /// Already fetched by the caller (the home card) — shown without a round
  /// trip.
  final SpotsDrawRound? initialRound;

  @override
  State<SpotsClawDrawLoaderScreen> createState() =>
      _SpotsClawDrawLoaderScreenState();
}

enum _LoadState { loading, ready, notFound, failed }

class _SpotsClawDrawLoaderScreenState extends State<SpotsClawDrawLoaderScreen> {
  SpotsDrawRound? _round;
  _LoadState _state = _LoadState.loading;

  @override
  void initState() {
    super.initState();
    if (widget.initialRound != null) {
      _round = widget.initialRound;
      _state = _LoadState.ready;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    // A malformed period names no draw. Answer that directly rather than
    // putting the string into a request path.
    if (widget.period != null && !SpotsDrawRound.isValidPeriod(widget.period)) {
      if (_state != _LoadState.notFound) {
        setState(() => _state = _LoadState.notFound);
      }
      return;
    }
    if (_state != _LoadState.loading) {
      setState(() => _state = _LoadState.loading);
    }
    final result = await Get.find<PlacesController>().fetchDraw(
      period: widget.period,
    );
    if (!mounted) return;
    setState(() {
      _round = result.round;
      _state =
          result.round != null
              ? _LoadState.ready
              : result.statusCode == 404
              ? _LoadState.notFound
              : _LoadState.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    if (_state == _LoadState.ready && round != null) {
      return SpotsClawDrawScreen(
        draw: round.draw,
        // The eyebrow's first slot names who went into the machine: the
        // voters of the venue that won the week.
        zoneName: round.placeTitle,
        week: round.week,
      );
    }

    return Scaffold(
      backgroundColor: Spots.mint,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                color: Spots.teal,
                // A cold open from the push has nothing beneath it.
                onPressed:
                    () =>
                        Navigator.canPop(context)
                            ? Get.back()
                            : RouteHelper.goToTab(RouteHelper.tabExplore),
              ),
            ),
            Expanded(
              child: Center(
                child:
                    _state == _LoadState.loading
                        ? const CircularProgressIndicator(color: Spots.teal)
                        : _Message(
                          notFound: _state == _LoadState.notFound,
                          onRetry: _load,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spots.gutter),
      child: Container(
        width: double.infinity,
        decoration: Spots.card(),
        padding: const EdgeInsets.all(Spots.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayCaps(
                (notFound
                        ? 'spots_claw_not_ready_title'
                        : 'spots_claw_load_failed_title')
                    .tr,
              ),
              style: Spots.display(20),
            ),
            const SizedBox(height: Spots.s8),
            Text(
              (notFound
                      ? 'spots_claw_not_ready_body'
                      : 'spots_claw_load_failed_body')
                  .tr,
              style: waddyRegular.copyWith(
                fontSize: 13,
                color: Spots.ink2,
                height: 1.4,
              ),
            ),
            // Nothing to retry for a week that has no draw — the answer
            // will not change by asking again.
            if (!notFound) ...[
              const SizedBox(height: Spots.s16),
              SpotsPressable(
                onTap: onRetry,
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
                    vertical: Spots.s12,
                  ),
                  child: Text(
                    displayCaps('spots_retry'.tr),
                    style: Spots.display(13, tracking: 0.02),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
