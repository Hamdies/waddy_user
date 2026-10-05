import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/home/widgets/delivery_address_sheet_widget.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/store_rules.dart';
import 'package:waddy_app/features/store/helpers/store_delivery_fee.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Hero banner — full header (status bar + app bar + search) in one card,
/// using the Waddy brand palette.
class HomeHeroBannerWidget extends StatelessWidget {
  // Only module screens (grocery/food/etc) need a way back to the module
  // picker — the main dashboard has no "back" state.
  final bool showBackButton;

  /// False when the host scroll view renders the search field itself as a
  /// pinned sliver. See [HomeScreen] — pinning is what stops the field from
  /// scrolling underneath the status bar and colliding with the clock.
  final bool showSearch;

  /// Drops the greeting headline and tightens the block to just the two things
  /// a module screen's header has to carry: where you are (+ cart) and search.
  ///
  /// The greeting is a brand moment that earns its height once, on the main
  /// dashboard. Repeating it on every module screen spends the same ~40pt of
  /// the fold on the same shout the user just read one tap ago, pushing the
  /// module's own content — the thing they navigated here for — below the fold.
  final bool compact;

  const HomeHeroBannerWidget({
    super.key,
    this.showBackButton = false,
    this.showSearch = true,
    this.compact = false,
  });

  static const Color _mint = WaddyColors.mint;
  static const Color _ink = WaddyColors.primary;

  /// The colour of the banner's first gradient stop — i.e. the exact pixels
  /// sitting behind the status bar while the hero is at rest.
  ///
  /// Public because the host page paints a status-bar scrim in it (see
  /// `HomeScreen`). Deriving both from here is the point: a scrim that is
  /// "about the same mint" as the banner is a visible seam across the top of
  /// the screen, and the two would drift the first time either is retuned.
  static Color get statusBarTint =>
      Color.lerp(_mint, WaddyColors.heroMint, 0.35)!;

