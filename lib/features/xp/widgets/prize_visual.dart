import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/helper/price_converter.dart';

/// How each [PrizeKind] looks and reads — the one home for it (X-38).
///
/// This used to be split across `iconForPrizeType` in the levels screen
/// (imported from there by Rewards and the level-up dialog),
/// `XpController.getRewardName`, and a value switch in the Rewards screen.
extension PrizeVisual on PrizeKind {
  /// Outlined glyph per kind, so each reward is visually distinct (a delivery
  /// van never looks like a discount tag) and renders identically on every
  /// device, unlike the medal emoji the backend sometimes sends.
  IconData get icon {
    switch (this) {
      case PrizeKind.freeDelivery:
        return Icons.local_shipping_outlined;
      case PrizeKind.discount:
        return Icons.sell_outlined;
      case PrizeKind.walletCredit:
        return Icons.account_balance_wallet_outlined;
      case PrizeKind.badge:
        return Icons.workspace_premium_outlined;
      case PrizeKind.other:
        return Icons.emoji_events_outlined;
    }
  }

  /// Localized name of the kind, for a prize with no title.
  String get label {
    switch (this) {
      case PrizeKind.freeDelivery:
        return 'free_delivery'.tr;
      case PrizeKind.discount:
        return 'xp_reward_type_discount'.tr;
      case PrizeKind.walletCredit:
        return 'xp_reward_type_wallet_credit'.tr;
      case PrizeKind.badge:
        return 'xp_reward_type_badge'.tr;
      case PrizeKind.other:
        return 'xp_reward_fallback'.tr;
    }
  }

  /// What the reward is worth, in money where it has a value.
  String? valueLine(double? value) {
    final v = value;
    switch (this) {
      case PrizeKind.freeDelivery:
        return 'free_delivery'.tr;
      case PrizeKind.discount:
        return v != null && v > 0
            ? 'xp_prize_discount_value'.trParams({
              'amount': PriceConverter.convertPrice(v),
            })
            : null;
      case PrizeKind.walletCredit:
        return v != null && v > 0
            ? 'xp_prize_wallet_value'.trParams({
              'amount': PriceConverter.convertPrice(v),
            })
            : null;
      case PrizeKind.badge:
      case PrizeKind.other:
        return null;
    }
  }
}

/// The conditions that decide whether a reward works today: the basket it
/// needs and how long it lasts. Null when there are none (X-39 — this lived
/// twice, in the XP home hero and the Rewards card).
///
/// [maxDays] hides a far-off expiry. The hero passes 30 so a reward good for
/// a year doesn't lead with its deadline.
String? prizeConditionsLine({
  double? minOrderAmount,
  DateTime? expiresAt,
  int? maxDays,
}) {
  final parts = <String>[];
  final min = minOrderAmount;
  if (min != null && min > 0) {
    parts.add(
      'xp_min_order'.trParams({
        'amount': PriceConverter.convertPrice(min, forDM: true),
      }),
    );
  }
  final expires = expiresAt;
  if (expires != null) {
    final days = expires.difference(DateTime.now()).inDays;
    if (days >= 0 && (maxDays == null || days <= maxDays)) {
      parts.add(
        days == 0
            ? 'xp_expires_today'.tr
            : trPlural('xp_expires_in_days', days),
      );
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
