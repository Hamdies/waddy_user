import 'package:get/get.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:flutter/material.dart';

// ─── Alexandria Type System — Waddy ───────────────────────────────────────────
// Scale: Major Third (×1.25) from 14sp base
// Weights: 400 Regular · 500 Medium · 600 SemiBold · 700 Bold · 800 ExtraBold
// Leading: body 1.4em · display 1.1em · label 1.3em

// Body (base 14sp) — default reading text
final robotoRegular = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

final robotoMedium = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w500,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.4,
);

final robotoBold = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w700,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.3,
);

final robotoBlack = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w900,
  fontSize: Dimensions.fontSizeDefault,
  height: 1.2,
);

// ─── Semantic aliases (use these in new code) ─────────────────────────────────

// Display — 28sp ExtraBold · ETA numbers, hero values
final waddyDisplay = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w800,
  fontSize: Dimensions.fontSizeOverLarge,
  height: 1.1,
  letterSpacing: -0.5,
);

// Headline — 22sp Bold · section headers, screen titles
final waddyHeadline = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w700,
  fontSize: Dimensions.fontSizeExtraLarge,
  height: 1.2,
  letterSpacing: -0.2,
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

// Micro — 10sp Regular · fine print, timestamps
final waddyMicro = TextStyle(
  fontFamily: AppConstants.fontFamily,
  fontWeight: FontWeight.w400,
  fontSize: Dimensions.fontSizeOverSmall,
  height: 1.3,
);

final BoxDecoration riderContainerDecoration = BoxDecoration(
  borderRadius: const BorderRadius.all(Radius.circular(Dimensions.radiusSmall)),
  color: Theme.of(Get.context!).primaryColor.withValues(alpha: 0.1), shape: BoxShape.rectangle,
);