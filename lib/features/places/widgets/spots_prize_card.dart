import 'package:flutter/material.dart';
import 'package:get/get.dart';
// intl exports its own bidi TextDirection, which shadows Flutter's and breaks
// TextDirection.ltr — hide it, DateFormat is all this card needs.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/common/widgets/spots/spots_marks.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// A voucher, as it looks in the list.
///
/// Deliberately quiet: this is a door, not the prize. The code, the QR, the
/// countdown and the rules all live on the details screen, so the row carries
/// only what you need to pick one — what you won, where, and whether it's
/// still good. Live rows get the mint fill; spent ones go white and fade.
class SpotsPrizeCard extends StatelessWidget {
  const SpotsPrizeCard({super.key, required this.prize, this.onTap});

  final PlacePrize prize;

  /// Opens prize details, where the code and the QR live.
  final VoidCallback? onTap;

  bool get _live => prize.isActive && prize.secondsRemaining > 0;

  /// What was won. `place_prizes` has no name column — the reward is modelled
  /// as a value ceiling — so the cap is the most specific true description
  /// available, matching the details screen's headline.
  String get _title {
    final cap = prize.valueCap;
    if (cap == null || cap <= 0) return 'spots_prize_free_item_title'.tr;
    final amount = cap.toStringAsFixed(2);
    final trimmed =
        amount.endsWith('.00')
            ? amount.substring(0, amount.length - 3)
            : amount;
    return 'spots_prize_value_cap'.trParams({
      'amount': trimmed,
      'currency': prize.currency ?? '',
    }).trim();
  }

  /// "Claim by Fri, Aug 8" while live; "Claimed Jul 28" / "Expired Jul 14"
  /// once it's spent. Falls back to the week label when the server sent no
  /// timestamp, so the line is never empty.
  String get _dateLabel {
    final String? locale = Get.locale?.toString();
    String fmt(DateTime date) => DateFormat('MMM d', locale).format(date);

    if (_live) {
      return prize.expiresAt != null
          ? 'spots_prize_claim_by'.trParams({
            'date': DateFormat('E, MMM d', locale).format(prize.expiresAt!),
          })
          : prize.weekLabel;
    }
    if (prize.isRedeemed) {
      return prize.redeemedAt != null
          ? 'spots_prize_claimed_on'.trParams({'date': fmt(prize.redeemedAt!)})
          : 'spots_prize_status_redeemed'.tr;
    }
    return prize.expiresAt != null
        ? 'spots_prize_expired_on'.trParams({'date': fmt(prize.expiresAt!)})
        : 'spots_prize_status_expired'.tr;
  }

  @override
  Widget build(BuildContext context) {
    // A spent voucher has nothing behind it worth opening — the code is burnt
    // and the QR is dead — so history rows are inert and greyed rather than
    // leading to a details screen that can only disappoint.
    final bool openable = _live && onTap != null;

    return Opacity(
      opacity: _live ? 1 : 0.6,
      child: SpotsPressable(
        onTap: openable ? onTap : null,
        enabled: openable,
        dx: _live ? 5 : 4,
        dy: _live ? 5 : 4,
        radius: 12,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spots.s16),
          decoration: Spots.card(
            fill: _live ? Spots.mint : const Color(0xFFF5F8F7),
            radius: 12,
            borderWidth: Spots.borderThick,
            dx: _live ? 0 : 4,
            dy: _live ? 0 : 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: waddyBlack.copyWith(
                              fontSize: 17,
                              color: _live ? Spots.teal : Spots.ink2,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spots.s8 + 2),
                        _StatusPill(prize: prize, live: _live),
                      ],
                    ),
                    // Venue, then street — "where do I go" beats the full
                    // Google address, which can run four lines on its own.
                    const SizedBox(height: Spots.s4 + 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: 1,
                            end: 4,
                          ),
                          child: SpotsGlyph(
                            SpotsMark.pin,
                            size: 11,
                            color: _live ? Spots.teal : Spots.ink3,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _locationLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: waddyBold.copyWith(
                              fontSize: 11.5,
                              height: 1.3,
                              color:
                                  _live
                                      ? Spots.teal.withValues(alpha: 0.8)
                                      : Spots.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spots.s8 + 2),
                    Text(
                      _dateLabel,
                      style: waddyBold.copyWith(
                        fontSize: 10.5,
                        height: 1.3,
                        color: _live ? Spots.teal900 : Spots.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              // The only affordance on the row. Spent rows don't get one —
              // a chevron that opens nothing is a promise the row can't keep.
              if (openable)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: Spots.s8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Spots.teal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Cilantro Café · Degla", prefixed by a drawn pin glyph. The venue name always exists, so the line
  /// always renders; the address only joins it when the server has one.
  String get _locationLine {
    final address = prize.placeAddress?.trim();
    return address == null || address.isEmpty
        ? prize.placeTitle
        : '${prize.placeTitle} · $address';
  }
}

/// READY / USED / EXPIRED — a flat state marker. It doesn't pulse: the row is
/// a link, and a blinking badge in a list reads as an alarm nobody can act on
/// without tapping through anyway.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.prize, required this.live});

  final PlacePrize prize;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final Color fill =
        live
            ? Spots.red
            : (prize.isRedeemed ? Spots.teal : const Color(0xFFE7ECEA));
    final Color fg = live || prize.isRedeemed ? Colors.white : Spots.ink3;
    final String label =
        live
            ? 'spots_prize_status_ready'.tr
            : (prize.isRedeemed
                ? 'spots_prize_status_redeemed'.tr
                : 'spots_prize_status_expired'.tr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spots.s8, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: Spots.border, width: Spots.borderThin),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        displayCaps(label),
        style: Spots.kicker(9.5, color: fg, tracking: 0.06),
      ),
    );
  }
}
