import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/util/motion.dart';

/// Tap wrapper that scales down slightly while pressed.
///
/// Thin alias over [Pressable] — the module screens were running their own
/// press curve and duration, which is exactly the kind of drift that makes two
/// halves of one screen feel like two products.
class PressableScale extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  /// What a screen reader announces for this control.
  ///
  /// [Pressable] only emits a `Semantics(button: true)` node when it gets a
  /// label, so a PressableScale without one is not merely unlabelled — it has
  /// no button role at all, and VoiceOver/TalkBack read the child's stray text
  /// fragments with no indication anything is tappable. The module homes are
  /// built almost entirely from these, so leaving it off makes the whole food
  /// and grocery feed unreachable by screen reader.
  ///
  /// Prefer one sentence describing the destination or effect over a
  /// transcription of the card's visible text.
  final String? semanticLabel;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: WaddyMotion.pressCard,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}
