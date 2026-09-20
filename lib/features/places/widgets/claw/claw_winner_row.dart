import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/widgets/claw/claw_tokens.dart';
import 'package:waddy_app/util/styles.dart';

/// One row in "PULLED BY THE CLAW".
///
/// A mint pill carrying four things, left to right: which pull it was, the
/// face, the name stack, and a `WON` tag. Every row has the same weight —
/// these are pulls from a random draw, not placings — except the signed-in
/// user's own, which takes a mint glow and reads `YOURS`.
///
/// Tappable only for the signed-in user's own win: the payload carries exactly
/// one prize id (`my_prize_id`), because `winners/recent` deliberately never
/// exposes other people's codes. A row that looked pressable and led nowhere
/// would be the same mistake as the design's ◀ ▶ plates.
class ClawWinnerRow extends StatelessWidget {
  const ClawWinnerRow({super.key, required this.entrant, this.onTap});

  final DrawEntrant entrant;
  final VoidCallback? onTap;

  /// Null when there is no usable photo — empty strings count as none, since a
  /// hand-built entrant can carry '' where the API would send null.
  String? get _photo =>
      (entrant.image != null && entrant.image!.trim().isNotEmpty)
          ? entrant.image
          : null;

  // The first pull used to take a mint "hero" treatment here. v2 drops it:
  // pull order is not a ranking, and giving pick 1 the brightest row in a
  // random draw is the same claim the numbered tiles were making. The only
  // row that stands out now is the signed-in user's own.

  @override
  Widget build(BuildContext context) {
    final mine = entrant.isMe;

    final name =
        entrant.name.trim().isEmpty ? 'spots_a_waddi_voter'.tr : entrant.name;

    // v2 rows are pills on the page, not bordered cards with a hard drop. The
    // fill carries the state — mint wash for a win, a hairline outline for a
    // slot still waiting — so the list reads as a row of results rather than
    // a stack of separate objects.
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: Spots.s12, vertical: 10),
      decoration: BoxDecoration(
        color: ClawTokens.wonRow,
        borderRadius: BorderRadius.circular(ClawTokens.rMd),
        border: Border.all(
          color: ClawTokens.deep.withValues(alpha: 0.14),
          width: 1.5,
        ),
        // Only the signed-in user's own row lifts, and only on mint. The
        // design gives every pulled row the same weight — the claw picks at
        // random, so a hero row among five equals asserts a ranking that does
        // not exist. "Which one is mine" is the one distinction worth making.
        boxShadow:
            mine && onTap == null
                ? [
                  BoxShadow(
                    color: ClawTokens.mint.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          // Both of the row's fixed labels are capped. At 2.0 text scale on a
          // 320pt screen an unbounded "PICK 1" and "YOURS" either side of the
          // name pushed the row 63px past the edge — the labels are the parts
          // that can afford to shrink, and the name is not.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 56),
            child: _PickLabel(rank: entrant.rank),
          ),
          const SizedBox(width: Spots.s12),
          _Face(photo: _photo, initials: entrant.initials),
          const SizedBox(width: Spots.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 15,
                    color: ClawTokens.deep,
                  ),
                ),
                // The vote count used to sit here beside the handle. It was
                // demoted out of a display-weight column first, but the number
                // itself was the problem: five rows reading 6, 4, 5, 10, 7
                // under plates numbered PICK 1–5 is leaderboard grammar over
                // data that carries no ranking, and no caption above the list
                // can out-argue a number repeated on every row. The claw picks
                // at random, so the count is not evidence of anything here —
                // it belongs on the vote screen, where it does mean something.
                if (entrant.handle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entrant.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: ClawTokens.deep.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spots.s8),
          // "WON" — or "YOURS" on the signed-in user's row, which is the one
          // thing a reader is actually scanning this list for.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64),
            child: Text(
              displayCaps(
                mine ? 'spots_claw_row_mine'.tr : 'spots_claw_row_won'.tr,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: Spots.kicker(
                9,
                color: ClawTokens.deep.withValues(alpha: mine ? 0.85 : 0.5),
                tracking: 0.14,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Spots.s4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ClawTokens.deep.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );

    // The whole row announces as one thing. Without this a screen reader reads
    // "1", "Farida N.", "@faridaaa" as three unrelated stops.
    //
    // The announcement carries no vote count, matching the visible row: a
    // number read out beside "pick 1" asserts the same ranking to a screen
    // reader that the printed column asserted to everyone else.
    final labelled = Semantics(
      button: onTap != null,
      label: 'spots_claw_winner_a11y'.trParams({
        'rank': '${entrant.rank}',
        'name': name,
      }),
      excludeSemantics: true,
      child: row,
    );

    if (onTap == null) return labelled;

    return SpotsPressable(
      onTap: onTap,
      radius: ClawTokens.rLg,
      child: labelled,
    );
  }
}

/// `PICK 1` — the row's leading label.
///
/// v2 demotes this from a 44pt numbered tile to a line of kicker text. The
/// tile was leaderboard furniture: a numbered plate at the head of every row
/// reads as a placing, and these are pull *order* from a random draw. As
/// text it still says which pull this was without dressing it as a rank.
class _PickLabel extends StatelessWidget {
  const _PickLabel({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Text(
      displayCaps('spots_claw_pick_n'.trParams({'n': '$rank'})),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
      style: Spots.kicker(
        9,
        color: ClawTokens.deep.withValues(alpha: 0.55),
        tracking: 0.16,
      ),
    );
  }
}

/// The face — a photo where there is one, initials where there is not.
///
/// Seeing *who* got pulled is the whole payoff of the animation, so this is
/// the one element in the row that never gives up space.
class _Face extends StatelessWidget {
  const _Face({required this.photo, required this.initials});

  final String? photo;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Spots.mint200,
        shape: BoxShape.circle,
        border: Border.all(color: ClawTokens.shellFill, width: ClawTokens.bw1),
      ),
      child:
          photo != null
              ? CustomImage(image: photo!, fit: BoxFit.cover)
              : Text(
                initials,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: Spots.display(17, color: Spots.teal),
              ),
    );
  }
}
