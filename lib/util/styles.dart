import 'package:get/get.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:flutter/material.dart';

// ─── Waddy Type System ────────────────────────────────────────────────────────
// Two faces, two jobs:
//   Body    Thmanyah Sans (AppConstants.fontFamily)        — everything you read
//   Display Alexandria    (AppConstants.displayFontFamily) — everything you hear
//
// Until now both names resolved to the same Thmanyah files, so "display" and
// "body" differed only by weight and size. One family at five weights cannot
// establish hierarchy on a screen that also has photos, badges and a dark
// panel competing — the headline has to sound different, not just louder.
//
// Scale: Major Third (×1.25) from 14sp base
// Weights: 400 Regular · 500 Medium · 600 SemiBold · 700 Bold · 800 ExtraBold
// Leading: body 1.4em · display 1.1em · label 1.3em

// Body (base 14sp) — default reading text
final waddyRegular = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

final waddyMedium = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w500,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

final waddyBold = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w700,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.3,
);

final waddyBlack = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w900,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.2,
);

// Arabic script has no uppercase and its connected letterforms visually break
// apart when letter-spaced — caps/tracking treatments must collapse to plain
// text under the Arabic locale.
bool get isArabicScript => Get.locale?.languageCode == 'ar';
String displayCaps(String text) => isArabicScript ? text : text.toUpperCase();
double displayTracking(double value) => isArabicScript ? 0 : value;

// ─── Display face (Alexandria) ────────────────────────────────────────────────
// The loud voice: hero greeting, section headers, scorelines, rank numerals,
// LIVE kickers. Alexandria ships Arabic and Latin in one family, so a headline
// under `ar` stays in the display face instead of falling back to the body one.

/// Display type at an arbitrary size. Tracking is expressed as a *ratio* of the
/// size (optical tracking) rather than a fixed point value, because -0.5 at 11sp
/// and -0.5 at 32sp are not the same adjustment — and it collapses to 0 under
/// Arabic, whose connected letterforms break when spaced.
TextStyle waddyDisplayFace(
  double size, {
  FontWeight weight = FontWeight.w800,
  Color? color,
  double tracking = -0.02,
  double height = 1.05,
}) => TextStyle(
  fontFamily: AppConstants.displayFontFamily,
  fontWeight: weight,
  fontSize: size,
  color: color,
  // Latin caps have no descenders, so display styles can crush the line box
  // to 0.95 and look tighter for it. Arabic cannot: ascenders and the
  // shadda/kasra marks sit outside that box and get clipped at the top. The
  // floor applies only where the requested height is too tight for the
  // script, so Latin keeps its 0.95 and every looser value passes through
  // untouched in both scripts.
  height:
      isArabicScript && height < _arabicMinLineHeight
          ? _arabicMinLineHeight
          : height,
  letterSpacing: displayTracking(tracking * size),
);

/// The tightest line box Arabic display type can use without clipping its
/// ascenders and diacritics.
const double _arabicMinLineHeight = 1.15;

/// ALL-CAPS kicker — status labels, eyebrows, badge text. Wide tracking, small
/// size, display face.
TextStyle waddyKicker(
  double size, {
  Color? color,
  double tracking = 0.10,
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: AppConstants.displayFontFamily,
  fontWeight: weight,
  fontSize: size,
  color: color,
  height: 1.2,
  letterSpacing: displayTracking(tracking * size),
);

// ─── Semantic aliases (use these in new code) ─────────────────────────────────

// Display — 28sp ExtraBold · ETA numbers, hero values
final waddyDisplay = waddyDisplayFace(
  Dimensions.fontSizeOverLarge,
  weight: FontWeight.w800,
  height: 1.1,
);

// Headline — 22sp Bold · section headers, screen titles
final waddyHeadline = waddyDisplayFace(
  Dimensions.fontSizeExtraLarge,
  weight: FontWeight.w700,
  tracking: -0.01,
  height: 1.2,
);

// Title — 18sp SemiBold · card titles, item names
final waddyTitle = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w600,
  fontSize: Dimensions.fontSizeLarge,
  height: 1.3,
);

// Body — 14sp Regular · default text
final waddyBody = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

// Body Medium — 14sp Medium · emphasized body
final waddyBodyMedium = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w500,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

// Label — 12sp Medium · chips, badges, tags
final waddyLabel = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w500,
  fontSize: Dimensions.fontSizeExtraSmall,
  height: 1.3,
  letterSpacing: 0.1,
);

// ─── Feed rail headers ────────────────────────────────────────────────────────
// "Most Popular In Maadi" / "Groceries in minutes" and their one-line
// subtitles. These sit within a section of each other on the home feed, so they
// are the pair most likely to be caught disagreeing — and they were: the same
// four values (w800/20/1.2/-0.25 and 12.5/1.2) were hand-written into
// top_restaurants_view.dart and grocery_shelf_view.dart, which is two sources
// of truth for one voice. Body face rather than the display face, which is a
// deliberate step down from waddyHeadline: these introduce browsable rails, not
// the screen.

/// Section headline over a home-feed rail.
final waddyRailHeadline = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w800,
  fontSize: 20,
  height: 1.2,
  // Optical correction at display size: at w800/20 the counters close up
  // without it. Collapses to 0 under Arabic, whose connected letterforms come
  // apart when tracked.
  letterSpacing: displayTracking(-0.0125 * 20),
);

/// The qualifying line under a rail headline — "Open now — fastest first".
final waddyRailSubtitle = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: 12.5,
  height: 1.2,
);

/// Headline to its own subtitle. The tightest seam on the feed by design — the
/// two lines are one sentence in two registers, so they bind tighter than the
/// header binds to the rail beneath it.
const double kRailSubtitleGap = 3;

// Micro — 10sp Regular · fine print, timestamps
final waddyMicro = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeOverSmall,
  height: 1.3,
);

final BoxDecoration riderContainerDecoration = BoxDecoration(
  borderRadius: const BorderRadius.all(Radius.circular(Dimensions.radiusSmall)),
  color: Theme.of(Get.context!).primaryColor.withValues(alpha: 0.1),
  shape: BoxShape.rectangle,
);
