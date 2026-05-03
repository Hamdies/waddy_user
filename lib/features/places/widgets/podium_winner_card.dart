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

class PodiumWinnerCard extends StatefulWidget {
  final Place place;
  const PodiumWinnerCard({super.key, required this.place});

  @override
  State<PodiumWinnerCard> createState() => _PodiumWinnerCardState();
}

class _PodiumWinnerCardState extends State<PodiumWinnerCard>
    with TickerProviderStateMixin {
  // Local voted state — optimistic update on tap
  bool _hasVoted = false;

  // Vote button bounce
  late final AnimationController _voteCtrl;
  late final Animation<double>   _voteScale;

  // Crown gentle pulse (looping)
  late final AnimationController _crownCtrl;
  late final Animation<double>  _crownScale;

  // Local state for optimistic update
  int _localVotesCount = 0;

  @override
  void initState() {
    super.initState();
    _localVotesCount = widget.place.votesCount;

    _voteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _voteScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.91), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.91, end: 1.08), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _voteCtrl, curve: Curves.easeOut));

    _crownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _crownScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _crownCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _voteCtrl.dispose();
    _crownCtrl.dispose();
    super.dispose();
  }

  void _onVote() {
    if (!AuthHelper.isLoggedIn()) return;
    if (_hasVoted) return;
    HapticFeedback.lightImpact();
    
    setState(() {
      _hasVoted = true;
      _localVotesCount += 1;
    });

    _voteCtrl.forward(from: 0);
    Get.find<PlacesController>().submitVote(widget.place.id, 5);
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  static int _heatScore(Place p) {
    final r = p.rating > 0 ? (p.rating / 5) * 76 : 46.0;
    final v = math.min(p.votesCount, 20) / 20 * 24;
    return (r + v).round().clamp(22, 99);
  }

  // Prefer cover image for full-bleed hero.
  static String _heroImage(Place p) {
    if (p.coverImage != null && p.coverImage!.trim().isNotEmpty) {
      return p.coverImage!;
    }
    // Only use coverImage, otherwise fallback to styled placeholder
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final neon    = Theme.of(context).secondaryHeaderColor;
    final primary = Theme.of(context).primaryColor;
    final place   = widget.place;
    final heat    = _heatScore(place);
    final imgUrl  = _heroImage(place);

    return GestureDetector(
      onTap: () => Get.toNamed(RouteHelper.getPlaceDetailsRoute(place.id)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // ── Main card ──
          Container(
            height: 290,
            decoration: BoxDecoration(
              border:    Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [

                  // ── Hero image or styled placeholder ──
                  imgUrl.isNotEmpty
                      ? CustomImage(image: imgUrl, fit: BoxFit.cover)
                      : _WinnerPlaceholder(title: place.title, neon: neon, primary: primary),

                  // ── Deeper gradient so text pops ──
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin:  Alignment.topCenter,
                        end:    Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x33000000),  // 20% black at mid
                          Color(0xE8000000),  // 91% black at bottom
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // ── Bottom content block ──
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          // ── Title — bigger, more presence ──
                          if (place.categoryName != null)
                            Text(
                              place.categoryName!.toUpperCase(),
                              style: robotoBlack.copyWith(
                                fontSize:      14,
                                color:         Colors.white70,
                                letterSpacing: 1.0,
                              ),
                            ),
                          const SizedBox(height: 1),
                          Text(
                            place.title.toUpperCase(),
                            style: robotoBlack.copyWith(
                              fontSize:      28,
                              color:         Colors.white,
                              height:        1.0,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // ── Winner Details List ──
                          Row(
                            children: [
                              Text(
                                _localVotesCount > 0
                                    ? '🔥 Top voted this week'
                                    : '✨ Be first to vote',
                                style: robotoBold.copyWith(
                                  fontSize: 12,
                                  color:    neon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _localVotesCount > 0
                                ? '$heat% positive · $_localVotesCount ${_localVotesCount == 1 ? 'vote' : 'votes'}'
                                : '$heat% positive',
                            style: robotoMedium.copyWith(
                              fontSize: 12,
                              color:    Colors.white70,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── View place link ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'VIEW PLACE →',
                                style: robotoMedium.copyWith(
                                  fontSize:      10,
                                  color:         Colors.white54,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // ── Votes pill + CTA row ──
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _hasVoted ? null : _onVote,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _hasVoted
                                          ? Colors.white
                                          : neon,
                                      border: Border.all(
                                          color: Colors.black, width: 2),
                                      boxShadow: _hasVoted
                                          ? null
                                          : const [
                                              BoxShadow(color: Colors.black,
                                                  offset: Offset(2, 2), blurRadius: 0),
                                            ],
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ScaleTransition(
                                            scale: _voteScale,
                                            child: Icon(
                                              _hasVoted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              color: _hasVoted ? Colors.black54 : Colors.red,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _hasVoted ? 'VOTED ✓' : 'ADD VOTE',
                                            style: robotoBlack.copyWith(
                                              fontSize:      14,
                                              color:         _hasVoted
                                                  ? Colors.black54
                                                  : Colors.black,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 👑 Crown sticker — bouncing pulse ──
          Positioned(
            top:  14,
            left: -4,
            child: Transform.rotate(
              angle: -0.06,
              child: ScaleTransition(
                scale: _crownScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color:  const Color(0xFFFFD600),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black,
                          offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    '👑 WINNER\n   OF THE WEEK',
                    style: robotoBlack.copyWith(
                      fontSize: 10,
                      color:    Colors.black,
                      height:   1.3,
                    ),
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

// ─── Styled placeholder when no image is available ────────────────────────────
class _WinnerPlaceholder extends StatelessWidget {
  final String title;
  final Color  neon;
  final Color  primary;

  const _WinnerPlaceholder({
    required this.title,
    required this.neon,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final initials = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, 0.45)!],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: robotoBlack.copyWith(
            fontSize:      80,
            color:         neon.withValues(alpha: 0.25),
            letterSpacing: 4,
            height:        1,
          ),
        ),
      ),
    );
  }
}
