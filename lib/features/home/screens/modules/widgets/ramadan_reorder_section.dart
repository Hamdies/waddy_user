import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/module_store_semantics.dart';
import 'package:waddy_app/features/home/screens/modules/widgets/pressable_scale.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

const Color _ramadanGold = Color(0xFFD4AF37);
const Color _ramadanBronze = Color(0xFF8B6914);

/// Ramadan-themed reorder strip shown instead of the normal
/// order-again/buy-again section while Ramadan mode is on.
class RamadanReorderSection extends StatelessWidget {
  final List<Store> stores;
  final Object Function(Store store) storeScreenBuilder;
  final double titleFontSize;
  final double subtitleFontSize;
  final double listHeight;
  final double bottomPadding;
  final double subtitleGap;

  const RamadanReorderSection({
    super.key,
    required this.stores,
    required this.storeScreenBuilder,
    this.titleFontSize = 18,
    this.subtitleFontSize = 12,
    this.listHeight = 162,
    this.bottomPadding = 16,
    this.subtitleGap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedRamadhan01,
                  color: _ramadanGold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: -3,
                      right: -3,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: _ramadanGold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusExtraSmall,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'ramadan_reorder'.tr,
                      style: waddyBold.copyWith(
                        fontSize: titleFontSize,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Text(
              'ramadan_reorder_subtitle'.tr,
              style: waddyRegular.copyWith(
                fontSize: subtitleFontSize,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(height: subtitleGap),
          SizedBox(
            height: listHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              itemCount: stores.length > 6 ? 6 : stores.length,
              itemBuilder:
                  (context, index) => _RamadanChip(
                    store: stores[index],
                    primaryColor: primaryColor,
                    storeScreenBuilder: storeScreenBuilder,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RamadanChip extends StatelessWidget {
  final Store store;
  final Color primaryColor;
  final Object Function(Store store) storeScreenBuilder;

  const _RamadanChip({
    required this.store,
    required this.primaryColor,
    required this.storeScreenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final items = store.items ?? [];
    final displayItems = items.take(3).toList();

    return PressableScale(
      semanticLabel: moduleStoreSemanticLabel(store),
      onTap:
          () => Get.toNamed(
            RouteHelper.getStoreRoute(id: store.id, page: 'store'),
            arguments: storeScreenBuilder(store),
          ),
      child: Container(
        width: 200,
        margin: const EdgeInsetsDirectional.only(
          end: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: _ramadanGold.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: _ramadanGold.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFDF5), Color(0xFFFFF8E7)],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: -6,
                end: -4,
                child: Icon(
                  Icons.nightlight_round,
                  size: 44,
                  color: _ramadanGold.withValues(alpha: 0.06),
                ),
              ),
              PositionedDirectional(
                bottom: 12,
                start: 6,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: _ramadanGold.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                            color: Colors.white,
                            border: Border.all(
                              color: _ramadanGold.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _ramadanGold.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                            child: CustomImage(
                              image: store.logoFullUrl ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name ?? '',
                                style: waddyBold.copyWith(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (store.deliveryTime != null)
                                Text(
                                  '${store.deliveryTime}',
                                  style: waddyRegular.copyWith(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ...displayItems.map(
                          (item) => Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Dimensions.paddingSizeSmall,
                            ),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: _ramadanGold.withValues(alpha: 0.06),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeExtraSmall,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                child: CustomImage(
                                  image: item.imageFullUrl ?? '',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (items.length > 3)
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _ramadanGold.withValues(alpha: 0.15),
                                  _ramadanGold.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${items.length - 3}',
                              style: waddyBold.copyWith(
                                fontSize: 11,
                                color: _ramadanBronze,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _ramadanGold.withValues(alpha: 0.18),
                            _ramadanGold.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        border: Border.all(
                          color: _ramadanGold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 13,
                            color: _ramadanBronze,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ramadan_reorder'.tr,
                            style: waddyMedium.copyWith(
                              fontSize: 11,
                              color: _ramadanBronze,
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
        ),
      ),
    );
  }
}
