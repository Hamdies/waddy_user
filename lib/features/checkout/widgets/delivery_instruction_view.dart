import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/checkout/widgets/voice_recorder_widget.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Delivery instructions as a row of tiles, always open.
///
/// The first tile is the voice note: it records, plays and deletes in place.
/// When the delivery address already has a saved note the tile starts out
/// ready to play it; when it has none, a hint under the tile points at it.
class DeliveryInstructionView extends StatefulWidget {
  /// The selected address's saved voice note, if any.
  final String? savedVoiceUrl;
  const DeliveryInstructionView({super.key, this.savedVoiceUrl});

  @override
  State<DeliveryInstructionView> createState() =>
      _DeliveryInstructionViewState();
}

class _DeliveryInstructionViewState extends State<DeliveryInstructionView> {
  static const double _tileWidth = 88;
  static const double _tileHeight = 84;
  static const double _tileGap = Dimensions.paddingSizeSmall;
  static const double _notch = 14;

  static const List<List<List<dynamic>>> _instructionIcons = [
    HugeIcons.strokeRoundedCallBlocked,
    HugeIcons.strokeRoundedNotificationOff01,
    HugeIcons.strokeRoundedDoor01,
    HugeIcons.strokeRoundedShield01,
    HugeIcons.strokeRoundedHome01,
    HugeIcons.strokeRoundedDesk,
  ];

  final ScrollController _rowController = ScrollController();

  /// Hidden for the rest of this checkout once the voice tile or the hint is
  /// touched.
  bool _hintDismissed = false;

  @override
  void initState() {
    super.initState();
    // The notch tracks the voice tile as the row scrolls.
    _rowController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rowController.dispose();
    super.dispose();
  }

  bool get _hasSavedVoice =>
      widget.savedVoiceUrl != null && widget.savedVoiceUrl!.isNotEmpty;

  void _dismissHint() {
    if (!_hintDismissed) setState(() => _hintDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CheckoutController>(
      builder: (checkoutController) {
        final bool hasVoice =
            checkoutController.voiceInstructionPath != null || _hasSavedVoice;

        final double offset =
            _rowController.hasClients ? _rowController.offset : 0;
        // Only while the voice tile's centre is on screen; once it scrolls
        // off there is nothing for the notch to point at.
        final bool showHint =
            !hasVoice && !_hintDismissed && offset < _tileWidth / 2;

        return CheckoutCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeDefault,
            0,
            Dimensions.paddingSizeDefault,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'delivery_instructions'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: WaddyColors.ink,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeMedium),

              SingleChildScrollView(
                controller: _rowController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  children: [
                    VoiceRecorderWidget(
                      // A different address brings a different saved note.
                      key: ValueKey(widget.savedVoiceUrl),
                      asTile: true,
                      tileWidth: _tileWidth,
                      tileHeight: _tileHeight,
                      existingRecordingPath:
                          checkoutController.voiceInstructionPath,
                      savedRemoteUrl: widget.savedVoiceUrl,
                      onInteract: _dismissHint,
                      onRecordingChanged:
                          checkoutController.setVoiceInstructionPath,
                    ),
                    for (
                      int i = 0;
                      i < AppConstants.deliveryInstructionList.length;
                      i++
                    ) ...[
                      const SizedBox(width: _tileGap),
                      _InstructionTile(
                        icon:
                            i < _instructionIcons.length
                                ? _instructionIcons[i]
                                : HugeIcons.strokeRoundedInformationCircle,
                        label: AppConstants.deliveryInstructionList[i].tr,
                        selected: checkoutController.selectedInstructions
                            .contains(i),
                        onTap: () => checkoutController.toggleInstruction(i),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHint)
                      _VoiceHint(
                        arrowStart: _tileWidth / 2 - _notch / 2 - offset,
                        onTap: _dismissHint,
                      ),
                    const SizedBox(height: Dimensions.paddingSizeMedium),
                    CheckoutCheckRow(
                      value: checkoutController.saveInstructionForAddress,
                      onTap: checkoutController.toggleSaveInstructionForAddress,
                      label: 'save_for_all_orders_at_this_address'.tr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InstructionTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InstructionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _DeliveryInstructionViewState._tileWidth,
          height: _DeliveryInstructionViewState._tileHeight,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: selected ? WaddyColors.mintSurface : WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(
              color: selected ? WaddyColors.primary : WaddyColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckoutIcon(icon: icon, size: 22, color: WaddyColors.ink),
                  const Spacer(),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: WaddyColors.primary,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraSmall,
                        ),
                      ),
                      child: const CheckoutIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 16,
                        color: WaddyColors.surface,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark callout under the tile row, with a notch pointing up at the voice
/// tile. Tapping it dismisses it.
class _VoiceHint extends StatelessWidget {
  final double arrowStart;
  final VoidCallback onTap;
  const _VoiceHint({required this.arrowStart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeMedium),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: arrowStart,
            top: -6,
            child: Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(
                width: _DeliveryInstructionViewState._notch,
                height: _DeliveryInstructionViewState._notch,
                decoration: BoxDecoration(
                  color: WaddyColors.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Material(
            color: WaddyColors.ink,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: WaddyColors.surface,
                      ),
                      child: const CheckoutIcon(
                        icon: HugeIcons.strokeRoundedMic01,
                        size: 20,
                        color: WaddyColors.mintInk,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Expanded(
                      child: Text(
                        'you_can_now_add_voice_directions'.tr,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: WaddyColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
