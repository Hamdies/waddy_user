part of '../food_store_screen.dart';

/// The menu page's cover hero and the compact header that replaces it on
/// scroll. Moved out of food_store_screen.dart unchanged (a part file shares
/// its library, so private members resolve as before).
extension _FoodStoreHero on _FoodStoreScreenState {
  // ═══════════════════════════════════════════
  // HERO — cover, floating controls, logo tile
  // ═══════════════════════════════════════════
  Widget _buildHero(BuildContext context, Store store) {
    return SizedBox(
      height: _kCoverHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFFDCE7E4),
              child: CustomImage(
                image: store.coverPhotoFullUrl ?? '',
                fit: BoxFit.cover,
                height: _kCoverHeight,
                width: double.infinity,
              ),
            ),
          ),

          // Scrim over the top third so the white controls hold contrast.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _kCoverHeight * 0.34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59134E4A), Color(0x00134E4A)],
                ),
              ),
            ),
          ),

          // ─── BACK / FAVOURITE / SEARCH ───
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _heroButton(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  tooltip: 'back'.tr,
                  onTap: () => Get.back(),
                ),
                Row(
                  children: [
                    // The shared widget owns the guest gate and the wished
                    // read; re-implementing either here would drift.
                    _heroChip(
                      tooltip: 'favourite'.tr,
                      child: GetBuilder<FavouriteController>(
                        builder: (favouriteController) {
                          return CustomFavouriteWidget(
                            isWished: favouriteController.wishStoreIdList
                                .contains(store.id),
                            isStore: true,
                            store: store,
                            storeId: store.id,
                            size: 18,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _heroButton(
                      icon: HugeIcons.strokeRoundedSearch01,
                      tooltip: 'search_for_items'.tr,
                      onTap:
                          () => Get.toNamed(
                            RouteHelper.getSearchStoreItemRoute(store.id),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── SCRATCH CARD — the logo's twin on the other corner: it sits on
          // the cover and scrolls away with it, so it never covers a product's
          // ADD button (docs/scratch_card_plan.md §3a) ───
          if (ScratchCardBadge.inBags)
            const PositionedDirectional(
              end: 15,
              bottom: -14,
              child: ScratchCardBadge(scale: 0.6, compact: true),
            ),

          // ─── LOGO TILE — overhangs the cover's bottom edge ───
          Positioned(
            left: 15,
            bottom: -_kLogoOverhang,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WaddyColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: WaddyColors.primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomImage(
                  image: store.logoFullUrl ?? '',
                  fit: BoxFit.cover,
                  height: 72,
                  width: 72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A white control floating over the hero: 40×40 painted, but given the
  /// 48pt tap floor because these sit right at the screen edge.
  Widget _heroButton({
    required List<List<dynamic>> icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return _heroChip(
      tooltip: tooltip,
      onTap: onTap,
      child: HugeIcon(icon: icon, size: 19, color: WaddyColors.ink),
    );
  }

  Widget _heroChip({
    required String tooltip,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: Dimensions.minTapTarget,
        height: Dimensions.minTapTarget,
        child: Center(
          child: Material(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: WaddyColors.primary.withValues(alpha: 0.18),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A flat, tinted icon tile — the scrolled header's own idiom, distinct
  /// from the elevated white chips that float over the hero photo.
  Widget _flatIconTile({
    required String tooltip,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: Dimensions.minTapTarget,
        height: Dimensions.minTapTarget,
        child: Center(
          child: Material(
            color: WaddyColors.surfaceRaised,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onTap,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SCROLLED HEADER — fixed bar once the hero clears the top
  // ═══════════════════════════════════════════
  Widget _buildScrolledHeader(BuildContext context, Store store) {
    final String? time =
        (store.deliveryTime ?? '').trim().isEmpty
            ? null
            : store.deliveryTime!.trim();

    // The bar is always built and always laid out — only its opacity changes —
    // so its height is known well before the scroll that reveals it, and the
    // tab strip's inset is correct on the very first reveal rather than one
    // frame late.
    _measureScrolledHeader();

    // Only the opacity and the pointer gate listen. The bar itself — its
    // layout, its text, its buttons — is built once per screen build and is
    // not rebuilt by a scroll.
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrolledHeader,
      builder:
          (context, showing, child) => AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: showing ? 1 : 0,
            child: IgnorePointer(ignoring: !showing, child: child),
          ),
      child: Container(
        key: _scrolledHeaderKey,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        decoration: const BoxDecoration(
          color: WaddyColors.surface,
          border: Border(bottom: BorderSide(color: WaddyColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A134E4A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Row(
            children: [
              _flatIconTile(
                tooltip: 'back'.tr,
                onTap: () => Get.back(),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 17,
                  color: WaddyColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.name ?? '',
                      style: waddyBold.copyWith(
                        fontSize: 16,
                        color: WaddyColors.ink,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (time != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: waddyRegular.copyWith(
                          fontSize: 12.5,
                          color: WaddyColors.inkLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GetBuilder<FavouriteController>(
                builder: (favouriteController) {
                  return _flatIconTile(
                    tooltip: 'favourite'.tr,
                    child: CustomFavouriteWidget(
                      isWished: favouriteController.wishStoreIdList.contains(
                        store.id,
                      ),
                      isStore: true,
                      store: store,
                      storeId: store.id,
                      size: 18,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              _flatIconTile(
                tooltip: 'search_for_items'.tr,
                onTap:
                    () => Get.toNamed(
                      RouteHelper.getSearchStoreItemRoute(store.id),
                    ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 18,
                  color: WaddyColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
