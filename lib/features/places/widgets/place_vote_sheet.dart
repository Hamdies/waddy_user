import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
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

  static const List<String> _ratingLabels = ['OKAY', 'GOOD', 'GREAT', 'AMAZING', 'LEGENDARY'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        border: Border(top: BorderSide(color: Colors.black, width: 4)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──────────────────────────────────
            Center(
              child: Container(
                width: 48,
                height: 4,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),

            // ── Header ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDD400),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hasVoted ? 'UPDATE YOUR VOTE' : 'CAST YOUR VOTE',
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'YOUR SIGNAL MATTERS',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00693E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Rating label ─────────────────────────────────
            const Text(
              'SIGNAL STRENGTH',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            // ── Stars ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      final selected = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFFDD400) : const Color(0xFFF6F6F6),
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: selected
                                ? const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)]
                                : null,
                          ),
                          child: Icon(
                            selected ? Icons.star : Icons.star_border,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_rating > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FC9B),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        _ratingLabels[_rating - 1],
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Comment ──────────────────────────────────────
            const Text(
              'YOUR TRANSMISSION',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)],
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Describe your experience...',
                  hintStyle: TextStyle(fontFamily: 'Manrope', fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Photo upload ─────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 18, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          'ADD PHOTO',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_imagePath != null) ...[
                  const SizedBox(width: 12),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                        ),
                        child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagePath = null),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: const Color(0xFFFDD400),
                  child: const Text(
                    '+XP',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────
            GestureDetector(
              onTap: _rating == 0 || _isSubmitting ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _rating > 0 && !_isSubmitting
                      ? const Color(0xFF00FC9B)
                      : const Color(0xFFE0E0E0),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: _rating > 0 && !_isSubmitting
                      ? const [BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0)]
                      : null,
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(
                          widget.hasVoted ? 'UPDATE VOTE' : 'SUBMIT VOTE',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: _rating > 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                ),
              ),
            ),

            // ── Remove vote ───────────────────────────────────
            if (widget.hasVoted) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isSubmitting ? null : _removeVote,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'REMOVE VOTE',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (image != null) setState(() => _imagePath = image.path);
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
