import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/home/widgets/home_hero_banner_widget.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/features/store/helpers/pack_size.dart';
import 'package:waddy_app/features/store/helpers/shelf_listings.dart';
import 'package:waddy_app/features/store/widgets/store_section_header.dart';
import 'package:waddy_app/features/store/widgets/store_product_card.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// A supermarket product's own page (Claude Design "Mart Product Screens"):
/// photo, name, price, the size to pick, what it is, and what goes with it,
/// over one bar that holds the quantity and the add.
///
/// ```
///   ‹                          ♡  🛍      mint field (store header), photo on a white plate
///   [   photo   ]
///   [30% off] collar on the plate, as on the cards
///   Double chocolate cream biscuits
///   108 g
///   EGP 15    ̶3̶0̶   Save EGP 15
///   Size                                 one tile per variation, two to a row
///   [250 ml     ] [1 L        ]
///   [EGP 15     ] [EGP 52     ]
///   About this item
///   You might also need                  mint aisle panel, 2-column grid
///   ─────────────────────────────────
///   [ − 1 + ]  [ Add to cart · EGP 15 ]
/// ```
///
/// Everything comes from the list item already in hand — choice options,
/// variations, `prepOption` — so it opens with no details fetch. Items with
/// add-ons or food-style variations aren't carried here; [open] sends them to
/// the full item page.
class MartProductScreen extends StatefulWidget {
  final Item item;

  const MartProductScreen({super.key, required this.item});

  /// Whether this page can sell [item]: no add-ons, no food variations.
  static bool supports(Item item) =>
      (item.addOns?.isEmpty ?? true) && (item.foodVariations?.isEmpty ?? true);

  /// Whether taps on [item] belong here: a grocery-family item this page can
  /// carry. Food, pharmacy and e-commerce keep their own pages. A payload
  /// that names no module type counts as grocery — the surfaces that call
  /// [open] are the grocery ones.
  static bool handles(Item item) {
    final ModuleType type = ModuleType.of(item.moduleType);
    return (type == ModuleType.grocery ||
            type == ModuleType.pets ||
            type == ModuleType.unknown) &&
        supports(item);
  }

  /// Opens [item]'s page — this one, or the full item page when this one
  /// can't carry it (add-ons, food variations, another module's item).
  static Future<void> open(Item item) async {
    if (!handles(item)) {
      await Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, true));
      return;
    }
    await Get.toNamed(
      RouteHelper.getMartProductRoute(item.id),
      arguments: MartProductScreen(item: item),
    );
  }

  @override
  State<MartProductScreen> createState() => _MartProductScreenState();
}

class _MartProductScreenState extends State<MartProductScreen> {
  late final List<ChoiceOptions> _choices =
      (widget.item.choiceOptions ?? const <ChoiceOptions>[])
          .where((c) => (c.options ?? const []).isNotEmpty)
          .toList();

  /// The picked option per choice; starts on the first one in stock.
  late final List<int> _picked = [
    for (int i = 0; i < _choices.length; i++) _firstAvailable(i),
  ];

  String? _preference;
  int _quantity = 1;

  /// Amber outline on the produce question after a refused add.
  bool _nudge = false;

  /// "Added ✓" on the button for a beat before the page closes.
  bool _added = false;

  Item get _item => widget.item;

  /// Other products from this store: its own category first, topped up from
  /// the whole store. Null until fetched.
  List<Item>? _related;

  /// The whole page is a skeleton until the rail lands, so the page arrives
  /// in one piece instead of the item first and an empty panel after. Capped
  /// at [_kSkeletonCap]: a slow rail must not hold the product hostage —
  /// past it the page shows, and the rail keeps its own placeholder.
  bool _skeleton = true;
  static const Duration _kSkeletonCap = Duration(milliseconds: 900);

  final ScrollController _scroll = ScrollController();

