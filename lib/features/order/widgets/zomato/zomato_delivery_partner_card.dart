import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/chat/domain/models/conversation_model.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:url_launcher/url_launcher_string.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ZomatoDeliveryPartnerCard
//
// States:
//   • No rider (searching)  → pulsing placeholder + amber "Matching…" chip
//   • Rider assigned, not yet picked up → rider info + call/chat buttons
//   • Rider en route (pickedUp/handover) → rider info + live green dot + clock
//   • Delivered / terminal → compact confirmation strip
//
// Bottom of every state: prominent support row (visible without scrolling).
// ─────────────────────────────────────────────────────────────────────────────

class ZomatoDeliveryPartnerCard extends StatelessWidget {
  final OrderModel order;
  final bool showChatPermission;
  final VoidCallback onTimerCancel;
  final VoidCallback onStartTracking;

  const ZomatoDeliveryPartnerCard({
    super.key,
    required this.order,
    required this.showChatPermission,
    required this.onTimerCancel,
    required this.onStartTracking,
  });

  @override
  Widget build(BuildContext context) {
    final dm = order.deliveryMan;
    final OrderStatus? status = OrderStatus.fromString(order.orderStatus);

    if (status?.isTerminal == true) {
      return _TerminalStrip(status: status);
    }

    if (dm == null) {
      return _SearchingCard();
    }

    final bool enRoute = status == OrderStatus.handover ||
        status == OrderStatus.pickedUp;
    final bool showActions = status?.isOngoing == true;
    final String name = '${dm.fName ?? ''} ${dm.lName ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rider identity ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RiderAvatar(imageUrl: dm.imageFullUrl ?? '', enRoute: enRoute),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'delivery_partner'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(status, dm.fName),
                        style: waddyBody.copyWith(
                          fontSize: 12.5,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status, enRoute: enRoute),
              ],
            ),
          ),

          // ── Action buttons (call / chat) ─────────────────────────────────
          if (showActions) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (showChatPermission) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Message',
                        icon: Icons.chat_bubble_outline_rounded,
                        filled: false,
                        onTap: () async {
                          onTimerCancel();
                          await Get.toNamed(
                            RouteHelper.getChatRoute(
                              notificationBody: NotificationBodyModel(
                                deliverymanId: dm.id,
                                orderId: int.parse(order.id.toString()),
                              ),
                              user: User(
                                id: dm.id,
                                fName: dm.fName,
                                lName: dm.lName,
                                imageFullUrl: dm.imageFullUrl,
                              ),
                            ),
                          );
                          onStartTracking();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _ActionBtn(
                      label: 'Call rider',
                      icon: Icons.phone_rounded,
                      filled: true,
                      color: WaddyColors.coral,
                      onTap: () {
                        if (dm.phone != null && dm.phone!.isNotEmpty) {
                          launchUrlString(
                            'tel:${dm.phone}',
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          _SupportRow(),
        ],
      ),
    );
  }

  String _subtitle(OrderStatus? status, String? firstName) {
    final name = firstName ?? 'Your rider';
    switch (status) {
      case OrderStatus.handover:
      case OrderStatus.pickedUp:
        return '$name is on the way with your order!';
      case OrderStatus.delivered:
        return 'Delivered \u2014 enjoy your meal!';
      case OrderStatus.canceled:
      case OrderStatus.failed:
        return 'This order was not completed.';
      default:
        return '$name is heading to the restaurant now.';
    }
  }
}

// ─── Rider Avatar (with en-route green ring) ───────────────────────────────────
class _RiderAvatar extends StatelessWidget {
  final String imageUrl;
  final bool enRoute;

