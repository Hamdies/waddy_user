import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_list.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/screens/pet_details_screen.dart';
import 'package:waddy_app/features/pets/screens/pet_onboarding_screen.dart';
import 'package:waddy_app/features/pets/widgets/pet_shop_card.dart';
import 'package:waddy_app/features/pets/widgets/pet_usual_card.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/features/pets/widgets/vet_clinic_rail.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

const double _kChipRowHeight = 36;
const double _kChipStripPad = Dimensions.paddingSizeSmall;

/// The Pets module home (Claude Design "Pet Module v2", screen 01).
///
///   hero (deliver-to, cart, search) → your pet → vet clinics nearby →
///   "Pet shops near you" → pinned sort/filter chips → shop rows
///
/// Picking a shop is the job here; browsing products happens inside a shop
/// (`PetStoreScreen`). Shop rows are the same [ModuleStoreRowCard] food and
/// grocery list with, so the rating bar, out-of-zone collapse and offer chips
/// behave the same in every module.
///
/// Returns a SLIVER: it is rendered straight into home's `CustomScrollView`,
/// like `GroceryHomeScreen`.
class PetHubScreen extends StatefulWidget {
  final ScrollController scrollController;

  const PetHubScreen({super.key, required this.scrollController});

  @override
  State<PetHubScreen> createState() => _PetHubScreenState();
}

class _PetHubScreenState extends State<PetHubScreen> {
  PetController get _pets => Get.find<PetController>();

  ModuleStoreFilters get _filters =>
      Get.find<StoreListController>().moduleFilters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The store page builds its species switcher from this; warming it here
    // means a shop opens on a full page instead of a shimmer.
    _pets.getCategories();
    final AddressModel? address = AddressHelper.getUserAddressFromSharedPref();
    final double? lat = double.tryParse(address?.latitude ?? '');
    final double? lng = double.tryParse(address?.longitude ?? '');
    if (lat != null && lng != null) _pets.getClinics(lat, lng);

