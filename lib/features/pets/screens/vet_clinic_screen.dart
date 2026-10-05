import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/domain/models/vet_clinic_model.dart';
import 'package:waddy_app/features/pets/widgets/clinic_status.dart';
import 'package:waddy_app/features/pets/widgets/clinic_tags.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// A vet clinic's page (Claude Design "Pet Module v2", screen 03).
///
///   cover · logo, name, rating, status · Call / Chat / Directions ·
///   24-hour banner · "Great for Luna" · Services & prices · Meet the vets ·
///   Opening hours · Location · sticky Chat + Call clinic
///
/// Info only: no booking, no cart (PET-04). Sections without data (no
/// prices, no vets) don't render rather than show placeholders. Reviews and
/// the design's save heart wait on clinic reviews/favourites (PET-18): the
/// Spots endpoints can't see clinics.
class VetClinicScreen extends StatelessWidget {
  final VetClinicModel clinic;

  const VetClinicScreen({super.key, required this.clinic});

  static Future<void> open(VetClinicModel clinic) async {
    await Get.to(() => VetClinicScreen(clinic: clinic));
  }

  static Future<void> _launch(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _call() => _launch('tel:${clinic.phone}');
  void _chat() => _launch('https://wa.me/${clinic.whatsapp}');
  void _directions() => _launch(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${clinic.latitude},${clinic.longitude}',
  );

  bool get _hasPhone => clinic.phone != null && clinic.phone!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _cover(context, top)),
          SliverToBoxAdapter(child: _intro()),
          SliverToBoxAdapter(child: _actions()),
          if (clinic.is24h) SliverToBoxAdapter(child: _emergency()),
          SliverToBoxAdapter(child: _fit()),
          SliverToBoxAdapter(child: _services()),
          SliverToBoxAdapter(child: _vets()),
          SliverToBoxAdapter(child: _hours()),
          SliverToBoxAdapter(child: _location()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  // ── Cover ─────────────────────────────────────────────────────────────

  Widget _cover(BuildContext context, double top) {
    final String? cover = clinic.coverUrl ?? clinic.imageUrl;
    final String? logo = clinic.coverUrl != null ? clinic.imageUrl : null;
    return SizedBox(
      height: 240 + top,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child:
                cover == null
                    ? const DecoratedBox(
                      decoration: BoxDecoration(gradient: petWash),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedStethoscope,
                          size: 56,
                          color: WaddyColors.primary,
                        ),
                      ),
                    )
                    : CustomImage(image: cover, fit: BoxFit.cover),
          ),
          PositionedDirectional(
            top: top + 12,
            start: 16,
            child: _RoundButton(
              icon: Icons.arrow_back,
              semanticLabel: 'back'.tr,
              onTap: () => Get.back(),
            ),
          ),
          PositionedDirectional(
            top: top + 12,
            end: 16,
            child: _RoundButton(
              icon: Icons.ios_share,
              semanticLabel: 'share'.tr,
              onTap:
                  () => Share.share(
                    '${clinic.name}\n${clinic.address ?? ''}\n'
                    'https://www.google.com/maps/search/?api=1&query=${clinic.latitude},${clinic.longitude}',
                  ),
            ),
          ),
          // The page's sheet rising over the photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 28,
            child: Container(
              decoration: const BoxDecoration(
                color: WaddyColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
          if (logo != null)
            PositionedDirectional(
              start: 20,
              bottom: -4,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: WaddyColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WaddyColors.canvas, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: WaddyColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CustomImage(image: logo, fit: BoxFit.cover),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Name, rating, status ──────────────────────────────────────────────

  Widget _intro() {
    final ClinicStatus? status = ClinicStatus.of(clinic);
    final bool open = clinic.isOpenNow == true;
    final TextStyle meta = waddyRegular.copyWith(
      fontSize: 12,
      color: WaddyColors.inkMid,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clinic.name,
            style: waddyBold.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: displayTracking(-0.6),
              color: WaddyColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (clinic.rating != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: WaddyColors.amber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      clinic.rating!.toStringAsFixed(1),
                      style: meta.copyWith(
                        fontWeight: FontWeight.w700,
                        color: WaddyColors.ink,
                      ),
                    ),
                  ],
                ),
                Text(
                  'clinic_reviews_count'.trParams({
                    'n': '${clinic.reviewsCount}',
                  }),
                  style: meta.copyWith(color: WaddyColors.inkLight),
                ),
                if (clinic.distanceKm != null)
                  Text('·', style: meta.copyWith(color: WaddyColors.inkLight)),
              ],
              if (clinic.distanceKm != null)
                Text(
                  'clinic_distance_away'.trParams({
                    'distance': clinicDistanceLabel(clinic.distanceKm!),
                  }),
                  style: meta,
                ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    open
                        ? WaddyColors.mintSurfaceDeep
                        : WaddyColors.coralSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: status.dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: waddyBold.copyWith(fontSize: 12, color: status.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Call / Chat / Directions ──────────────────────────────────────────

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (_hasPhone) ...[
            Expanded(
              child: _ActionTile(
                icon: HugeIcons.strokeRoundedCall,
                label: 'clinic_call'.tr,
                primary: true,
                onTap: _call,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
          ],
          if (clinic.whatsapp != null) ...[
            Expanded(
              child: _ActionTile(
                icon: HugeIcons.strokeRoundedWhatsapp,
                label: 'clinic_whatsapp'.tr,
                onTap: _chat,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
          ],
          Expanded(
            child: _ActionTile(
              icon: HugeIcons.strokeRoundedNavigation03,
              label: 'clinic_directions'.tr,
              onTap: _directions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergency() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WaddyColors.coralSurface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: WaddyColors.coralDark,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'clinic_emergency_title'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'clinic_emergency_sub'.tr,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: WaddyColors.inkMid,
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

  /// "Great for Luna" / "Doesn't treat dogs". Only when the clinic has said
  /// which animals it treats and there is a pet to compare against.
  Widget _fit() {
    return GetBuilder<PetController>(
      id: PetController.idPets,
      builder: (pets) {
        final UserPetModel? pet = pets.primaryPet;
        if (pet == null || clinic.species.isEmpty)
          return const SizedBox.shrink();
        final bool fits = clinic.treats(pet.species);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  fits ? WaddyColors.mintSurfaceDeep : WaddyColors.amberSurface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: WaddyColors.surface,
                  ),
                  child: PetAvatar(
                    species: pet.species,
                    photoUrl: pet.photoUrl,
                    size: 44,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fits
                            ? 'clinic_great_for'.trParams({'name': pet.name})
                            : 'clinic_doesnt_treat'.trParams({
                              'species': pet.species.label,
                            }),
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: WaddyColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'clinic_treats_list'.trParams({
                          'list': clinic.species
                              .map((s) => s.label)
                              .join(' · '),
                        }),
                        style: waddyRegular.copyWith(
                          fontSize: 12,
                          color: WaddyColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
                HugeIcon(
                  icon: pet.species.icon,
                  size: 20,
                  color: fits ? WaddyColors.primary : WaddyColors.amberInk,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Services & prices ─────────────────────────────────────────────────

  Widget _services() {
    final List<String> services =
        clinic.services.where(ClinicServiceView.known).toList();
    if (services.isEmpty) return const SizedBox.shrink();
    final bool anyPrice = services.any((s) => clinic.servicePrices[s] != null);
    return _Section(
      title:
          anyPrice ? 'clinic_services_prices'.tr : 'clinic_services_title'.tr,
      subtitle: anyPrice ? 'clinic_prices_note'.tr : null,
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (int i = 0; i < services.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border:
                      i == services.length - 1
                          ? null
                          : const Border(
                            bottom: BorderSide(color: WaddyColors.divider),
                          ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: petWash,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: ClinicServiceView.icon(services[i]),
                          size: 18,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ClinicServiceView.label(services[i]),
                            style: waddyBold.copyWith(
                              fontSize: 14,
                              color: WaddyColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'clinic_service_desc_${services[i]}'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 11,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (clinic.servicePrices[services[i]] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'clinic_price_from'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 10,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                          Text(
                            PriceConverter.convertPrice(
                              clinic.servicePrices[services[i]],
                            ),
                            style: waddyBold.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: WaddyColors.ink,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Meet the vets ─────────────────────────────────────────────────────

  Widget _vets() {
    if (clinic.vets.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'clinic_meet_vets'.tr,
      flush: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < clinic.vets.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _VetCard(vet: clinic.vets[i]),
            ],
          ],
        ),
      ),
    );
  }

  // ── Opening hours ─────────────────────────────────────────────────────

  /// The week from Saturday, as it runs in Egypt; today highlighted.
  static const List<String> _week = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  Widget _hours() {
    if (clinic.openingHours.isEmpty) return const SizedBox.shrink();
    // DateTime.weekday: Monday = 1 … Sunday = 7.
    const List<String> byWeekday = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final String today = byWeekday[DateTime.now().weekday - 1];
    return _Section(
      title: 'clinic_opening_hours'.tr,
      child: _Card(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            for (final String day in _week) _hoursRow(day, day == today),
          ],
        ),
      ),
    );
  }

  Widget _hoursRow(String day, bool isToday) {
    final dynamic raw = clinic.openingHours[day];
    final Map? h = raw is Map ? raw : null;
    final bool closed =
        h == null ||
        VetClinicModel.isClosedFlag(h['closed']) ||
        h['open'] == null ||
        h['close'] == null;
    final String open = '${h?['open'] ?? ''}';
    final String close = '${h?['close'] ?? ''}';
    final String time =
        closed
            ? 'clinic_closed'.tr
            : (open == '00:00' && (close == '23:59' || close == '24:00'))
            ? 'clinic_open_24h'.tr
            : '${_time(open)} – ${_time(close)}';
    final FontWeight w = isToday ? FontWeight.w800 : FontWeight.w500;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isToday ? WaddyColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isToday
                  ? 'clinic_day_today'.trParams({'day': 'day_$day'.tr})
                  : 'day_$day'.tr,
              style: waddyRegular.copyWith(
                fontSize: 13,
                fontWeight: w,
                color: WaddyColors.ink,
              ),
            ),
          ),
          Text(
            time,
            textDirection: TextDirection.ltr,
            style: waddyRegular.copyWith(
              fontSize: 13,
              fontWeight: w,
              color: closed ? WaddyColors.coralInk : WaddyColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  static String _time(String hhmm) {
    try {
      return DateConverter.convertTimeToTime(hhmm);
    } catch (_) {
      return hhmm;
    }
  }

  // ── Location ──────────────────────────────────────────────────────────

  Widget _location() {
    final LatLng at = LatLng(clinic.latitude, clinic.longitude);
    return _Section(
      title: 'clinic_location'.tr,
      child: _Card(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge - 2),
              child: SizedBox(
                height: 140,
                // A picture of where it is, not a map to play with: taps go
                // to the maps app, which does directions properly.
                child: IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: at, zoom: 15),
                    liteModeEnabled: true,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    markers: {
                      Marker(markerId: const MarkerId('clinic'), position: at),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clinic.address ?? clinic.name,
                          style: waddyBold.copyWith(
                            fontSize: 14,
                            color: WaddyColors.ink,
                          ),
                        ),
                        if (clinic.distanceKm != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'clinic_distance_away'.trParams({
                              'distance': clinicDistanceLabel(
                                clinic.distanceKm!,
                              ),
                            }),
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Pressable(
                    onTap: _directions,
                    semanticLabel: 'clinic_directions'.tr,
                    scale: WaddyMotion.pressControl,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.surface,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        border: Border.all(
                          color: WaddyColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: WaddyColors.mint,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'clinic_directions'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: WaddyColors.primary,
                        ),
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

  // ── Sticky bar ────────────────────────────────────────────────────────

  Widget? _bottomBar(BuildContext context) {
    if (!_hasPhone && clinic.whatsapp == null) return null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        children: [
          if (clinic.whatsapp != null)
            Pressable(
              onTap: _chat,
              semanticLabel: 'clinic_whatsapp'.tr,
              scale: WaddyMotion.pressControl,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: WaddyColors.surface,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  border: Border.all(color: WaddyColors.primary, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedWhatsapp,
                      size: 17,
                      color: WaddyColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'clinic_whatsapp'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (clinic.whatsapp != null && _hasPhone)
            const SizedBox(width: Dimensions.paddingSizeSmall),
          if (_hasPhone)
            Expanded(
              child: Pressable(
                onTap: _call,
                semanticLabel: 'clinic_call_clinic'.tr,
                scale: WaddyMotion.pressControl,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: WaddyColors.primary,
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    boxShadow: const [
                      BoxShadow(color: WaddyColors.mint, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCall,
                        size: 17,
                        color: WaddyColors.mint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'clinic_call_clinic'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PIECES
// ═══════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  /// The child handles its own side padding (a horizontal rail).
  final bool flush;

  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.flush = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: waddyBold.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: displayTracking(-0.4),
                  color: WaddyColors.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: waddyRegular.copyWith(
                    fontSize: 12,
                    color: WaddyColors.inkLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        flush
            ? child
            : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: child,
    );
  }
}

class _VetCard extends StatelessWidget {
  final ClinicVet vet;

  const _VetCard({required this.vet});

  @override
  Widget build(BuildContext context) {
    // "Dr. Mona Saleh" → "M": the first letter after a title.
    final String initial =
        vet.name
            .replaceFirst(RegExp(r'^(dr\.?|د\.?)\s*', caseSensitive: false), '')
            .characters
            .first
            .toUpperCase();
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: petWash,
            ),
            child: Center(
              child: Text(
                initial,
                style: waddyBold.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: WaddyColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vet.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: waddyBold.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: WaddyColors.ink,
            ),
          ),
          if (vet.role != null) ...[
            const SizedBox(height: 2),
            Text(
              vet.role!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyRegular.copyWith(
                fontSize: 11,
                color: WaddyColors.inkMid,
              ),
            ),
          ],
          if (vet.years != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: WaddyColors.primarySurface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                'clinic_vet_years'.trParams({'n': '${vet.years}'}),
                style: waddyBold.copyWith(
                  fontSize: 11,
                  color: WaddyColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: primary ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border:
              primary
                  ? null
                  : Border.all(color: WaddyColors.primary, width: 1.5),
          boxShadow:
              primary
                  ? const [
                    BoxShadow(color: WaddyColors.mint, offset: Offset(0, 3)),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              size: 19,
              color: primary ? WaddyColors.mint : WaddyColors.primary,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: waddyBold.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primary ? Colors.white : WaddyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: WaddyMotion.pressControl,
      minSize: Dimensions.minTapTarget,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: WaddyColors.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: WaddyColors.primary),
      ),
    );
  }
}
