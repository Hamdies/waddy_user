import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/models/transaction_model.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';

class HistoryItemWidget extends StatelessWidget {
  final int index;
  final bool fromWallet;
  final List<Transaction>? data;
  const HistoryItemWidget({
    super.key,
    required this.index,
    required this.fromWallet,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final transaction = data![index];
    final isDebit =
        transaction.transactionType == 'order_place' ||
        transaction.transactionType == 'partial_payment';

    return Row(
      children: [
        // Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isDebit
                    ? Colors.red.withValues(alpha: 0.08)
                    : const Color(0xFF0D9F6E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: Center(
            child:
                fromWallet
                    ? (isDebit
                        ? Image.asset(
                          Images.walletDebitIcon,
                          height: 18,
                          width: 18,
                        )
                        : Image.asset(
                          Images.walletCreditIcon,
                          height: 18,
                          width: 18,
                        ))
                    : (transaction.transactionType == 'point_to_wallet'
                        ? Image.asset(Images.debitIcon, height: 16, width: 16)
                        : Image.asset(
                          Images.creditIcon,
                          height: 16,
                          width: 16,
                        )),
          ),
        ),

        const SizedBox(width: 12),

        // Title + date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getDescription(transaction),
                style: waddyMedium.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                DateConverter.dateToDateAndTimeAm(transaction.createdAt!),
                style: waddyRegular.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Amount
        if (fromWallet)
          Text(
            isDebit
                ? '- ${PriceConverter.convertPrice(transaction.debit! + transaction.adminBonus!)}'
                : '+ ${PriceConverter.convertPrice(transaction.credit! + transaction.adminBonus!)}',
            style: waddyBold.copyWith(
              fontSize: 14,
              color: isDebit ? Colors.red : const Color(0xFF0D9F6E),
            ),
            textDirection: TextDirection.ltr,
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transaction.transactionType == 'point_to_wallet'
                    ? '-${transaction.debit!.toStringAsFixed(0)}'
                    : '+${transaction.credit!.toStringAsFixed(0)}',
                style: waddyBold.copyWith(
                  fontSize: 14,
                  color:
                      transaction.transactionType == 'point_to_wallet'
                          ? Colors.red
                          : const Color(0xFF0D9F6E),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'points'.tr,
                style: waddyRegular.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _getDescription(Transaction transaction) {
    switch (transaction.transactionType) {
      case 'add_fund':
        return '${'added_via'.tr} ${transaction.reference!.replaceAll('_', ' ')}';
      case 'partial_payment':
        return '${'spend_on_order'.tr} #${transaction.reference}';
      case 'loyalty_point':
        return 'converted_from_loyalty_point'.tr;
      case 'referrer':
        return 'earned_by_referral'.tr;
      case 'order_place':
        return '${'order_place'.tr} #${transaction.reference}';
      default:
        return transaction.transactionType!.tr;
    }
  }
}
