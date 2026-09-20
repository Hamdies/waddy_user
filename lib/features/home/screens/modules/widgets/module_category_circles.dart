import 'package:waddy_app/common/models/image_variants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/cuisine/domain/models/cuisine_model.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/store_logo_slideshow.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Tile geometry, shared by the category tile, the "all" tile and the shimmer
/// so the three can never drift apart.
const double _kTileSize = 76;

/// Inset around the dish image. Generous on purpose: these are photographed
/// dishes, and 10pt of mint ground is what stops them reading as a texture
/// that runs to the tile edge.
const double _kTileInset = 10;

/// Gap between the tile and its label.
const double _kLabelGap = 7;

/// Label type size and leading, shared by the tile and the height solver so a
/// change to one can never leave the other reserving the wrong box.
const double _kLabelSize = 13;
const double _kLabelHeight = 1.15;

/// Strip height: tile + label gap + however many label lines are actually
/// needed, at the viewer's text scale.
///
/// Was a flat 128 — tile + gap + *two* lines, reserved unconditionally. Most
/// cuisine names are one word ("Pizza", "Grills", "Burgers"), so on a typical
/// screen ~15pt of that box was permanently empty, and it sat directly above
/// the filter strip: the largest gap on the page fell between two controls
/// that belong together, and was bigger than the gaps between whole sections.
///
/// Two lines are still reserved the moment any visible label needs them, so
/// tiles never sit at different heights within one strip — the alignment the
/// fixed height was protecting is kept, it is just no longer paid for when
/// nothing needs it.
///
/// Text scale is applied here rather than clamped: this strip is vertical, so
/// growing it pushes content down instead of off the side, and a user at a
/// large accessibility size gets labels that fit rather than ellipsized.
double _stripHeight(BuildContext context, {required bool twoLines}) {
  final double lineHeight =
      _kLabelSize * _kLabelHeight * MediaQuery.textScalerOf(context).scale(1.0);
  // +2: the TextPainter used to decide `twoLines` measures the same style at
  // the same width as the real Text, but font-fallback/hinting can still
  // round the actual RenderParagraph a hair taller than the painter's
  // estimate — enough, at the boundary, to overflow the Column by a pixel or
  // two. A couple of points of slack costs nothing visually and removes that
  // boundary case entirely.
  return _kTileSize + _kLabelGap + lineHeight * (twoLines ? 2 : 1) + 2;
}

/// Whether any of [labels] will wrap to a second line at [_kTileSize] wide.
///
/// Measured, not guessed: a `TextPainter` at the label's real style and the
/// tile's real width is the only way to know whether "Middle Eastern" wraps
/// where "Pizza" does not, and guessing by character count breaks the moment
/// the app is in Arabic.
bool _needsTwoLines(BuildContext context, List<String> labels) {
  final double scale = MediaQuery.textScalerOf(context).scale(1.0);
  for (final String label in labels) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: waddyMedium.copyWith(
          fontSize: _kLabelSize,
          height: _kLabelHeight,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 2,
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(scale),
    )..layout(maxWidth: _kTileSize);
    if (painter.didExceedMaxLines || painter.computeLineMetrics().length > 1) {
      return true;
    }
  }
  return false;
}

/// Gap between tiles.
const double _kTileGap = 12;

/// The mint wash beneath a dish: deepest at the top, fading to near-white at
/// the bottom so the tile reads as lit from above and the dish sits ON it
/// rather than in front of it.
///
/// Both states share the same wash — see the note at the selected border.
const LinearGradient _kTileGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  // Three stops, not two: the midpoint is what keeps the fade from
  // banding across a box this small.
  stops: [0.0, 0.55, 1.0],
  colors: [WaddyColors.mintSurfaceDeep, Color(0xFFEAFBF4), Color(0xFFF9FEFC)],
);

/// How many cuisines the strip shows before it hands the rest to a sheet.
///
/// Ten is about three screens of horizontal swiping — past that the strip
/// stops being a glanceable set and becomes a second, worse scroll competing
/// with the store list underneath it. The overflow is not hidden: a trailing
/// tile says how many more there are and opens all of them at once, which is
/// a faster way to reach the 24th cuisine than swiping to it.
const int kDefaultVisibleCuisines = 10;

/// Horizontal category strip: leading "all" tile with a store-logo slideshow,
/// then one tile per category.
class ModuleCategoryCircles extends StatelessWidget {
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategoryTap;

  /// Printed on the leading tile. Keep it short — it shares a 76pt tile with
  /// the cuisine names beside it.
  final String allLabel;