  const _RiderAvatar({required this.imageUrl, required this.enRoute});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enRoute
              ? WaddyColors.mintDark
              : WaddyColors.primary.withValues(alpha: 0.20),
          width: enRoute ? 2.5 : 1.5,
        ),
        boxShadow: enRoute
            ? [
                BoxShadow(
                  color: WaddyColors.mint.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: CustomImage(
          image: imageUrl,
            height: 58,
          width: 58,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final OrderStatus? status;
  final bool enRoute;

  const _StatusBadge({required this.status, required this.enRoute});

  @override
  Widget build(BuildContext context) {
    if (enRoute) return const _LiveDot();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: WaddyColors.amberSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WaddyColors.amber.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Soon',
        style: waddyLabel.copyWith(
          color: const Color(0xFFB36A00),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Live Dot badge ────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WaddyColors.mint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.mintDark,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Live',
            style: waddyLabel.copyWith(
              color: WaddyColors.mintDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Searching Card ────────────────────────────────────────────────────────────
class _SearchingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PulsingAvatarPlaceholder(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'delivery_partner'.tr,
                        style: waddyTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Finding the best rider near you\u2026',
                        style: waddyBody.copyWith(
                          fontSize: 12.5,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
                _MatchingChip(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SupportRow(),
        ],
      ),
    );
  }
}

// ─── Terminal strip (delivered / cancelled) ────────────────────────────────────
class _TerminalStrip extends StatelessWidget {
  final OrderStatus? status;
  const _TerminalStrip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool delivered = status == OrderStatus.delivered ||
        status == OrderStatus.refunded;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: delivered ? WaddyColors.mintSurface : WaddyColors.errorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: delivered
              ? WaddyColors.mint.withValues(alpha: 0.30)
              : WaddyColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            delivered
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: delivered ? WaddyColors.mintDark : WaddyColors.error,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivered ? 'Delivered!' : 'Order not completed',
                  style: waddyBodyMedium.copyWith(
                    color: delivered ? WaddyColors.mintDark : WaddyColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  delivered
                      ? 'Hope you enjoy every bite!'
                      : 'Contact support if you need help.',
                  style: waddyMicro.copyWith(
                    color: delivered
                        ? WaddyColors.mintDark.withValues(alpha: 0.7)
                        : WaddyColors.error.withValues(alpha: 0.7),
                    fontSize: 11.5,
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

// ─── Pulsing Avatar Placeholder ────────────────────────────────────────────────
class _PulsingAvatarPlaceholder extends StatefulWidget {
  @override
  State<_PulsingAvatarPlaceholder> createState() =>
      _PulsingAvatarPlaceholderState();
}

class _PulsingAvatarPlaceholderState extends State<_PulsingAvatarPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0.7;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: WaddyColors.primarySurface,
        ),
        child: const Icon(
          Icons.two_wheeler_rounded,
          color: WaddyColors.primary,
          size: 28,
        ),
      ),
    );
  }
}

// ─── Matching Chip (searching spinner) ────────────────────────────────────────
class _MatchingChip extends StatefulWidget {
  @override
  State<_MatchingChip> createState() => _MatchingChipState();
}

class _MatchingChipState extends State<_MatchingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: WaddyColors.amberSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WaddyColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFB36A00)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Matching',
            style: waddyLabel.copyWith(
              color: const Color(0xFFB36A00),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Support Row ──────────────────────────────────────────────────────────────
class _SupportRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      onTap: () => Get.toNamed(RouteHelper.getSupportRoute()),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF9),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border(top: BorderSide(color: WaddyColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.headset_mic_rounded,
              color: WaddyColors.primary,
              size: 15,
            ),
            const SizedBox(width: 7),
            Text(
              'Need help? Contact support',
              style: waddyLabel.copyWith(
                color: WaddyColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_rounded,
              color: WaddyColors.primary,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final Color? color;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color btnColor = color ?? WaddyColors.primary;
    return Material(
      color: filled ? btnColor : WaddyColors.surface,
      borderRadius: BorderRadius.circular(48),
      child: InkWell(
        borderRadius: BorderRadius.circular(48),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            border: filled
                ? null
                : Border.all(color: btnColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: filled ? Colors.white : btnColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: waddyLabel.copyWith(
                  color: filled ? Colors.white : btnColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
