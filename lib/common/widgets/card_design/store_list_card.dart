import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Ratings below this many reviews are not shown as a score.
///
/// A store with `5.0 (1)` reads as fabricated, and it makes a rating sort pure
/// noise across a catalogue this small. Below the threshold the slot carries a
/// `New` chip instead of going blank — an empty slot beside a populated one
/// reads as *bad*, not as *new*, which is the one option that misleads.
const int kMinRatingsToShow = 20;

/// The horizontal list card for a store.
///
/// One metric line, not two: `★ 4.8 · 32 min · Free 15 EGP`. Distance is
/// deliberately absent — in a single hyperlocal zone every store is 1-3 km, and
/// the delivery estimate already encodes the difference, so the number costs a
/// line without separating any two stores.
///
/// Everything is direction-relative. The metric row is built from separate
/// widgets rather than one interpolated string, because Western digits inside an
/// Arabic paragraph are LTR runs in an RTL context: the bidi algorithm reorders
/// them, landing the separators in the wrong places and letting the struck-out
/// price jump away from its label.
class StoreListCard extends StatefulWidget {
  final Store store;

  /// Editorial or Spots signal, drawn over the image. The image is the single
  /// home for this class of badge: a header row above the name costs a full
  /// line on *every* card to serve the few that carry one.
  final String? overlayBadge;

  const StoreListCard({super.key, required this.store, this.overlayBadge});

  @override
  State<StoreListCard> createState() => _StoreListCardState();
}

class _StoreListCardState extends State<StoreListCard>
    with SingleTickerProviderStateMixin {
  static const double _imageSize = 110;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 1.0,
    end: 0.97,
  ).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openStore() {
    Get.find<SplashController>().activateModuleFor(widget.store.moduleId);
    Get.toNamed(
      RouteHelper.getStoreRoute(id: widget.store.id, page: 'store'),
      arguments: StoreScreen(store: widget.store, fromModule: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder:
            (context, child) =>
                Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomInkWell(
            onTap: _openStore,
            radius: Dimensions.radiusLarge,
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(context),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Expanded(child: _buildContent(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return SizedBox(
      width: _imageSize,
      height: _imageSize,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: CustomImage(
              image: widget.store.coverPhotoFullUrl ?? '',
              variants: widget.store.coverPhotoVariants,
              decodeWidth: _imageSize,
              height: _imageSize,
              width: _imageSize,
              fit: BoxFit.cover,
            ),
          ),

          // The logo chip carries brand identity that a photo of food cannot:
          // a plate of shawarma does not say *whose*. It solves recognition
          // without spending a second row on it.
          if ((widget.store.logoFullUrl ?? '').isNotEmpty)
            PositionedDirectional(
              top: Dimensions.paddingSizeExtraSmall,
              start: Dimensions.paddingSizeExtraSmall,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraSmall,
                  ),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraSmall,
                  ),
                  child: CustomImage(
                    image: widget.store.logoFullUrl!,
                    variants: widget.store.logoVariants,
                    decodeWidth: 28,
                    height: 28,
                    width: 28,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          if (widget.overlayBadge != null)
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeExtraSmall,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomStart: Radius.circular(Dimensions.radiusDefault),
                    bottomEnd: Radius.circular(Dimensions.radiusDefault),
                  ),
                ),
                child: Text(
                  widget.overlayBadge!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeOverSmall,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final cuisines = widget.store.cuisineNames ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.store.name ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: waddyBold.copyWith(fontSize: Dimensions.fontSizeDefault),
        ),

        if (cuisines.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            cuisines.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: theme.disabledColor,
            ),
          ),
        ],

        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        _buildMetricRow(context),

        if (_buildOfferPills(context).isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Wrap(
            spacing: Dimensions.paddingSizeExtraSmall + 2,
            runSpacing: Dimensions.paddingSizeExtraSmall,
            children: _buildOfferPills(context),
          ),
        ],
      ],
    );
  }

  /// `★ 4.8 · 32 min · Free 15 EGP` as discrete widgets.
  ///
  /// The `Row` itself inherits the ambient direction so the *sequence* mirrors
  /// in Arabic, while each numeric child is pinned LTR so its own digits are
  /// not reordered against the glyphs beside them.
  Widget _buildMetricRow(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <Widget>[];

    final rating = widget.store.avgRating;
    final ratingCount = widget.store.ratingCount ?? 0;
    if (rating != null && rating > 0 && ratingCount >= kMinRatingsToShow) {
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 14, color: Color(0xFFFFC107)),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              textDirection: TextDirection.ltr,
              style: waddyBold.copyWith(fontSize: Dimensions.fontSizeSmall),
            ),
          ],
        ),
      );
    } else {
      parts.add(const _NewChip());
    }

    final deliveryTime = widget.store.deliveryTime;
    if (deliveryTime != null && deliveryTime.isNotEmpty) {
      parts.add(
        Text(
          '$deliveryTime ${'min'.tr}',
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    if (widget.store.freeDelivery == true) {
      parts.add(
        Text(
          'free_delivery'.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyMedium.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: theme.primaryColor,
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeExtraSmall + 2,
            ),
            child: Text(
              '·',
              style: waddyRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: theme.disabledColor,
              ),
            ),
          ),
        );
      }
      children.add(Flexible(child: parts[i]));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  List<Widget> _buildOfferPills(BuildContext context) {
    final pills = <Widget>[];

    final discount = widget.store.discount;
    if (discount != null && (discount.discount ?? 0) > 0) {
      final isPercent = discount.discountType == 'percent';
      final amount =
          isPercent
              ? '${discount.discount!.toStringAsFixed(0)}%'
              : '${Get.find<SplashController>().configModelOrNull?.currencySymbol ?? ''}${discount.discount!.toStringAsFixed(0)}';
      pills.add(
        _OfferPill(
          label: '$amount ${'off'.tr}',
          background: const Color(0xFFFFF3CD),
          foreground: const Color(0xFF8A6100),
        ),
      );
    }

    return pills;
  }
}

class _NewChip extends StatelessWidget {
  const _NewChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtraSmall + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
      child: Text(
        'new'.tr,
        maxLines: 1,
        style: waddyBold.copyWith(
          fontSize: Dimensions.fontSizeOverSmall,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}

class _OfferPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _OfferPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: waddyMedium.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          color: foreground,
        ),
      ),
    );
  }
}
