import 'package:flutter/material.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/auth/widgets/auth_bottom_sheet.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/domain/models/zone_data_model.dart';
import 'package:waddy_app/features/location/widgets/coming_soon_delivery.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The single conversion gate for guest mode. See docs/guest_mode_plan.md.
///
/// Two entry points:
///  - [requireAccount] — the generic, auth-only guard used by every gated
///    surface in the matrix (profile, orders, wallet, chat, vote, favourite…).
///    No-ops for logged-in users; opens the soft phone→OTP sheet for guests.
///  - [checkoutGuard] — checkout's two-gate sequence: an UNCONDITIONAL zone
///    check first (guest AND logged-in), short-circuiting to the NO DELIVERY
///    sheet before any auth ask, then [requireAccount]. This is why the zone
///    check lives here as an outer precondition and not inside [requireAccount]
///    (which no-ops for logged-in users and would let a logged-in out-of-zone
///    user sail through). — Amendments A & D.
class GuestGate {
  GuestGate._();

  /// Runs [onGranted] if the user has an account; otherwise opens the soft
  /// auth sheet and runs [onGranted] on success. The auth sheet already backs
  /// up and merges the guest cart, so callers don't manage that.
  ///
  /// [reason] is a short analytics tag for which surface triggered the wall
  /// (e.g. 'checkout', 'profile', 'vote', 'favourite').
  static void requireAccount(VoidCallback onGranted, {required String reason}) {
    if (AuthHelper.isLoggedIn()) {
      onGranted();
      return;
    }
    AnalyticsHelper.log('account_required', {'reason': reason});
    showAuthBottomSheet(onSuccess: onGranted);
  }

  /// Checkout's two-gate sequence — gate 1 (zone) is unconditional.
  ///
  /// 1. Re-verify the CURRENT delivery address against serving zones
  ///    synchronously (don't trust a possibly-stale flag). Out of zone →
  ///    NO DELIVERY sheet, stop. The auth sheet never opens.
  /// 2. In zone → [requireAccount] → [onGranted].
  static Future<void> checkoutGuard(VoidCallback onGranted) async {
    final locationController = Get.find<LocationController>();

    // Gate 1 — zone, unconditional (guest AND logged-in). refreshOutOfZoneStatus
    // is a no-op without location permission and is internally throttled, so
    // this trusts the last known flag when a fresh fix isn't available rather
    // than blocking checkout on a GPS round-trip.
    await locationController.refreshOutOfZoneStatus();
    if (locationController.outOfServingZone) {
      AnalyticsHelper.log('checkout_blocked_out_of_zone', {
        'auth_state': AuthHelper.isLoggedIn() ? 'user' : 'guest',
      });
      await showNoDeliverySheet(source: 'checkout');
      return;
    }

    // Gate 2 — account.
    requireAccount(onGranted, reason: 'checkout');
  }

