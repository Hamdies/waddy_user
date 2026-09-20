import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The review composer.
///
/// Rebuilt from a version whose rating control was five identical grey squares
/// in a bordered box: at rest nothing signalled "scale", nothing said the
/// squares were tappable, and the row read as five disabled buttons. The
/// score is the primary input on this sheet and it looked like the dead part
/// of it.
///
/// The rewrite: a single expressive face that reacts as you rate, stars that
/// grow toward the selection, the score named in words, an optional photo, and
/// a submit button that says what it will do. The sheet also sizes to its
/// content so it doesn't leave a screen of dead space above the keyboard.
class PlaceVoteSheet extends StatefulWidget {
  final int placeId;

  /// Whether the caller already has a review here — drives update vs. create
  /// copy and the remove affordance. Named for voting historically; it is
  /// review state now.
  final bool hasVoted;
  final int? initialRating;
  final String? initialComment;

  /// Shown under the title so the user knows what they're reviewing — the
  /// sheet covers the screen that had that context.
  final String? placeTitle;

  const PlaceVoteSheet({
    super.key,
    required this.placeId,
    this.hasVoted = false,
    this.initialRating,
    this.initialComment,
    this.placeTitle,
  });

  @override
  State<PlaceVoteSheet> createState() => _PlaceVoteSheetState();
}

class _PlaceVoteSheetState extends State<PlaceVoteSheet> {
  int _rating = 0;
  int? _hovered;
  XFile? _photo;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _isSubmitting = false;

  static const List<String> _ratingLabelKeys = [
    'rating_okay',
    'rating_good',
    'rating_great',
    'rating_amazing',
    'rating_legendary',
  ];

  /// Red → green → mint as the score climbs, so the colour itself carries the
  /// verdict before the label is read.
  static Color _ratingColor(int rating) {
    if (rating <= 0) return Spots.ink3;
    if (rating <= 3) {
      return Color.lerp(Spots.red, Spots.green, (rating - 1) / 2)!;
    }
    return Color.lerp(Spots.green, Spots.mint, (rating - 3) / 2)!;
  }

  /// A review needs a score or words — either alone is complete.
  bool get _canSubmit =>
      _rating > 0 || _commentController.text.trim().isNotEmpty;

