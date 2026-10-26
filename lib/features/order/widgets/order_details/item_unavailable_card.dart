import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// XS-4: the store ran out of an item after the order was placed. The
/// customer decides: continue without it, or cancel. The store then updates
/// the bill or cancels (with refund) on its side.
class ItemUnavailableCard extends StatefulWidget {
  final String itemName;
  final Future<bool> Function(String choice) onAnswer;
  const ItemUnavailableCard({super.key, required this.itemName, required this.onAnswer});

  @override
  State<ItemUnavailableCard> createState() => _ItemUnavailableCardState();
}

class _ItemUnavailableCardState extends State<ItemUnavailableCard> {
  String? _sending;

  Future<void> _answer(String choice) async {
    if (_sending != null) return;
    setState(() => _sending = choice);
    final bool ok = await widget.onAnswer(choice);
    if (mounted && !ok) setState(() => _sending = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: WaddyColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: WaddyColors.coral.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('od_item_unavailable_title'.trParams({'item': widget.itemName}), style: waddyBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text('od_item_unavailable_body'.tr, style: waddyRegular),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Row(children: [
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: WaddyColors.mint, foregroundColor: WaddyColors.primary, minimumSize: const Size(0, 48)),
            onPressed: _sending == null ? () => _answer('remove') : null,
            child: _sending == 'remove' ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('od_item_unavailable_continue'.tr, textAlign: TextAlign.center),
          )),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: WaddyColors.coral, minimumSize: const Size(0, 48)),
            onPressed: _sending == null ? () => _answer('cancel') : null,
            child: _sending == 'cancel' ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('od_item_unavailable_cancel'.tr, textAlign: TextAlign.center),
          )),
        ]),
      ]),
    );
  }
}