  /// Spoken for the leading tile when [allLabel] is an abbreviation.
  /// Falls back to [allLabel] when the two are the same.
  final String? allSemanticLabel;

  /// Rendered glyph shown when no logo is available — a `Widget` rather than
  /// an [IconData] so callers can pass a Material `Icon` or a `HugeIcon`.
  final Widget fallbackIcon;

  /// Show at most this many categories (null = all).
  final int? maxCategories;
  final double bottomPadding;

  const ModuleCategoryCircles({
    super.key,
    required this.selectedCategoryId,
    required this.onCategoryTap,
    required this.allLabel,
    this.allSemanticLabel,
    required this.fallbackIcon,
    this.maxCategories,
    this.bottomPadding = 6,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<CategoryController>(
      builder: (categoryController) {
        if (categoryController.categoryList == null) {
          return const ModuleCategoryCirclesShimmer();
        }
        if (categoryController.categoryList!.isEmpty) return const SizedBox();

        final allCategories = categoryController.categoryList!;
        final visibleCategories =
            (maxCategories != null && allCategories.length > maxCategories!)
                ? allCategories.take(maxCategories!).toList()
                : allCategories;

        final storeController = Get.find<StoreController>();
        final stores =
            storeController.popularStoreList ??
            storeController.latestStoreList ??
            <Store>[];

        final List<String> labels = [
          allLabel,
          for (final c in visibleCategories) c.name ?? '',
        ];

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            height: _stripHeight(
              context,
              twoLines: _needsTwoLines(context, labels),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              children: List.generate(visibleCategories.length + 1, (index) {
                if (index == 0) {
                  return _AllStoresItem(
                    isSelected: selectedCategoryId == null,
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    stores: stores,
                    label: allLabel,
                    semanticLabel: allSemanticLabel ?? allLabel,
                    fallbackIcon: fallbackIcon,
                    onTap: () => onCategoryTap(null),
                  );
                }
                final category = visibleCategories[index - 1];
                return _CategoryItem(
                  isSelected: selectedCategoryId == category.id,
                  label: category.name ?? '',
                  imageUrl: category.imageFullUrl,
                  imageVariants: category.imageVariants,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  onTap: () => onCategoryTap(category.id),
                  index: index,
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _AllStoresItem extends StatelessWidget {
  final bool isSelected;
  final Color primaryColor;
  final Color accentColor;
  final List<Store> stores;

  /// What the tile PRINTS — kept short ("All") so it fits one line like the
  /// cuisine tiles beside it.
  final String label;

  /// What the tile SAYS. The printed label is abbreviated for the 76pt tile;
  /// "All" alone is meaningless out of visual context, so screen readers get
  /// the full phrase ("All restaurants") instead.
  final String semanticLabel;

  /// Rendered glyph shown when no logo is available — a `Widget` rather than
  /// an [IconData] so callers can pass a Material `Icon` or a `HugeIcon`.
  final Widget fallbackIcon;
  final VoidCallback onTap;

  const _AllStoresItem({
    required this.isSelected,
    required this.primaryColor,
    required this.accentColor,
    required this.stores,
    required this.label,
    required this.semanticLabel,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kTileGap),
      child: PressableScale(
        semanticLabel:
            isSelected ? '$semanticLabel, ${'selected'.tr}' : semanticLabel,
        onTap: onTap,
        // Clips rather than asserts: `_stripHeight` estimates this column's
        // height from a `TextPainter` pass over the label, and a clip is the
        // backstop if that estimate is ever a hair short for some
        // label/locale/text-scale combination it didn't see.
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _kTileSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _kTileSize,
                  height: _kTileSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    // Same wash and same selected ring as every other tile:
                    // this one used to flip to a solid teal fill when
                    // active, which made "All" the loudest thing in a strip
                    // whose job is to show the cuisines.
                    gradient: _kTileGradient,
                    border:
                        isSelected
                            ? Border.all(color: primaryColor, width: 2)
                            : null,
                  ),
                  // Inset and rounded exactly like the dish tiles beside it.
                  // Bleeding a store logo to the tile edge made this one read
                  // as a different component in the row — a brand card among
                  // food thumbnails — rather than as the first option in a
                  // set.
                  child: Padding(
                    padding: const EdgeInsets.all(_kTileInset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: StoreLogoSlideshow(
                        stores: stores,
                        size: _kTileSize - _kTileInset * 2,
                        fallback: fallbackIcon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _kLabelGap),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: waddyMedium.copyWith(
                    fontSize: _kLabelSize,
                    height: _kLabelHeight,
                    color: isSelected ? primaryColor : WaddyColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final bool isSelected;
  final String label;
  final String? imageUrl;
  final ImageVariants? imageVariants;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onTap;
  final int index;

  const _CategoryItem({
    required this.isSelected,
    required this.label,
    required this.imageUrl,
    this.imageVariants,
    required this.primaryColor,
    required this.accentColor,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // No entry animation. These tiles used to fade and slide up 8px with a
    // per-index stagger (300ms + 50ms each), underneath a second 400ms fade
    // over the whole strip. Home is a screen the user returns to constantly,
    // and re-animating it on every entry made an app they never left look
    // like it was cold-starting. Steady-state content should already be
    // there when the screen appears; the motion budget belongs to state
    // *changes* (selection, filtering), which the AnimatedContainers below
    // still spend it on.
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kTileGap),
      child: PressableScale(
        // Selection is the whole point of these, and it is conveyed only by
        // a ring and a label colour — so it has to be spoken, not painted.
        semanticLabel: isSelected ? '$label, ${'selected'.tr}' : label,
        onTap: onTap,
        // Clips rather than asserts: `_stripHeight` estimates this column's
        // height from a `TextPainter` pass over the label, and a clip is
        // the backstop if that estimate is ever a hair short for some
        // label/locale/text-scale combination it didn't see.
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _kTileSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _kTileSize,
                  height: _kTileSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    gradient: _kTileGradient,
                    // Selected is a ring, not a fill: the wash beneath the
                    // dish has to stay the same in both states or the food
                    // photo changes colour when you tap it.
                    border:
                        isSelected
                            ? Border.all(color: primaryColor, width: 2)
                            : null,
                  ),
                  // Dish shots are subjects on a plate, not textures:
                  // `cover` cropped the plate against the tile edge and
                  // left them looking squeezed. Inset the image and
                  // `contain` it so the whole dish reads, with the mint
                  // wash as its ground.
                  child: Padding(
                    padding: const EdgeInsets.all(_kTileInset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomImage(
                        image: imageUrl ?? '',
                        fit: BoxFit.cover,
                        variants: imageVariants,
                        // Decode to the padded box, not the tile.
                        decodeWidth: _kTileSize - _kTileInset * 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _kLabelGap),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: waddyMedium.copyWith(
                    fontSize: _kLabelSize,
                    height: _kLabelHeight,
                    // Cuisine names are how you steer this list — they
                    // were 10.5px grey, smaller than the meta text on the
                    // rows below and the first thing to disappear at a
                    // glance.
                    color: isSelected ? primaryColor : WaddyColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModuleCategoryCirclesShimmer extends StatelessWidget {
  const ModuleCategoryCirclesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        // One label line: the shimmer has no text to measure, and the common
        // case is single-word cuisine names. Reserving two here would make the
        // strip shrink the moment real data arrived — a visible jump on every
        // cold load, to save a jump that only happens when a name wraps.
        height: _stripHeight(context, twoLines: false),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
          itemBuilder:
              (context, index) => Padding(
                padding: const EdgeInsetsDirectional.only(end: _kTileGap),
                child: Column(
                  children: [
                    Shimmer(
                      child: Container(
                        width: _kTileSize,
                        height: _kTileSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(height: _kLabelGap),
                    Shimmer(
                      child: Container(
                        width: 52,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraSmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

/// Same strip, fed by cuisines instead of categories.
///
/// Food restaurants are grouped by what they ARE (burgers, pizza, seafood),
/// and the Food module has no category rows at all — so the food home screen
/// reads CuisineController while grocery and the rest stay on categories.
/// Item chrome is shared with [ModuleCategoryCircles]; only the source differs.
class ModuleCuisineCircles extends StatelessWidget {
  final int? selectedCuisineId;
  final ValueChanged<int?> onCuisineTap;

  /// Printed on the leading tile. Keep it short — see [ModuleCategoryCircles].
  /// Unused when [showAllTile] is false.
  final String allLabel;

  /// Spoken for the leading tile when [allLabel] is an abbreviation.
  final String? allSemanticLabel;

  /// Rendered glyph shown when no logo is available — a `Widget` rather than
  /// an [IconData] so callers can pass a Material `Icon` or a `HugeIcon`.
  final Widget fallbackIcon;

  /// Whether the strip opens with an "all" tile.
  ///
  /// Off where something else already states what the unfiltered list is —
  /// the food home's section header reads "All restaurants" until a cuisine is
  /// picked, which says it in words a foot above the strip. The tile was
  /// saying the same thing again, and saying it badly: it carried a slideshow
  /// of store logos, so the control meaning "no filter" advertised one
  /// specific restaurant, wore a selected ring while doing it, and was the
  /// only brand mark in a row of dish photographs.
  ///
  /// Deselecting without the tile is tapping the selected cuisine again —
  /// [onCuisineTap] already toggles — plus whatever clear-all affordance the
  /// host screen provides.
  final bool showAllTile;

  /// How many cuisine tiles the strip shows before the overflow tile. Pass
  /// null for every cuisine inline (no overflow tile).
  final int? maxCuisines;

  final double bottomPadding;

  const ModuleCuisineCircles({
    super.key,
    required this.selectedCuisineId,
    required this.onCuisineTap,
    required this.allLabel,
    this.allSemanticLabel,
    required this.fallbackIcon,
    this.showAllTile = true,
    this.maxCuisines = kDefaultVisibleCuisines,
    this.bottomPadding = 6,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).secondaryHeaderColor;

    return GetBuilder<CuisineController>(
      builder: (cuisineController) {
        final List<CuisineModel>? all = cuisineController.cuisineList;
        // `loaded` separates "still fetching" from "came back empty"; without
        // it a failed fetch would shimmer forever instead of collapsing.
        if (all == null) {
          return cuisineController.loaded
              ? const SizedBox()
              : const ModuleCategoryCirclesShimmer();
        }
        if (all.isEmpty) return const SizedBox();

        final bool hasOverflow =
            maxCuisines != null && all.length > maxCuisines!;
        final List<CuisineModel> visible =
            hasOverflow ? all.take(maxCuisines!).toList() : all;
        final int hiddenCount = all.length - visible.length;

        // How many slots precede the first cuisine — 1 with the leading "all"
        // tile, 0 without. Named rather than written as a bare `+ 1` in three
        // places, because every index below is relative to it.
        final int leadingCount = showAllTile ? 1 : 0;

        // Every label the strip can actually render, so a one-line strip is
        // only claimed when nothing in it wraps. The overflow tile's "View
        // all" is in here too — it is a label on a tile like any other.
        final List<String> labels = [
          if (showAllTile) allLabel,
          for (final CuisineModel c in visible) c.name ?? '',
          if (hasOverflow) 'view_all'.tr,
        ];

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            height: _stripHeight(
              context,
              twoLines: _needsTwoLines(context, labels),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              // Optional leading "all" tile + the visible cuisines + a
              // trailing overflow tile when there are more than fit.
              children: List.generate(
                leadingCount + visible.length + (hasOverflow ? 1 : 0),
                (index) {
                  if (showAllTile && index == 0) {
                    final storeController = Get.find<StoreController>();
                    final stores =
                        storeController.popularStoreList ??
                        storeController.latestStoreList ??
                        <Store>[];
                    return _AllStoresItem(
                      isSelected: selectedCuisineId == null,
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                      stores: stores,
                      label: allLabel,
                      semanticLabel: allSemanticLabel ?? allLabel,
                      fallbackIcon: fallbackIcon,
                      onTap: () => onCuisineTap(null),
                    );
                  }
                  if (hasOverflow && index == leadingCount + visible.length) {
                    return _MoreCuisinesItem(
                      hiddenCount: hiddenCount,
                      primaryColor: primaryColor,
                      onTap:
                          () => showAllCuisinesSheet(
                            cuisines: all,
                            selectedCuisineId: selectedCuisineId,
                            onCuisineTap: onCuisineTap,
                          ),
                    );
                  }
                  final CuisineModel cuisine = visible[index - leadingCount];
                  return _CategoryItem(
                    isSelected: selectedCuisineId == cuisine.id,
                    label: cuisine.name ?? '',
                    imageUrl: cuisine.imageFullUrl,
                    imageVariants: cuisine.imageVariants,
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    onTap: () => onCuisineTap(cuisine.id),
                    index: index,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// OVERFLOW TILE + ALL-CUISINES SHEET
// ═══════════════════════════════════════════

/// Trailing tile that opens the full cuisine list.
///
/// It prints the count of what is hidden ("+14") rather than a bare chevron:
/// a strip that simply ends gives no reason to tap, while a number tells you
/// whether the thing you are looking for is plausibly behind it.
///
/// Same 76pt geometry and the same mint wash as the tiles beside it, so it
/// reads as the last member of the set and not as a button bolted to the end.
/// It carries no selected state — it is a door, not a filter.
class _MoreCuisinesItem extends StatelessWidget {
  final int hiddenCount;
  final Color primaryColor;
  final VoidCallback onTap;

  const _MoreCuisinesItem({
    required this.hiddenCount,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kTileGap),
      child: PressableScale(
        semanticLabel: '${'view_all'.tr}, $hiddenCount ${'more'.tr}',
        onTap: onTap,
        child: SizedBox(
          width: _kTileSize,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _kTileSize,
                height: _kTileSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  gradient: _kTileGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$hiddenCount',
                        textDirection: TextDirection.ltr,
                        style: waddyBold.copyWith(
                          fontSize: 22,
                          height: 1.0,
                          color: WaddyColors.mintInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: WaddyColors.mintInk.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kLabelGap),
              Text(
                'view_all'.tr,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: waddyMedium.copyWith(
                  fontSize: _kLabelSize,
                  height: _kLabelHeight,
                  color: WaddyColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every cuisine at once, as a grid in a bottom sheet.
///
/// A sheet rather than a screen: picking a cuisine re-filters the list you can
/// still see behind it, so pushing a route would hide the thing the choice
/// acts on and cost a second navigation to get back to it.
///
/// The grid is capped at 70% of the screen and scrolls inside that, so a
/// catalogue of forty cuisines does not become a full-height wall.
void showAllCuisinesSheet({
  required List<CuisineModel> cuisines,
  required int? selectedCuisineId,
  required ValueChanged<int?> onCuisineTap,
}) {
  Get.bottomSheet(
    _AllCuisinesSheet(
      cuisines: cuisines,
      selectedCuisineId: selectedCuisineId,
      onCuisineTap: onCuisineTap,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _AllCuisinesSheet extends StatelessWidget {
  final List<CuisineModel> cuisines;
  final int? selectedCuisineId;
  final ValueChanged<int?> onCuisineTap;

  const _AllCuisinesSheet({
    required this.cuisines,
    required this.selectedCuisineId,
    required this.onCuisineTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle + title stay put; only the grid scrolls, so the sheet
          // never loses its own label mid-scroll.
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Center(
            child: Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: WaddyColors.divider,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeLarge,
              Dimensions.paddingSizeDefault,
              Dimensions.paddingSizeMedium,
            ),
            child: Row(
              children: [
                Text(
                  'all_cuisines'.tr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: WaddyColors.ink,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Text(
                  '${cuisines.length}',
                  textDirection: TextDirection.ltr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: WaddyColors.inkLight,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeDefault,
                0,
                Dimensions.paddingSizeDefault,
                Dimensions.paddingSizeExtraLarge,
              ),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: Dimensions.paddingSizeDefault,
                crossAxisSpacing: _kTileGap,
                // Tile + gap + two label lines, matching the strip's geometry
                // so a cuisine looks identical in both places.
                childAspectRatio: 0.78,
              ),
              itemCount: cuisines.length,
              itemBuilder: (context, index) {
                final CuisineModel cuisine = cuisines[index];
                return _SheetCuisineTile(
                  cuisine: cuisine,
                  isSelected: selectedCuisineId == cuisine.id,
                  onTap: () {
                    Get.back();
                    onCuisineTap(cuisine.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One cuisine inside the sheet grid.
///
/// Deliberately not [_CategoryItem]: that tile is built for a horizontal strip
/// with a fixed 76pt width and its own entrance animation keyed to a scroll
/// index. In a grid the tile has to take the column width it is given, and
/// forty staggered entrance animations firing at once is noise.
class _SheetCuisineTile extends StatelessWidget {
  final CuisineModel cuisine;
  final bool isSelected;
  final VoidCallback onTap;

  const _SheetCuisineTile({
    required this.cuisine,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final String label = cuisine.name ?? '';

    return PressableScale(
      semanticLabel: isSelected ? '$label, ${'selected'.tr}' : label,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                gradient: _kTileGradient,
                border:
                    isSelected
                        ? Border.all(color: primaryColor, width: 2)
                        : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(_kTileInset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomImage(
                    image: cuisine.imageFullUrl ?? '',
                    variants: cuisine.imageVariants,
                    fit: BoxFit.contain,
                    decodeWidth: _kTileSize,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _kLabelGap),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: waddyMedium.copyWith(
                fontSize: _kLabelSize,
                height: _kLabelHeight,
                color: isSelected ? primaryColor : WaddyColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
