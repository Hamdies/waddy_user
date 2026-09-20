import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/common/widgets/spots/spots_theme.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/util/styles.dart';

/// The organic growth loop: every winner becomes a small ad.
///
/// The code is deliberately NOT on this card — the image is meant to be
/// posted publicly, and a visible code is a code someone else can burn.
class SpotsWinCard extends StatelessWidget {
  const SpotsWinCard({super.key, required this.prize, this.winnerName});

  final PlacePrize prize;

  /// The winner's display name for the byline. Omitted when the profile has
  /// no name — an empty "Claimed by" line reads as a bug on a public post.
  final String? winnerName;

  /// 4:5 portrait — captured at 3× it lands at 1080×1350, Stories-native.
  static const double width = 320;
  static const double height = 400;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Spots.panel,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'WADDY',
                      style: waddyBlack.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SPOTS',
                      style: waddyBlack.copyWith(
                        fontSize: 22,
                        color: Spots.mint,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Transform.rotate(
                      angle: -9 * 3.1415926535 / 180,
                      child: Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.bottomRight,
                        child: CustomPaint(
                          painter: const _DashedCirclePainter(),
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: Center(
                              child: Image.asset(
                                'assets/image/waddy.png',
                                width: 50,
                                height: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Dashed mint seal, tilted — the "certified" beat that makes
                // the card read as an award rather than a receipt.
                const SizedBox(height: Spots.s16),
                Text(
                  displayCaps('spots_win_card_kicker'.tr),
                  style: Spots.kicker(11, color: Spots.mint, tracking: 0.1),
                ),
                const SizedBox(height: Spots.s8),
                Text(
                  displayCaps('spots_win_card_headline'.tr),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBlack.copyWith(
                    fontSize: 27,
                    color: Colors.white,
                    height: 1.08,
                    letterSpacing: displayTracking(-0.01 * 27),
                  ),
                ),
                const SizedBox(height: Spots.s12),
                if (winnerName != null && winnerName!.isNotEmpty) ...[
                  const SizedBox(height: Spots.s8 + 2),
                  Text.rich(
                    TextSpan(
                      text: '${'spots_win_card_claimed_by'.tr} ',
                      style: waddyBold.copyWith(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: winnerName,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            color: Spots.mint,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                // Venue plate
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spots.s16,
                    vertical: Spots.s12 + 2,
                  ),
                  // The template's .atbox is a flat mint plate — no border, no
                  // lift. It sits on the panel, so it needs neither.
                  decoration: BoxDecoration(
                    color: Spots.mint,
                    borderRadius: BorderRadius.circular(Spots.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayCaps('spots_win_card_at'.tr),
                        style: Spots.kicker(
                          10,
                          color: Spots.teal.withValues(alpha: 0.75),
                          tracking: 0.08,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prize.placeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBlack.copyWith(
                          fontSize: 19,
                          color: Spots.teal,
                          height: 1.05,
                          letterSpacing: displayTracking(-0.01 * 19),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  'spots_win_card_footer'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The template's `2.5px dashed` mint ring around the winner stamp. Flutter
/// has no dashed border, so the ring is stroked arc by arc.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Spots.mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.butt;

    final radius = (size.shortestSide - 2.5) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    // ~22 dashes with an equal gap between each, so the ring closes evenly.
    const dashes = 22;
    const sweep = 2 * 3.1415926535 / dashes;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The Spots canvas texture, drawn rather than imaged so the card stays a
/// single self-contained widget with no asset to ship.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    const step = 16.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shows the win card so the winner sees it before it goes out, then captures
/// that exact widget to PNG and opens the share sheet.
///
/// Previewing rather than firing the share sheet blind is the point: this is
/// the image that ends up on someone's Story, so they get to look at it first.
class SpotsWinCardSheet extends StatefulWidget {
  const SpotsWinCardSheet({super.key, required this.prize});

  final PlacePrize prize;

  static Future<void> show(BuildContext context, PlacePrize prize) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotsWinCardSheet(prize: prize),
    );
  }

  @override
  State<SpotsWinCardSheet> createState() => _SpotsWinCardSheetState();
}

class _SpotsWinCardSheetState extends State<SpotsWinCardSheet> {
  final GlobalKey _cardKey = GlobalKey();

  /// iOS/iPadOS anchors the share sheet to a rect in the source view. A zero
  /// rect is rejected outright, so the share button's own bounds are used.
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _sharing = false;

  /// The byline name. The API has no handle field, so this is the profile's
  /// first name — never the phone or email, which must not go on a public
  /// image. Returns null when there's nothing safe to show.
  String? _winnerName() {
    if (!Get.isRegistered<ProfileController>()) return null;
    final user = Get.find<ProfileController>().userInfoModel;
    final first = user?.fName?.trim() ?? '';
    return first.isEmpty ? null : first;
  }

  /// The share button's rect in global (screen) coordinates. Falls back to a
  /// 1×1 rect at the screen centre when the button hasn't been laid out — iOS
  /// only rejects a *zero* rect, so any real rect is enough to open the sheet.
  Rect _sharePositionOrigin() {
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _share() async {
    if (_sharing) return;

    // Captured before the await chain: after the sheet's own state changes the
    // button may no longer be the same render object.
    final origin = _sharePositionOrigin();
    setState(() => _sharing = true);

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        showCustomSnackBar('spots_win_card_failed'.tr, isError: true);
        return;
      }

      // 3× so the PNG lands at 960×1200 — no upscaling on any phone.
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        showCustomSnackBar('spots_win_card_failed'.tr, isError: true);
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/waddi_spots_win_${widget.prize.id}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'spots_win_card_share_text'.trParams({
          'venue': widget.prize.placeTitle,
        }),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('❌ [SPOTS] win-card share failed: $e');
      showCustomSnackBar('spots_win_card_failed'.tr, isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(Spots.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // RepaintBoundary is the capture target — what's inside it is
            // exactly what gets shared, nothing more.
            // The mint lift is the sheet's, not the card's: it must not be
            // baked into the captured PNG.
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Spots.border,
                  width: Spots.borderThick,
                ),
                boxShadow: Spots.shadow(dx: 6, dy: 6, color: Spots.mint),
              ),
              child: RepaintBoundary(
                key: _cardKey,
                child: SpotsWinCard(
                  prize: widget.prize,
                  winnerName: _winnerName(),
                ),
              ),
            ),
            const SizedBox(height: Spots.s16),
            SpotsPressable(
              onTap: _sharing ? null : _share,
              dx: 3,
              dy: 3,
              radius: Spots.radiusMd,
              child: Container(
                key: _shareButtonKey,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: Spots.s16),
                decoration: Spots.card(
                  fill: Spots.mint,
                  radius: Spots.radiusMd,
                  borderWidth: Spots.borderThin,
                  dx: 0,
                  dy: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_sharing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Spots.teal900,
                        ),
                      )
                    else
                      const Icon(
                        Icons.ios_share_rounded,
                        size: 18,
                        color: Spots.teal900,
                      ),
                    const SizedBox(width: Spots.s8),
                    Text(
                      displayCaps('spots_prize_share_win'.tr),
                      style: Spots.kicker(
                        13,
                        color: Spots.teal900,
                        tracking: 0.06,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spots.s8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                displayCaps('spots_maybe_later'.tr),
                style: Spots.kicker(12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
