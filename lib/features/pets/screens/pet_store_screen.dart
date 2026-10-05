import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/store/widgets/store_page_shimmer.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/cart/widgets/pill_cart_bar.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/pet_category_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/screens/pet_onboarding_screen.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/features/store/controllers/store_page_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_category_items_screen.dart';
import 'package:waddy_app/features/store/widgets/filter_widget.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/features/store/widgets/store_info_sheet.dart';
import 'package:waddy_app/features/store/widgets/store_notices.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/features/store/widgets/store_section_header.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// Who the page is shopping for: one of the customer's pets, or a species
/// nobody in the household is (yet).
class _Shopper {
  final PetSpecies species;
  final UserPetModel? pet;

  const _Shopper(this.species, [this.pet]);

  String get key =>
      pet == null ? 'species_${species.wire}' : 'pet_${pet!.id ?? pet!.name}';
}

/// A pet shop's page (Claude Design "Pet Module v2", screen 02).
///
/// ```
///   header        store, search, filter         (shared with every store page)
///   Shop for X    the household's pets, then the other species, and under
///                 them the species' needs as tiles → the category page
///   Popular       best sellers for the species
///   Treat time    the species' treats, on amber
///   care          litter / grooming / cage or tank care
///   Every pet     the "All pets" shelf: bowls, carriers… (D3)
/// ```
///
/// A shelf of fewer than [_kMinCards] items is shown as rows rather than a
/// rail of one lonely card, and the shelves under Popular skip what Popular
/// already shows.
///
/// Built from the specialty page's parts. The categories are the module's
/// shared species tree (`/pets/categories`), not the store's own, so one
/// switcher works the same in every shop (PET-02).
class PetStoreScreen extends StatefulWidget {
  final Store? store;
  final String slug;

  const PetStoreScreen({super.key, required this.store, this.slug = ''});

  @override
  State<PetStoreScreen> createState() => _PetStoreScreenState();
}

class _PetStoreScreenState extends State<PetStoreScreen> {
  final ScrollController _scroll = ScrollController();
  late final StorePageController _page;

  double _cartBarHeight = 0;
  final ValueNotifier<bool> _mini = ValueNotifier<bool>(false);
  static const double _kMiniHeaderAt = 120;

  PetController get _pets => Get.find<PetController>();

  @override
  void initState() {
    super.initState();
    _page = StorePageController.open();
    _scroll.addListener(_onScroll);
    _initDataCall();
  }

  @override
  void dispose() {
    _page.close();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _mini.dispose();
    super.dispose();
  }

  Future<void> _initDataCall() async {
    _page.resetFilter(isUpdate: false);
    _page.resetStoreRails(notify: false);
    if (_page.isSearching) _page.changeSearchStatus(isUpdate: false);
    _pets.getCategories();
    _pets.getPets();
    await _page.getStoreDetails(Store(id: widget.store!.id), slug: widget.slug);
    final int? storeId = widget.store!.id ?? _page.store?.id;
    if (storeId == null) return;
    // First page only: the filter sheet reads its price ceiling from it.
    _page.getStoreItemList(storeId, 1, 'all', false);
  }

  void _onScroll() {
    final bool mini = _scroll.offset > _kMiniHeaderAt;
    if (mini != _mini.value) _mini.value = mini;
  }

  /// The household's pets first, then every species none of them is.
  List<_Shopper> _options(List<UserPetModel> household) {
    final Set<PetSpecies> owned = {for (final p in household) p.species};
    return [
      for (final p in household) _Shopper(p.species, p),
      for (final s in PetSpecies.values)
        if (!owned.contains(s)) _Shopper(s),
    ];
  }

  /// The last pick (remembered across shops by [PetController.shopperKey]),
  /// else the primary pet, else cats.
  _Shopper _current(List<_Shopper> options) {
    final String? key = _pets.shopperKey;
    if (key != null) {
      final _Shopper? picked = options.firstWhereOrNull((o) => o.key == key);
      if (picked != null) return picked;
    }
    final UserPetModel? primary = _pets.primaryPet;
    return primary == null
        ? const _Shopper(PetSpecies.cat)
        : _Shopper(primary.species, primary);
  }

