import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/helper/route_helper.dart';
// intl exports its own bidi TextDirection, which shadows Flutter's and breaks
// TextDirection.ltr — hide it, DateFormat is all this screen needs.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/models/spots_draw_round_model.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// Prize details — the screen the winner holds up at the counter.
///
/// Faithful to the "Prize Details (mobile)" template: teal hero carrying the
/// QR on a mint-shadowed plate, an expiry sticker breaking the hero's bottom
/// edge, then name / location / dashed divider / how-to-claim / code box /
/// meta row / rules, with the actions pinned to the bottom of the scroll.
class SpotsPrizeDetailsScreen extends StatefulWidget {
  const SpotsPrizeDetailsScreen({super.key, required this.prizeId, this.prize});

  final int prizeId;

  /// Passed straight through when pushed from the list, so the screen paints
  /// immediately. A push deep-link has no object and falls back to a lookup.
  final PlacePrize? prize;

  @override
  State<SpotsPrizeDetailsScreen> createState() =>
      _SpotsPrizeDetailsScreenState();
}

class _SpotsPrizeDetailsScreenState extends State<SpotsPrizeDetailsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.prize == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = Get.find<PlacesController>();
        // Arriving from the win push, the prize is new by definition — a list
        // loaded before the draw ran does not have it. Only skip the round
        // trip when the cached list already knows this id.
        controller.getMyPrizes(reload: _resolve(controller) == null);
      });
    }
  }

  /// Prefer the controller's copy so a redemption elsewhere reflects here.
  PlacePrize? _resolve(PlacesController controller) {
    for (final p in [...controller.activePrizes, ...controller.prizeHistory]) {
      if (p.id == widget.prizeId) return p;
    }
    return widget.prize;
  }

  Future<void> _directions(PlacePrize prize) async {
    if (prize.latitude == null || prize.longitude == null) {
      showCustomSnackBar('spots_prize_no_location'.tr, isError: true);
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${prize.latitude},${prize.longitude}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      showCustomSnackBar('failed_to_open_link'.tr, isError: true);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showCustomSnackBar('spots_prize_code_copied'.tr, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Spots.paper,
      body: GetBuilder<PlacesController>(
        // `getMyPrizes` only notifies ids; without one this screen never
        // repainted once the fetch landed. See `PlacesController.idPrizes`.
        id: PlacesController.idPrizes,
        builder: (controller) {
          final prize = _resolve(controller);

          if (prize == null) {
            return SafeArea(
              child: Center(
                child:
                    controller.isPrizesLoading
                        ? const CircularProgressIndicator(color: Spots.teal)
                        : Padding(
                          padding: const EdgeInsets.all(Spots.s32),
                          child: Text(
                            'spots_prizes_empty_title'.tr,
                            textAlign: TextAlign.center,
                            style: waddyBold.copyWith(
                              fontSize: 15,
                              color: Spots.ink2,
                            ),
                          ),
                        ),
              ),
            );
          }

          return Column(
            children: [
              _PrizeHero(prize: prize),
              Expanded(
                child: _PrizeBody(
                  prize: prize,
                  onDirections: () => _directions(prize),
                  onCopyCode: () => _copyCode(prize.code),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Teal hero: QR on a white plate with a mint hard shadow, back button
/// floating top-start, and the expiry sticker breaking the bottom border.
class _PrizeHero extends StatelessWidget {
  const _PrizeHero({required this.prize});

  final PlacePrize prize;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return SizedBox(
      // 230px of hero + the status bar, per the template's fixed hero height
      height: 230 + top,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 230 + top,
            decoration: const BoxDecoration(
              color: Spots.teal,
              border: Border(
                bottom: BorderSide(
                  color: Spots.border,
                  width: Spots.borderThick,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(10),
                decoration: Spots.card(
                  fill: Colors.white,
                  borderWidth: Spots.borderThick,
                  dx: 5,
                  dy: 5,
                  shadowColor: Spots.mint,
                ),
                child: QrImageView(
                  // The counter deep link when the venue has one, so staff can
                  // scan straight into a prefilled page; the bare code is the
                  // fallback and is what they read out either way.
                  data:
                      (prize.redeemUrl != null && prize.redeemUrl!.isNotEmpty)
                          ? prize.redeemUrl!
                          : prize.code,
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Spots.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Spots.ink,
                  ),
                ),
              ),
            ),
          ),

          // Back button — paper on teal, hard shadow, ≥44px target
          PositionedDirectional(
            top: top + 14,
            start: 14,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Get.back(),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: Spots.card(
                  fill: Spots.paper,
                  radius: Spots.radiusMd,
                  borderWidth: 2.5,
                  dx: 3,
                  dy: 3,
                ),
                child: Icon(
                  Directionality.of(context) == TextDirection.ltr
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 26,
                  color: Spots.teal,
                ),
              ),
            ),
          ),

          // Expiry sticker straddling the hero's bottom edge. It sits *inside*
          // the hero rather than hanging below it: overhanging clipped against
          // the scrolling body and landed on top of the address.
          if (prize.expiresAt != null && prize.isActive)
            PositionedDirectional(
              bottom: 0,
              end: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: Spots.card(
                  fill: Spots.red,
                  radius: Spots.radiusPill,
                  borderWidth: 2.5,
                  dx: 3,
                  dy: 3,
                ),
                child: Text(
                  displayCaps(
                    'spots_prize_claim_by'.trParams({
                      'date': DateFormat(
                        'E, MMM d',
                        Get.locale?.toString(),
                      ).format(prize.expiresAt!),
                    }),
                  ),
                  style: waddyBlack.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: displayTracking(0.04 * 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrizeBody extends StatelessWidget {
  const _PrizeBody({
    required this.prize,
    required this.onDirections,
    required this.onCopyCode,
  });

  final PlacePrize prize;
  final VoidCallback onDirections;
  final VoidCallback onCopyCode;

  String _statusLabel() {
    if (prize.isRedeemed) return 'spots_prize_status_redeemed'.tr;
    if (prize.isExpired) return 'spots_prize_status_expired'.tr;
    return 'spots_prize_status_ready'.tr;
  }

  Color _statusColor() {
    if (prize.isRedeemed) return Spots.green;
    if (prize.isExpired) return Spots.ink3;
    return Spots.red; // "Ready" is red in the template — urgency, not error
  }

  /// The template's headline is a prize name ("1 free coffee, on us"), but
  /// `place_prizes` has no name column — the backend models a reward purely as
  /// a value ceiling (`value_cap`, per-place or the 60 EGP default, plus
  /// `currency`). The cap is therefore the most specific true description
  /// available, and it takes the headline slot. The generic fallback only
  /// fires when the server genuinely sent no cap.
  String _title() {
    final cap = prize.valueCap;
    if (cap == null || cap <= 0) return 'spots_prize_free_item_title'.tr;

    // "60 EGP", not "60.00 EGP" — trailing zeroes read as a price tag, and
    // this is a ceiling the cashier eyeballs, not an amount anyone pays.
    final amount = cap.toStringAsFixed(2);
    final trimmed =
        amount.endsWith('.00')
            ? amount.substring(0, amount.length - 3)
            : amount;

    return 'spots_prize_value_cap'
        .trParams({'amount': trimmed, 'currency': prize.currency ?? ''})
        // A null currency would otherwise leave a dangling space before the
        // sentence ends.
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.toString();

    // The actions sit at the bottom of the viewport when the content is short
    // and scroll naturally once it grows. `minHeight` alone can't do that: the
    // scroll view leaves `maxHeight` unbounded, so a Spacer inside has no
    // remaining space to claim. Handing the Column the viewport's own height
    // as a minimum *and* letting IntrinsicHeight bound it makes both cases
    // resolve — hence LayoutBuilder rather than a bare ConstrainedBox.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Spots.s20,
                  Spots.s24 + Spots.s4,
                  Spots.s20,
                  MediaQuery.of(context).padding.bottom + Spots.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayCaps(_title()),
                      style: waddyBlack.copyWith(
                        fontSize: 26,
                        color: Spots.ink,
                        height: 1.05,
                        letterSpacing: displayTracking(-0.01 * 26),
                      ),
                    ),
                    // The venue is the second line, in ink — it's the answer to
                    // "where do I go", so it can't be meta-grey like the street
                    // address under it.
                    const SizedBox(height: Spots.s8),
                    Text(
                      prize.placeTitle,
                      style: waddyBold.copyWith(
                        fontSize: 15,
                        color: Spots.ink,
                        height: 1.3,
                      ),
                    ),
                    if (prize.placeAddress != null &&
                        prize.placeAddress!.trim().isNotEmpty) ...[
                      const SizedBox(height: Spots.s4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SpotsGlyph(
                            SpotsMark.pin,
                            size: 12,
                            color: Spots.ink3,
                          ),
                          const SizedBox(width: Spots.s4 + 2),
                          Expanded(
                            child: Text(
                              prize.placeAddress!.trim(),
                              // A Google-sourced address can run four lines and
                              // shove everything below it off the fold; two is
                              // enough to recognise the branch.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: waddyBold.copyWith(
                                fontSize: 12.5,
                                color: Spots.ink3,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const _DashedDivider(),

                    Text(
                      displayCaps('spots_prize_how_to_claim'.tr),
                      style: Spots.kicker(11, tracking: 0.1),
                    ),
                    const SizedBox(height: Spots.s8),
                    Text(
                      'spots_prize_how_to_claim_body'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 14,
                        color: Spots.ink,
                        height: 1.6,
                      ),
                    ),

                    // ── Code box: mint plate, tap to copy ──
                    const SizedBox(height: Spots.s20 + 2),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCopyCode,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Spots.s16 + 2),
                        decoration: Spots.card(
                          fill: Spots.mint,
                          radius: Spots.radiusLg + 2,
                          borderWidth: Spots.borderThick,
                          dx: 5,
                          dy: 5,
                        ),
                        child: Column(
                          children: [
                            Text(
                              displayCaps('spots_prize_your_code'.tr),
                              style: waddyBold.copyWith(
                                fontSize: 10.5,
                                color: Spots.teal.withValues(alpha: 0.8),
                                letterSpacing: displayTracking(0.1 * 10.5),
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: Spots.s8),
                            // The QR above is what staff scan, but this screen is now
                            // the only place the code itself appears — the list row
                            // deliberately doesn't carry it — so it has to be
                            // readable here. Tapping copies it.
                            Text(
                              prize.code,
                              // The code is ASCII whatever the UI language.
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: waddyBlack.copyWith(
                                fontSize: 24,
                                color: Spots.teal,
                                height: 1.1,
                                letterSpacing: 2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: Spots.s8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayCaps('spots_prize_show_at_counter'.tr),
                                  style: waddyBold.copyWith(
                                    fontSize: 10.5,
                                    color: Spots.teal.withValues(alpha: 0.8),
                                    letterSpacing: displayTracking(0.06 * 10.5),
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: Spots.s4 + 2),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Spots.teal.withValues(alpha: 0.8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Meta row ──
                    const SizedBox(height: Spots.s16 + 2),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaBox(
                            label: 'spots_prize_won_on'.tr,
                            value:
                                prize.wonAt != null
                                    ? DateFormat(
                                      'MMM d, y',
                                      locale,
                                    ).format(prize.wonAt!)
                                    : '—',
                          ),
                        ),
                        const SizedBox(width: Spots.s12),
                        Expanded(
                          child: _MetaBox(
                            label: 'spots_prize_status'.tr,
                            value: _statusLabel(),
                            valueColor: _statusColor(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: Spots.s16),
                    Text(
                      'spots_prize_rules'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 10.5,
                        color: Spots.ink3,
                        height: 1.6,
                      ),
                    ),

                    // Pushes the actions to the bottom when content is short
                    const Spacer(),

                    const SizedBox(height: Spots.s24),
                    _ActionButton(
                      label: 'spots_prize_get_directions'.tr,
                      onTap: onDirections,
                      filled: true,
                      height: 56,
                    ),
                    // The round this voucher came out of. Winning is the one
                    // result worth watching twice, and a voucher is the only
                    // place a past week's draw can be reached from.
                    if (SpotsDrawRound.isValidPeriod(prize.period)) ...[
                      const SizedBox(height: Spots.s12 - 1),
                      _ActionButton(
                        label: 'spots_claw_watch_draw'.tr,
                        onTap:
                            () => Get.toNamed(
                              RouteHelper.getSpotsClawDrawRoute(
                                period: prize.period,
                              ),
                            ),
                        filled: false,
                        height: 48,
                      ),
                    ],
                    const SizedBox(height: Spots.s12 - 1),
                    _ActionButton(
                      label: 'spots_prize_back_to_prizes'.tr,
                      onTap: () => Get.back(),
                      filled: false,
                      height: 48,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The template's `border-top: 2px dashed` rule.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spots.s20 + 2),
      child: CustomPaint(
        size: const Size(double.infinity, 2),
        painter: _DashPainter(),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Spots.border
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.butt;
    const dash = 6.0, gap = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 1),
        Offset((x + dash).clamp(0, size.width), 1),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spots.s12),
      decoration: BoxDecoration(
        border: Border.all(color: Spots.border, width: 2.5),
        borderRadius: BorderRadius.circular(Spots.radiusMd + 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayCaps(label), style: Spots.kicker(9.5, tracking: 0.08)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: waddyBlack.copyWith(
              fontSize: 13.5,
              color: valueColor ?? Spots.ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
    this.height = 52,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SpotsPressable(
      onTap: onTap,
      dx: 4,
      dy: 4,
      radius: Spots.radiusMd + 1,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: Spots.card(
          fill: filled ? Spots.mint : Spots.paper,
          radius: Spots.radiusMd + 1,
          borderWidth: Spots.borderThick,
          dx: 0,
          dy: 0,
        ),
        child: Text(
          displayCaps(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyBlack.copyWith(
            fontSize: filled ? 16 : 14,
            color: Spots.teal,
            height: 1,
            letterSpacing: displayTracking(0.04 * (filled ? 16 : 14)),
          ),
        ),
      ),
    );
  }
}
