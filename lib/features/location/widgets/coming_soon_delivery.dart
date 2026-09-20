import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Out-of-zone delivery messaging: the "Coming soon" primitives that replace
/// delivery promises on every surface, plus the home-header banner.
///
/// An out-of-zone user browses the app completely normally — that is deliberate
/// (see [LocationGate]). What must never happen is promising them "25 min" or
/// "FREE DELIVERY" for a store we cannot deliver from: they'd invest in a cart
/// and hit a wall at checkout. So every delivery-time / delivery-fee render
/// site branches through here first.
///
/// The delivery-time sites are structurally heterogeneous — an icon pill, a
/// bare `Text`, a `TextSpan` inside a `RichText` — so one drop-in widget can't
/// serve them all. Instead this exposes the shared *predicate* plus one shape
/// per render style, which keeps the zone logic in exactly one place.

/// The single predicate every call site uses. Kept as one getter so a future
/// change (e.g. per-store zoning rather than per-user) is a one-line edit here
/// instead of an audit of ~18 widgets.
bool get isComingSoon => Get.find<LocationController>().outOfServingZone;

/// GetBuilder id for zone-status rebuilds.
///
/// [LocationController.outOfServingZone] is a derived getter, not an
/// observable, so nothing rebuilds on its own when the zone changes. Most
/// delivery-time sites live under `GetBuilder<StoreController>`, which a
/// `LocationController.update()` will never reach.
///
/// Wrapping only the chip would not help: when the branch is currently showing
/// a real "25 min", there is no chip in the tree to do the rebuilding — and the
/// stale delivery promise is exactly the case that must not leak. So call sites
/// wrap the *branch* (both arms) in a `GetBuilder<LocationController>` with
/// this id, and the controller calls `update([kZoneStatusId])` on zone change.
const String kZoneStatusId = 'zone_status';

/// Wraps a delivery-time/fee branch so it rebuilds when the serving zone
/// changes mid-session. Use for any site that renders a real delivery promise
/// in its `else` arm.
class ZoneAware extends StatelessWidget {
  final Widget Function(BuildContext context) builder;
  const ZoneAware({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocationController>(
      id: kZoneStatusId,
      builder: (_) => builder(context),
    );
  }
}

/// Pill form — replaces the delivery-time badge on store cards.
///
/// Matches the existing delivery pill's geometry so cards keep their rhythm,
/// but deliberately renders NEUTRAL GREY rather than the brand teal: "coming
/// soon" is a limitation, and styling it like the promotional badges it
/// replaces would read as an offer.
class ComingSoonChip extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  const ComingSoonChip({super.key, this.fontSize = 10.5, this.iconSize = 10});

  @override
  Widget build(BuildContext context) {
    final Color fg = Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: iconSize, color: fg),
          const SizedBox(width: 4),
          Text(
            'coming_soon'.tr,
            style: waddyBold.copyWith(fontSize: fontSize, color: fg),
          ),
        ],
      ),
    );
  }
}

/// `TextSpan` form — for sites that render delivery time inside a `RichText`
/// rather than as a standalone widget.
TextSpan comingSoonSpan(BuildContext context, {double? fontSize}) {
  return TextSpan(
    text: 'coming_soon'.tr,
    style: waddyMedium.copyWith(
      fontSize: fontSize ?? Dimensions.fontSizeSmall,
      color: Theme.of(context).disabledColor,
    ),
  );
}

/// Plain-text form — for info rows and any site where a chip's background would
/// fight the surrounding layout.
class ComingSoonText extends StatelessWidget {
  final double? fontSize;
  const ComingSoonText({super.key, this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      'coming_soon'.tr,
      style: waddyMedium.copyWith(
        fontSize: fontSize ?? Dimensions.fontSizeSmall,
        color: Theme.of(context).disabledColor,
      ),
    );
  }
}

/// "Notify me when you launch here" — the demand-capture CTA.
///
/// One tap, no typing, no PII: it records WHERE the user is and WHAT they were
/// trying to do, which is what decides the launch order and the merchant
/// sign-up list.
///
/// The confirmation copy is deliberately conditional. Push is the only delivery
/// channel, so if notifications are denied we still record the request (the
/// demand signal doesn't depend on the channel) but show a count-only
/// confirmation with NO notification promise. Promising an alert we have no way
/// to send is worse for trust than never offering one.
class NotifyMeButton extends StatelessWidget {
  final String source;
  final int? storeId;
  const NotifyMeButton({super.key, required this.source, this.storeId});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocationController>(
      id: kZoneStatusId,
      builder: (locationController) {
        if (locationController.zoneRequestSubmitted) {
          return _SubmittedConfirmation(
            count: locationController.requestsInArea,
          );
        }
        return CustomButton(
          buttonText: 'notify_me_when_you_launch'.tr,
          isLoading: locationController.submittingZoneRequest,
          onPressed: () {
            locationController.submitZoneRequest(
              source: source,
              storeId: storeId,
            );
          },
        );
      },
    );
  }
}

/// Post-submit state. Never asks twice.
class _SubmittedConfirmation extends StatelessWidget {
  final int? count;
  const _SubmittedConfirmation({this.count});

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: primary),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Flexible(
              child: Text(
                'you_are_on_the_list'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        // Only when the server actually returned a count. A hard-coded or
        // zero value here would read as "nobody else wants this" — the exact
        // opposite of the intended "you're not alone" message.
        if (count != null && count! > 1) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'people_here_are_waiting_too'.trParams({'count': '$count'}),
            textAlign: TextAlign.center,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// "Coming soon to your area! Closest zone: X — view all delivery locations"
///
/// Rung 0 of the out-of-zone signalling ladder: the persistent, passive notice
/// that sets expectations before the user invests anything. Naming the nearest
/// serving zone turns a rejection ("we don't deliver here") into an invitation
/// ("we're nearly there"), which is the whole point of browsing-while-out-of-
/// zone rather than blocking at the door.
///
/// Renders nothing when in zone. The closest-zone clause appears only once the
/// zone list and real GPS resolve; until then it degrades to a plain line
/// rather than showing a placeholder.
class ComingSoonBanner extends StatelessWidget {
  /// Horizontal padding inside the banner. Defaults to 0 because the usual
  /// mount point already sits inside a padded header column.
  final double horizontalPadding;
  const ComingSoonBanner({super.key, this.horizontalPadding = 0});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocationController>(
      id: kZoneStatusId,
      builder: (locationController) {
        if (!locationController.outOfServingZone) {
          return const SizedBox.shrink();
        }
        final String? closest = locationController.closestZoneName;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AnalyticsHelper.log('coming_soon_banner_tapped');
              GuestGate.showDeliveryLocationsSheet();
            },
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        children: [
                          TextSpan(text: '${'coming_soon_to_your_area'.tr} '),
                          if (closest != null)
                            TextSpan(
                              text: '${'closest_zone'.tr}: $closest! ',
                              style: waddyBold.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          TextSpan(
                            text: 'view_all_delivery_locations'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
