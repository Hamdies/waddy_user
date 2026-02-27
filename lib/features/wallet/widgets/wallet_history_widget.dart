import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/wallet/controllers/wallet_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import '../../../common/widgets/history_item_widget.dart';
import 'add_fund_dialogue_widget.dart';

class WalletHistoryWidget extends StatelessWidget {
  const WalletHistoryWidget({super.key});

  static const Color _neonGreen = Color(0xFF1EF2A0);
  static const Color _darkTeal = Color(0xFF134E4A);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WalletController>(
      builder: (walletController) {
        // Build popup menu entries
        List<PopupMenuEntry<int>> menuItems = [];
        String currentFilterName = 'all'.tr;

        for (int i = 0; i < walletController.walletFilterList.length; i++) {
          final filter = walletController.walletFilterList[i];
          final isSelected = filter.value == walletController.type;

          if (isSelected) {
            currentFilterName = filter.title!.tr;
          }

          menuItems.add(
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color:
                        isSelected
                            ? _neonGreen
                            : Theme.of(context).disabledColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    filter.title!.tr,
                    style: robotoMedium.copyWith(
                      color:
                          isSelected
                              ? _darkTeal
                              : Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and filter button
            Padding(
              padding: EdgeInsets.only(
                top:
                    ResponsiveHelper.isDesktop(context)
                        ? Dimensions.paddingSizeExtraSmall
                        : Dimensions.paddingSizeLarge,
                bottom: Dimensions.paddingSizeDefault,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Text(
                    'wallet_history'.tr,
                    style: robotoBold.copyWith(
                      fontSize: 18,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),

                  // Filter dropdown button
                  PopupMenuButton<int>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => menuItems,
                    onSelected: (value) {
                      walletController.setWalletFilerType(
                        walletController.walletFilterList[value].value!,
                      );
                      walletController.getWalletTransactionList(
                        '1',
                        false,
                        walletController.type,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _darkTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _darkTeal.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            color: _darkTeal,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentFilterName,
                            style: robotoMedium.copyWith(
                              color: _darkTeal,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _darkTeal,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transaction list
            walletController.transactionList != null
                ? walletController.transactionList!.isNotEmpty
                    ? ListView.builder(
                      key: UniqueKey(),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: walletController.transactionList!.length,
                      padding: const EdgeInsets.only(top: 8),
                      itemBuilder: (context, index) {
                        return WalletTransactionCard(
                          index: index,
                          data: walletController.transactionList,
                        );
                      },
                    )
                    : _buildEmptyState(context)
                : WalletShimmer(walletController: walletController),

            // Loading indicator
            if (walletController.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ScrollController fundScrollController = ScrollController();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wallet icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _darkTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 35,
              color: _darkTeal.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'no_transactions_yet'.tr,
            style: robotoBold.copyWith(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'your_transaction_history_will_appear_here'.tr,
            style: robotoRegular.copyWith(
              fontSize: 13,
              color: Theme.of(context).hintColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // CTA Button
          if (Get.find<SplashController>().configModel!.addFundStatus! &&
              Get.find<SplashController>().configModel!.digitalPayment!)
            GestureDetector(
              onTap: () {
                Get.dialog(
                  Dialog(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    child: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                        controller: fundScrollController,
                        child: AddFundDialogueWidget(
                          cardScrollController: fundScrollController,
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: _neonGreen.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.black, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'add_fund'.tr,
                      style: robotoBold.copyWith(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Transaction card
class WalletTransactionCard extends StatelessWidget {
  final int index;
  final List<dynamic>? data;

  const WalletTransactionCard({
    super.key,
    required this.index,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: HistoryItemWidget(
        index: index,
        fromWallet: true,
        data: data?.cast(),
      ),
    );
  }
}

class WalletShimmer extends StatelessWidget {
  final WalletController walletController;
  const WalletShimmer({super.key, required this.walletController});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 4,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            enabled: walletController.transactionList == null,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).shadowColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Theme.of(context).shadowColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).shadowColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 10,
                      width: 45,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 16,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
