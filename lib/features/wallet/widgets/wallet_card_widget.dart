import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/features/wallet/domain/models/card_appearance_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

const int _totalSymbols = 33;

String _symbolPath(int index) => 'assets/image/wallet_ch/${index + 1}c.svg';

class WalletCardWidget extends StatefulWidget {
  const WalletCardWidget({super.key});

  @override
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  bool _isBalanceHidden = false;
  int _previewColorIndex = 0;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _startPreviewAnimation();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _startPreviewAnimation() {
    _previewTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _previewColorIndex =
              (_previewColorIndex + 1) % CardAppearances.options.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WalletController>(
      builder: (walletController) {
        return GetBuilder<ProfileController>(
          builder: (profileController) {
            final firstName = profileController.userInfoModel?.fName ?? '';
            final lastName = profileController.userInfoModel?.lName ?? '';
            final userName = '$firstName $lastName'.trim();
            final selectedIndex = walletController.selectedCardAppearance;
            final selectedSymbol = walletController.selectedCardSymbol;
            final appearance = CardAppearances.options[selectedIndex];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Dimensions.paddingSizeSmall),

                // Main Card
                _buildMainCard(
                  appearance,
                  userName,
                  profileController,
                  selectedSymbol,
                ),

                const SizedBox(height: 20),

                // Animated mini card preview (appearance button)
                _buildAnimatedPreviewButton(walletController),

                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainCard(
    CardAppearance appearance,
    String userName,
    ProfileController profileController,
    int symbolIndex,
  ) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          color: appearance.cardColor,
          boxShadow: [
            BoxShadow(
              color: appearance.cardColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: User name + Waddi logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      userName.isNotEmpty ? userName : 'card_holder'.tr,
                      style: waddyBold.copyWith(
                        color: appearance.textColor,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    Images.waddyLogo,
                    width: 32,
                    height: 32,
                    color: appearance.brandColor,
                  ),
                ],
              ),

              const Spacer(),

              // Balance with show/hide
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _isBalanceHidden
                          ? '\u2022\u2022\u2022\u2022\u2022\u2022'
                          : PriceConverter.convertPrice(
                            profileController.userInfoModel!.walletBalance,
                          ),
                      textDirection: TextDirection.ltr,
                      style: waddyBold.copyWith(
                        color: appearance.textColor,
                        fontSize: 30,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBalanceHidden = !_isBalanceHidden;
                      });
                    },
                    child: Icon(
                      _isBalanceHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: appearance.textColor.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row: Add Fund button + Symbol
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Add Fund on card
                  SvgPicture.asset(
                    _symbolPath(symbolIndex),
                    color: appearance.brandColor,
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedPreviewButton(WalletController walletController) {
    final previewAppearance = CardAppearances.options[_previewColorIndex];
    final currentAppearance =
        CardAppearances.options[walletController.selectedCardAppearance];

    return GestureDetector(
      onTap: () => _showAppearanceBottomSheet(walletController),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated mini card preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              width: 52,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                color: previewAppearance.cardColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      Images.waddyLogo,
                      width: 10,
                      height: 10,
                      color: previewAppearance.brandColor,
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SvgPicture.asset(
                        _symbolPath(walletController.selectedCardSymbol),
                        color: previewAppearance.brandColor,
                        width: 10,
                        height: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'appearance'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'change_card_color_icon'.tr,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).hintColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceBottomSheet(WalletController walletController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).hintColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'appearance'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 20,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).hintColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Theme.of(context).hintColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Scrollable content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Color section
                            Text(
                              'color'.tr,
                              style: waddyBold.copyWith(
                                fontSize: 16,
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 3x3 Color Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.586,
                                  ),
                              itemCount: CardAppearances.options.length,
                              itemBuilder: (context, index) {
                                final cardOption =
                                    CardAppearances.options[index];
                                final isSelected =
                                    index ==
                                    walletController.selectedCardAppearance;

                                return GestureDetector(
                                  onTap: () {
                                    walletController.setCardAppearance(index);
                                    setSheetState(() {});
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      color: cardOption.cardColor,
                                      border:
                                          isSelected
                                              ? Border.all(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                width: 2.5,
                                              )
                                              : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(
                                            Dimensions.paddingSizeSmall,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Image.asset(
                                                Images.waddyLogo,
                                                width: 14,
                                                height: 14,
                                                color: cardOption.brandColor,
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: SvgPicture.asset(
                                                  _symbolPath(
                                                    walletController
                                                        .selectedCardSymbol,
                                                  ),
                                                  color: cardOption.brandColor,
                                                  width: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Symbol section
                            Text(
                              'symbol'.tr,
                              style: waddyBold.copyWith(
                                fontSize: 16,
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Symbol Grid (33 icons, ~6 per row)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: _totalSymbols,
                              itemBuilder: (context, index) {
                                final isSelected =
                                    index ==
                                    walletController.selectedCardSymbol;
                                final currentAppearance =
                                    CardAppearances.options[walletController
                                        .selectedCardAppearance];

                                return GestureDetector(
                                  onTap: () {
                                    walletController.setCardSymbol(index);
                                    setSheetState(() {});
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      color:
                                          isSelected
                                              ? currentAppearance.cardColor
                                              : Theme.of(context).hintColor
                                                  .withValues(alpha: 0.06),
                                      border:
                                          isSelected
                                              ? Border.all(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeSmall,
                                      ),
                                      child: SvgPicture.asset(
                                        _symbolPath(index),
                                        color:
                                            isSelected
                                                ? currentAppearance.brandColor
                                                : Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class WalletStepper extends StatelessWidget {
  const WalletStepper({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  thickness: 3,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.30),
                ),
              ),
              Container(
                height: 15,
                width: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'earn_money_to_your_wallet_by_completing_the_offer_challenged'
                      .tr,
                  style: waddyRegular,
                ),
                Text(
                  'convert_your_loyalty_points_into_wallet_money'.tr,
                  style: waddyRegular,
                ),
                Text(
                  'amin_also_reward_their_top_customers_with_wallet_money'.tr,
                  style: waddyRegular,
                ),
                Text(
                  'send_your_wallet_money_while_order'.tr,
                  style: waddyRegular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
