import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sixam_mart/features/places/controllers/places_controller.dart';
import 'package:sixam_mart/util/styles.dart';
import 'dart:io';

class PlaceVoteSheet extends StatefulWidget {
  final int placeId;
  final bool hasVoted;

  const PlaceVoteSheet({super.key, required this.placeId, this.hasVoted = false});

  @override
  State<PlaceVoteSheet> createState() => _PlaceVoteSheetState();
}

class _PlaceVoteSheetState extends State<PlaceVoteSheet> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  String? _imagePath;
  bool _isSubmitting = false;

  static const List<String> _ratingEmojis = ['😐', '🙂', '😊', '🤩', '🔥'];
  static const List<String> _ratingLabels = ['okay', 'good', 'great', 'amazing', 'legendary'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final neon = Theme.of(context).secondaryHeaderColor;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // Header with emoji
            Row(
              children: [
                const Text('🗳️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.hasVoted ? 'update_your_vote'.tr : 'rate_this_place'.tr,
                        style: robotoBold.copyWith(fontSize: 18),
                      ),
                      Text(
                        'share_your_experience'.tr,
                        style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Star Rating with emoji feedback
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: neon.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(color: neon.withValues(alpha: 0.05), blurRadius: 8),
                ],
              ),
              child: Column(
                children: [
                  if (_rating > 0) ...[
                    Text(
                      _ratingEmojis[_rating - 1],
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ratingLabels[_rating - 1].tr,
                      style: robotoMedium.copyWith(fontSize: 13, color: Colors.amber.shade800),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedScale(
                          scale: i < _rating ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 40,
                            color: i < _rating ? Colors.amber.shade600 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: robotoRegular.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'write_a_review'.tr,
                hintStyle: robotoRegular.copyWith(fontSize: 14, color: Theme.of(context).disabledColor),
                filled: true,
                fillColor: primary.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: neon, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),

            const SizedBox(height: 14),

            // Photo upload row
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: neon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: neon.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text('add_photo'.tr,
                            style: robotoMedium.copyWith(fontSize: 12, color: neon)),
                      ],
                    ),
                  ),
                ),
                if (_imagePath != null) ...[
                  const SizedBox(width: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_imagePath!),
                          width: 50, height: 50, fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6, right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagePath = null),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text('earn_xp_for_photo'.tr,
                          style: robotoMedium.copyWith(fontSize: 9, color: Colors.amber.shade800)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Submit button — gradient
            GestureDetector(
              onTap: _rating == 0 || _isSubmitting ? null : _submit,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _rating > 0 && !_isSubmitting
                      ? LinearGradient(colors: [neon, neon.withValues(alpha: 0.8)])
                      : null,
                  color: _rating == 0 || _isSubmitting ? Theme.of(context).disabledColor.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _rating > 0 && !_isSubmitting
                      ? [BoxShadow(
                          color: neon.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )]
                      : null,
                ),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        )
                      : Text(
                          widget.hasVoted ? 'update_vote'.tr : 'submit_vote'.tr,
                          style: robotoBold.copyWith(
                            fontSize: 15,
                            color: _rating > 0 ? primary : Theme.of(context).disabledColor,
                          ),
                        ),
                ),
              ),
            ),

            // Remove vote
            if (widget.hasVoted) ...[
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _removeVote,
                  child: Text(
                    'remove_vote'.tr,
                    style: robotoRegular.copyWith(fontSize: 13, color: const Color(0xFFFF5252)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final success = await Get.find<PlacesController>().submitVote(
      widget.placeId,
      _rating,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      imagePath: _imagePath,
    );
    setState(() => _isSubmitting = false);
    if (success) Get.back();
  }

  Future<void> _removeVote() async {
    setState(() => _isSubmitting = true);
    final success = await Get.find<PlacesController>().removeVote(widget.placeId);
    setState(() => _isSubmitting = false);
    if (success) Get.back();
  }
}
