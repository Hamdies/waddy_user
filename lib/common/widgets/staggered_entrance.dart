import 'package:flutter/material.dart';
import 'package:waddy_app/util/motion.dart';

/// One arrival language for the feed: a short rise into a fade, cascaded
/// across neighbours.
///
/// This lives here rather than beside any one rail because cohesion is the
/// whole argument. The home fold's two largest objects used to arrive in two
/// different vocabularies — the module tiles crossfaded in as a single slab
/// while the store rail cascaded card by card — so the screen assembled itself
/// in two voices. Nobody names that; they just find the screen slightly harder
/// to settle into.
///
/// Only the first [WaddyMotion.maxStaggered] children animate. Anything past
/// the first screenful is built lazily *during scroll*, and an entrance fired
/// then reads as the list failing to keep up rather than as polish.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  /// Travel distance as a fraction of the child's own height. Fractional
  /// rather than a fixed offset so the move stays in proportion on a 132pt
  /// card and a 176pt one, instead of reading as a bigger jump on the small
  /// phone where there is least room for it.
  final double rise;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.rise = 0.06,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  bool get _staggers => widget.index < WaddyMotion.maxStaggered;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: WaddyMotion.reveal,
      // Children outside the first screenful start already arrived.
      value: _staggers ? 0.0 : 1.0,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: WaddyMotion.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.rise),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: WaddyMotion.easeOut));

    if (_staggers) {
      Future.delayed(WaddyMotion.stagger * widget.index, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion keeps the fade — it explains that content arrived — and
    // drops the travel, which is the part that causes trouble.
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: _opacity, child: widget.child);
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
