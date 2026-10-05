import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/util/dimensions.dart';

const Color _orange = Color(0xFFF96D2B);

class AddFundScreen extends StatefulWidget {
  const AddFundScreen({super.key});

  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<double> _quickAmounts = [50, 100, 250, 500];

  int? _selectedQuickIndex;

  @override
  void initState() {
    super.initState();
    final wc = Get.find<WalletController>();
    wc.isTextFieldEmpty('', isUpdate: false);
    wc.changeDigitalPaymentName('', isUpdate: false);

    final config = Get.find<SplashController>().configModel;
    if (config.activePaymentMethodList!.length == 1) {
      wc.changeDigitalPaymentName(
        config.activePaymentMethodList!.first.getWay!,
        isUpdate: false,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _cur =>
      PriceConverter.convertPrice(0).replaceAll(RegExp(r'[0-9.,]'), '').trim();

  void _selectQuick(int i) {
    setState(() {
      _selectedQuickIndex = i;
      _amountController.text = _quickAmounts[i].toStringAsFixed(0);
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
    Get.find<WalletController>().isTextFieldEmpty(_amountController.text);
  }

  void _onAmountChanged(String value) {
    setState(() {
      final p = double.tryParse(value);
      _selectedQuickIndex =
          p != null && _quickAmounts.contains(p)
              ? _quickAmounts.indexOf(p)
              : null;
    });

    String c = value.replaceAll(RegExp(r'[-, ]'), '');
    if (c != value) {
      _amountController.text = c;
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: c.length),
      );
    }

    try {
      if (double.parse(c) > 0) {
        Get.find<WalletController>().isTextFieldEmpty(c);
      }
    } catch (_) {
      Get.find<WalletController>().isTextFieldEmpty('');
    }
  }

  void _onProceed(WalletController wc) {
    if (_amountController.text.isEmpty) {
      showCustomSnackBar('please_provide_transfer_amount'.tr);
    } else if (_amountController.text == '0') {
      showCustomSnackBar('you_can_not_add_zero_amount_in_wallet'.tr);
    } else if (wc.digitalPaymentName == '') {
      showCustomSnackBar('please_select_payment_method'.tr);
    } else {
      final sym = Get.find<SplashController>().configModel.currencySymbol!;
      double amount = double.parse(_amountController.text.replaceAll(sym, ''));
      wc.addFundToWallet(amount, wc.digitalPaymentName!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance =
        Get.find<ProfileController>().userInfoModel?.walletBalance ?? 0;
    final hintC = Theme.of(context).hintColor;
    final cardC = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: cardC,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(
            Icons.arrow_back,
            size: 22,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'add_balance'.tr,
              style: waddyBold.copyWith(
                fontSize: 17,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              '${'available_balance'.tr}: ${PriceConverter.convertPrice(balance)}',
              style: waddyRegular.copyWith(fontSize: 12, color: hintC),
            ),
          ],
        ),
      ),
      body: GetBuilder<WalletController>(
        builder: (wc) {
          final methods =
              Get.find<SplashController>().configModel.activePaymentMethodList!;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      // ═══ AMOUNT CARD ═══
                      Container(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        decoration: BoxDecoration(
                          color: cardC,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text field
                            TextField(
                              controller: _amountController,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              style: waddyMedium.copyWith(fontSize: 16),
                              onChanged: _onAmountChanged,
                              decoration: InputDecoration(
                                labelText: 'enter_amount'.tr,
                                labelStyle: waddyRegular.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 14,
                                ),
                                floatingLabelStyle: waddyRegular.copyWith(
                                  color: hintC.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                prefixText: '$_cur ',
                                prefixStyle: waddyMedium.copyWith(fontSize: 16),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeMedium,
                                  vertical: Dimensions.paddingSizeMedium,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  borderSide: BorderSide(
                                    color: hintC.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  borderSide: BorderSide(
                                    color: hintC.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Chips row ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(_quickAmounts.length, (
                                i,
                              ) {
                                final isSelected = _selectedQuickIndex == i;
                                final label =
                                    '$_cur ${_quickAmounts[i].toStringAsFixed(0)}';

                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i < 3 ? 8 : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _selectQuick(i),
                                      child:
                                          isSelected
                                              ? _selectedChip(label)
                                              : _normalChip(label),
                                    ),
                                  ),
                                );
                              }),
                            ),

                            const SizedBox(height: 16),

                            Divider(
                              height: 1,
                              color: hintC.withValues(alpha: 0.1),
                            ),

                            const SizedBox(height: 14),

                            // Bonus or secure text
                            if (wc.fundBonusList != null &&
                                wc.fundBonusList!.isNotEmpty)
                              _buildBonusRow(wc)
                            else
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 14,
                                    color: hintC,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'add_fund_form_secured_digital_payment_gateways'
                                          .tr,
                                      style: waddyRegular.copyWith(
                                        fontSize: 12,
                                        color: hintC,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ═══ PAYMENT METHOD CARD ═══
                      Container(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        decoration: BoxDecoration(
                          color: cardC,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'choose_payment_method'.tr,
                              style: waddyBold.copyWith(fontSize: 15),
                            ),

                            const SizedBox(height: 12),
                            ...List.generate(methods.length, (index) {
                              final m = methods[index];
                              final sel = m.getWay == wc.digitalPaymentName;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < methods.length - 1 ? 8 : 0,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      () => wc.changeDigitalPaymentName(
                                        m.getWay!,
                                      ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimensions.paddingSizeMedium,
                                      vertical: Dimensions.paddingSizeMedium,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          sel
                                              ? Theme.of(context)
                                                  .secondaryHeaderColor
                                                  .withValues(alpha: 0.04)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      border: Border.all(
                                        color:
                                            sel
                                                ? Theme.of(context).primaryColor
                                                : hintC.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                sel
                                                    ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                    : Colors.transparent,
                                            border: Border.all(
                                              color:
                                                  sel
                                                      ? Theme.of(
                                                        context,
                                                      ).primaryColor
                                                      : Theme.of(
                                                        context,
                                                      ).disabledColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child:
                                              sel
                                                  ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 13,
                                                  )
                                                  : null,
                                        ),
                                        const SizedBox(width: 10),
                                        CustomImage(
                                          height: 20,
                                          fit: BoxFit.contain,
                                          image: '${m.getWayImageFullUrl}',
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            m.getWayTitle!,
                                            style: waddyMedium.copyWith(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ═══ NOTE CARD ═══
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).secondaryHeaderColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'note'.tr}:',
                              style: waddyMedium.copyWith(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _bullet('wallet_note_1'.tr),
                            const SizedBox(height: 10),
                            _bullet('wallet_note_2'.tr),
                            const SizedBox(height: 10),
                            _bullet('wallet_note_3'.tr),
                          ],
                        ),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ═══ BOTTOM BUTTON ═══
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                decoration: BoxDecoration(
                  color: cardC,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: CustomButton(
                    buttonText: 'proceed_to_add_balance'.tr,
                    isLoading: wc.isLoading,
                    onPressed: () => _onProceed(wc),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Selected chip: orange filled top + "Most Popular" badge ──
  Widget _selectedChip(String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(
                context,
              ).secondaryHeaderColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Center(
                child: Text(
                  label,
                  style: waddyBold.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Normal chip: outlined, single line ──
  Widget _normalChip(String label) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).hintColor.withValues(alpha: 0.18),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: waddyMedium.copyWith(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildBonusRow(WalletController wc) {
    final b = wc.fundBonusList!.first;
    return Row(
      children: [
        Icon(
          Icons.card_giftcard_rounded,
          size: 16,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: waddyRegular.copyWith(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              children: [
                TextSpan(text: '${'add_minimum'.tr} '),
                TextSpan(
                  text: PriceConverter.convertPrice(b.minimumAddAmount),
                  style: waddyBold.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                TextSpan(text: ' ${'and_get'.tr} '),
                TextSpan(
                  text:
                      '${b.bonusAmount}${b.bonusType == 'percent' ? '%' : ''}',
                  style: waddyBold.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                TextSpan(text: ' ${'bonus'.tr}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(
            top: 6,
            right: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: waddyRegular.copyWith(
              fontSize: 13,
              color: Theme.of(context).primaryColor,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