  void _pick(_Shopper s) => setState(() => _pets.shopperKey = s.key);

  Future<void> _addPet() async {
    await PetOnboardingScreen.open();
    if (!mounted) return;
    // A pet just added takes the page over from whatever was browsed.
    if ((_pets.pets ?? const []).isNotEmpty) {
      setState(() => _pets.shopperKey = null);
    }
  }

  /// What the headings call the shopper: the pet's name, or the species'
  /// category name ("Cats") when it is not one of the household's.
  String _shopperName(_Shopper s, PetCategoryModel? speciesCat) =>
      s.pet?.name ?? speciesCat?.name ?? s.species.label;

  void _openCategory(PetCategoryModel main, {PetCategoryModel? need}) {
    final int index =
        _page.categoryList?.indexWhere((c) => c.id == main.id) ?? -1;
    final int? storeId = _page.store?.id;
    if (index < 0 || storeId == null) return;
    _page.setCategoryIndex(index);
    Get.to(
      () => StoreCategoryItemsScreen(
        page: _page,
        storeId: storeId,
        categoryName: need?.name ?? main.name,
        initialSubCategoryId: need?.id,
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    final double maxPrice = (_page.storeItemModel?.items ?? []).fold<double>(
      0,
      (prev, item) => (item.price ?? 0) > prev ? item.price! : prev,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => FilterWidget(
            page: _page,
            maxValue: maxPrice > 0 ? maxPrice : 1000,
          ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: GetBuilder<StorePageController>(
        tag: _page.tag,
        builder: (page) {
          final Store? store = page.store?.name != null ? page.store : null;
          if (store == null)
            return StorePageShimmer(
              layout: StorePageShimmerLayout.specialty,
              store: widget.store,
            );
          return GetBuilder<PetController>(
            id: PetController.idCategories,
            builder: (pets) {
              final List<PetCategoryModel>? tree = pets.categories;
              if (tree != null) {
                page.useCategories([for (final c in tree) c.toCategoryModel()]);
              }
              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _initDataCall,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: StoreHeroBannerWidget(
                            store: store,
                            onStoreTap:
                                () => StoreInfoSheet.show(context, store),
                            onFilterTap: () => _openFilterSheet(context),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: StoreDiscountBanner(store: store),
                        ),
                        SliverToBoxAdapter(
                          child: StoreAnnouncement(store: store),
                        ),
                        SliverToBoxAdapter(
                          child: GetBuilder<PetController>(
                            id: PetController.idPets,
                            builder: (_) => _body(store, tree),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                _cartBarHeight +
                                Dimensions.paddingSizeExtraLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.paddingOf(context).top,
                    child: ColoredBox(
                      color: HomeHeroBannerWidget.statusBarTint,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _mini,
                      builder:
                          (context, visible, _) =>
                              StoreMiniHeader(store: store, visible: visible),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PillCartBar(
                      store: store,
                      onHeightChanged: (h) {
                        if (!mounted || (h - _cartBarHeight).abs() < 0.5) {
                          return;
                        }
                        setState(() => _cartBarHeight = h);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(Store store, List<PetCategoryModel>? tree) {
    final List<UserPetModel> household = _pets.pets ?? const [];
    final List<_Shopper> options = _options(household);
    final _Shopper shopper = _current(options);
    final PetCategoryModel? speciesCat = _pets.speciesCategory(shopper.species);
    final String name = _shopperName(shopper, speciesCat);
    // No pet and nothing picked: the cats on show are a default, not a
    // guess about the customer, so the heading doesn't claim them.
    final bool browsing = household.isEmpty && _pets.shopperKey == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSectionHeader(
          title:
              browsing
                  ? 'pet_store_shop_by_pet'.tr
                  : 'pet_store_shop_for'.trParams({'name': name}),
          padding: const EdgeInsetsDirectional.fromSTEB(
            Dimensions.paddingSizeLarge,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeLarge,
            Dimensions.paddingSizeMedium,
          ),
        ),
        _switcher(options, shopper, showAddPet: household.isEmpty),
        if (tree == null)
          const _NeedsShimmer()
        else if (speciesCat != null) ...[
          _needsGrid(speciesCat),
          _speciesShelves(store, shopper, speciesCat, name),
        ],
        if (tree != null && _pets.allPetsCategory != null)
          _everyPet(_pets.allPetsCategory!),
      ],
    );
  }

  // ── Shop for ──────────────────────────────────────────────────────────

  Widget _switcher(
    List<_Shopper> options,
    _Shopper current, {
    required bool showAddPet,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAddPet) _AddPetChip(onTap: _addPet),
          for (final _Shopper o in options)
            _ShopperChip(
              shopper: o,
              label:
                  o.pet?.name ??
                  _pets.speciesCategory(o.species)?.name ??
                  o.species.label,
              selected: o.key == current.key,
              onTap: () => _pick(o),
            ),
        ],
      ),
    );
  }

  // ── Needs grid ────────────────────────────────────────────────────────

  static const int _kNeedColumns = 4;

  /// Explicit rows rather than a [GridView]: a nested scroll view pads
  /// itself with the safe-area insets, which opened a ~60pt hole above the
  /// tiles on a notched iPhone. Every tile is the same square, with two
  /// label lines reserved under it at the viewer's text scale, so a
  /// two-line "Treats & chews" cannot shrink its square or drop its top.
  Widget _needsGrid(PetCategoryModel species) {
    final List<PetCategoryModel> needs =
        species.children.take(_kNeedColumns * 2 - 1).toList();
    final double labelHeight =
        MediaQuery.textScalerOf(context).scale(_NeedTile.labelSize) *
        _NeedTile.labelLineHeight *
        2;
    final List<Widget> tiles = [
      for (final PetCategoryModel need in needs)
        _NeedTile(
          label: need.name,
          imageUrl: need.imageUrl,
          icon: _needIcon(need.need, species.species),
          labelHeight: labelHeight,
          onTap: () => _openCategory(species, need: need),
        ),
      _NeedTile(
        label: 'see_all'.tr,
        icon: HugeIcons.strokeRoundedDashboardSquare02,
        labelHeight: labelHeight,
        navigates: true,
        onTap: () => _openCategory(species),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: Column(
        children: [
          for (int r = 0; r < tiles.length; r += _kNeedColumns) ...[
            if (r > 0) const SizedBox(height: Dimensions.paddingSizeMedium),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < _kNeedColumns; c++) ...[
                  if (c > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child:
                        r + c < tiles.length
                            ? tiles[r + c]
                            : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Stand-ins until the need tiles have art (PET-15). Keyed on the need
  /// part of the seeded code, so a renamed category keeps its picture.
  /// The species paw is kept off every need: it is what a dog *is* here,
  /// so a paw on "Leads & collars" read as a second "all dog things".
  static List<List<dynamic>> _needIcon(String need, PetSpecies? species) =>
      switch (need) {
        'food' =>
          species == PetSpecies.bird
              ? HugeIcons.strokeRoundedWheat
              : HugeIcons.strokeRoundedRiceBowl01,
        'treats' =>
          species == PetSpecies.dog
              ? HugeIcons.strokeRoundedBone01
              : HugeIcons.strokeRoundedCookie,
        'litter' => HugeIcons.strokeRoundedBrushCleaning,
        'toys' => HugeIcons.strokeRoundedTennisBall,
        'beds' => HugeIcons.strokeRoundedBed,
        'grooming' => HugeIcons.strokeRoundedShampoo,
        'health' => HugeIcons.strokeRoundedStethoscope,
        'walk' => HugeIcons.strokeRoundedNecklace,
        'cages' => HugeIcons.strokeRoundedHome01,
        'care' => HugeIcons.strokeRoundedClean,
        'tanks' => HugeIcons.strokeRoundedFish,
        'bedding' => HugeIcons.strokeRoundedPillow,
        'bowls' => HugeIcons.strokeRoundedRiceBowl01,
        'travel' => HugeIcons.strokeRoundedLuggage01,
        'cleaning' => HugeIcons.strokeRoundedBrushCleaning,
        'accessories' => HugeIcons.strokeRoundedRibbon,
        _ => HugeIcons.strokeRoundedTags,
      };

  // ── Species shelves ───────────────────────────────────────────────────

  /// Below this a shelf is rows, not a rail: one card on a rail left two
  /// thirds of the screen empty under a full-size heading.
  static const int _kMinCards = 3;

  /// Rows a row-shelf shows before "See all".
  static const int _kMaxRows = 4;

  /// Which need is this species' "care" shelf: litter for a cat, grooming
  /// for a dog, cage or tank care, bedding for a hamster.
  static const Map<PetSpecies, String> _careNeed = {
    PetSpecies.cat: 'litter',
    PetSpecies.dog: 'grooming',
    PetSpecies.bird: 'care',
    PetSpecies.fish: 'care',
    PetSpecies.small: 'bedding',
  };

  Widget _speciesShelves(
    Store store,
    _Shopper shopper,
    PetCategoryModel species,
    String name,
  ) {
    final String wire = shopper.species.wire;
    final String bestKey = 'best_$wire';
    final PetCategoryModel? treats = species.child('treats');
    final PetCategoryModel? care = species.child(_careNeed[shopper.species]!);
    final UserPetModel? pet = shopper.pet;

    // Best sellers first; the shelves under it wait for it so they can
    // leave out what it already shows (Popular spans the whole species,
    // treats included). Its empty state speaks for the whole species: if
    // nothing sells under Cats, nothing is stocked under Cats.
    return _rail(
      bestKey,
      categoryId: species.id,
      sort: 'popular',
      placeholder: const _RailShimmer(),
      empty: _SpeciesEmpty(species: shopper.species, name: species.name),
      failed:
          () => _RailRetry(
            onRetry:
                () => _page.retryStoreRail(
                  bestKey,
                  categoryId: species.id,
                  sort: 'popular',
                ),
          ),
      builder: (popular) {
        final Set<int?> shown = {for (final Item i in popular) i.id};
        List<Item> fresh(List<Item> items) =>
            items.where((i) => !shown.contains(i.id)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shelf(
              key: bestKey,
              title: 'pet_store_best_for'.trParams({'name': name}),
              subtitle: 'most_ordered_at_sub'.trParams({
                'store': store.name ?? '',
              }),
              items: popular,
            ),
            if (treats != null)
              _rail(
                'treats_$wire',
                categoryId: treats.id,
                builder: (items) {
                  final List<Item> left = fresh(items);
                  if (left.isEmpty) return const SizedBox.shrink();
                  return _treatPanel(
                    subtitle:
                        pet != null
                            ? PetCopy.tr('pet_store_treat_sub', pet)
                            : 'pet_store_treat_sub_species'.trParams({
                              'species': species.name,
                            }),
                    items: left,
                  );
                },
              ),
            if (care != null)
              _rail(
                'care_$wire',
                categoryId: care.id,
                builder: (items) {
                  final List<Item> left = fresh(items);
                  if (left.isEmpty) return const SizedBox.shrink();
                  return _shelf(
                    key: 'care_$wire',
                    title: care.name,
                    items: left,
                    onSeeAll: () => _openCategory(species, need: care),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _everyPet(PetCategoryModel all) {
    return _rail(
      'all_pets',
      categoryId: all.id,
      builder:
          (items) => _shelf(
            key: 'all_pets',
            title: 'pet_store_every_pet'.tr,
            subtitle: 'pet_store_every_pet_sub'.tr,
            items: items,
            onSeeAll: () => _openCategory(all),
          ),
    );
  }

  /// One shelf fed by [StorePageController.fetchStoreRail]: fetched when
  /// first built, rebuilt alone when it lands, [empty] (default: nothing)
  /// when the shop has nothing for it, [failed] (default: [empty]) when
  /// the fetch did not come back.
  Widget _rail(
    String key, {
    required int categoryId,
    String? sort,
    Widget placeholder = const SizedBox.shrink(),
    Widget empty = const SizedBox.shrink(),
    Widget Function()? failed,
    required Widget Function(List<Item> items) builder,
  }) {
    return GetBuilder<StorePageController>(
      tag: _page.tag,
      id: StorePageController.storeRailId(key),
      builder: (page) {
        final List<Item>? items = page.storeRail(key);
        if (items == null) {
          // Post-frame: the fetch notifies, and a notify mid-build throws.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => page.fetchStoreRail(key, categoryId: categoryId, sort: sort),
          );
          return placeholder;
        }
        if (items.isEmpty) {
          return failed != null && page.storeRailFailed(key) ? failed() : empty;
        }
        return builder(items);
      },
    );
  }

  /// "See all" only when there is more than the shelf shows: the backend's
  /// total when it sent one, else whether the page came back full.
  bool _hasMore(String key, int shown) {
    final int total =
        _page.storeRailTotal(key) ?? _page.storeRail(key)?.length ?? 0;
    return total > shown;
  }

  /// A titled shelf: a card rail when there are enough items to fill one,
  /// else up to [_kMaxRows] full-width rows.
  Widget _shelf({
    required String key,
    required String title,
    String? subtitle,
    required List<Item> items,
    VoidCallback? onSeeAll,
  }) {
    final bool asCards = items.length >= _kMinCards;
    final List<Item> visible = asCards ? items : items.take(_kMaxRows).toList();
    final bool seeAll = onSeeAll != null && _hasMore(key, visible.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSectionHeader(
          title: title,
          subtitle: subtitle,
          action: seeAll ? 'see_all'.tr : null,
          onAction: seeAll ? onSeeAll : null,
        ),
        if (asCards)
          _cards(visible, padding: Dimensions.paddingSizeLarge)
        else
          _rows(visible),
      ],
    );
  }

  Widget _cards(
    List<Item> items, {
    required double padding,
    bool bordered = true,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(
        padding,
        0,
        padding,
        Dimensions.paddingSizeExtraSmall,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
              StoreProductCard(
                key: ValueKey<int?>(items[i].id),
                item: items[i],
                bordered: bordered,
                onOpen: () => MartProductScreen.open(items[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rows(
    List<Item> items, {
    double padding = Dimensions.paddingSizeDefault,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: Dimensions.paddingSizeSmall),
            StoreMenuRow(
              key: ValueKey<int?>(items[i].id),
              item: items[i],
              onOpen: () => MartProductScreen.open(items[i]),
            ),
          ],
        ],
      ),
    );
  }

  /// "Treat time": the treats shelf on amber, the one warm panel on the
  /// page, so the impulse buy stands apart from the staples.
  Widget _treatPanel({required String subtitle, required List<Item> items}) {
    final bool asCards = items.length >= _kMinCards;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeExtremeLarge,
        Dimensions.paddingSizeMedium,
        0,
      ),
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeMedium),
      decoration: BoxDecoration(
        color: WaddyColors.amberSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoreSectionHeader(
            title: 'pet_store_treat_time'.tr,
            subtitle: subtitle,
            padding: const EdgeInsetsDirectional.fromSTEB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeLarge,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeMedium,
            ),
          ),
          if (asCards)
            _cards(
              items,
              padding: Dimensions.paddingSizeMedium,
              bordered: false,
            )
          else
            _rows(
              items.take(_kMaxRows).toList(),
              padding: Dimensions.paddingSizeMedium,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PIECES
// ═══════════════════════════════════════════

const double _kChipWidth = 80;
const double _kAvatarSize = 64;

class _ShopperChip extends StatelessWidget {
  final _Shopper shopper;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopperChip({
    required this.shopper,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: _kChipWidth,
        child: Column(
          children: [
            PetAvatar(
              species: shopper.species,
              photoUrl: shopper.pet?.photoUrl,
              size: _kAvatarSize,
              ringed: selected,
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            _ChipLabel(label, selected: selected),
          ],
        ),
      ),
    );
  }
}

/// The switcher's first chip for a customer with no pet: the page's
/// "for Loky" only works once there is a Loky.
class _AddPetChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPetChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String label = 'pet_store_add_pet'.tr;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: _kChipWidth,
        child: Column(
          children: [
            Container(
              width: _kAvatarSize,
              height: _kAvatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WaddyColors.mintSurface,
                border: Border.all(color: WaddyColors.primary, width: 1.5),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: 26,
                  color: WaddyColors.primary,
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            _ChipLabel(label, selected: true),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;
  final bool selected;

  const _ChipLabel(this.text, {required this.selected});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: waddyBold.copyWith(
        fontSize: Dimensions.fontSizeExtraSmall,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? WaddyColors.primary : WaddyColors.inkMid,
      ),
    );
  }
}

class _NeedTile extends StatelessWidget {
  static const double labelSize = 12;
  static const double labelLineHeight = 1.25;

  final String label;
  final String? imageUrl;
  final List<List<dynamic>> icon;

  /// Two label lines at the viewer's text scale, the same for every tile,
  /// so the squares above them line up across the row.
  final double labelHeight;

  /// "See all": deep teal, so it reads as a way out of the grid rather
  /// than one more category.
  final bool navigates;
  final VoidCallback onTap;

  const _NeedTile({
    required this.label,
    required this.icon,
    required this.labelHeight,
    required this.onTap,
    this.imageUrl,
    this.navigates = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressTile,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: navigates ? null : petWash,
                color: navigates ? WaddyColors.primary : null,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  hasImage
                      ? CustomImage(
                        image: imageUrl!,
                        fit: BoxFit.contain,
                        fallback: _glyph(),
                      )
                      : _glyph(),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          SizedBox(
            height: labelHeight,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: labelSize,
                height: labelLineHeight,
                color: navigates ? WaddyColors.primary : WaddyColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glyph() => Center(
    child: HugeIcon(
      icon: icon,
      size: 30,
      color: navigates ? WaddyColors.mint : WaddyColors.primary,
    ),
  );
}

class _SpeciesEmpty extends StatelessWidget {
  final PetSpecies species;
  final String name;

  const _SpeciesEmpty({required this.species, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtremeLarge,
        Dimensions.paddingSizeDefault,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeExtraLarge,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider, width: 1.5),
      ),
      child: Column(
        children: [
          HugeIcon(icon: species.icon, size: 36, color: WaddyColors.primary),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          Text(
            'pet_store_species_empty'.trParams({'species': name}),
            textAlign: TextAlign.center,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: WaddyColors.ink,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            'pet_store_species_empty_sub'.tr,
            textAlign: TextAlign.center,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: WaddyColors.inkLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Popular's fetch did not come back. Without this the page's main shelf
/// vanished and read as "this shop sells nothing for cats".
class _RailRetry extends StatelessWidget {
  final VoidCallback onRetry;

  const _RailRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtremeLarge,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'pet_store_rail_failed'.tr,
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: WaddyColors.inkMid,
              ),
            ),
          ),
          Pressable(
            onTap: onRetry,
            semanticLabel: 'retry'.tr,
            minSize: Dimensions.minTapTarget,
            child: Text(
              'retry'.tr,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: WaddyColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for a loading shelf at the loaded shelf's size: the section
/// header's padding and two text lines, then a rail of cards.
class _RailShimmer extends StatelessWidget {
  const _RailShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Dimensions.paddingSizeExtremeLarge,
        bottom: Dimensions.paddingSizeExtraSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(width: 160, height: 20),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                _Bar(width: 220, height: 12),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          // Scrolls like the rail it stands in for: three cards are wider
          // than a phone.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeLarge,
            ),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
                  const _Bar(width: StoreProductCard.width, height: 200),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsShimmer extends StatelessWidget {
  const _NeedsShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: Dimensions.paddingSizeSmall),
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Bar(width: double.infinity, height: double.infinity),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;

  const _Bar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WaddyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(
          height < 40 ? Dimensions.radiusExtraSmall : Dimensions.radiusLarge,
        ),
      ),
    );
  }
}
