part of '../xp_levels_screen.dart';

// Shared building blocks: section header, dark tile, empty tile.

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────
/// Kicker + title, with an optional trailing action.
///
/// Not `SpotsSectionHeader`: that one is built for the light Places canvas
/// (`Spots.ink` on paper) and this surface is the dark foil. The structure and
/// the directional arrow rule are deliberately the same.
class _SectionHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.kicker,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // The arrow is not mirrored by the framework — it has to be chosen.
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayCaps(kicker),
          style: waddyBlack.copyWith(
            fontSize: 9.5,
            color: _Xp.onDarkFaint,
            letterSpacing: displayTracking(0.1 * 9.5),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: waddyBlack.copyWith(
            fontSize: 15,
            color: Colors.white,
            height: 1,
          ),
        ),
      ],
    );

    if (actionLabel == null || onAction == null) return heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        Pressable(
          semanticLabel: actionLabel!,
          minSize: Dimensions.minTapTarget,
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Dimensions.paddingSizeSmall,
            ),
            child: Text(
              '${displayCaps(actionLabel!)} ${isLtr ? '→' : '←'}',
              style: waddyBlack.copyWith(
                fontSize: 11,
                color: _Xp.mint,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A secondary surface on the foil canvas. Deliberately *lighter* than the
/// hero (fill-forward, hairline edge) so the hero stays the one heavily-framed
/// object and these read as content, not competing outlined cards.
class _DarkTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Slightly raised presence for tappable tiles (challenge/reward) so they
  /// still afford interaction without shouting like the hero.
  final bool interactive;
  const _DarkTile({
    required this.child,
    required this.padding,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _Xp.overlay(interactive ? 0.07 : 0.05),
        border: Border.all(
          color: _Xp.overlay(interactive ? 0.16 : 0.10),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(_Xp.rMd),
      ),
      child: child,
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String emoji;
  final String text;
  const _EmptyTile({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return _DarkTile(
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: waddyBold.copyWith(
                fontSize: 12,
                color: _Xp.onDarkMed,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