  /// The "No delivery there" escalation (reference screen 3). Shown when an
  /// action is attempted on an out-of-zone address. Leads to the serving-zones
  /// list ("All delivery Locations", reference screen 4).
  /// [source] tailors only the SUBTITLE — the title stays constant so the sheet
  /// reads as one consistent message rather than four different rejections.
  /// It fires from four depths now (home auto-show, add-to-cart, cart, and
  /// checkout); repeating identical generic copy is what makes a soft block
  /// feel like a wall. Naming the user's actual area, and pointing at what they
  /// CAN do next, keeps it a signpost.
  /// [storeId] — pass when the block came from add-to-cart. Knowing WHICH store
  /// someone wanted turns "demand in Nasr City" into a merchant sign-up list,
  /// which is the most actionable thing this whole flow produces.
  static Future<void> showNoDeliverySheet({
    String? source,
    int? storeId,
  }) async {
    AnalyticsHelper.log('no_delivery_sheet_shown', {
      'source': source ?? 'auto',
    });

    // The area name comes from the saved address, which is always a real place.
    // When it's missing, fall back to the generic copy rather than rendering an
    // empty placeholder mid-sentence.
    final String? area = Get.find<LocationController>().displayAddress?.trim();
    final String description;
    if (area == null || area.isEmpty) {
      description = 'no_delivery_there_desc'.tr;
    } else if (source == 'add_to_cart') {
      description = 'no_delivery_browse_desc'.trParams({'area': area});
    } else if (source == 'checkout' || source == 'cart_proceed') {
      description = 'no_delivery_change_address_desc'.trParams({'area': area});
    } else {
      description = 'no_delivery_there_desc'.tr;
    }

    // See showAuthBottomSheet: defer a frame and use the stable overlay context
    // so presenting from a mid-rebuild tap can't hit a deactivated ancestor.
    await WidgetsBinding.instance.endOfFrame;
    await showModalBottomSheet(
      context: Get.overlayContext ?? Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: Dimensions.paddingSizeLarge,
              right: Dimensions.paddingSizeLarge,
              top: Dimensions.paddingSizeDefault,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  Dimensions.paddingSizeLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeLarge,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  Icons.flag_outlined,
                  size: 56,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(
                  'no_delivery_there'.tr,
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                // Primary action is now "Notify me", not "view zones": this
                // sheet fires at all four out-of-zone depths, so promoting the
                // capture here lights up the whole ladder in one place. The
                // zone list stays reachable, just demoted — it answers a
                // narrower question ("where DO you deliver?").
                NotifyMeButton(source: source ?? 'sheet', storeId: storeId),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                TextButton(
                  onPressed: () {
                    AnalyticsHelper.log('no_delivery_sheet_view_zones');
                    Navigator.of(context).pop();
                    showDeliveryLocationsSheet();
                  },
                  child: Text(
                    'view_all_delivery_locations'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'got_it'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "You're a bit far away from your address!" — shown when the user's real
  /// position resolves inside a DIFFERENT serving zone than their saved
  /// delivery address. Identical for guests and logged-in users.
  ///
  /// This is an ASK, never an automatic correction: the saved address is a
  /// deliberate choice (or, for a guest, the browsing seed), and someone
  /// ordering to home while standing at the office must not have their
  /// delivery address moved out from under them.
  ///
  ///  - "Yes, Keep this address" → nothing changes; suppressed for this zone.
  ///  - "No, Change address"     → logged-in users get their address book,
  ///    guests (who have none) get the location picker.
  static Future<void> showAddressDivergenceSheet() async {
    final locationController = Get.find<LocationController>();
    final String savedLabel =
        AddressHelper.getUserAddressFromSharedPref()?.address ?? '';
    AnalyticsHelper.log('address_divergence_sheet_shown', {
      'auth_state': AuthHelper.isLoggedIn() ? 'user' : 'guest',
    });

    // See showAuthBottomSheet: defer a frame and use the stable overlay context
    // so presenting from a mid-rebuild tap can't hit a deactivated ancestor.
    await WidgetsBinding.instance.endOfFrame;
    await showModalBottomSheet(
      context: Get.overlayContext ?? Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The whole point is a deliberate choice — don't let a stray tap outside
      // dismiss it without an answer.
      isDismissible: false,
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: Dimensions.paddingSizeLarge,
              right: Dimensions.paddingSizeLarge,
              top: Dimensions.paddingSizeDefault,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  Dimensions.paddingSizeLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeLarge,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  Icons.wrong_location_outlined,
                  size: 56,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(
                  'far_from_your_address'.tr,
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  savedLabel.isEmpty
                      ? 'far_from_your_address_desc_generic'.tr
                      : '${'far_from_your_address_desc'.tr} $savedLabel',
                  textAlign: TextAlign.center,
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                CustomButton(
                  buttonText: 'yes_keep_this_address'.tr,
                  onPressed: () {
                    AnalyticsHelper.log('address_divergence_kept');
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                TextButton(
                  onPressed: () {
                    AnalyticsHelper.log('address_divergence_changed');
                    Navigator.of(context).pop();
                    // A guest has no address book — send them straight to the
                    // picker instead of an empty list.
                    Get.toNamed(
                      AuthHelper.isLoggedIn()
                          ? RouteHelper.getAddressRoute()
                          : RouteHelper.getAccessLocationRoute('home'),
                    );
                  },
                  child: Text(
                    'no_change_address'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Remember the answer against the zone we asked about, so a "keep" doesn't
    // re-prompt on every home load — but a move to a NEW zone asks again.
    try {
      final String? zoneKey = locationController.gpsZoneKey;
      if (zoneKey != null) {
        Get.find<SharedPreferences>().setString(
          AppConstants.addressDivergenceAskedZone,
          zoneKey,
        );
      }
    } catch (e, s) {
      swallow('remember address-divergence prompt', e, s);
    }
  }

  /// Auto-shows the address-divergence sheet at most once per serving zone.
  /// Called from home once zone data is fresh. No-op unless the user's real
  /// position is inside a different serving zone than their saved address.
  static Future<void> maybeAutoShowAddressDivergence() async {
    final locationController = Get.find<LocationController>();
    if (!locationController.gpsZoneDiverges) return;

    final String? zoneKey = locationController.gpsZoneKey;
    if (zoneKey == null) return;
    try {
      final prefs = Get.find<SharedPreferences>();
      if (prefs.getString(AppConstants.addressDivergenceAskedZone) == zoneKey) {
        return;
      }
    } catch (_) {
      // Prefs unavailable — fall through and ask once for this load.
    }
    await showAddressDivergenceSheet();
  }

  /// Auto-shows the "No delivery there" sheet AT MOST ONCE per out-of-zone
  /// episode (guest AND logged-in). Called when an out-of-zone module home
  /// loads. The flag is cleared by [LocationController.setOutOfServingZone]
  /// when the user returns to a serving zone, so a later out-of-zone episode
  /// shows it again. No-op when in zone.
  static Future<void> maybeAutoShowNoDelivery() async {
    if (!Get.find<LocationController>().outOfServingZone) return;
    try {
      final prefs = Get.find<SharedPreferences>();
      if (prefs.getBool(AppConstants.noDeliverySheetShown) ?? false) return;
      await prefs.setBool(AppConstants.noDeliverySheetShown, true);
    } catch (_) {
      // If prefs are unavailable, fall through and show once for this load.
    }
    await showNoDeliverySheet();
  }

  /// The "All delivery Locations" list (reference screen 4). A plain two-column
  /// list of the zone names we currently serve — sourced live from
  /// [LocationController.getServiceZoneList] so it stays correct as zones
  /// change — plus a primary "Add a new address" (opens the location picker so
  /// the user can pick an in-zone spot) and a "Maybe later" dismiss.
  static Future<void> showDeliveryLocationsSheet() async {
    AnalyticsHelper.log('delivery_locations_sheet_shown');
    // Preload the zone list so the sheet has names on first paint.
    final List<ZoneDataModel>? zones =
        await Get.find<LocationController>().getServiceZoneList();
    final List<String> names = [
      for (final z in zones ?? [])
        if ((z.name ?? '').trim().isNotEmpty) z.name!.trim(),
    ];

    await WidgetsBinding.instance.endOfFrame;
    await showModalBottomSheet(
      context: Get.overlayContext ?? Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: Dimensions.paddingSizeLarge,
              right: Dimensions.paddingSizeLarge,
              top: Dimensions.paddingSizeDefault,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  Dimensions.paddingSizeLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(
                      bottom: Dimensions.paddingSizeLarge,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).disabledColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'all_delivery_locations'.tr,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeExtraLarge,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text(
                  'we_are_currently_delivering_in'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Flexible(
                  child: SingleChildScrollView(
                    child:
                        names.isEmpty
                            ? Text(
                              'delivery_locations_unavailable'.tr,
                              style: waddyRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).disabledColor,
                              ),
                            )
                            : _ZoneNamesGrid(names: names),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text(
                  'we_are_working_to_reach_you'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                // The passive rung needs an active exit too: someone who opened
                // this list to check whether we reach them, and found we don't,
                // is exactly the person worth capturing.
                if (Get.find<LocationController>().outOfServingZone) ...[
                  const NotifyMeButton(source: 'sheet'),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                ],
                CustomButton(
                  buttonText: 'add_a_new_address'.tr,
                  onPressed: () {
                    AnalyticsHelper.log('delivery_locations_add_address');
                    Navigator.of(context).pop();
                    Get.toNamed(RouteHelper.getAccessLocationRoute('home'));
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                // Entry point for the serving-zones polygon map. It used to
                // hang off the out-of-zone hint pill on home; that pill is gone,
                // and a names-only list answers "do you serve me?" far less
                // well than a map does for someone near a boundary.

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'maybe_later'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Two-column bulleted list of served zone names for the delivery-locations
/// sheet (reference screen 4). Splits the names left-to-right across two
/// columns to mirror the reference layout.
class _ZoneNamesGrid extends StatelessWidget {
  final List<String> names;
  const _ZoneNamesGrid({required this.names});

  @override
  Widget build(BuildContext context) {
    final int half = (names.length + 1) ~/ 2;
    final List<String> left = names.sublist(0, half);
    final List<String> right = names.sublist(half);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(context, left)),
        const SizedBox(width: Dimensions.paddingSizeDefault),
        Expanded(child: _column(context, right)),
      ],
    );
  }

  Widget _column(BuildContext context, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in items)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: waddyBold.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    name,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