  /// Whether the hero's controls have scrolled away and the bar shows.
  final ValueNotifier<bool> _showScrolledHeader = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadRelated().whenComplete(_endSkeleton);
    Future<void>.delayed(_kSkeletonCap, _endSkeleton);
  }

  void _endSkeleton() {
    if (mounted && _skeleton) setState(() => _skeleton = false);
  }

  void _onScroll() {
    // Shows once the plate's top edge passes under the bar.
    _showScrolledHeader.value = _scroll.offset > 120;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _showScrolledHeader.dispose();
    super.dispose();
  }

  Future<void> _loadRelated() async {
    final int? storeId = _item.storeId;
    if (storeId == null) {
      _related = const [];
      return;
    }
    final StoreServiceInterface stores = Get.find<StoreServiceInterface>();
    final List<Item> found = [];
    void take(List<Item>? items) {
      for (final Item i in items ?? const <Item>[]) {
        if (i.id != _item.id &&
            MartProductScreen.handles(i) &&
            found.every((f) => f.id != i.id)) {
          found.add(i);
        }
      }
    }

    try {
      if (_item.categoryId != null) {
        take(
          (await stores.getStoreItemList(
            storeID: storeId,
            offset: 1,
            categoryID: _item.categoryId,
            type: 'all',
          ))?.items,
        );
      }
      if (found.length < 6 && mounted) {
        take(
          (await stores.getStoreItemList(
            storeID: storeId,
            offset: 1,
            // The endpoint requires a category; 0 is its "all of them".
            // Null goes out as the string "null" and matches nothing.
            categoryID: 0,
            type: 'all',
          ))?.items,
        );
      }
    } catch (_) {
      // The rail is a nicety; a failed fetch leaves the page without it.
    }
    // The same product listed twice (an unlinked copy beside the catalogue
    // one) must not show up as "something else" on its own page.
    final String self = (_item.name ?? '').trim().toLowerCase();
    final List<Item> others =
        ShelfListings.dedupe(found)
            .where(
              (i) =>
                  (i.name ?? '').trim().toLowerCase() != self &&
                  (_item.catalogProductId == null ||
                      i.catalogProductId != _item.catalogProductId),
            )
            .toList();
    if (mounted) setState(() => _related = others.take(6).toList());
  }

  bool get _tracksStock =>
      Get.find<SplashController>().configModel.moduleConfig?.module?.stock ??
      false;

  bool get _asks => ProducePreference.asks(_item.prepOption);

  /// The backend's variation key: the picked options, spaces removed,
  /// joined by "-".
  String _typeFor(List<int> picked) => [
    for (int i = 0; i < _choices.length; i++)
      _choices[i].options![picked[i]].replaceAll(' ', ''),
  ].join('-');

  Variation? _variationFor(List<int> picked) {
    if (_choices.isEmpty) return null;
    final String type = _typeFor(picked);
    for (final Variation v in _item.variations ?? const <Variation>[]) {
      if (v.type == type) return v;
    }
    return null;
  }

  Variation? get _variation => _variationFor(_picked);

  int _firstAvailable(int choice) {
    if (_choices.length != 1) return 0;
    for (int o = 0; o < _choices[choice].options!.length; o++) {
      if (!_soldOut(_variationFor([o]))) return o;
    }
    return 0;
  }

  bool _soldOut(Variation? v) =>
      _tracksStock && v != null && (v.stock ?? 0) <= 0;

  bool get _itemSoldOut =>
      _tracksStock &&
      (_choices.isEmpty ? (_item.stock ?? 0) <= 0 : _soldOut(_variation));

  int? get _stock => _variation != null ? _variation!.stock : _item.stock;

  double get _unitPrice => ItemPrice.of(_item, base: _variation?.price).now;

  void _changeQuantity(int delta) {
    final int next = _quantity + delta;
    if (next < 1) return;
    final int? limit = _item.quantityLimit;
    if (limit != null && limit > 0 && next > limit) {
      showCustomSnackBar(
        '${'maximum_quantity_limit'.tr} $limit',
        getXSnackBar: true,
      );
      return;
    }
    if (_tracksStock && next > (_stock ?? 0)) {
      showCustomSnackBar('out_of_stock'.tr, getXSnackBar: true);
      return;
    }
    setState(() => _quantity = next);
  }

  Future<void> _add() async {
    if (_added) return;
    if (_asks && _preference == null) {
      setState(() => _nudge = true);
      showCustomSnackBar(
        'choose_prep_${_item.prepOption}'.tr,
        getXSnackBar: true,
      );
      return;
    }
    if (_choices.isNotEmpty && _variation == null) {
      showCustomSnackBar('out_of_stock'.tr, getXSnackBar: true);
      return;
    }
    // Zone first: the add below can reach a clear-your-basket dialog, and an
    // impossible add must not cost someone their cart.
    if (await Get.find<CartController>().blockedOutOfZone()) return;
    if (!mounted) return;
    Get.find<ItemController>().addLineToCart(
      _item,
      variation: _variation,
      preference: _asks ? _preference : null,
      quantity: _quantity,
    );
    setState(() => _added = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Get.back();
  }

  void _toggleFavourite(bool isFav) {
    if (!AuthHelper.isLoggedIn()) {
      showCustomSnackBar('you_are_not_logged_in'.tr);
      return;
    }
    final FavouriteController favourites = Get.find<FavouriteController>();
    if (isFav) {
      favourites.removeFromFavouriteList(_item.id, false);
    } else {
      favourites.addToFavouriteList(_item, null, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? description = _description();
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: WaddyMotion.fast,
                    child:
                        _skeleton
                            ? const _PageSkeleton(key: ValueKey('skeleton'))
                            : SingleChildScrollView(
                              key: const ValueKey('page'),
                              controller: _scroll,
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _hero(context),
                                  _titleBlock(),
                                  if (description != null) _about(description),
                                  for (int i = 0; i < _choices.length; i++)
                                    _choiceGroup(i),
                                  if (_asks) _preferenceGroup(),
                                  _similar(),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeExtraLarge,
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
                // Back stays reachable while the skeleton shows.
                if (_skeleton)
                  PositionedDirectional(
                    top:
                        MediaQuery.paddingOf(context).top +
                        Dimensions.paddingSizeSmall,
                    start: Dimensions.paddingSizeDefault,
                    end: Dimensions.paddingSizeDefault,
                    child: _controls(),
                  )
                else
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _scrolledHeader(context),
                  ),
              ],
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  /// The description, tags stripped. Shown even when it repeats the name —
  /// the page should never look like it has no description to give.
  String? _description() {
    final String text =
        (_item.description ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return text.isEmpty ? null : text;
  }

  // ── Hero ──────────────────────────────────────────────────────────────

  /// The store header's mint field (same gradient, so the product page reads
  /// as a step into the store, not a different app), with the photo on a
  /// white plate floating over it. The plate, not a tint on the photo: a
  /// multiply would make product colour lie — meat, produce, packaging.
  Widget _hero(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Container(
      height: 340 + top,
      decoration: BoxDecoration(gradient: StoreHeroBannerWidget.gradient),
      child: Stack(
        children: [
          Positioned.fill(
            top: top + 64,
            left: Dimensions.paddingSizeDefault,
            right: Dimensions.paddingSizeDefault,
            bottom: Dimensions.paddingSizeExtraSmall,
            child: Container(
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: WaddyColors.shadowTeal,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _itemSoldOut ? 0.45 : 1,
                      child: CustomImage(
                        image: _item.imageFullUrl ?? '',
                        variants: _item.imageVariants,
                        fit: BoxFit.contain,
                        decodeWidth: 720,
                      ),
                    ),
                  ),
                  // The cards' sale collar, so "on sale" looks the same here
                  // as on the shelf the shopper came from.
                  if (!_itemSoldOut)
                    OfferCollarBadge.itemCorner(
                      _item,
                      base: _variation?.price,
                      top: -4,
                      start: -4,
                    ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: top + Dimensions.paddingSizeSmall,
            start: Dimensions.paddingSizeDefault,
            end: Dimensions.paddingSizeDefault,
            child: _controls(),
          ),
        ],
      ),
    );
  }

  /// Back · heart · basket over the hero.
  Widget _controls() {
    return Row(
      children: [
        _backButton(),
        const Spacer(),
        GetBuilder<FavouriteController>(
          builder: (favourites) {
            final bool isFav = favourites.wishItemIdList.contains(_item.id);
            // The free HugeIcons set has no filled heart: "favourited" is the
            // coral and a heavier stroke, as on the store cards.
            return _RoundButton(
              icon: HugeIcons.strokeRoundedFavourite,
              strokeWidth: isFav ? 2.6 : 1.5,
              color: isFav ? WaddyColors.coralDark : WaddyColors.inkMid,
              label: isFav ? 'remove_from_favourite'.tr : 'add_to_favourite'.tr,
              onTap: () => _toggleFavourite(isFav),
            );
          },
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        _basketButton(),
      ],
    );
  }

  Widget _backButton({bool flat = false}) => _RoundButton(
    icon:
        Directionality.of(context) == TextDirection.rtl
            ? HugeIcons.strokeRoundedArrowRight01
            : HugeIcons.strokeRoundedArrowLeft01,
    label: 'back'.tr,
    flat: flat,
    onTap: () => Get.back(),
  );

  Widget _basketButton({bool flat = false}) => GetBuilder<CartController>(
    builder:
        (cart) => _RoundButton(
          icon: HugeIcons.strokeRoundedShoppingBasket03,
          label: 'cart'.tr,
          flat: flat,
          count: cart.cartList.length,
          onTap: () => Get.toNamed(RouteHelper.getCartRoute()),
        ),
  );

  /// The bar that takes over once the hero's controls scroll away: back, the
  /// product's name, the basket. Faded in on a notifier, so a scroll never
  /// rebuilds the page.
  Widget _scrolledHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrolledHeader,
      builder:
          (context, showing, child) => AnimatedOpacity(
            duration: WaddyMotion.fast,
            opacity: showing ? 1 : 0,
            child: IgnorePointer(ignoring: !showing, child: child),
          ),
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        decoration: const BoxDecoration(
          color: WaddyColors.surface,
          border: Border(bottom: BorderSide(color: WaddyColors.divider)),
          boxShadow: [
            BoxShadow(
              color: WaddyColors.shadowTeal,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeSmall,
          ),
          child: Row(
            children: [
              _backButton(flat: true),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Text(
                  PackSize.of(_item.name).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WaddyColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              _basketButton(flat: true),
            ],
          ),
        ),
      ),
    );
  }

  // ── Name and price ────────────────────────────────────────────────────

  Widget _titleBlock() {
    final PackSize pack = PackSize.of(_item.name);
    // Only the size the name states. The unit field is admin-typed and mostly
    // a "Kilogram" default ("/ kg" under a 600 ml dish liquid), so it's
    // never shown.
    final String? sizeLine = pack.size;
    final ItemPrice price = ItemPrice.of(_item, base: _variation?.price);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: waddyBold.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: displayTracking(-0.6),
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (sizeLine != null) ...[
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      // The pack size as a mint pill: on a shelf it is the
                      // second thing a shopper checks, so it gets a shape,
                      // not grey text.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeMedium,
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        decoration: BoxDecoration(
                          color: WaddyColors.mintSurfaceDeep,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          sizeLine,
                          style: waddyBold.copyWith(
                            fontSize: 13,
                            color: WaddyColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              // The price takes the end of the row, opposite the name.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PriceTag(
                    price: price,
                    size: PriceTagSize.large,
                    dimmed: _itemSoldOut,
                  ),
                  // The app's deal block: the square full-mint chip the cart
                  // and checkout put on a discounted line. Not
                  // CheckoutSavingChip itself — it forces LTR, which flips
                  // "وفّر 15" in Arabic.
                  if (price.onSale && !_itemSoldOut) ...[
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Container(
                      color: WaddyColors.mint,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                        vertical: 2,
                      ),
                      child: Text(
                        '${'you_save'.tr} ${PriceConverter.convertPrice(price.was - price.now)}',
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (_itemSoldOut) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'out_of_stock'.tr,
              style: waddyBold.copyWith(
                fontSize: 13,
                color: WaddyColors.coralInk,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Options ───────────────────────────────────────────────────────────

  Text _sectionTitle(String text) => Text(
    text,
    // The store page's section title (StoreSectionHeader): 20/800.
    style: waddyBold.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: displayTracking(-0.4),
      color: WaddyColors.ink,
    ),
  );

  /// Two tiles to a row, each as tall as the taller of the pair — a sale
  /// tile (with its was-price line) must not leave its neighbour short.
  Widget _optionGrid(List<Widget> tiles) {
    return Column(
      children: [
        for (int i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: Dimensions.paddingSizeMedium),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// One choice, as a grid of two. Alone, each option is a whole variation
  /// and shows its own price; next to other choices a single option no longer
  /// names one price, so the tile is the label alone.
  Widget _choiceGroup(int index) {
    final ChoiceOptions choice = _choices[index];
    final List<String> options = choice.options!;
    final bool priced = _choices.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeExtraLarge,
        Dimensions.paddingSizeLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(choice.title ?? ''),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          _optionGrid([
            for (int o = 0; o < options.length; o++)
              Builder(
                builder: (_) {
                  final Variation? v = priced ? _variationFor([o]) : null;
                  return _OptionTile(
                    label: options[o].trim(),
                    price:
                        v?.price == null
                            ? null
                            : ItemPrice.of(_item, base: v!.price),
                    selected: _picked[index] == o,
                    disabled: priced && _soldOut(v),
                    onTap:
                        () => setState(() {
                          _picked[index] = o;
                          if (priced) _quantity = 1;
                        }),
                  );
                },
              ),
          ]),
        ],
      ),
    );
  }

  Widget _preferenceGroup() {
    final String option = _item.prepOption!;
    final bool flagged = _nudge && _preference == null;
    return Padding(
      // The amber frame's own padding is taken off the page gutter, so the
      // title and tiles line up with the groups above.
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge - Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeExtraLarge - Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeLarge - Dimensions.paddingSizeSmall,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: flagged ? WaddyColors.amber : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(ProducePreference.title(option)),
            const SizedBox(height: Dimensions.paddingSizeMedium),
            _optionGrid([
              for (final String code in ProducePreference.answersFor(option))
                _OptionTile(
                  label: ProducePreference.label(code) ?? code,
                  hint: ProducePreference.hint(code),
                  emoji: _kPreferenceEmoji[code],
                  selected: _preference == code,
                  onTap: () => setState(() => _preference = code),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── About + similar ───────────────────────────────────────────────────

  /// A white card, like the store page's tiles — a hairline-topped paragraph
  /// on the canvas read as a form, not a shop.
  Widget _about(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraLarge,
        Dimensions.paddingSizeDefault,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'about_this_item'.tr,
              style: waddyBold.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: WaddyColors.ink,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              text,
              style: waddyRegular.copyWith(
                fontSize: 14,
                height: 1.55,
                color: WaddyColors.inkMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// More from the shelf, on the store page's mint aisle panel — same
  /// gradient, radius and borderless cards, so it reads as the aisle the
  /// shopper just stepped out of.
  ///
  /// Titled "You might also need", not "Goes well with": the list is this
  /// aisle topped up from the whole store, not a pairing, and the old title
  /// put micellar water under tomatoes as a recommendation.
  Widget _similar() {
    if (_related == null) return const _RailSkeleton();
    final List<Item> items = _related!;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 32, 0, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreSectionHeader(
            title: 'you_might_also_need'.tr,
            onMint: true,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Two to a row, every card one fixed height, flowing with the
            // page's own scroll — a rail hid everything past the third card.
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: StoreProductCard.railHeight(context),
              ),
              itemBuilder:
                  (_, i) => StoreProductCard(
                    item: items[i],
                    bordered: false,
                    cardWidth: null,
                    // The specialty page's card (Deals right now): a photo
                    // that fills its frame, the full name, the price.
                    fit: BoxFit.cover,
                    perUnit: true,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────

  Widget _bottomBar(BuildContext context) {
    final bool soldOut = _itemSoldOut;
    final String label =
        soldOut
            ? 'out_of_stock'.tr
            : _added
            ? '${'added'.tr} ✓'
            : 'add_to_cart'.tr;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        children: [
          if (!soldOut) ...[
            Container(
              width: 124,
              height: 52,
              // Teal beside the mint add — the cart bar's pairing.
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _StepButton(
                    icon: HugeIcons.strokeRoundedMinusSign,
                    label: 'decrease_quantity'.tr,
                    onTap: _quantity > 1 ? () => _changeQuantity(-1) : null,
                  ),
                  Expanded(
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: waddyBold.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: HugeIcons.strokeRoundedAdd01,
                    label: 'increase_quantity'.tr,
                    onTap: () => _changeQuantity(1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall + 2),
          ],
          Expanded(
            child: Pressable(
              onTap: soldOut ? null : _add,
              semanticLabel: label,
              scale: WaddyMotion.pressCard,
              child: AnimatedContainer(
                duration: WaddyMotion.fast,
                curve: WaddyMotion.easeOut,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      soldOut
                          ? WaddyColors.divider
                          : _added
                          ? WaddyColors.primary
                          : WaddyColors.mint,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      soldOut
                          ? null
                          : [
                            BoxShadow(
                              color:
                                  _added
                                      ? WaddyColors.mint
                                      : WaddyColors.primary,
                              offset: const Offset(0, 2),
                            ),
                          ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    soldOut || _added
                        ? label
                        : '$label · ${PriceConverter.convertPrice(_unitPrice * _quantity)}',
                    maxLines: 1,
                    style: waddyBold.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color:
                          soldOut
                              ? WaddyColors.inkLight
                              : _added
                              ? WaddyColors.mint
                              : WaddyColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero's round control: back, heart, cart.
class _RoundButton extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double strokeWidth;

  /// Raised grey, no shadow — for the white scrolled header, where a white
  /// circle would vanish.
  final bool flat;

  /// A badge on the corner when above zero (the cart's line count).
  final int count;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = WaddyColors.primary,
    this.strokeWidth = 1.5,
    this.flat = false,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      minSize: Dimensions.minTapTarget,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                // White on the hero's mint, as the store header's controls.
                decoration: BoxDecoration(
                  color: flat ? WaddyColors.surfaceRaised : WaddyColors.surface,
                  shape: BoxShape.circle,
                  boxShadow:
                      flat
                          ? null
                          : const [
                            BoxShadow(
                              color: WaddyColors.shadowTeal,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 20,
                    color: color,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
            ),
            if (count > 0)
              PositionedDirectional(
                top: -2,
                end: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: WaddyColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    style: waddyBold.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.mint,
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

/// A little face for each produce answer — the Waddy touch on a question that
/// would otherwise be two grey cards.
const Map<String, String> _kPreferenceEmoji = {
  'salad': '🥗',
  'cooking': '🍳',
  'ready_to_eat': '😋',
  'ripe_later': '📅',
};

/// One option of a choice, drawn as a card: the label, then its own price
/// (and the struck-through was-price when on sale) — or, for a question like
/// "Use it for", a face and a line of hint. Left-aligned and no taller than
/// its text. The pick goes mint with a teal rim, the app's chunky teal edge
/// under it and a teal tick; the rim is 2px either way, so nothing shifts
/// when the pick moves.
class _OptionTile extends StatelessWidget {
  final String label;
  final ItemPrice? price;
  final String? hint;
  final String? emoji;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.price,
    this.hint,
    this.emoji,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: disabled ? null : onTap,
      semanticLabel: [
        label,
        if (price != null) PriceConverter.convertPrice(price!.now),
      ].join(', '),
      selected: selected,
      scale: WaddyMotion.pressControl,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        curve: WaddyMotion.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          color: selected ? WaddyColors.mintSurfaceDeep : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: selected ? WaddyColors.primary : WaddyColors.divider,
            width: 2,
          ),
          boxShadow:
              selected
                  ? const [
                    BoxShadow(color: WaddyColors.primary, offset: Offset(0, 2)),
                  ]
                  : null,
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // A face: it sits on the tile's top row with the tick, and the
              // label drops under it, so neither is squeezed by the other.
              if (emoji != null) ...[
                Row(
                  children: [
                    Text(emoji!, style: const TextStyle(fontSize: 24)),
                    const Spacer(),
                    _Tick(selected: selected),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: WaddyColors.ink,
                  ),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: (price == null ? waddyBold : waddyRegular)
                            .copyWith(
                              fontSize: 15,
                              fontWeight:
                                  price == null ? FontWeight.w700 : null,
                              height: 1.2,
                              color: WaddyColors.ink,
                              decoration:
                                  disabled ? TextDecoration.lineThrough : null,
                            ),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    _Tick(selected: selected),
                  ],
                ),
              if (hint != null && hint!.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  hint!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: waddyRegular.copyWith(
                    fontSize: 12.5,
                    height: 1.35,
                    color:
                        selected ? WaddyColors.mintInk : WaddyColors.inkLight,
                  ),
                ),
              ],
              if (price != null) ...[
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Text(
                  PriceConverter.convertPrice(price!.now),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  style: waddyBold.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WaddyColors.ink,
                  ),
                ),
                if (price!.onSale)
                  Text(
                    PriceConverter.convertPrice(price!.was),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: waddyRegular.copyWith(
                      fontSize: 13,
                      color: WaddyColors.inkLight,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: WaddyColors.inkLight,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring that fills teal, with a mint tick, on the picked option.
class _Tick extends StatelessWidget {
  final bool selected;
  const _Tick({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: WaddyMotion.fast,
      curve: WaddyMotion.easeOut,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? WaddyColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? WaddyColors.primary : WaddyColors.inkMuted,
          width: 1.5,
        ),
      ),
      child:
          selected
              ? const Icon(Icons.check_rounded, size: 14, color: WaddyColors.mint)
              : null,
    );
  }
}

class _StepButton extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: SizedBox(
        width: 40,
        height: 52,
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 20,
            strokeWidth: 2,
            color:
                onTap == null ? WaddyColors.onPrimaryMuted : WaddyColors.mint,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SKELETONS — the page's own shapes, so nothing jumps when it lands
// ═══════════════════════════════════════════════════════════════

Widget _bone({double? width, required double height, double radius = 8}) =>
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: WaddyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

/// The whole page in outline: mint hero with an empty plate, name, size
/// pill, price, about card and the rail panel.
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 340 + top,
            decoration: BoxDecoration(gradient: StoreHeroBannerWidget.gradient),
            padding: EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              top + 64,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeExtraSmall,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(48),
              child: Shimmer(child: _bone(height: double.infinity, radius: 20)),
            ),
          ),
          Shimmer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeLarge,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(width: 230, height: 28),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  _bone(width: 64, height: 26, radius: 999),
                  const SizedBox(height: Dimensions.paddingSizeMedium),
                  _bone(width: 96, height: 30),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  _bone(height: 110, radius: Dimensions.radiusLarge),
                ],
              ),
            ),
          ),
          const _RailSkeleton(),
        ],
      ),
    );
  }
}

/// The mint rail panel with three card outlines.
class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 32, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaddyColors.mintSurfaceDeep, WaddyColors.mintSurface],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bone(width: 190, height: 24),
            const SizedBox(height: 12),
            SizedBox(
              height: StoreProductCard.railHeight(context),
              child: Row(
                children: [
                  for (int i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                        decoration: BoxDecoration(
                          color: WaddyColors.surface,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(
                              height: 120,
                              radius: Dimensions.radiusDefault,
                            ),
                            const SizedBox(height: 10),
                            _bone(width: 120, height: 14),
                            const SizedBox(height: 6),
                            _bone(width: 80, height: 14),
                            const SizedBox(height: 10),
                            _bone(width: 60, height: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