    await _pets.getPets();
    if (!mounted) return;
    _pets.getUsual();
    // No pet yet: "Meet your pet" opens every time the hub does, until
    // there is one (user call, 10-02). Skip closes it for this visit only.
    if (_pets.needsOnboarding) PetOnboardingScreen.open();
  }

  void _applyFilters(ModuleStoreFilters next) {
    Get.find<StoreListController>().setModuleStoreFilters(next);
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: HomeHeroBannerWidget(showBackButton: true, compact: true),
        ),
        const SliverToBoxAdapter(child: _YourPetCard()),
        const SliverToBoxAdapter(child: PetBirthdayNudge()),
        const SliverToBoxAdapter(child: PetUsualCard()),
        const SliverToBoxAdapter(child: VetClinicRail()),
        SliverToBoxAdapter(child: _shopsHeader()),
        SliverPersistentHeader(
          pinned: true,
          delegate: _ChipsHeader(
            child: GetBuilder<StoreListController>(
              id: StoreListController.storeListId,
              builder: (_) => _chips(),
            ),
          ),
        ),
        _shopList(),
      ],
    );
  }

  Widget _shopsHeader() {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (stores) {
        final int? total = stores.storeModel?.totalSize;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'pet_shops_near_you'.tr,
                style: waddyBold.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: displayTracking(-0.4),
                  color: WaddyColors.ink,
                ),
              ),
              if (total != null && total > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'pet_shops_count'.trParams({'n': '$total'}),
                  style: waddyRegular.copyWith(
                    fontSize: 12,
                    color: WaddyColors.inkLight,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The design's strip: a sort button cycling Nearest → Fastest → Top rated,
  /// then Open now · Free delivery · Offers · 4.7+ rated. Nearest is the
  /// store list's own default order, so it sends no sort.
  Widget _chips() {
    const List<String?> sorts = [null, 'fastest', 'rating'];
    final String? sort = _filters.sort;
    final int sortIndex = sorts.contains(sort) ? sorts.indexOf(sort) : 0;
    final String sortLabel = switch (sorts[sortIndex]) {
      'fastest' => 'fastest'.tr,
      'rating' => 'top_rated'.tr,
      _ => 'nearest'.tr,
    };
    final bool topRated = _filters.minRating != null;

    final List<Widget> chips = [
      _Chip(
        label: sortLabel,
        leading: const HugeIcon(
          icon: HugeIcons.strokeRoundedSorting01,
          size: 14,
          color: WaddyColors.primary,
        ),
        active: false,
        outlined: true,
        onTap:
            () => _applyFilters(
              _filters.copyWith(sort: sorts[(sortIndex + 1) % sorts.length]),
            ),
      ),
      _Chip(
        label: 'pet_filter_open_now'.tr,
        active: _filters.openNow,
        onTap:
            () => _applyFilters(_filters.copyWith(openNow: !_filters.openNow)),
      ),
      _Chip(
        label: 'free_delivery'.tr,
        active: _filters.freeDelivery,
        onTap:
            () => _applyFilters(
              _filters.copyWith(freeDelivery: !_filters.freeDelivery),
            ),
      ),
      _Chip(
        label: 'offers'.tr,
        active: _filters.offers,
        onTap: () => _applyFilters(_filters.copyWith(offers: !_filters.offers)),
      ),
      _Chip(
        label: 'rated_4_7_plus'.tr,
        active: topRated,
        onTap:
            () => _applyFilters(
              _filters.copyWith(minRating: topRated ? null : 4.7),
            ),
      ),
    ];

    return Container(
      // The page's own ground, so the pinned strip doesn't read as a band.
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: _kChipStripPad),
      child: SizedBox(
        height: _kChipRowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          itemCount: chips.length,
          separatorBuilder:
              (_, __) => const SizedBox(width: Dimensions.paddingSizeSmall),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );
  }

  Widget _shopList() {
    return GetBuilder<StoreListController>(
      id: StoreListController.storeListId,
      builder: (stores) {
        final ModuleStoreFilters f = _filters;
        final bool filtered =
            f.offers || f.freeDelivery || f.openNow || f.minRating != null;
        return ModuleStoreListSliver(
          scrollController: widget.scrollController,
          isLastInScrollView: true,
          storeModel: stores.storeModel,
          shimmer: const _ShopListShimmer(),
          emptyIcon: const HugeIcon(
            icon: HugeIcons.strokeRoundedStore01,
            size: 52,
            color: WaddyColors.inkMuted,
          ),
          emptyTitle:
              filtered ? 'no_pet_shops_match'.tr : 'no_pet_shops_yet'.tr,
          emptySubtitle:
              filtered ? 'try_different_filters'.tr : 'no_pet_shops_yet_sub'.tr,
          cardBuilder:
              (store) => PetShopCard(
                store: store,
                onTap: () => StoreNavigator.open(store),
              ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// YOUR PET
// ═══════════════════════════════════════════

/// The hub's personal line. With a pet: their avatar(s) and "Everything Luna
/// needs". Without: the way into "Meet your pet".
class _YourPetCard extends StatelessWidget {
  const _YourPetCard();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PetController>(
      id: PetController.idPets,
      builder: (pets) {
        final List<UserPetModel>? list = pets.pets;
        if (list == null) {
          return const SizedBox(height: Dimensions.paddingSizeMedium);
        }
        final UserPetModel? primary = pets.primaryPet;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child:
              primary == null
                  ? const _MeetYourPetCard()
                  : _PetLine(pets: list, primary: primary),
        );
      },
    );
  }
}

/// The hub's hero line (design screen 01, revised): "Everything Luna needs"
/// on full mint, with the pet pinned beside it as a taped polaroid.
///
/// With more than one pet a second polaroid peeks out behind, and the "+"
/// under the headline adds another. Tapping the polaroid opens the pet.
class _PetLine extends StatelessWidget {
  final List<UserPetModel> pets;
  final UserPetModel primary;

  const _PetLine({required this.pets, required this.primary});

  void _open(UserPetModel pet) =>
      pet.id == null
          // A guest's draft has no row yet, so it reopens the onboarding steps.
          ? PetOnboardingScreen.open(editing: pet)
          : PetDetailsScreen.open(pet);

  @override
  Widget build(BuildContext context) {
    final UserPetModel? second = pets.firstWhereOrNull((p) => p != primary);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WaddyColors.mint,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge + 4),
      ),
      child: Stack(
        children: [
          // Faint paw prints, the design's background motif.
          PositionedDirectional(
            end: 96,
            bottom: -10,
            child: Transform.rotate(
              angle: -0.44,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPawPrint,
                size: 64,
                color: WaddyColors.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
          PositionedDirectional(
            start: -18,
            top: -14,
            child: Transform.rotate(
              angle: 0.35,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPawPrint,
                size: 72,
                color: WaddyColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PetCopy.tr('pet_hub_headline', primary),
                        style: waddyBold.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: displayTracking(-0.6),
                          color: WaddyColors.primary,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeMedium),
                      Pressable(
                        onTap: () => PetOnboardingScreen.open(),
                        semanticLabel: 'add_another_pet'.tr,
                        scale: WaddyMotion.pressControl,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: WaddyColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add,
                                size: 16,
                                color: WaddyColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'add_another_pet'.tr,
                                style: waddyBold.copyWith(
                                  fontSize: 12,
                                  color: WaddyColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                SizedBox(
                  width: 116,
                  height: 140,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (second != null)
                        Transform.translate(
                          offset: const Offset(-10, 4),
                          child: Transform.rotate(
                            angle: -0.12,
                            child: Opacity(
                              opacity: 0.9,
                              child: _Polaroid(
                                pet: second,
                                onTap: () => _open(second),
                                taped: false,
                              ),
                            ),
                          ),
                        ),
                      Transform.rotate(
                        angle: 0.087,
                        child: _Polaroid(
                          pet: primary,
                          onTap: () => _open(primary),
                        ),
                      ),
                    ],
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

/// A taped polaroid of one pet: photo (or species icon on the wash), name
/// under it, a strip of amber tape across the top and the species badge
/// on its corner.
class _Polaroid extends StatelessWidget {
  final UserPetModel pet;
  final VoidCallback onTap;
  final bool taped;

  const _Polaroid({required this.pet, required this.onTap, this.taped = true});

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = pet.photoUrl != null && pet.photoUrl!.isNotEmpty;
    final Widget glyph = Center(
      child: HugeIcon(
        icon: pet.species.icon,
        size: 40,
        color: WaddyColors.primary,
      ),
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: 'edit_pet'.trParams({'name': pet.name}),
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusDefault + 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault - 2,
                    ),
                    child: SizedBox(
                      height: 88,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(gradient: petWash),
                        child:
                            hasPhoto
                                ? CustomImage(
                                  image: pet.photoUrl!,
                                  fit: BoxFit.cover,
                                  fallback: glyph,
                                )
                                : glyph,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: waddyBold.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (taped)
              Positioned(
                top: -8,
                left: 28,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Container(
                    width: 44,
                    height: 16,
                    decoration: BoxDecoration(
                      color: WaddyColors.amber.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            if (taped)
              Positioned(
                right: -10,
                bottom: 22,
                child: Transform.rotate(
                  angle: -0.21,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: WaddyColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: WaddyColors.surface, width: 2),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: pet.species.icon,
                        size: 16,
                        color: WaddyColors.mint,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeetYourPetCard extends StatelessWidget {
  const _MeetYourPetCard();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => PetOnboardingScreen.open(),
      semanticLabel: 'meet_your_pet_cta'.tr,
      scale: WaddyMotion.pressCard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: petWash,
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge - 4),
        ),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedPawPrint,
              size: 34,
              color: WaddyColors.primary,
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'meet_your_pet_title'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'meet_your_pet_sub'.tr,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: WaddyColors.inkMid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Text(
                'meet_your_pet_cta'.tr,
                style: waddyBold.copyWith(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// CHIPS
// ═══════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final bool outlined;
  final Widget? leading;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.outlined = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                active || outlined ? WaddyColors.primary : WaddyColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: waddyBold.copyWith(
                fontSize: 12,
                color: active ? Colors.white : WaddyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _ChipsHeader({required this.child});

  static const double _height = _kChipRowHeight + _kChipStripPad * 2;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _ChipsHeader oldDelegate) =>
      oldDelegate.child != child;
}

class _ShopListShimmer extends StatelessWidget {
  const _ShopListShimmer();

  /// Shaped like [PetShopCard]: cover, then the name/meta lines.
  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WaddyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(
              bottom: Dimensions.paddingSizeMedium,
            ),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 132,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  bar(160, 16),
                  const SizedBox(height: 6),
                  bar(220, 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
