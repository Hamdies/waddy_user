import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/xp_leaderboard_model.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// ─── WADDI XP — Leaderboard ───────────────────────────────────────────────────
/// Native port of Leaderboard.dc.html: a dark deep-teal board with WEEKLY /
/// MONTHLY / LIFETIME season segments, a 2-1-3 podium for the top three, and a
/// ranked standings list (rank · avatar · name · XP · level) with the signed-in
/// user's row highlighted in mint. If the user isn't in the visible top list, a
/// sticky "you" pin shows their real rank at the bottom. All data is live from
/// [XpController.getLeaderboard] — no fabricated rank-movement deltas.
class XpLeaderboardScreen extends StatefulWidget {
  const XpLeaderboardScreen({super.key});

  @override
  State<XpLeaderboardScreen> createState() => _XpLeaderboardScreenState();
}

class _XpLeaderboardScreenState extends State<XpLeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getLeaderboard(reload: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Lb.panel,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            Expanded(
              child: GetBuilder<XpController>(
                id: XpController.idLeaderboard,
                builder: (xp) {
                  final model = xp.leaderboardModel;
                  if (xp.isLeaderboardLoading && model == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: _Lb.mint),
                    );
                  }

                  final entries = model?.entries ?? [];
                  final me = model?.currentUser;
                  final meInList = entries.any((e) => e.isMe);
                  final top3 = entries.take(3).toList();
                  final rest = entries.skip(3).toList();

                  return RefreshIndicator(
                    color: _Lb.mint,
                    backgroundColor: _Lb.panel,
                    onRefresh: () => xp.getLeaderboard(reload: true),
                    child: Column(
                      children: [
                        Expanded(
                          child:
                              entries.isEmpty
                                  ? _EmptyBoard(
                                    onRefresh:
                                        () => xp.getLeaderboard(reload: true),
                                  )
                                  : ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: ClampingScrollPhysics(),
                                        ),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      MediaQuery.of(context).padding.bottom +
                                          24,
                                    ),
                                    children: [
                                      if (top3.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _Podium(top3: top3),
                                      ],
                                      if (rest.isNotEmpty) ...[
                                        const SizedBox(height: 22),
                                        Text(
                                          'STANDINGS',
                                          style: waddyBlack.copyWith(
                                            fontSize: 10,
                                            color: _Lb.onMed,
                                            letterSpacing: 0.1 * 10,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ...rest.map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            child: _StandingRow(entry: e),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                        ),
                        // Sticky "you" pin — only when the user has a rank and
                        // isn't already visible in the list above.
                        if (me != null && me.rank > 0 && !meInList)
                          _MePin(user: me),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME (matches the XP design tokens)
// ─────────────────────────────────────────────────────────────────────────────
class _Lb {
  _Lb._();
  static const Color mint = Color(0xFF1EF2A0);
  static const Color teal = Color(0xFF134E4A);
  static const Color panel = Color(0xFF0E3532);
  static const Color border = Color(0xFF134E4A);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFFF3B30);

  static Color get onMed => Colors.white.withValues(alpha: 0.5);
  static Color get faint => Colors.white.withValues(alpha: 0.4);
  static Color get tileFill => Colors.white.withValues(alpha: 0.06);
  static Color get tileBorder => Colors.white.withValues(alpha: 0.28);
}

String _fmtXp(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${buf.toString()} XP';
}

/// Handle form: "@NAME" — a multi-word display name is shown as-is (uppercased),
/// a single token is prefixed with '@' to read as a handle.
String _handle(String name) {
  final s = name.trim();
  if (s.isEmpty) return '@USER';
  if (s.startsWith('@')) return s.toUpperCase();
  return s.contains(' ') ? s.toUpperCase() : '@${s.toUpperCase()}';
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — kicker/title + season segments + reset note
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(
                    top: 2,
                    right: Dimensions.paddingSizeMedium,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE RACE',
                      style: waddyBlack.copyWith(
                        fontSize: 10,
                        color: _Lb.onMed,
                        letterSpacing: 0.1 * 10,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LEADERBOARD',
                      style: waddyBlack.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SeasonSegments(),
          const SizedBox(height: 8),
          GetBuilder<XpController>(
            id: XpController.idLeaderboard,
            builder:
                (xp) => Text(
                  _resetNote(xp.leaderboardPeriod),
                  style: waddyBold.copyWith(
                    fontSize: 9.5,
                    color: _Lb.faint,
                    height: 1.2,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _resetNote(String period) {
    switch (period) {
      case 'weekly':
        return 'Season resets Monday · lifetime XP never resets';
      case 'monthly':
        return 'Season resets on the 1st · lifetime XP never resets';
      default:
        return 'Lifetime XP never resets';
    }
  }
}

class _SeasonSegments extends StatelessWidget {
  const _SeasonSegments();

  // UI label → controller period key.
  static const _segments = [
    ('WEEKLY', 'weekly'),
    ('MONTHLY', 'monthly'),
    ('LIFETIME', 'alltime'),
  ];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idLeaderboard,
      builder: (xp) {
        final selected = xp.leaderboardPeriod;
        return Row(
          children: [
            for (var i = 0; i < _segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SegmentButton(
                  label: _segments[i].$1,
                  active: _segments[i].$2 == selected,
                  onTap: () => xp.changeLeaderboardPeriod(_segments[i].$2),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _Lb.mint : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active ? _Lb.border : _Lb.tileBorder,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: Text(
          label,
          style: waddyBlack.copyWith(
            fontSize: 10.5,
            color: active ? _Lb.teal : Colors.white.withValues(alpha: 0.6),
            letterSpacing: 0.04 * 10.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PODIUM — 2 · 1 · 3 with graduated stand heights
// ─────────────────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? at(int i) => i < top3.length ? top3[i] : null;
    final first = at(0);
    final second = at(1);
    final third = at(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumCol(entry: second, place: 2)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumCol(entry: first, place: 1)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumCol(entry: third, place: 3)),
      ],
    );
  }
}

class _PodiumCol extends StatelessWidget {
  final LeaderboardEntry? entry;
  final int place;
  const _PodiumCol({required this.entry, required this.place});

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox.shrink();
    final e = entry!;
    final first = place == 1;
    final standHeight =
        first
            ? 56.0
            : place == 2
            ? 40.0
            : 30.0;
    final avatarSize = first ? 52.0 : 44.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(
          image: e.image,
          name: e.name,
          size: avatarSize,
          radius: 9,
          borderColor: first ? _Lb.mint : Colors.white.withValues(alpha: 0.3),
          borderWidth: first ? 2.5 : 2.5,
        ),
        const SizedBox(height: 6),
        Text(
          _handle(e.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyBlack.copyWith(
            fontSize: 10,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _fmtXp(e.totalXp),
          style: waddyBold.copyWith(fontSize: 9, color: _Lb.mint, height: 1),
        ),
        const SizedBox(height: 8),
        // Stand
        Container(
          width: double.infinity,
          height: standHeight,
          decoration: BoxDecoration(
            color:
                first
                    ? _Lb.mint.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.08),
            border: Border(
              top: BorderSide(
                color: first ? _Lb.mint : Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
              left: BorderSide(
                color: first ? _Lb.mint : Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
              right: BorderSide(
                color: first ? _Lb.mint : Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusSmall),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$place',
            style: waddyBlack.copyWith(
              fontSize: 16,
              color: first ? _Lb.mint : Colors.white.withValues(alpha: 0.6),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDING ROW — rank · avatar · name · XP · level
// ─────────────────────────────────────────────────────────────────────────────
class _StandingRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _StandingRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final me = entry.isMe;
    return Container(
      decoration: BoxDecoration(
        color: me ? _Lb.mint.withValues(alpha: 0.1) : _Lb.tileFill,
        border: Border.all(color: me ? _Lb.mint : _Lb.tileBorder, width: 2.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
        vertical: 11,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#${entry.rank}',
              style: waddyBlack.copyWith(
                fontSize: 13,
                color: me ? _Lb.mint : Colors.white.withValues(alpha: 0.55),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(
            image: entry.image,
            name: entry.name,
            size: 30,
            radius: 7,
            borderColor: Colors.white.withValues(alpha: 0.2),
            borderWidth: 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              me ? '${_handle(entry.name)}  ·  YOU' : _handle(entry.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBlack.copyWith(
                fontSize: 12,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _fmtXp(entry.totalXp),
            style: waddyBlack.copyWith(
              fontSize: 11.5,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          // Real rank movement since the user last viewed this board.
          SizedBox(
            width: 36,
            child: _Delta(movement: entry.movement, delta: entry.delta),
          ),
        ],
      ),
    );
  }
}

/// The ▲/▼/HELD/NEW movement chip — mirrors the design's delta column, driven
/// by the server's real per-period rank snapshot.
class _Delta extends StatelessWidget {
  final String movement;
  final int delta;
  const _Delta({required this.movement, required this.delta});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (movement) {
      case 'up':
        label = '▲${delta.abs()}';
        color = _Lb.green;
        break;
      case 'down':
        label = '▼${delta.abs()}';
        color = _Lb.red;
        break;
      case 'held':
        label = 'HELD';
        color = Colors.white.withValues(alpha: 0.35);
        break;
      case 'new':
        label = 'NEW';
        color = _Lb.mint;
        break;
      default:
        label = '';
        color = Colors.transparent;
    }
    return Text(
      label,
      textAlign: TextAlign.right,
      style: waddyBlack.copyWith(fontSize: 10, color: color, height: 1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ME PIN — sticky bottom card with the user's own rank when off-list
// ─────────────────────────────────────────────────────────────────────────────
class _MePin extends StatelessWidget {
  final LeaderboardEntry user;
  const _MePin({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _Lb.mint.withValues(alpha: 0.12),
        border: Border.all(color: _Lb.mint, width: 2.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
        vertical: 11,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#${user.rank}',
              style: waddyBlack.copyWith(
                fontSize: 13,
                color: _Lb.mint,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(
            image: user.image,
            name: user.name,
            size: 30,
            radius: 7,
            borderColor: _Lb.mint,
            borderWidth: 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_handle(user.name)}  ·  YOU',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBlack.copyWith(
                fontSize: 12,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _fmtXp(user.totalXp),
            style: waddyBlack.copyWith(
              fontSize: 11.5,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: _Delta(movement: user.movement, delta: user.delta),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR — rounded-square, real image or monogram
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String? image;
  final String name;
  final double size;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  const _Avatar({
    required this.image,
    required this.name,
    required this.size,
    required this.radius,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final initial = () {
      final s = name.replaceAll('@', '').trim();
      return s.isNotEmpty ? s[0].toUpperCase() : '?';
    }();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _Lb.teal,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child:
          (image != null && image!.isNotEmpty)
              ? CustomImage(
                image: image!,
                fit: BoxFit.cover,
                width: size,
                height: size,
              )
              : Text(
                initial,
                style: waddyBlack.copyWith(
                  fontSize: size * 0.42,
                  color: Colors.white,
                  height: 1,
                ),
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyBoard extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyBoard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(child: Text('🏆', style: TextStyle(fontSize: 44))),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'NO RANKINGS YET',
            style: waddyBlack.copyWith(
              fontSize: 15,
              color: Colors.white,
              letterSpacing: 0.06 * 15,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Earn XP to claim your spot on the board.',
            style: waddyBold.copyWith(
              fontSize: 12,
              color: _Lb.onMed,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