  /// The block's fill. Shared with [StoreHeroBannerWidget] so a store page's
  /// header is the same object as the module home's, not a lookalike.
  //
  // Route the fade through mintSurface (a pale minty-white) instead of lerping
  // mint straight to white — a direct mint→white lerp desaturates through a
  // muddy gray-green midpoint, which is what reads as a "dirty shadow" instead
  // of a clean dissolve.
  // Holds mint for most of the block, then resolves quickly at the very
  // bottom. The long eight-stop dissolve this replaces spent the lower third
  // of the banner on a fade, which is why the block read as mostly empty
  // gradient — Talabat and Rabbit both keep the hero a solid colour and end
  // it, and the block is legible as one object because of it.
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      statusBarTint,
      _mint,
      _mint,
      Color.lerp(_mint, WaddyColors.mintSurface, 0.55)!,
      WaddyColors.surface,
    ],
    stops: const [0.0, 0.22, 0.74, 0.92, 1.0],
  );

  /// Mint is a light surface: force dark status-bar icons while the banner
  /// extends behind the notch.
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  /// The greeting template, with `@name` still in it.
  ///
  /// The name is substituted at render time rather than here so the translator
  /// controls the word order. See [_greetingSpans].
  String _greetingTemplate() {
    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 5) return 'hero_greeting_late'.tr;
    if (hour >= 17) return 'hero_greeting_evening'.tr;
    if (hour >= 12) return 'hero_greeting_afternoon'.tr;
    return 'hero_greeting_morning'.tr;
  }

  /// Splits the greeting so the shout lands consistently across the full line.
  ///
  /// The whole line goes through [displayCaps], preserving the existing
  /// language-specific behavior for scripts without uppercase.
  ///
  /// Splitting on the placeholder (rather than composing name + statement in
  /// code) keeps word order under the translator's control: Arabic can put the
  /// name wherever it belongs, and `displayCaps` is already a no-op there.
  List<TextSpan> _greetingSpans(String firstName, TextStyle base) {
    final parts = _greetingTemplate().split('@name');

    // Defensive: a translation that dropped the placeholder still renders,
    // it just doesn't get a name in it.
    if (parts.length == 1) {
      return [TextSpan(text: displayCaps(parts.first), style: base)];
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: displayCaps(parts[i]), style: base));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(text: displayCaps(firstName), style: base));
      }
    }
    return spans;
  }

  /// Longest first part we'll still treat as a neighbourhood rather than a
  /// landmark. "Mansheya El-Tahrir" (18) is a place a user recognises;
  /// "Egyptian General Petroleum Corporation" (38) is a building they happened
  /// to be standing next to when the GPS fixed.
  static const int _kLandmarkLength = 18;

  String _shortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) return 'your_location'.tr;
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    List<String> readable = [];
    for (var part in parts) {
      if (part.contains('+') && part.length < 15) continue;
      if (RegExp(r'^\d+').hasMatch(part)) continue;
      if (part.isNotEmpty) readable.add(part);
    }
    if (readable.isEmpty) readable.add(parts[0]);

    // Reverse-geocoded addresses lead with whatever POI the pin landed on, and
    // that name is the least recognisable thing in the string — it eats the
    // line and then ellipsises mid-word, so the user can't confirm their own
    // area at a glance. Drop it when there are real locality parts behind it;
    // the full address is still one tap away in the selector.
    if (readable.length >= 3 && readable.first.length > _kLandmarkLength) {
      readable = readable.sublist(1);
    }

    readable = readable.take(2).toList();
    String result = readable.join(', ');
    if (result.length > 35) result = readable[0];
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: heroGradient),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        // The banner is the single largest object on the fold and it holds no
        // orderable content — address, greeting, search. Every point it spends
        // is a point the first store card does not get, and at (16, 18, 16, 16)
        // it pushed the chart's photos to the screen edge: the user's first
        // sight of the app was a colour field with a headline in it.
        //
        // Trimmed at the top and bottom rather than in the middle. The seams
        // between the three rows are what hold the block together as one
        // thought; the outer padding is just margin, and margin is where a
        // banner can give back height without any of its parts moving closer
        // together than they should be.
        //
        // Now 8. The row above and the field below are both 48pt tap targets
        // whose visible art is a 38pt circle and a bordered box — each already
        // carries its own inset, so the outer margin is stacking on top of
        // breathing room the controls provide themselves.
        padding: EdgeInsets.fromLTRB(16, 8, 16, showSearch ? 8 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row — deliver-to selector anchors the left,
            // streak/points badges on the right. No wordmark: the
            // greeting below carries the brand voice.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBackButton) ...[
                  _BackButton(
                    onTap: () {
                      Get.find<SplashController>().leaveModule();
                      Get.find<StoreListController>().resetStoreData();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Pressable(
                    onTap: DeliveryAddressSheetWidget.show,
                    // Scales from the start edge: a centre-anchored press
                    // would slide the address text inward and back, which
                    // reads as the line jittering rather than as a press.
                    alignment: AlignmentDirectional.centerStart,
                    child: GetBuilder<LocationController>(
                      id: kZoneStatusId,
                      builder: (locationController) {
                        // Single source of truth — never shows the browse
                        // seed as if it were the user's own location.
                        final String? displayAddress =
                            locationController.displayAddress;
                        final bool outOfZone =
                            locationController.outOfServingZone;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (outOfZone)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  AnalyticsHelper.log(
                                    'coming_soon_banner_tapped',
                                  );
                                  GuestGate.showDeliveryLocationsSheet();
                                },
                                // The status line is a 12sp row sitting on
                                // the address control's tap area, and it is
                                // the out-of-zone user's only way forward.
                                // Padding buys it real hit area without
                                // moving the text: the column's own 6pt gap
                                // below absorbs the added height.
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Dimensions.paddingSizeSmall,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // A filled alert glyph made the whole
                                      // header read as an error screen. This
                                      // is a coverage state, not a failure —
                                      // a quiet coral dot marks it without
                                      // shouting over the address below.
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: WaddyColors.coralDark,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        displayCaps('out_of_zone_pill'.tr),
                                        style: TextStyle(
                                          fontFamily: AppConstants.fontFamily,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: displayTracking(0.5),
                                          color: WaddyColors.coralDark,
                                        ),
                                      ),
                                      Text(
                                        '  ·  ',
                                        style: TextStyle(
                                          fontFamily: AppConstants.fontFamily,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: _ink.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      Flexible(
                                        // Naming the zone here ("· Maadi")
                                        // under "not serving this area" read
                                        // as if Maadi were the unserved area.
                                        // The link says what the tap does; the
                                        // sheet it opens names the zones.
                                        child: Text(
                                          'out_of_zone_areas_link'.tr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: AppConstants.fontFamily,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: _ink.withValues(alpha: 0.65),
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            // Compact runs the eyebrow inline with the
                            // address instead of stacking it — see the row
                            // below. Out of zone it always stacks: that
                            // branch is not a label but a status line with
                            // its own tap target inside it, and it cannot
                            // share a line with the address it qualifies.
                            else if (!compact)
                              Text(
                                displayCaps('deliver_to'.tr),
                                style: TextStyle(
                                  fontFamily: AppConstants.fontFamily,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: displayTracking(0.8),
                                  color: _ink.withValues(alpha: 0.65),
                                ),
                              ),
                            // No gap when the eyebrow was inlined away and
                            // there is nothing above the address to separate
                            // it from.
                            if (!compact || outOfZone)
                              const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Inlined eyebrow. Sits before the pin so the
                                // line reads "DELIVER TO 📍 Maadi" — label,
                                // then the thing it labels.
                                if (compact && !outOfZone) ...[
                                  // Flexible, not a bare Text: the label is
                                  // short in English but a translator's is
                                  // not, and an unyielding prefix would push
                                  // the address off the line rather than
                                  // ellipsising itself. The address is the
                                  // half worth keeping, so it stays a
                                  // Flexible below and this yields first at
                                  // a tighter fit.
                                  Flexible(
                                    child: Text(
                                      displayCaps('deliver_to'.tr),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppConstants.fontFamily,
                                        fontWeight: FontWeight.w800,
                                        // A step down from the stacked 13: on
                                        // its own line the label was a heading,
                                        // inline it is a prefix, and at equal
                                        // size it competes with the address for
                                        // the same line.
                                        fontSize: 11,
                                        letterSpacing: displayTracking(0.8),
                                        color: _ink.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Icon(
                                  outOfZone
                                      ? Icons.location_off_rounded
                                      : Icons.location_on_rounded,
                                  size: 15,
                                  // Out of zone the coral is already spent
                                  // on the status line above; a second red
                                  // mark on the address makes the user's
                                  // own location look like the error.
                                  color:
                                      outOfZone
                                          ? _ink.withValues(alpha: 0.55)
                                          : WaddyColors.coralDark,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  // Outweighs the inlined label so the two
                                  // don't split a tight line proportionally
                                  // and both end up clipped. Under pressure
                                  // the label collapses and the address keeps
                                  // very nearly the whole row — which is the
                                  // right trade: "DELI… 📍 Maa…" tells the
                                  // user nothing, "DE… 📍 Maadi, Cairo" still
                                  // confirms where the order is going.
                                  flex: 20,
                                  child: Text(
                                    _shortAddress(displayAddress),
                                    // Utility, not headline. At w800/14.5 it
                                    // was pulling against the greeting below
                                    // it; a step down in both size and
                                    // weight leaves it perfectly legible and
                                    // clearly subordinate.
                                    style: TextStyle(
                                      fontFamily: AppConstants.fontFamily,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _ink.withValues(alpha: 0.9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: _ink.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // TEMPORARY — remove before release. Opens the out-of-zone
                // sheet on demand so the McCoin mood animation can be eyeballed
                // without having to move the device outside a serving zone.
                // kDebugMode-gated so it can never ship in a release build.
                
                const _CartButton(),
              ],
            ),

            // Out-of-zone messaging now lives inline in the eyebrow row
            // above (label swaps to "OUT OF ZONE" + closest-zone hint) to
            // save vertical space instead of a separate banner here.
            //
            // 8, on the grid. The address row and the greeting are the same
            // voice answering the same question — where you are, and who is
            // being greeted there — so they can sit at the binding gap rather
            // than the section gap that was separating them. The measured gap
            // reads wider than 8: the address column is 41pt centred inside the
            // 48pt row above, so it carries ~3.5pt of its own slack.
            if (!compact) const SizedBox(height: Dimensions.paddingSizeSmall),

            // Chunky greeting headline — the brand's loud moment. Caps and
            // tracking collapse to plain text under Arabic, whose connected
            // script has no uppercase and breaks when letter-spaced.
            if (!compact)
              GetBuilder<ProfileController>(
                builder: (profileController) {
                  // Re-read the session here rather than using the `loggedIn`
                  // captured by _buildContent: after login only this builder
                  // reruns (ProfileController.update()), so a captured value
                  // stays stale and the name never appears until a refresh
                  // rebuilds the whole banner.
                  final firstName =
                      (AuthHelper.isLoggedIn()
                          ? profileController.userInfoModel?.fName
                          : null) ??
                      'there_greeting'.tr;
                  // Display face at w900 — the loud voice on the fold, and now
                  // a genuinely different typeface from the body copy beneath
                  // it rather than the same family one weight heavier.
                  //
                  // 20, down from 22 (and 24 before that). The weight and the
                  // caps are the voice; the size was just volume on top of
                  // them. Two stacked lines of the heaviest type in the app is
                  // what made the fold read as a marketing landing page rather
                  // than the top of a delivery app — and this line is the one
                  // block of the banner holding nothing the user can act on, so
                  // it is where height should come from first: everything
                  // around it is a 48pt tap target that cannot give any back.
                  // Held at 20 rather than 18 — past that the shout starts
                  // sounding like body copy at the top of the fold.
                  final base = waddyDisplayFace(
                    20,
                    weight: FontWeight.w900,
                    color: _ink,
                    tracking: -0.022,
                    // 1.05 is single-line leading, and this line is not
                    // reliably single-line: "Hamdies, LATE NIGHT CRAVINGS?"
                    // wraps, and at w900 two lines that close read as one solid
                    // block of ink with the descenders of the first row sitting
                    // in the caps of the second. Kept at 1.15 through the size
                    // trim: Arabic drops the caps transform entirely, so its
                    // descenders are real.
                    height: 1.15,
                  );
                  // Hard-capped at two lines. The greeting was unbounded, and
                  // its height is set by content nobody here controls: a long
                  // first name, a translator's phrasing, or a large system font
                  // could each push it to a third line of w900 caps — 25pt of
                  // the fold spent silently, on the one block of the banner
                  // that holds nothing the user can act on.
                  //
                  // Ellipsis rather than scale-down: this is a throwaway line
                  // of brand voice, so losing its tail costs nothing, where
                  // shrinking it would make the greeting a different size on
                  // different phones for no reason the user can see.
                  return Text.rich(
                    TextSpan(children: _greetingSpans(firstName, base)),
                    style: base,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),

            // The search field is part of the banner — address, greeting,
            // search, then the block ends. 8 binds it to the greeting above
            // it rather than leaving it floating between two blocks.
            //
            // Compact drops the greeting, which leaves the field binding
            // straight to the address row instead. 12 rather than 8 there:
            // the greeting used to sit between them as a visual break, and
            // without it two controls at the binding gap read as one crowded
            // stack instead of two separate things to tap.
            if (showSearch) ...[
              SizedBox(
                height:
                    compact
                        ? Dimensions.paddingSizeMedium
                        : Dimensions.paddingSizeSmall,
              ),
              HomeHeroSearchField(compact: compact),
            ],
          ],
        ),
      ),
    );
  }
}

/// The home search field. Lives here rather than inline in the banner because
/// the home scroll view mounts it as a pinned sliver — the banner and the
/// pinned header have to render the identical control or the field visibly
/// changes as it sticks.
class HomeHeroSearchField extends StatelessWidget {
  /// Matches the banner's own compact mode — see [HomeHeroBannerWidget.compact].
  final bool compact;

  /// Where a tap goes. Defaults to the global search; a store page points it
  /// at that store's own item search.
  final VoidCallback? onTap;

  /// A fixed placeholder in place of the cycling suggestions. A store's
  /// search covers only that store, so "Search for Koshary" would promise
  /// results it cannot return.
  final String? hint;

  const HomeHeroSearchField({
    super.key,
    this.compact = false,
    this.onTap,
    this.hint,
  });

  /// Compact height. Below [Dimensions.minTapTarget] as *painted* art, but the
  /// control keeps a full 48pt target: the shortfall is added back as
  /// transparent padding around it, so the box looks smaller without becoming
  /// harder to hit. 40 is the floor — the field still has to read as a field
  /// rather than a chip, and its 14sp hint needs the room.
  static const double _kCompactHeight = 40;

  @override
  Widget build(BuildContext context) {
    final double height = compact ? _kCompactHeight : Dimensions.minTapTarget;
    // Give the tap target back whatever the shrunk box gave up, split evenly
    // above and below. Nothing moves visually — this padding is transparent
    // and the surrounding gaps were already sized against a 48pt row.
    final double slack = (Dimensions.minTapTarget - height) / 2;

    return Pressable(
      onTap: onTap ?? () => Get.toNamed(RouteHelper.getSearchRoute()),
      semanticLabel: hint ?? 'search'.tr,
      child: Container(
        // 48, down from 52. This control does not accept text — it navigates
        // to the search screen — so its height is pure presence, and 48 is
        // exactly Dimensions.minTapTarget: the smallest it can be while still
        // being a comfortable target, which is the right size for a control
        // whose whole job is to be tapped once.
        //
        // Compact trims it to 40: on a module screen the header is chrome the
        // user scrolled past on the way in, not the fold's headline act.
        height: height,
        margin: EdgeInsets.symmetric(vertical: slack),
        padding: EdgeInsets.symmetric(
          horizontal:
              compact
                  ? Dimensions.paddingSizeMedium
                  : Dimensions.paddingSizeDefault,
        ),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          // Radius tracks the height so the corners stay the same shape
          // rather than reading rounder as the box gets shorter.
          borderRadius: BorderRadius.circular(
            compact ? Dimensions.radiusDefault : Dimensions.radiusLarge,
          ),
          // A visible edge, because this is the primary action on a
          // daily-ordering screen and it was a white box on a white page held
          // up by a 10%-alpha shadow alone. Once the header pins, it sits on
          // pure surface with nothing behind it — at which point the shadow is
          // the only thing distinguishing "search" from "background", and a
          // shadow is not an affordance.
          border: Border.all(
            color: HomeHeroBannerWidget._ink.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: HomeHeroBannerWidget._ink.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: HomeHeroBannerWidget._ink.withValues(alpha: 0.45),
              size: compact ? 19 : 22,
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child:
                  hint != null
                      ? Text(
                        hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyMedium.copyWith(
                          fontSize: compact ? 13 : 14,
                          color: HomeHeroBannerWidget._ink.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      )
                      : _CyclingSearchHint(compact: compact),
            ),
          ],
        ),
      ),
    );
  }
}

/// The supermarket page's header (Mart Store Page v4, "B · Compact"): the
/// module hero's mint block, holding the store — logo, name and whether it
/// is open — then an in-store search bar with the filter inside it, then
/// what the store promises (delivery time, free delivery, rating) as chips.
///
/// ```
///   (←) [logo] Green Basket ⌄          (🛒)
///              ● Open until 2 AM
///   ┌ 🔍 Search Green Basket      │ ⚙ ┐
///   (⏱ 10–30 min) (🚚 Free over EGP 199) (★ 4.7 rating)
/// ```
///
/// Tapping the store opens its details (hours, fee, address), as the
/// deliver-to line does on the module home. Every chip is drawn only when
/// the store has that fact to state.
class StoreHeroBannerWidget extends StatelessWidget {
  final Store store;
  final VoidCallback onStoreTap;

  /// Shows a filter button inside the search bar when set.
  final VoidCallback? onFilterTap;

  /// An extra control before the cart button (the scratch-card sticker).
  final Widget? trailing;

  const StoreHeroBannerWidget({
    super.key,
    required this.store,
    required this.onStoreTap,
    this.onFilterTap,
    this.trailing,
  });

  /// Mint holding behind the store row, easing to the page's canvas under
  /// the chips. Starts on [HomeHeroBannerWidget.statusBarTint] so the
  /// page's status-bar scrim meets it without a seam.
  static LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      HomeHeroBannerWidget.statusBarTint,
      WaddyColors.mint,
      Color.lerp(WaddyColors.mint, WaddyColors.surface, 0.49)!,
      WaddyColors.canvas,
    ],
    stops: const [0.0, 0.18, 0.7, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = _StoreInfoChip.forStore(store);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: HomeHeroBannerWidget.overlayStyle,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeSmall,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeExtraLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _BackButton(onTap: () => Get.back()),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Pressable(
                        onTap: onStoreTap,
                        semanticLabel: store.name,
                        alignment: AlignmentDirectional.centerStart,
                        child: _StoreIdentity(store: store),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (trailing != null) ...[
                      trailing!,
                      const SizedBox(width: 10),
                    ],
                    const _CartButton(),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _StoreSearchBar(store: store, onFilterTap: onFilterTap),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeMedium),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (int i = 0; i < chips.length; i++) ...[
                          if (i > 0)
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                          chips[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The header that takes over once the store header has scrolled away: back,
/// the search field, cart — on a mint bar that slides down from the top.
///
/// Always mounted, so the slide runs both ways; [visible] drives it, and it
/// ignores touches while hidden.
class StoreMiniHeader extends StatelessWidget {
  final Store store;
  final bool visible;

  const StoreMiniHeader({
    super.key,
    required this.store,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.1),
        duration: WaddyMotion.enter,
        curve: WaddyMotion.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: WaddyMotion.fast,
          child: Container(
            decoration: BoxDecoration(
              color: WaddyColors.mint,
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  0,
                  Dimensions.paddingSizeDefault,
                  2,
                ),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Get.back()),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Pressable(
                        onTap: () => _openStoreSearch(store),
                        semanticLabel: 'store_search_hint'.trParams({
                          'store': store.name ?? '',
                        }),
                        scale: WaddyMotion.pressCard,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeMedium,
                          ),
                          decoration: BoxDecoration(
                            color: WaddyColors.surface,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: WaddyColors.inkMid,
                              ),
                              const SizedBox(
                                width: Dimensions.paddingSizeSmall,
                              ),
                              Expanded(
                                child: Text(
                                  'store_search_hint'.trParams({
                                    'store': store.name ?? '',
                                  }),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: waddyRegular.copyWith(
                                    fontSize: 13,
                                    color: WaddyColors.inkLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _CartButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openStoreSearch(Store store) =>
    Get.toNamed(RouteHelper.getSearchStoreItemRoute(store.id));

/// Logo plate, name, and one status line: open until when, open, or closed.
class _StoreIdentity extends StatelessWidget {
  final Store store;

  const _StoreIdentity({required this.store});

  static const Color _ink = HomeHeroBannerWidget._ink;

  @override
  Widget build(BuildContext context) {
    final bool isOpen = store.isOpenNow;
    final String? closesAt = store.closesAt();
    final String status =
        !isOpen
            ? 'closed'.tr
            : closesAt != null
            ? 'open_until_time'.trParams({
              'time': DateConverter.convertTimeToTime(closesAt),
            })
            : 'open'.tr;

    return Row(
      children: [
        // White-rimmed plate, logo contained: `cover` crops wordmark logos
        // at this size.
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: WaddyColors.surface, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomImage(
            image: store.logoFullUrl ?? '',
            variants: store.logoVariants,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Two lines, the chevron riding the last word: one line cut
              // "Seoudi Market Maadi" to "Seoudi Market M…" beside the
              // scratch-card sticker, and the branch is the part that matters.
              Text.rich(
                TextSpan(
                  text: store.name ?? '',
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 2),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.15,
                  letterSpacing: displayTracking(-0.4),
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOpen ? _ink : WaddyColors.coralDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isOpen ? _ink : WaddyColors.coralDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// In-store search: a 48 white bar naming the store, with the filter button
/// behind a hairline at its end. The bar opens the store search; the filter
/// opens the price sheet.
class _StoreSearchBar extends StatelessWidget {
  final Store store;
  final VoidCallback? onFilterTap;

  const _StoreSearchBar({required this.store, this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    final String hint = 'store_search_hint'.trParams({
      'store': store.name ?? '',
    });
    return Container(
      height: Dimensions.minTapTarget,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WaddyColors.divider),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => _openStoreSearch(store),
              semanticLabel: hint,
              scale: WaddyMotion.pressCard,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: WaddyColors.inkMid,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyRegular.copyWith(
                          fontSize: 14,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onFilterTap != null) ...[
            Container(width: 1, height: 22, color: WaddyColors.divider),
            Pressable(
              onTap: onFilterTap,
              semanticLabel: 'filter'.tr,
              scale: WaddyMotion.pressControl,
              child: const SizedBox(
                width: Dimensions.minTapTarget,
                height: Dimensions.minTapTarget,
                child: Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: WaddyColors.inkMid,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One fact the store promises, as a translucent chip on the mint.
class _StoreInfoChip extends StatelessWidget {
  final Widget icon;
  final String label;

  const _StoreInfoChip({required this.icon, required this.label});

  /// Delivery time, the fee (or free delivery), the minimum order and the
  /// rating — each only when the store has it to say. Free delivery follows
  /// the cart bar's rules: the store's own flag, else the admin's "over an
  /// amount" threshold; a takeaway-only store promises none. The fee is
  /// [StoreDeliveryFee]'s, which returns null rather than guess, and then
  /// the chip is simply not drawn.
  ///
  /// The minimum is here because it is the one rule that blocks an order,
  /// and before it was first met in the cart bar — after the first add.
  static List<Widget> forStore(Store store) {
    final String? time = store.deliveryTime?.trim();
    final double rating = store.avgRating ?? 0;
    final double minimum = store.minimumOrder ?? 0;

    String? freeDelivery;
    if (store.delivery != false) {
      final admin =
          Get.find<SplashController>().configModelOrNull?.adminFreeDelivery;
      final bool adminOn = admin?.status == true;
      if (store.freeDelivery == true ||
          (adminOn && admin?.type == 'free_delivery_to_all_store')) {
        freeDelivery = 'free_delivery'.tr;
      } else if (adminOn &&
          admin?.type == 'free_delivery_by_order_amount' &&
          (admin?.freeDeliveryOver ?? 0) > 0) {
        freeDelivery = 'free_over_amount'.trParams({
          'amount': PriceConverter.convertPrice(admin!.freeDeliveryOver),
        });
      }
    }

    final double? fee =
        freeDelivery == null && store.delivery != false
            ? StoreDeliveryFee.estimate(
              store: store,
              address: AddressHelper.getUserAddressFromSharedPref(),
            )
            : null;

    return [
      if (time != null && time.isNotEmpty)
        _StoreInfoChip(
          icon: const Icon(
            Icons.schedule_rounded,
            size: 13,
            color: WaddyColors.primaryLight,
          ),
          label: time,
        ),
      if (freeDelivery != null)
        _StoreInfoChip(
          icon: const Icon(
            Icons.local_shipping_outlined,
            size: 14,
            color: WaddyColors.primaryLight,
          ),
          label: freeDelivery,
        )
      else if (fee != null)
        _StoreInfoChip(
          icon: const Icon(
            Icons.local_shipping_outlined,
            size: 14,
            color: WaddyColors.primaryLight,
          ),
          label: '${'delivery_fee'.tr} ${PriceConverter.convertPrice(fee)}',
        ),
      if (minimum > 0)
        _StoreInfoChip(
          icon: const Icon(
            Icons.shopping_basket_outlined,
            size: 14,
            color: WaddyColors.primaryLight,
          ),
          label: '${'min_order'.tr} ${PriceConverter.convertPrice(minimum)}',
        ),
      if (rating > 0)
        _StoreInfoChip(
          icon: const Icon(
            Icons.star_rounded,
            size: 14,
            color: WaddyColors.amber,
          ),
          label: 'n_rating'.trParams({'n': rating.toStringAsFixed(1)}),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: WaddyColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: waddyMedium.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WaddyColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search placeholder that cycles through craving suggestions after a fixed
/// "Search for " lead-in.
///
/// The lead-in is not decoration: the cycling half is empty for a beat between
/// suggestions, and a search box showing nothing but an icon doesn't say what
/// it searches. The prefix keeps the field self-explanatory at every frame of
/// the animation, and the suggestions rotate across all three modules (food,
/// grocery, pets) so the scope reads as the whole catalogue.
class _CyclingSearchHint extends StatefulWidget {
  final bool compact;

  const _CyclingSearchHint({this.compact = false});

  @override
  State<_CyclingSearchHint> createState() => _CyclingSearchHintState();
}

class _CyclingSearchHintState extends State<_CyclingSearchHint>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<String> _foodHintKeys = [
    'hero_search_hint_1',
    'hero_search_hint_2',
    'hero_search_hint_3',
    'hero_search_hint_4',
    'hero_search_hint_5',
    'hero_search_hint_6',
  ];

  /// Inside the grocery module the field searches supermarkets and grocers,
  /// so "Search for Koshary" was a promise the results could not keep.
  static const List<String> _groceryHintKeys = [
    'grocery_search_hint_1',
    'grocery_search_hint_2',
    'grocery_search_hint_3',
    'grocery_search_hint_4',
    'grocery_search_hint_5',
    'grocery_search_hint_6',
  ];

  /// Resolved once at mount: the hero is rebuilt per module home, so a module
  /// change arrives as a fresh State rather than mid-animation.
  late final bool _isGrocery =
      Get.find<SplashController>().module?.moduleType?.toLowerCase() ==
      AppConstants.grocery;

  List<String> get _hintKeys => _isGrocery ? _groceryHintKeys : _foodHintKeys;

  static const Duration _typeSpeed = Duration(milliseconds: 72);
  static const Duration _deleteSpeed = Duration(milliseconds: 38);
  static const Duration _holdAfterTyped = Duration(milliseconds: 1600);

  /// How many times to run the whole suggestion list before settling.
  ///
  /// This used to loop forever. Roughly a third of every cycle is spent
  /// typing or deleting at ~14 setState/second, on the app's busiest screen,
  /// for as long as the screen is mounted — and the dashboard's PageView keeps
  /// Home mounted while the user is on Orders or Account. Two passes is enough
  /// to make the point that the field searches the whole catalogue; after that
  /// the motion is only competing with the content below it for the eye.
  static const int _maxCycles = 2;

  int _cycles = 0;
  bool get _finished => _cycles >= _maxCycles;

  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  Timer? _timer;
  int _hintIndex = 0;
  String _visible = '';
  bool _deleting = false;
  // Caret shows only while "typing"/deleting. A caret blinking next to a
  // fully-typed suggestion makes the field look focused when it isn't.
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule(const Duration(milliseconds: 600));
  }

  /// A Timer chain does not stop because the app went to the background — it
  /// keeps typing a search hint nobody can see until the OS freezes the
  /// process. Suspend on the way out, pick the cycle back up on the way in.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_finished && _timer == null) _schedule(_typeSpeed);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule(Duration delay) {
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    final String target = _hintKeys[_hintIndex].tr;

    if (!_deleting) {
      if (_visible.length < target.length) {
        setState(() {
          _holding = false;
          _visible = target.substring(0, _visible.length + 1);
        });
        _schedule(_typeSpeed);
      } else {
        // Rest on a fully-typed suggestion, never on a half-deleted one: the
        // field's resting state has to read as a real hint.
        setState(() => _holding = true);
        if (_finished) {
          _timer = null;
          // The caret is only ever rendered mid-type, so once the hint settles
          // its controller is driving a ticker for a widget that is no longer
          // in the tree — a permanent frame callback with nothing to paint.
          _caret.stop();
          return;
        }
        _deleting = true;
        _schedule(_holdAfterTyped);
      }
    } else if (_visible.length > 1) {
      setState(() {
        _holding = false;
        _visible = _visible.substring(0, _visible.length - 1);
      });
      _schedule(_deleteSpeed);
    } else {
      // Hand straight over to the next suggestion's first character instead of
      // deleting to empty and pausing. An empty suffix leaves the field reading
      // "Search for" — a dangling preposition that looks like a truncated
      // string rather than a hint, and the old 350ms pause parked it there for
      // roughly a tenth of every cycle.
      _deleting = false;
      _hintIndex = (_hintIndex + 1) % _hintKeys.length;
      if (_hintIndex == 0) _cycles++;
      final String next = _hintKeys[_hintIndex].tr;
      setState(() {
        _holding = false;
        _visible = next.isEmpty ? '' : next.substring(0, 1);
      });
      _schedule(_typeSpeed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = waddyMedium.copyWith(
      fontSize: widget.compact ? 13 : 14,
      color: HomeHeroBannerWidget._ink.withValues(alpha: 0.4),
    );

    if (MediaQuery.of(context).disableAnimations) {
      return Text(
        _isGrocery
            ? 'grocery_search_placeholder'.tr
            : 'hero_search_placeholder'.tr,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      children: [
        Text('hero_search_prefix'.tr, style: style, maxLines: 1),
        Flexible(
          child: Text(
            _visible,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
        // No caret on an empty field — a lone blinking bar in a blank search
        // box reads as a broken or focused input.
        if (!_holding && _visible.isNotEmpty)
          FadeTransition(
            opacity: _caret,
            child: Container(
              width: 2,
              // Tracks the hint's size — a caret cut for 14sp text stands
              // visibly taller than the 13sp glyphs beside it.
              height: widget.compact ? 15 : 16,
              margin: const EdgeInsetsDirectional.only(start: 2),
              decoration: BoxDecoration(
                color: WaddyColors.mintDark,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
      ],
    );
  }
}

/// Back-to-dashboard button — same white-circle affordance as the cart
/// button, shown only on module screens (grocery/food) that sit "inside"
/// the main dashboard.
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'back'.tr,
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: 40,
        height: 48,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: WaddyColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cart button — design's top-right affordance: a white circle holding the
/// cart glyph, with a coral count badge that appears only when the cart has
/// items (badge border matches the mint hero so it reads as a cutout).
class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      // The badge only shows the line count; a quantity tap elsewhere in the
      // app should not rebuild it.
      filter: (cart) => cart.cartList.length,
      builder: (cartController) {
        final int count = cartController.cartList.length;
        return Pressable(
          onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
          semanticLabel: '${'cart'.tr}${count > 0 ? ', $count' : ''}',
          scale: WaddyMotion.pressControl,
          // 48dp minimum touch target; the visible circle stays smaller.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: WaddyColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WaddyColors.primary.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedShoppingBasket03,
                      size: 18,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
                // Directional, not `right`: under RTL the whole header mirrors
                // and the cart button moves to the visual left, but a hardcoded
                // `right` pins the badge to the physical right — i.e. the
                // button's inner edge, pointing back at the address text
                // instead of out toward the screen corner.
                if (count > 0)
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: _CartBadge(count: count),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Cart count, with a pop when it grows.
///
/// This is the receipt for "added to cart". Without it the only confirmation
/// of a tap somewhere else on the screen is a digit quietly changing in the
/// corner, which the user is not looking at — so the action either needs a
/// toast or it needs this. This is the cheaper of the two and it doesn't cover
/// content.
///
/// It fires on growth only. A badge that pops when you *remove* an item is
/// celebrating the wrong thing.
class _CartBadge extends StatefulWidget {
  final int count;

  const _CartBadge({required this.count});

  @override
  State<_CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends State<_CartBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  // Overshoot and settle. Starting at 0.7 rather than 0 doubles this as the
  // entrance for the 0→1 case: nothing in the real world appears from nothing,
  // and a badge scaling up from a visible size reads as arriving rather than
  // as being switched on.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.7,
        end: 1.18,
      ).chain(CurveTween(curve: WaddyMotion.easeOut)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: WaddyMotion.easeOut)),
      weight: 45,
    ),
  ]).animate(_pop);

  @override
  void initState() {
    super.initState();
    _pop.forward();
  }

  @override
  void didUpdateWidget(covariant _CartBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: WaddyColors.coral,
        shape: BoxShape.circle,
        border: Border.all(color: WaddyColors.mint, width: 2),
      ),
      child: Center(
        child: Text(
          widget.count > 99 ? '99+' : '${widget.count}',
          style: const TextStyle(
            fontFamily: AppConstants.fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );

    // The pop is pure emphasis — the number has already changed underneath it —
    // so reduced motion drops it entirely rather than softening it.
    if (MediaQuery.of(context).disableAnimations) return badge;
    return ScaleTransition(scale: _scale, child: badge);
  }
}

/// TEMPORARY debug affordance — delete along with its call site in the header.
///
/// Fires [GuestGate.showNoDeliverySheet] directly, bypassing the zone check,
/// so the sad-McCoin sheet can be reviewed from anywhere.
class _McCoinTestButton extends StatelessWidget {
  const _McCoinTestButton();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => GuestGate.showNoDeliverySheet(source: 'debug_button'),
      semanticLabel: 'Preview no-delivery sheet',
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WaddyColors.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.bug_report_rounded,
                size: 18,
                color: WaddyColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
