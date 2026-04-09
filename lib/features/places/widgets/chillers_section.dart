import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/styles.dart';

// ── Neubrutalism constants ──
const _kBorderWidth   = 2.0;
const _kBlackBorder   = BorderSide(color: Colors.black, width: _kBorderWidth);
const _kShadowOffset  = Offset(3, 3);
const _kShadow        = BoxShadow(color: Colors.black, offset: _kShadowOffset, blurRadius: 0);
const _kShadowSm      = BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0);

// ── Badge palette ──
const _kGoldBadge   = Color(0xFFFFD600);  // #1 — pure gold
const _kSilverBadge = Color(0xFFB0BEC5);  // #2 — silver-blue
const _kBronzeBadge = Color(0xFFFF6B35);  // #3 — punchy orange-bronze

// ═══════════════════════════════════════════════════════════════════════════
// ChillersSection — Top Voters Leaderboard  (Neubrutalism edition)
// ═══════════════════════════════════════════════════════════════════════════

class ChillersSection extends StatefulWidget {
  const ChillersSection({super.key});

  @override
  State<ChillersSection> createState() => _ChillersSectionState();
}

class _ChillersSectionState extends State<ChillersSection>
    with TickerProviderStateMixin {
  static final List<TopVoter> _mockVoters = [
    TopVoter(id: 2, name: 'Farah',       avatar: 'https://i.pinimg.com/736x/22/7b/b6/227bb6280af3d6c5089ea30445962d82.jpg', votesCount: 1250),
    TopVoter(id: 1, name: 'Hamdies',     avatar: 'https://scontent-hbe1-2.xx.fbcdn.net/v/t39.30808-6/639997509_3138504309680927_4896135208538382839_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=1d70fc&_nc_ohc=UHR1SpCbwhsQ7kNvwGd2qJD&_nc_oc=AdqNjhhhbnltI-Wc5BDU8f4ZZfbnHDQYqznWLTXq49rPtF4NTZfpkN61Cn3VE2y6pmo&_nc_zt=23&_nc_ht=scontent-hbe1-2.xx&_nc_gid=lRnz1WRRbQdnKTk1EQL8Ow&_nc_ss=7a3a8&oh=00_Af0loP3ufsuew8_A-HGZ331i6HCNXwz3wgJVI5dWTlKZJA&oe=69D5F9F9', votesCount: 980),
    TopVoter(id: 3, name: 'Emma Wilson', avatar: 'https://i.pinimg.com/736x/51/73/2c/51732c720c061264fbbcdf4366aed115.jpg', votesCount: 756),
  ];

  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _titleEnter;
  late final Animation<double> _avatar1Enter;
  late final Animation<double> _avatar2Enter;
  late final Animation<double> _avatar3Enter;
  late final Animation<double> _crownDrop;
  late final Animation<double> _rankBarEnter;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _titleEnter = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    _avatar1Enter = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutBack),
    );
    _avatar2Enter = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOutBack),
    );
    _avatar3Enter = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.30, 0.70, curve: Curves.easeOutBack),
    );
    _crownDrop = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.bounceOut),
    );
    _rankBarEnter = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final neon    = theme.secondaryHeaderColor;  // #1EF2A0
    final primary = theme.primaryColor;          // #134E4A

    return GetBuilder<PlacesController>(
      builder: (controller) {
        final topVoters = controller.topVoters;
        final isLoading = controller.isTopVotersLoading;

        if (isLoading) return _buildShimmer(neon, primary);

        final votersToShow = (topVoters != null && topVoters.isNotEmpty)
            ? _mockVoters
            : _mockVoters;

        final first  = votersToShow.isNotEmpty        ? votersToShow[0] : null;
        final second = votersToShow.length > 1        ? votersToShow[1] : null;
        final third  = votersToShow.length > 2        ? votersToShow[2] : null;

        // Current user image
        String? userImage;
        try {
          final pc = Get.find<ProfileController>();
          if (AuthHelper.isLoggedIn() && pc.userInfoModel != null) {
            userImage = pc.userInfoModel!.imageFullUrl;
          }
        } catch (_) {}

        // ── Motivation logic ──
        final userRank  = controller.currentUserRank;
        final userVotes = controller.currentUserVotes ?? 3;
        String rankMotivation;
        double rankProgress;
        bool   showProgress;
        final bool isChampion = userRank == 1;

        String threatLine = '';
        if (userRank == 1) {
          rankMotivation = "YOU'RE #1 — DEFEND!";
          rankProgress   = 1.0;
          showProgress   = false;
          if (second != null) {
            final gap = (userVotes - second.votesCount).clamp(0, 999999);
            threatLine = '${second.name} is only $gap votes behind 👀';
          }
        } else if (userRank == 2 && first != null) {
          final needed   = (first.votesCount - userVotes).clamp(0, 999999);
          rankMotivation = '+$needed VOTES TO #1!';
          rankProgress   = first.votesCount > 0
              ? (userVotes / first.votesCount).clamp(0.0, 1.0)
              : 0.0;
          showProgress   = needed > 0;
          if (third != null) {
            final gap  = (userVotes - third.votesCount).clamp(0, 999999);
            threatLine = '${third.name} is $gap votes behind you 👀';
          }
        } else if (userRank == 3 && second != null) {
          final needed   = (second.votesCount - userVotes).clamp(0, 999999);
          rankMotivation = '+$needed VOTES TO #2!';
          rankProgress   = second.votesCount > 0
              ? (userVotes / second.votesCount).clamp(0.0, 1.0)
              : 0.0;
          showProgress   = needed > 0;
        } else {
          final thirdVotes = third?.votesCount ?? 756;
          final needed     = (thirdVotes - userVotes).clamp(0, 999999);
          rankMotivation   = needed > 0
              ? '+$needed TO CRACK TOP 3!'
              : '${_formatVotesCount(userVotes)} VOTES — YOU\'RE IN!';
          rankProgress = thirdVotes > 0
              ? (userVotes / thirdVotes).clamp(0.0, 1.0)
              : 0.0;
          showProgress = needed > 0;
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_entranceCtrl, _pulseCtrl]),
          builder: (context, _) {
            final pulse = _pulseCtrl.value;

            return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: _kBorderWidth),
                  boxShadow: const [_kShadow],
                ),
                clipBehavior: Clip.none,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Hatched header strip ──
                    _animatedFade(
                      entrance: _titleEnter.value,
                      child: _buildHeader(primary, neon),
                    ),

                    // ── Podium row ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // #2 — Left
                          if (second != null)
                            Expanded(
                              child: _animatedScale(
                                entrance: _avatar2Enter.value,
                                child: _ChillerAvatar(
                                  voter:        second,
                                  rank:         2,
                                  avatarSize:   76,
                                  badgeColor:   _kSilverBadge,
                                  accentColor:  primary,
                                  labelBg:      Colors.white,
                                  columnHeight: 90,
                                ),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),

                          // #1 — Center (taller pedestal)
                          if (first != null)
                            Expanded(
                              child: _animatedScale(
                                entrance: _avatar1Enter.value,
                                child: _ChillerAvatar(
                                  voter:         first,
                                  rank:          1,
                                  avatarSize:    98,
                                  badgeColor:    _kGoldBadge,
                                  accentColor:   primary,
                                  labelBg:       Colors.white,
                                  columnHeight:  120,
                                  showCrown:     true,
                                  crownEntrance: _crownDrop.value,
                                  crownPulse:    pulse,
                                ),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),

                          // #3 — Right
                          if (third != null)
                            Expanded(
                              child: _animatedScale(
                                entrance: _avatar3Enter.value,
                                child: _ChillerAvatar(
                                  voter:        third,
                                  rank:         3,
                                  avatarSize:   76,
                                  badgeColor:   _kBronzeBadge,
                                  accentColor:  primary,
                                  labelBg:      Colors.white,
                                  columnHeight: 90,
                                ),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Rank bar ──
                    _animatedFade(
                      entrance: _rankBarEnter.value,
                      child: _buildRankBar(
                        controller:  controller,
                        userImage:   userImage,
                        motivation:  rankMotivation,
                        threatLine:  threatLine,
                        progress:    rankProgress,
                        showProgress: showProgress,
                        isChampion:  isChampion,
                        primary:     primary,
                        neon:        neon,
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
            );
          },
        );
      },
    );
  }

  // ── Hatched black header strip ──
  Widget _buildHeader(Color primary, Color neon) {
    return Container(
      width: double.infinity,
      color: primary,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neubrutalism accent block
          Container(
            width: 6,
            height: 36,
            color: neon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOP 3 CHILLERS',
                  style: robotoBlack.copyWith(
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Users ranked by how many spots they\'ve voted for this week',
                  style: robotoRegular.copyWith(
                    fontSize: 9,
                    color: Colors.white54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: neon,
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: Text(
              'LEADERBOARD',
              style: robotoBold.copyWith(
                fontSize: 9,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedFade({
    required double entrance,
    required Widget child,
    double slideDistance = 24,
  }) {
    return Opacity(
      opacity: entrance.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, slideDistance * (1 - entrance)),
        child: child,
      ),
    );
  }

  Widget _animatedScale({required double entrance, required Widget child}) {
    return Transform.scale(
      scale: entrance.clamp(0.0, 1.1),
      child: Opacity(
        opacity: entrance.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }

  // ── Rank bar ──
  Widget _buildRankBar({
    required PlacesController controller,
    String? userImage,
    required String motivation,
    String threatLine = '',
    required double progress,
    required bool showProgress,
    required bool isChampion,
    required Color primary,
    required Color neon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: _kBorderWidth),
            boxShadow: const [_kShadowSm],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // User avatar — neubrutalist square frame
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: _kBorderWidth),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: (userImage != null && userImage.isNotEmpty)
                    ? Image.network(
                        userImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _userFallback(primary),
                      )
                    : _userFallback(primary),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: primary,
                          child: Text(
                            '#${controller.currentUserRank ?? '—'}',
                            style: robotoBlack.copyWith(
                              fontSize: 12,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            motivation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: robotoBold.copyWith(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (threatLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          threatLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoRegular.copyWith(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    // Inline progress bar — neubrutalist thick bordered
                    if (showProgress)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.0, 1.0),
                                    child: Container(color: primary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // "View All" neubrutalism button
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary,
                    border: Border.all(color: Colors.black, width: _kBorderWidth),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    'VIEW ALL',
                    style: robotoBlack.copyWith(
                      fontSize: 9,
                      color: Colors.white,
                      letterSpacing: 0.8,
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

  static Widget _userFallback(Color accent) => Container(
        color: accent.withOpacity(0.12),
        child: Center(
          child: Icon(Icons.person, size: 22, color: accent),
        ),
      );

  Widget _buildShimmer(Color neon, Color primary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: neon,
        border: Border.all(color: Colors.black, width: _kBorderWidth),
        boxShadow: const [_kShadow],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 28,
            color: primary.withOpacity(0.25),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _shimmerBlock(76, primary),
              _shimmerBlock(98, primary),
              _shimmerBlock(76, primary),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              border: Border.all(color: Colors.black, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBlock(double size, Color color) => Container(
        width: size,
        height: size,
        color: color.withOpacity(0.18),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// _ChillerAvatar — Neubrutalism avatar card
// ═══════════════════════════════════════════════════════════════════════════

class _ChillerAvatar extends StatelessWidget {
  final TopVoter voter;
  final int      rank;
  final double   avatarSize;
  final Color    badgeColor;
  final Color    accentColor;
  final Color    labelBg;
  final double   columnHeight;
  final bool     showCrown;
  final double   crownEntrance;
  final double   crownPulse;

  const _ChillerAvatar({
    required this.voter,
    required this.rank,
    required this.avatarSize,
    required this.badgeColor,
    required this.accentColor,
    required this.labelBg,
    required this.columnHeight,
    this.showCrown     = false,
    this.crownEntrance = 1.0,
    this.crownPulse    = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Crown
        if (showCrown)
          Opacity(
            opacity: crownEntrance.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -8 * (1 - crownEntrance) + math.sin(crownPulse * math.pi) * 2),
              child: const Text('\u{1F451}', style: TextStyle(fontSize: 24)),
            ),
          )
        else
          const SizedBox(height: 28),

        const SizedBox(height: 4),

        // ── Avatar square with border + hard shadow ──
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width:  avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: _kBorderWidth),
                boxShadow: const [_kShadowSm],
              ),
              child: _buildImage(),
            ),

            // Rank badge — neubrutalist block, pinned bottom-right
            Positioned(
              bottom: -6,
              right:  -6,
              child: Container(
                width:  isFirst ? 30 : 26,
                height: isFirst ? 30 : 26,
                decoration: BoxDecoration(
                  color:  badgeColor,
                  border: Border.all(color: Colors.black, width: _kBorderWidth),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: robotoBlack.copyWith(
                      fontSize: isFirst ? 14 : 12,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Name tag — neubrutalism label chip ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          child: Text(
            '@${voter.name.split(' ').first.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: robotoBold.copyWith(
              fontSize: isFirst ? 11 : 10,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // ── Votes pill ──
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isFirst ? 10 : 7,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: accentColor,
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          child: Text(
            '${_formatVotesCount(voter.votesCount)} VOTES',
            style: robotoBlack.copyWith(
              fontSize: isFirst ? 10 : 8.5,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (voter.avatar == null || voter.avatar!.isEmpty) return _fallback();
    String url = voter.avatar!;
    if (!url.startsWith('http')) {
      url = '${AppConstants.baseUrl}/storage/app/public/profile/$url';
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        color: accentColor.withOpacity(0.15),
        child: Center(
          child: Text(
            voter.name.isNotEmpty ? voter.name[0].toUpperCase() : '?',
            style: robotoBlack.copyWith(
              fontSize: avatarSize * 0.38,
              color: Colors.white,
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper
// ═══════════════════════════════════════════════════════════════════════════

String _formatVotesCount(int count) {
  if (count >= 1000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
  }
  return '$count';
}
