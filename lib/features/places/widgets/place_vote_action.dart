import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/widgets/place_vote_sheet.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/common/widgets/spots/spots_confetti.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// Single source of truth for the app's two distinct Spots verbs.
///
/// **Vote** is a one-tap act of support — no sheet, no rating, no form. The
/// backend validates `rating` as nullable, so a bare vote is a complete vote;
/// the star rating was only ever a client-side gate. Casting is optimistic and
/// undoable for a few seconds rather than confirmed up front, because a
/// confirmation dialog on every tap costs more than the rare misfire does.
///
/// **Review** is a separate, deliberate act: rating + words + photo, entered
/// through [PlaceVoteSheet]. Users who want to say something can review
/// without voting, and users who just want to back a spot are no longer made
/// to write about it first.
///
/// Both gate through [GuestGate] so a guest gets the phone→OTP sheet in place.
/// See docs/guest_mode_plan.md (auth-wall matrix).

/// One-tap vote. Casts immediately and offers an undo.
Future<void> openVoteSheet(int placeId) async {
  GuestGate.requireAccount(() => _castVote(placeId), reason: 'vote');
}

/// Deliberate review composer — rating, comment, photo.
Future<void> openReviewSheet(int placeId) async {
  GuestGate.requireAccount(
    () => _presentReviewSheet(placeId),
    reason: 'review',
  );
}

/// Withdraw the vote from this spot. Direct — no sheet, no form.
Future<void> unvotePlace(int placeId) async {
  GuestGate.requireAccount(() async {
    final controller = Get.find<PlacesController>();
    final removed = await controller.removeVote(placeId, silent: true);
    if (removed) _showVoteToast('vote_removed'.tr, placeId: placeId);
  }, reason: 'unvote');
}

Future<void> _castVote(int placeId) async {
  final controller = Get.find<PlacesController>();

  // Already backing this spot? A second tap is a mis-tap, not a second vote —
  // the vote is idempotent server-side, so say so instead of re-posting.
  await controller.getVoteStatus(placeId);
  if (controller.voteStatus?.hasVoted ?? false) {
    _showVoteToast('already_backing_this_spot'.tr, placeId: placeId);
    return;
  }

  // `silent` suppresses the controller's own success toast: the undo snackbar
  // below is the confirmation, and two stacked toasts hide the undo action.
  final success = await controller.submitVote(placeId, null, silent: true);
  if (success) {
    // The vote is the app's core act and it landed with no acknowledgement
    // beyond a count changing. The burst is the payoff.
    showSpotsConfetti();
    _showVoteToast('vote_cast'.tr, placeId: placeId, undoable: true);
  }
}

Future<void> _presentReviewSheet(int placeId) async {
  final controller = Get.find<PlacesController>();
  // Resolve any existing review so the sheet opens prefilled, guarded so a slow
  // round-trip can't produce a double-tapped sheet.
  Get.dialog(
    const Center(child: CircularProgressIndicator(color: Spots.mint)),
    barrierColor: Colors.black26,
    barrierDismissible: false,
  );
  await controller.getVoteStatus(placeId);
  if (Get.isDialogOpen ?? false) Get.back();

  final status = controller.voteStatus;
  Get.bottomSheet(
    PlaceVoteSheet(
      placeId: placeId,
      // The sheet covers the screen carrying this context, so it names the
      // spot itself rather than asking the user to remember.
      placeTitle:
          controller.placeDetails?.id == placeId
              ? controller.placeDetails?.title
              : null,
      // Keyed off REVIEW state, not vote state: the sheet's "update / remove"
      // affordances are about the review, and a user can have one without the
      // other in either direction.
      hasVoted: status?.hasReviewed ?? false,
      initialRating: status?.vote?.rating,
      initialComment: status?.vote?.comment,
    ),
    isScrollControlled: true,
    // The sheet paints its own paper surface and top border; a default sheet
    // background would sit behind it as an opaque full-height slab.
    backgroundColor: Colors.transparent,
    // Keep the sheet clear of the keyboard-driven resize so the comment field
    // stays reachable while typing.
    ignoreSafeArea: false,
    // Tapping the scrim or dragging the handle closes the sheet. Without these
    // the only way out was submitting.
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black54,
  );
}

/// Spots-styled confirmation. Carries the UNDO affordance for a fresh vote —
/// [showCustomSnackBar] has no action slot, hence the local bar.
void _showVoteToast(
  String message, {
  required int placeId,
  bool undoable = false,
}) {
  final context = Get.context;
  if (context == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Spots.panel,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: undoable ? 5 : 2),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Spots.mint, width: Spots.borderThin),
        borderRadius: BorderRadius.all(Radius.circular(Spots.radiusMd)),
      ),
      content: Text(
        displayCaps(message),
        style: Spots.kicker(12, color: Colors.white, tracking: 0.06),
      ),
      action:
          undoable
              ? SnackBarAction(
                label: displayCaps('undo'.tr),
                textColor: Spots.mint,
                onPressed:
                    () => Get.find<PlacesController>().removeVote(
                      placeId,
                      silent: true,
                    ),
              )
              : null,
    ),
  );
}
