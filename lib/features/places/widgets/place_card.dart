import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/places/domain/models/place_model.dart';
import 'package:waddy_app/util/styles.dart';

// ── Neubrutalism constants ──
// Border hierarchy: card=1.5, button=1.0, pill=1.0
const _kBorderCard   = 1.5;   // card outer frame
const _kBorderBtn    = 1.0;   // buttons & pills
const _kBorder       = _kBorderCard; // default alias kept for compatibility
const _kBlack        = Colors.black;
const _kShadowSm     = BoxShadow(color: _kBlack, offset: Offset(2, 2), blurRadius: 2);

Color _brandInk(ThemeData t)    => t.primaryColor;
Color _brandAccent(ThemeData t) => t.secondaryHeaderColor;

// ═══════════════════════════════════════════════════════════════════════════
// PlaceCard
// ═══════════════════════════════════════════════════════════════════════════

class PlaceCard extends StatefulWidget {
  final Place place;
  final VoidCallback? onTap;
  final bool showFavorite;
  final int index;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
    this.showFavorite = true,
    this.index = 0,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnim  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 68), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (!mounted || _isPressed == v) return;
    setState(() => _isPressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme   = Theme.of(context);
    final Place    place    = widget.place;
    final Color   accent   = _brandAccent(theme);
    final Color   brand    = _brandInk(theme);
    final String? heroImg  = _heroImage(place);
    final String? logoImg  = _pinLogoImage(place);
    final String  subtitle = _subtitleLine(place);
    final String  sticker  = _placeSticker(place);

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown:    (_) => _setPressed(true),
          onTapUp:      (_) => _setPressed(false),
          onTapCancel:  ()  => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve:    Curves.easeOut,
            margin:   const EdgeInsets.only(top: 8, bottom: 4),
            // Neubrutalism press: translate into shadow
            transform: Matrix4.identity()
              ..translateByDouble(
                _isPressed ? 2.0 : 0.0,
                _isPressed ? 2.0 : 0.0,
                0.0, 1.0,
              ),
            decoration: BoxDecoration(
              color:  Colors.white,
              border: Border.all(color: _kBlack, width: _kBorder),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.65),
                  offset:     _isPressed ? const Offset(1, 1) : const Offset(3, 3),
                  blurRadius: _isPressed ? 0 : 3,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroImage(
                    image:     heroImg,
                    logoImage: logoImg,
                    title:     place.title,
                    accent:    accent,
                    brand:     brand,
                    sticker:   sticker,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title + vote pill aligned in the same row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TitleSection(
                                title:    place.title,
                                subtitle: subtitle,
                                brand:    brand,
                              ),
                            ),
                            if (widget.showFavorite) ...[
                              const SizedBox(width: 4),
                              _VotePill(
                                count:  place.votesCount,
                                accent: accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _VibeLine(
                          heat:   _heatScore(place),
                          votes:  place.votesCount,
                          brand:  brand,
                          accent: accent,
                        ),
                        const SizedBox(height: 8),
                        _ExploreButton(brand: brand, accent: accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _HeroImage
// ═══════════════════════════════════════════════════════════════════════════

class _HeroImage extends StatelessWidget {
  final String?  image;
  final String?  logoImage;
  final String   title;
  final Color    accent;
  final Color    brand;
  final String   sticker;

  const _HeroImage({
    required this.image,
    required this.logoImage,
    required this.title,
    required this.accent,
    required this.brand,
    required this.sticker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   160,
      height:  136,
      decoration: BoxDecoration(
        border: Border.all(color: _kBlack, width: _kBorder),
        boxShadow: const [_kShadowSm],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            CustomImage(image: image!, fit: BoxFit.cover)
          else
            _HeroFallback(title: title, accent: accent, brand: brand),

          // ── Logo badge — bottom-right, square, hard shadow ──
          Positioned(
            bottom: 5,
            right:  5,
            child: Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color:     Colors.white,
                border:    Border.all(color: _kBlack, width: 2),
                boxShadow: const [_kShadowSm],
              ),
              child: logoImage != null
                  ? CustomImage(image: logoImage!, fit: BoxFit.cover)
                  : Icon(Icons.storefront_rounded, color: brand, size: 18),
            ),
          ),

          // ── Fun sticker — top-left, always shown, slightly rotated ──
          Positioned(
            top:  6,
            left: -2,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color:     accent,
                  border:    Border.all(color: _kBlack, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: _kBlack, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Text(
                  sticker,
                  textAlign: TextAlign.center,
                  style: robotoBlack.copyWith(
                    fontSize:      7.5,
                    color:         _kBlack,
                    letterSpacing: 0.3,
                    height:        1.25,
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

// ═══════════════════════════════════════════════════════════════════════════
// _HeroFallback
// ═══════════════════════════════════════════════════════════════════════════

class _HeroFallback extends StatelessWidget {
  final String title;
  final Color  accent;
  final Color  brand;

  const _HeroFallback({
    required this.title,
    required this.accent,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(accent, Colors.white, 0.72)!,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 28, color: brand),
            const SizedBox(height: 5),
            Text(
              _initials(title),
              style: robotoBlack.copyWith(
                fontSize:      15,
                letterSpacing: 0.7,
                color:         brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TitleSection — title + subtitle + open badge
// ═══════════════════════════════════════════════════════════════════════════

class _TitleSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color  brand;

  const _TitleSection({
    required this.title,
    required this.subtitle,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          maxLines:  1,
          overflow:  TextOverflow.ellipsis,
          style: robotoBlack.copyWith(
            fontSize:      17,
            height:        1,
            letterSpacing: 0.35,
            color:         brand,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
            style: robotoMedium.copyWith(
              fontSize: 10.5,
              height:   1.2,
              color:    brand.withValues(alpha: 0.65),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _VotePill — compact heart + count badge shown top-right of content
// ═══════════════════════════════════════════════════════════════════════════

class _VotePill extends StatelessWidget {
  final int   count;
  final Color accent;

  const _VotePill({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color:     accent,
        border:    Border.all(color: _kBlack, width: _kBorderBtn),
        boxShadow: const [
          BoxShadow(color: _kBlack, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, size: 10, color: _kBlack),
          const SizedBox(width: 3),
          Text(
            _formatCount(count),
            style: robotoBlack.copyWith(fontSize: 10, color: _kBlack, height: 1),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _VibeLine — thin progress bar
// ═══════════════════════════════════════════════════════════════════════════

class _VibeLine extends StatelessWidget {
  final int   heat;
  final int   votes;
  final Color brand;
  final Color accent;

  const _VibeLine({
    required this.heat,
    required this.votes,
    required this.brand,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (heat / 100.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin neubrutalism progress bar — animates in on mount
        TweenAnimationBuilder<double>(
          tween:    Tween(begin: 0.0, end: pct),
          duration: const Duration(milliseconds: 700),
          curve:    Curves.easeOutCubic,
          builder: (_, value, __) => Container(
            height: 5,
            decoration: BoxDecoration(
              color:  brand.withValues(alpha: 0.08),
              border: Border.all(color: _kBlack, width: 1),
            ),
            child: FractionallySizedBox(
              widthFactor: value,
              alignment:   Alignment.centerLeft,
              child:       Container(color: accent),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(Icons.favorite_rounded, size: 10,
                color: brand.withValues(alpha: 0.45)),
            const SizedBox(width: 3),
            Text(
              '${_formatCount(votes)} ${votes == 1 ? 'vote' : 'votes'}',
              style: robotoRegular.copyWith(
                fontSize: 10.5,
                color:    brand.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ExploreButton — full-width primary CTA (neon accent)
// ═══════════════════════════════════════════════════════════════════════════

class _ExploreButton extends StatelessWidget {
  final Color brand;
  final Color accent;

  const _ExploreButton({required this.brand, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color:     accent,
        border:    Border.all(color: _kBlack, width: _kBorderBtn),
        boxShadow: const [_kShadowSm],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_forward_rounded, size: 13, color: _kBlack),
          const SizedBox(width: 5),
          Text(
            'EXPLORE',
            style: robotoBlack.copyWith(
              fontSize:      10,
              color:         _kBlack,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Internal models & helpers
// ═══════════════════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════════════
// Internal models & helpers  (unchanged logic)
// ═══════════════════════════════════════════════════════════════════════════

// Fun sticker assigned deterministically from place id
String _placeSticker(Place place) {
  if (place.rank == 1) return '🏆 WINNER';
  const options = [
    '☕ BEST\nCOFFEE', '💎 HIDDEN\nGEM',  '✨ MUST\nVISIT',
    '🌟 LOCAL\nFAV',   '🔥 HOT\nSPOT',   '🎯 GOOD\nVIBES',
    '🌙 NIGHT\nSPOT',  '🎨 ARTSY',        '🍃 CHILL\nZONE',
    '⚡ HYPED',
  ];
  return options[place.id % options.length];
}

String _subtitleLine(Place place) {
  final parts = <String>[
    if (place.categoryName?.trim().isNotEmpty ?? false) place.categoryName!.trim(),
    if (place.zone?.displayName?.trim().isNotEmpty ?? false)
      place.zone!.displayName!.trim(),
    if ((place.address?.trim().isNotEmpty ?? false) &&
        (place.zone?.displayName?.trim().isNotEmpty != true))
      place.address!.trim(),
  ];
  final unique = _uniqueStrings(parts);
  if (unique.isNotEmpty) return unique.take(2).join(' • ');
  final desc = place.description?.trim() ?? '';
  if (desc.isNotEmpty && desc.toLowerCase() != place.title.trim().toLowerCase()) {
    return desc;
  }
  return '';
}


List<String> _uniqueStrings(List<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final v = raw.trim();
    final k = v.toLowerCase();
    if (v.isEmpty || seen.contains(k)) continue;
    seen.add(k);
    result.add(v);
  }
  return result;
}

int _heatScore(Place place) {
  final r = place.rating > 0 ? (place.rating / 5) * 76 : 46.0;
  final v = math.min(place.votesCount, 20) / 20 * 24;
  return (r + v).round().clamp(22, 99);
}

String? _heroImage(Place place) {
  // Only use coverImage or gallery photos, skip `place.image` (which is the logo)
  for (final c in <String?>[
    place.coverImage,
    if (place.gallery != null) ...place.gallery!.map((i) => i.image),
  ]) {
    final v = c?.trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return null;
}

String? _pinLogoImage(Place place) {
  for (final c in <String?>[place.image, place.coverImage]) {
    final v = c?.trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return null;
}

String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
  }
  return '$count';
}

String _initials(String title) {
  final parts = title.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).toList();
  if (parts.isEmpty) return 'WP';
  return parts.map((p) => p.substring(0, 1).toUpperCase()).join();
}
