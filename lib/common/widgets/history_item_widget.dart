import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/models/transaction_model.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';

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

  static const Color _neonGreen = Color(0xFF1EF2A0);

  @override
  Widget build(BuildContext context) {
    final transaction = data![index];
    final isDebit =
        transaction.transactionType == 'order_place' ||
        transaction.transactionType == 'partial_payment';

    return Row(
      children: [
        // Transaction icon with colored background
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                isDebit
                    ? Colors.red.withValues(alpha: 0.1)
                    : _neonGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child:
                fromWallet
                    ? (isDebit
                        ? Image.asset(
                          Images.walletDebitIcon,
                          height: 20,
                          width: 20,
                        )
                        : Image.asset(
                          Images.walletCreditIcon,
                          height: 20,
                          width: 20,
                        ))
                    : (transaction.transactionType == 'point_to_wallet'
                        ? Image.asset(Images.debitIcon, height: 18, width: 18)
                        : Image.asset(
                          Images.creditIcon,
                          height: 18,
                          width: 18,
                        )),
          ),
        ),

        const SizedBox(width: Dimensions.paddingSizeDefault),

        // Transaction details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              if (fromWallet)
                Text(
                  isDebit
                      ? '- ${PriceConverter.convertPrice(transaction.debit! + transaction.adminBonus!)}'
                      : '+ ${PriceConverter.convertPrice(transaction.credit! + transaction.adminBonus!)}',
                  style: robotoBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: isDebit ? Colors.red : _neonGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                )
              else
                Row(
                  children: [
                    Text(
                      transaction.transactionType == 'point_to_wallet'
                          ? '-${transaction.debit!.toStringAsFixed(0)}'
                          : '+${transaction.credit!.toStringAsFixed(0)}',
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color:
                            transaction.transactionType == 'point_to_wallet'
                                ? Colors.red
                                : _neonGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                    Text(
                      'points'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 4),

              // Description
              Text(
                _getTransactionDescription(transaction),
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).hintColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: Dimensions.paddingSizeSmall),

        // Date and status
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateConverter.dateToDateAndTimeAm(transaction.createdAt!),
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(
                  transaction,
                  fromWallet,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getStatusText(transaction, fromWallet),
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: _getStatusColor(transaction, fromWallet),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getTransactionDescription(Transaction transaction) {
    switch (transaction.transactionType) {
      case 'add_fund':
        final bonus =
            transaction.adminBonus != 0
                ? ' (${'bonus'.tr} = ${transaction.adminBonus})'
                : '';
        return '${'added_via'.tr} ${transaction.reference!.replaceAll('_', ' ')}$bonus';
      case 'partial_payment':
        return '${'spend_on_order'.tr} # ${transaction.reference}';
      case 'loyalty_point':
        return 'converted_from_loyalty_point'.tr;
      case 'referrer':
        return 'earned_by_referral'.tr;
      case 'order_place':
        return '${'order_place'.tr} # ${transaction.reference}';
      default:
        return transaction.transactionType!.tr;
    }
  }

  Color _getStatusColor(Transaction transaction, bool fromWallet) {
    if (fromWallet) {
      return (transaction.transactionType == 'order_place' ||
              transaction.transactionType == 'partial_payment')
          ? Colors.red
          : const Color(0xFF1EF2A0);
    } else {
      return transaction.transactionType == 'point_to_wallet'
          ? Colors.red
          : const Color(0xFF1EF2A0);
    }
  }

  String _getStatusText(Transaction transaction, bool fromWallet) {
    if (fromWallet) {
      return (transaction.transactionType == 'order_place' ||
              transaction.transactionType == 'partial_payment')
          ? 'debit'.tr
          : 'credit'.tr;
    } else {
      return transaction.transactionType == 'point_to_wallet'
          ? 'debit'.tr
          : 'credit'.tr;
    }
  }
}
