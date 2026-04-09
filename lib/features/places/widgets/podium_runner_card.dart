import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';

/// Medium card for 2nd and 3rd place.
/// Shows image, rank badge, name, category/zone, vibe bar, vote button.
class PodiumRunnerCard extends StatefulWidget {
  final Place  place;
  final int    rank;
  final int    winnerVotesCount;
  final bool   isLast;
  final double imageAspectRatio;

  const PodiumRunnerCard({
    super.key,
    required this.place,
    required this.rank,
    required this.winnerVotesCount,
    this.isLast           = false,
    this.imageAspectRatio = 1.2,
  });

  @override
  State<PodiumRunnerCard> createState() => _PodiumRunnerCardState();
}

class _PodiumRunnerCardState extends State<PodiumRunnerCard>
    with SingleTickerProviderStateMixin {
  bool _hasVoted = false;

  late final AnimationController _voteCtrl;
  late final Animation<double>   _voteScale;

  @override
  void initState() {
    super.initState();
    _voteCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _voteScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.91), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.91, end: 1.08), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _voteCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _voteCtrl.dispose();
    super.dispose();
  }

  void _onVote() {
    if (!AuthHelper.isLoggedIn()) return;
    if (_hasVoted) return;
    HapticFeedback.lightImpact();
    setState(() => _hasVoted = true);
    _voteCtrl.forward(from: 0);
    Get.find<PlacesController>().submitVote(widget.place.id, 5);
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  static int _heat(Place p) {
    final r = p.rating > 0 ? (p.rating / 5) * 76 : 46.0;
    final v = math.min(p.votesCount, 20) / 20 * 24;
    return (r + v).round().clamp(22, 99);
  }

  static String? _heroImage(Place p) {
    if (p.coverImage != null && p.coverImage!.trim().isNotEmpty) {
      return p.coverImage!;
    }
    return null;
  }

  static String _subtitle(Place p) {
    final parts = <String>[
      if (p.categoryName?.trim().isNotEmpty ?? false) p.categoryName!.trim(),
      if (p.zone?.displayName?.trim().isNotEmpty ?? false)
        p.zone!.displayName!.trim(),
    ];
    final seen = <String>{};
    final unique = parts.where((s) {
      final k = s.toLowerCase();
      return seen.add(k);
    }).take(2).toList();
    return unique.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final neon    = Theme.of(context).secondaryHeaderColor;
    final primary = Theme.of(context).primaryColor;
    final place   = widget.place;
    final heat    = _heat(place);
    final subtitle = _subtitle(place);

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getPlaceDetailsRoute(place.id)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color:  Colors.white,
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Image ──
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: widget.imageAspectRatio,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                        ),
                        child: _heroImage(place) != null
                            ? CustomImage(
                                image: _heroImage(place)!,
                                fit: BoxFit.cover,
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color.lerp(neon, Colors.white, 0.72)!,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.storefront_rounded, size: 20, color: primary),
                                      const SizedBox(height: 3),
                                      Text(
                                        place.title.isNotEmpty ? place.title[0].toUpperCase() : '?',
                                        style: robotoBlack.copyWith(
                                          fontSize:      12,
                                          letterSpacing: 0.5,
                                          color:         primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    // ── Logo Badge ──
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        width:  34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:     Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:    Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6.5),
                          child: place.image != null && place.image!.isNotEmpty
                              ? CustomImage(image: place.image!, fit: BoxFit.cover)
                              : Icon(Icons.storefront_rounded, color: primary, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Info block ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Name
                      Text(
                        place.title.toUpperCase(),
                        style: robotoBlack.copyWith(
                          fontSize:      12,
                          color:         Colors.black,
                          letterSpacing: 0.2,
                          height:        1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Category · Zone
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: robotoRegular.copyWith(
                            fontSize: 8.5,
                            color:    Colors.black54,
                            height:   1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Vibe bar (removed vibe text layout)
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color:  Colors.black.withValues(alpha: 0.07),
                          border: Border.all(color: Colors.black, width: 0.8),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: (heat / 100.0).clamp(0.0, 1.0),
                          alignment:   Alignment.centerLeft,
                          child: Container(color: neon),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Vote button — full width
                      GestureDetector(
                        onTap: _onVote,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 28,
                          decoration: BoxDecoration(
                            color: _hasVoted ? Colors.white : neon,
                            border: Border.all(color: Colors.black, width: 1.2),
                            boxShadow: _hasVoted
                                ? null
                                : const [
                                    BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 0),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: _voteScale,
                                child: Icon(
                                  _hasVoted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size:  12,
                                  color: _hasVoted ? primary : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _hasVoted
                                    ? 'VOTED ✓'
                                    : '${_fmt(place.votesCount)} vote${place.votesCount == 1 ? '' : 's'}',
                                style: robotoBlack.copyWith(
                                  fontSize: 9,
                                  color:    _hasVoted ? Colors.black45 : Colors.black,
                                  height:   1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rank sticker — top-right corner ──
          Positioned(
            top: -4,
            right: -6,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                  ],
                ),
                child: Text(
                  '#${widget.rank}',
                  style: robotoBlack.copyWith(
                    fontSize: 11,
                    color:    Colors.black,
                    height:   1,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
