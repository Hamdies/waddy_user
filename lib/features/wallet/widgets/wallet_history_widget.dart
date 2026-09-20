import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import '../../../common/widgets/history_item_widget.dart';

class WalletHistoryWidget extends StatelessWidget {
  const WalletHistoryWidget({super.key});

  // No hardcoded accent — uses theme colors

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WalletController>(
      builder: (walletController) {
        return Container(
          margin: const EdgeInsets.symmetric(
            vertical: Dimensions.paddingSizeSmall,
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — uppercase, letter-spaced, gray
              Text(
                'transaction_history'.tr.toUpperCase(),
                style: waddyBold.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Chip filters — outlined, scrollable
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    walletController.walletFilterList.length,
                    (index) {
                      final filter = walletController.walletFilterList[index];
                      final isSelected = filter.value == walletController.type;

                      return Padding(
                        padding: EdgeInsets.only(
                          right:
                              index <
                                      walletController.walletFilterList.length -
                                          1
                                  ? 8
                                  : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            walletController.setWalletFilerType(filter.value!);
                            walletController.getWalletTransactionList(
                              '1',
                              false,
                              walletController.type,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeDefault,
                              vertical: Dimensions.paddingSizeSmall,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.secondary
                                          .withValues(alpha: 0.12)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusExtraLarge,
                              ),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.secondary
                                        : Theme.of(
                                          context,
                                        ).hintColor.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              filter.title!.tr,
                              style: waddyMedium.copyWith(
                                fontSize: 13,
                                color:
                                    isSelected
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(
                                          context,
                                        ).hintColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Transaction list or empty state
              walletController.transactionList != null
                  ? walletController.transactionList!.isNotEmpty
                      ? ListView.separated(
                        key: UniqueKey(),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: walletController.transactionList!.length,
                        padding: EdgeInsets.zero,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 24,
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.08),
                            ),
                        itemBuilder: (context, index) {
                          return HistoryItemWidget(
                            index: index,
                            fromWallet: true,
                            data: walletController.transactionList?.cast(),
                          );
                        },
                      )
                      : _buildEmptyState(context)
                  : WalletShimmer(walletController: walletController),

              if (walletController.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtremeLarge,
      ),
      child: Center(
        child: Column(
          children: [
            // Stacked card placeholders
            SizedBox(
              height: 100,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    child: _buildPlaceholderCard(context, 0.85),
                  ),
                  Positioned(
                    top: 16,
                    child: _buildPlaceholderCard(context, 0.92),
                  ),
                  Positioned(
                    top: 32,
                    child: _buildPlaceholderCard(context, 1.0),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'transactions_will_appear_here'.tr,
              style: waddyMedium.copyWith(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(BuildContext context, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 160,
        height: 44,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeMedium,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: Theme.of(context).hintColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraSmall,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 6,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).hintColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).hintColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
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
}

class WalletShimmer extends StatelessWidget {
  final WalletController walletController;
  const WalletShimmer({super.key, required this.walletController});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 4,
      padding: EdgeInsets.zero,
      separatorBuilder:
          (context, index) => Divider(
            height: 24,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          ),
      itemBuilder: (context, index) {
        return Shimmer(
          duration: const Duration(seconds: 2),
          enabled: walletController.transactionList == null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).shadowColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 11,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 9,
                      width: 70,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 11,
                width: 45,
                decoration: BoxDecoration(
                  color: Theme.of(context).shadowColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
