import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/common/widgets/spots/spots_l10n.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/reward_state.dart';
import 'package:waddy_app/features/xp/widgets/xp_motion.dart';
import 'package:waddy_app/features/xp/widgets/xp_tokens.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';

/// ─── WADDI XP — Rewards ───────────────────────────────────────────────────────
/// Where every reward tap on the XP home lands (X-27). It used to be a stock
/// light Material page — a hard light/dark flip out of the XP surface — with a
/// stats row that always read zero and status filters that made the user work
/// out what they could do. Now it is on the XP tokens and grouped by the
/// action each reward wants:
///
///   ready to claim → claiming does something (wallet credit, a coupon)
///   ready to use   → spend it: free delivery at checkout, a coupon code
///   badges, used, expired → the record
///
/// Every usable reward carries its way to be used.
class XpPrizesScreen extends StatefulWidget {
  const XpPrizesScreen({super.key});

  @override
  State<XpPrizesScreen> createState() => _XpPrizesScreenState();
}

class _XpPrizesScreenState extends State<XpPrizesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<XpController>().getPrizes(reload: true);
    });
  }

  Future<void> _refresh() => Get.find<XpController>().getPrizes(reload: true);

  /// Successful claims so far; each one keys a fresh coin burst (XM-04).
  int _bursts = 0;

  Future<void> _claim(Prize prize) async {
    final ok = await Get.find<XpController>().claimPrize(prize.id);
    if (ok && mounted) setState(() => _bursts++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpTokens.panel,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GetBuilder<XpController>(
                      id: XpController.idPrizes,
                      builder: (xp) {
                        final model = xp.prizeModel;
                        if (model == null) {
                          if (xp.prizesFailed && !xp.isPrizesLoading) {
                            return _ErrorState(onRetry: _refresh);
                          }
                          return const Center(
                            child: CircularProgressIndicator(color: XpTokens.mint),
                          );
                        }

                        final groups = _group(model.prizes);
                        return RefreshIndicator(
                          color: XpTokens.mint,
                          backgroundColor: XpTokens.panel,
                          onRefresh: _refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              Dimensions.paddingSizeDefault,
                              Dimensions.paddingSizeExtraSmall,
                              Dimensions.paddingSizeDefault,
                              MediaQuery.of(context).padding.bottom + 28,
                            ),
                            children: [
                              if (groups.every((g) => g.prizes.isEmpty))
                                const _EmptyState()
                              else
                                for (final g in groups)
                                  if (g.prizes.isNotEmpty) ...[
                                    _GroupHeader(
                                      label: g.label,
                                      count: g.prizes.length,
                                    ),
                                    for (final p in g.prizes)
                                      Padding(
                                        // Keyed by prize, so a card a claim moves to
                                        // another group keeps its state and its
                                        // icon plays the change.
                                        key: ValueKey('prize-${p.id}'),
                                        padding: const EdgeInsets.only(
                                          bottom: Dimensions.paddingSizeSmall,
                                        ),
                                        child: _PrizeCard(
                                          prize: p,
                                          kind: g.kind,
                                          claiming: xp.isClaimingPrizeId(p.id),
                                          onClaim: () => _claim(p),
                                        ),
                                      ),
                                  ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // A claim's payoff: a one-shot coin burst over the list.
                  if (_bursts > 0)
                    Align(
                      alignment: const Alignment(0, -0.3),
                      child: IgnorePointer(
                        child: XpLottieOnce(
                          key: ValueKey(_bursts),
                          asset: XpMotion.coinBurst,
                          size: 180,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Group> _group(List<Prize> prizes) {
    final claim = <Prize>[];
    final use = <Prize>[];
    final badges = <Prize>[];
    final used = <Prize>[];
    final expired = <Prize>[];

    for (final p in prizes) {
      switch (p.rewardState) {
        case RewardState.claim:
          claim.add(p);
        case RewardState.use:
          use.add(p);
        case RewardState.badge:
          badges.add(p);
        case RewardState.used:
          used.add(p);
        case RewardState.expired:
          expired.add(p);
        case RewardState.locked:
          // `/prizes` lists owned prizes only; nothing lands here.
          break;
      }
    }

    return [
      _Group(_Kind.claim, 'xp_prizes_ready_to_claim'.tr, claim),
      _Group(_Kind.use, 'xp_prizes_ready_to_use'.tr, use),
      _Group(_Kind.badge, 'xp_prizes_badges'.tr, badges),
      _Group(_Kind.record, 'xp_prizes_used'.tr, used),
      _Group(_Kind.record, 'xp_prizes_expired'.tr, expired),
    ];
  }
}

enum _Kind { claim, use, badge, record }

class _Group {
  final _Kind kind;
  final String label;
  final List<Prize> prizes;
  const _Group(this.kind, this.label, this.prizes);
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        14,
        Dimensions.paddingSizeDefault,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: Dimensions.minTapTarget,
                height: Dimensions.minTapTarget,
                margin: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeMedium,
                ),
                decoration: BoxDecoration(
                  color: XpTokens.overlay(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: XpTokens.overlay(0.2), width: 1.5),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayCaps('xp_rewards_kicker'.tr),
                  style: waddyBlack.copyWith(
                    fontSize: 10,
                    color: XpTokens.onDarkMed,
                    letterSpacing: displayTracking(0.1 * 10),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayCaps('xp_prizes_title'.tr),
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
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  const _GroupHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Dimensions.paddingSizeLarge,
        bottom: 10,
      ),
      child: Text(
        displayCaps('$label · ${fmtCount(count)}'),
        style: waddyBlack.copyWith(
          fontSize: 11,
          color: Colors.white,
          letterSpacing: displayTracking(0.08 * 11),
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIZE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PrizeCard extends StatelessWidget {
  final Prize prize;
  final _Kind kind;
  final bool claiming;
  final VoidCallback onClaim;
  const _PrizeCard({
    required this.prize,
    required this.kind,
    required this.claiming,
    required this.onClaim,
  });

  bool get _live => kind == _Kind.claim || kind == _Kind.use;

  @override
  Widget build(BuildContext context) {
    final accent = _live ? XpTokens.mint : XpTokens.onDarkMed;
    final value = prize.kind.valueLine(prize.value);
    final conditions =
        _live
            ? prizeConditionsLine(
              minOrderAmount: prize.minOrderAmount,
              expiresAt: prize.expiresAt,
            )
            : null;
    final freeDelivery = prize.kind == PrizeKind.freeDelivery;
    final code = prize.couponCode;

    return Container(
      decoration: BoxDecoration(
        color:
            _live
                ? XpTokens.mint.withValues(alpha: 0.08)
                : XpTokens.overlay(0.05),
        border: Border.all(
          color: _live ? XpTokens.mint : XpTokens.overlay(0.22),
          width: _live ? 2.5 : 1.5,
        ),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(XpTokens.rMd),
                ),
                alignment: Alignment.center,
                // Live rewards animate: on reveal, and when a claim changes
                // their status. The record (badges, used, expired) stays
                // static (XM-06).
                child:
                    _live
                        ? XpRiveIcon(
                          icon: XpIcon.forPrize(prize.kind),
                          size: 34,
                          fallback: prize.kind.icon,
                          fallbackColor: accent,
                          playWhen: prize.status,
                        )
                        : Icon(prize.kind.icon, color: accent),
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prize.title.isNotEmpty
                          ? prize.title
                          : 'xp_reward_fallback'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: waddyBlack.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (value != null) value,
                        'xp_level_short'.trParams({
                          'level': fmtCount(prize.level),
                        }),
                      ].join(' · '),
                      style: waddyBold.copyWith(
                        fontSize: 11,
                        color: XpTokens.onDarkMed,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_live) ...[
                const SizedBox(width: Dimensions.paddingSizeSmall),
                _Tag(
                  text:
                      prize.isUsed
                          ? 'xp_reward_used_tag'.tr
                          : prize.isExpired
                          ? 'expired'.tr
                          : 'xp_reward_ready_tag'.tr,
                ),
              ],
            ],
          ),
          if (conditions != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              conditions,
              style: waddyBold.copyWith(
                fontSize: 11,
                color: _expiresSoon ? XpTokens.coral : XpTokens.onDarkMed,
                height: 1.2,
              ),
            ),
          ],
          if (kind == _Kind.use && code != null && code.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            _CouponCode(code: code),
          ],
          if (_live) ...[
            const SizedBox(height: Dimensions.paddingSizeMedium),
            kind == _Kind.claim
                ? _ActionButton(
                  label: 'claim'.tr,
                  icon: Icons.redeem_outlined,
                  busy: claiming,
                  onTap:
                      claiming
                          ? null
                          : onClaim,
                )
                : _ActionButton(
                  label:
                      freeDelivery
                          ? 'xp_order_with_free_delivery'.tr
                          : 'xp_order_now'.tr,
                  icon:
                      freeDelivery
                          ? PrizeKind.freeDelivery.icon
                          : Icons.storefront_outlined,
                  onTap: () => RouteHelper.goToTab(RouteHelper.tabHome),
                ),
            if (kind == _Kind.use && freeDelivery) ...[
              const SizedBox(height: 6),
              Text(
                'xp_free_delivery_hint'.tr,
                style: waddyBold.copyWith(
                  fontSize: 10.5,
                  color: XpTokens.onDarkFaint,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool get _expiresSoon {
    final e = prize.expiresAt;
    return e != null && e.difference(DateTime.now()).inDays < 3;
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: XpTokens.overlay(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
      child: Text(
        displayCaps(text),
        style: waddyBlack.copyWith(
          fontSize: 10,
          color: XpTokens.onDarkMed,
          height: 1,
        ),
      ),
    );
  }
}

class _CouponCode extends StatelessWidget {
  final String code;
  const _CouponCode({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeExtraSmall,
        Dimensions.paddingSizeExtraSmall,
        Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: XpTokens.foil,
        border: Border.all(color: XpTokens.mint.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(XpTokens.rSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  code,
                  style: waddyBlack.copyWith(
                    fontSize: 15,
                    color: XpTokens.mint,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'xp_coupon_use_hint'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 10.5,
                    color: XpTokens.onDarkFaint,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showCustomSnackBar('code_copied'.tr, isError: false);
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: XpTokens.mint,
            ),
            label: Text(
              'copy'.tr,
              style: waddyBold.copyWith(color: XpTokens.mint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      minSize: Dimensions.minTapTarget,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeMedium - 2,
          horizontal: Dimensions.paddingSizeDefault,
        ),
        decoration: BoxDecoration(
          color: XpTokens.mint,
          borderRadius: BorderRadius.circular(XpTokens.rMd),
          border: Border.all(color: XpTokens.teal, width: 2),
        ),
        child:
            busy
                ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(XpTokens.teal),
                    ),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: XpTokens.teal),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Flexible(
                      child: Text(
                        displayCaps(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBlack.copyWith(
                          fontSize: 13,
                          color: XpTokens.teal,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY + ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const XpRiveIcon(
            icon: XpIcon.gift,
            size: 72,
            fallback: Icons.redeem_outlined,
            fallbackColor: XpTokens.mint,
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'xp_rewards_empty'.tr,
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: 13,
              color: XpTokens.onDarkMed,
              height: 1.3,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          _ActionButton(
            label: 'xp_order_now'.tr,
            icon: Icons.storefront_outlined,
            onTap: () => RouteHelper.goToTab(RouteHelper.tabHome),
          ),
        ],
      ),
    );
  }
}

/// A failed load is not "no rewards" (X-13).
class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 30)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'failed_to_load'.tr,
              textAlign: TextAlign.center,
              style: waddyBlack.copyWith(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            _ActionButton(
              label: 'retry'.tr,
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