  int get _shown => _hovered ?? _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0;
    if (widget.initialComment != null) {
      _commentController.text = widget.initialComment!;
    }
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() => setState(() {});

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    HapticFeedback.selectionClick();
    setState(() => _rating = value);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: const BoxDecoration(
        color: Spots.paper,
        border: Border(
          top: BorderSide(color: Spots.border, width: Spots.borderThick),
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spots.radiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Spots.s20,
                  0,
                  Spots.s20,
                  Spots.s16 + media.viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: Spots.s20),
                    _ratingBlock(),
                    const SizedBox(height: Spots.s20),
                    _commentBlock(),
                    const SizedBox(height: Spots.s12),
                    _photoRow(),
                    const SizedBox(height: Spots.s20),
                    _submitButton(),
                    if (widget.hasVoted) ...[
                      const SizedBox(height: Spots.s12),
                      _removeButton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grabber() {
    return Padding(
      padding: const EdgeInsets.only(top: Spots.s12, bottom: Spots.s16),
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: Spots.canvasDot,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayCaps(
                  widget.hasVoted
                      ? 'update_your_review'.tr
                      : 'rate_and_review'.tr,
                ),
                style: Spots.display(24, color: Spots.ink),
              ),
              const SizedBox(height: Spots.s4),
              Text(
                widget.placeTitle?.isNotEmpty == true
                    ? widget.placeTitle!
                    : 'tell_locals_what_its_like'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Spots.ink3,
                ),
              ),
            ],
          ),
        ),
        // Always reachable: with the keyboard up, the scrim and the grabber
        // are both out of thumb range.
        Semantics(
          button: true,
          label: 'close'.tr,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
              Get.back();
            },
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Spots.paperWarm,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Spots.ink2, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  /// Stars on the sheet's own paper, no box around them — the box made the row
  /// read as a disabled field. Size and colour both track the score, so the
  /// control is obviously live before it is touched.
  Widget _ratingBlock() {
    final shown = _shown;
    final color = _ratingColor(shown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final index = i + 1;
            final selected = index <= shown;
            return Expanded(
              child: Semantics(
                button: true,
                label: '$index',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _hovered = index),
                  onTapCancel: () => setState(() => _hovered = null),
                  onTap: () {
                    setState(() => _hovered = null);
                    _setRating(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: Spots.s8),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      scale: selected ? 1.0 : 0.82,
                      child: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 42,
                        color: selected ? color : Spots.canvasDot,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: Spots.s4),
        // Reserves its own height so naming the score doesn't reflow the
        // sheet under the user's thumb.
        SizedBox(
          height: 20,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: shown > 0 ? 1 : 0.55,
              child: Text(
                displayCaps(
                  shown > 0 ? _ratingLabelKeys[shown - 1].tr : 'tap_to_rate'.tr,
                ),
                style: Spots.kicker(
                  12,
                  color: shown > 0 ? color : Spots.ink3,
                  tracking: 0.08,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _commentBlock() {
    return Container(
      decoration: BoxDecoration(
        color: Spots.paperWarm,
        borderRadius: BorderRadius.circular(Spots.radiusMd),
        border: Border.all(
          color:
              _commentFocus.hasFocus
                  ? Spots.teal
                  : Spots.border.withValues(alpha: 0.35),
          width: Spots.borderThin,
        ),
      ),
      child: TextField(
        controller: _commentController,
        focusNode: _commentFocus,
        maxLines: 4,
        minLines: 3,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontFamily: AppConstants.fontFamily,
          fontSize: 14,
          height: 1.45,
          color: Spots.ink,
        ),
        decoration: InputDecoration(
          hintText: 'describe_your_experience'.tr,
          hintStyle: const TextStyle(
            fontFamily: AppConstants.fontFamily,
            fontSize: 14,
            color: Spots.ink3,
          ),
          border: InputBorder.none,
          // The default counter is a stray grey number under a bordered box;
          // 1000 chars is a limit nobody approaches by accident.
          counterText: '',
          contentPadding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
        ),
      ),
    );
  }

  Widget _photoRow() {
    if (_photo != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Spots.radiusSm),
            child: Image.file(
              File(_photo!.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: Spots.s12),
          Expanded(
            child: Text(
              'photo_attached'.tr,
              style: const TextStyle(
                fontFamily: AppConstants.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Spots.ink2,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _photo = null),
            child: const Padding(
              padding: EdgeInsets.all(Spots.s8),
              child: Icon(Icons.close, size: 18, color: Spots.ink3),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickPhoto,
      child: Row(
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 18, color: Spots.teal),
          const SizedBox(width: Spots.s8),
          Text(
            'add_a_photo'.tr,
            style: const TextStyle(
              fontFamily: AppConstants.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Spots.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    final enabled = _canSubmit && !_isSubmitting;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Spots.s16),
        decoration: BoxDecoration(
          color: enabled ? Spots.mint : Spots.canvasDot,
          border: Border.all(color: Spots.border, width: Spots.borderThin),
          borderRadius: BorderRadius.circular(Spots.radiusMd),
          boxShadow: enabled ? Spots.shadow() : null,
        ),
        child: Center(
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Spots.teal,
                    ),
                  )
                  : Text(
                    displayCaps(
                      widget.hasVoted ? 'update_review'.tr : 'post_review'.tr,
                    ),
                    style: Spots.display(
                      16,
                      color: enabled ? Spots.teal : Spots.ink3,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _removeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isSubmitting ? null : _removeReview,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Spots.s12),
        alignment: Alignment.center,
        child: Text(
          displayCaps('remove_my_review'.tr),
          style: Spots.kicker(11, color: Spots.red, tracking: 0.06),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    // Posts a REVIEW. It never casts, moves or removes a vote — the user can
    // review a place they never voted for, and vice versa.
    final success = await Get.find<PlacesController>().submitReview(
      widget.placeId,
      _rating > 0 ? _rating : null,
      review:
          _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
      imagePath: _photo?.path,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) Get.back(result: true);
  }

  Future<void> _removeReview() async {
    setState(() => _isSubmitting = true);
    // Removes only the review; any vote on this spot stays put.
    final success = await Get.find<PlacesController>().removeReview(
      widget.placeId,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) Get.back(result: false);
  }
}
