import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/widgets/games/game_shared_widgets.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/util/styles.dart';

const Color _kGold = Color(0xFFFFB100);

class VotePlaceGameSlide extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDotTap;

  const VotePlaceGameSlide({
    super.key,
    required this.currentIndex,
    required this.onDotTap,
  });

  @override
  State<VotePlaceGameSlide> createState() => _VotePlaceGameSlideState();
}

class _VotePlaceGameSlideState extends State<VotePlaceGameSlide>
    with SingleTickerProviderStateMixin {
  bool _controllerAvailable = false;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _controllerAvailable = Get.isRegistered<PlacesController>();
    if (_controllerAvailable) {
      final c = Get.find<PlacesController>();
      if (c.leaderboard == null || c.leaderboard!.isEmpty) {
        c.getLeaderboard(limit: 3);
      }
      // Ensure places are available as fallback when leaderboard is empty
      if (c.places == null || c.places!.isEmpty) {
        c.getPlaces(reload: false);
      }
    }
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary,
              mixColor(primary, Colors.black, 0.22),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _VoteBackdropPainter(accent: accent),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Banner ──
                LuckySpinBanner(
                  label: 'vote_for_best_place'.tr.toUpperCase(),
                  primaryColor: primary,
                  accentColor: accent,
                ),
                const SizedBox(height: 4),

                Text(
                  'pick_your_favorite_earn_xp'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),

                // ── Social proof badge ──
                _buildSocialProofBadge(accent),
                const SizedBox(height: 8),

                // ── Place cards ──
                Expanded(child: _buildPlaceCards(primary, accent)),
                const SizedBox(height: 8),

                // ── CTA ──
                ShowcaseCta(
                  label: 'see_all_places'.tr.toUpperCase(),
                  icon: Icons.explore_rounded,
                  backgroundColor: accent,
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  onTap: () {
                    Get.back();
                  },
                ),
                const SizedBox(height: 10),

                // ── Dots ──
                SlideDots(
                  currentIndex: widget.currentIndex,
                  onDotTap: widget.onDotTap,
                  activeColor: accent,
                  inactiveColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialProofBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            'trending_places_near_you'.tr,
            style: robotoMedium.copyWith(
              fontSize: 10,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCards(Color primary, Color accent) {
    if (!_controllerAvailable) {
      return _buildSkeletonCards(primary, accent);
    }

    return GetBuilder<PlacesController>(
      builder: (controller) {
        final leaderboard = controller.leaderboard;
        final fallbackPlaces = controller.places;
        final places = (leaderboard != null && leaderboard.isNotEmpty)
            ? leaderboard
            : fallbackPlaces;

        if (controller.isLeaderboardLoading && controller.isPlacesLoading) {
          return _buildShimmerCards(primary, accent);
        }

        if (places == null || places.isEmpty) {
          return _buildSkeletonCards(primary, accent);
        }

        final displayPlaces = places.take(3).toList();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(displayPlaces.length, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 6 : 0),
              child: _VotePlaceCard(
                place: displayPlaces[index],
                rank: index + 1,
                primary: primary,
                accent: accent,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildShimmerCards(Color primary, Color accent) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 6 : 0),
              child: _buildSingleShimmerCard(primary, accent),
            );
          }),
        );
      },
    );
  }

  Widget _buildSingleShimmerCard(Color primary, Color accent) {
    return Container(
      width: 96,
      height: 138,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_shimmerController.value * 3 - 1, 0),
              end: Alignment(_shimmerController.value * 3, 0),
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Column(
            children: [
              // Image placeholder
              Container(
                height: 50,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 8),
              // Title placeholder
              Container(
                height: 10,
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 6),
              // Votes placeholder
              Container(
                height: 8,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              // Stars placeholder
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      Icons.star_outline_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Skeleton fallback — shows blurred/ghost preview cards when no data
  Widget _buildSkeletonCards(Color primary, Color accent) {
    final fakeNames = ['Top Pick', 'Local Gem', 'Fan Fave'];
    final fakeVotes = [142, 98, 67];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index > 0 ? 6 : 0),
          child: Container(
            width: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ghost image area
                Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.place_rounded,
                          color: accent.withValues(alpha: 0.25),
                          size: 28,
                        ),
                      ),
                      // Rank badge
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _rankColor(index + 1)
                                .withValues(alpha: 0.7),
                          ),
                          child: Center(
                            child: Text(
                              '#${index + 1}',
                              style: robotoBold.copyWith(
                                fontSize: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                  child: Column(
                    children: [
                      Text(
                        fakeNames[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: robotoBold.copyWith(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${fakeVotes[index]} ${'votes'.tr}',
                          style: robotoMedium.copyWith(
                            fontSize: 9,
                            color: accent.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Greyed-out stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1),
                            child: Icon(
                              i < (3 - index)
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: i < (3 - index)
                                  ? _kGold.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '+10 XP',
                        style: robotoBold.copyWith(
                          fontSize: 8,
                          color: _kGold.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return _kGold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}

// ─── Individual place card ───────────────────────────────────────────────
class _VotePlaceCard extends StatefulWidget {
  final Place place;
  final int rank;
  final Color primary;
  final Color accent;

  const _VotePlaceCard({
    required this.place,
    required this.rank,
    required this.primary,
    required this.accent,
  });

  @override
  State<_VotePlaceCard> createState() => _VotePlaceCardState();
}

class _VotePlaceCardState extends State<_VotePlaceCard>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  bool _voted = false;
  bool _showCheck = false;
  late final AnimationController _voteAnimController;

  @override
  void initState() {
    super.initState();
    _voteAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _voteAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: mixColor(widget.primary, Colors.white, 0.08),
        border: Border.all(
          color: _voted
              ? widget.accent.withValues(alpha: 0.5)
              : widget.accent.withValues(alpha: 0.28),
          width: _voted ? 1.5 : 1,
        ),
        boxShadow: [
          if (_voted)
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image ──
          SizedBox(
            height: 50,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.place.image != null
                    ? CustomImage(
                        image: widget.place.image!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: widget.primary.withValues(alpha: 0.3),
                        child: Icon(Icons.place_rounded,
                            color: widget.accent.withValues(alpha: 0.5),
                            size: 28),
                      ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          widget.primary.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Rank badge
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _rankColor(widget.rank),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: _rankColor(widget.rank).withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '#${widget.rank}',
                        style: robotoBold.copyWith(
                            fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                // Checkmark overlay
                if (_showCheck)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showCheck ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        color: widget.accent.withValues(alpha: 0.7),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
            child: Column(
              children: [
                // Title
                Text(
                  widget.place.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: robotoBold.copyWith(
                      fontSize: 10, color: Colors.white),
                ),
                const SizedBox(height: 3),

                // Votes pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.place.votesCount} ${'votes'.tr}',
                    style: robotoMedium.copyWith(
                      fontSize: 9,
                      color: widget.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Star row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    final filled = starIndex <= _selectedRating;
                    return GestureDetector(
                      onTap: () => _onStarTap(starIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: filled
                              ? _kGold
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    );
                  }),
                ),

                // XP hint
                const SizedBox(height: 3),
                Text(
                  '+10 XP',
                  style: robotoBold.copyWith(
                    fontSize: 8,
                    color: _kGold.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onStarTap(int rating) {
    if (_voted && _selectedRating == rating) return;

    HapticFeedback.lightImpact();
    setState(() {
      _selectedRating = rating;
      _voted = true;
      _showCheck = true;
    });

    // Submit vote
    if (Get.isRegistered<PlacesController>()) {
      Get.find<PlacesController>().submitVote(widget.place.id, rating);
    }

    // Hide check after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return _kGold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}

// ─── Background painter: subtle dot grid ─────────────────────────────────
class _VoteBackdropPainter extends CustomPainter {
  final Color accent;

  _VoteBackdropPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: 0.04);
    const double spacing = 28;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
