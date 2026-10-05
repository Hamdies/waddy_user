import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/pet_usual_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/screens/pet_details_screen.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/features/item/screens/mart_product_screen.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "Order again · Luna's usual" (design screen 01, PET-10).
///
/// The design's "Subscribe, save 10%" is a reminder in v1 (D4): no recurring
/// order and no discount, a push every N weeks that brings them back here.
/// "Buy again" opens the product's sheet, so a size or option is picked the
/// same way as anywhere else.
class PetUsualCard extends StatelessWidget {
  const PetUsualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PetController>(
      id: PetController.idUsual,
      builder: (pets) {
        final PetUsualModel? usual = pets.usual;
        if (usual == null) return const SizedBox.shrink();
        final UserPetModel? pet = pets.primaryPet;
        final Item item = usual.item;
        final PetReminderModel? reminder = usual.reminder;
        final double price = item.price ?? 0;
        final double now =
            PriceConverter.convertWithDiscount(
              price,
              item.discount ?? 0,
              item.discountType,
            ) ??
            price;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_again'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: displayTracking(-0.4),
                      color: WaddyColors.ink,
                    ),
                  ),
                  if (pet != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'pet_usual_sub'.trParams({'name': pet.name}),
                      style: waddyRegular.copyWith(
                        fontSize: 12,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WaddyColors.amberSurface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault + 2,
                        ),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: WaddyColors.surface,
                          child: CustomImage(
                            image: item.imageFullUrl ?? '',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: waddyBold.copyWith(
                                fontSize: 14,
                                height: 1.3,
                                color: WaddyColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            PriceTag(price: ItemPrice.of(item)),
                            if (now < price) ...[
                              const SizedBox(height: 6),
                              OfferCollarBadge.forPrice(
                                ItemPrice.of(item),
                                compact: true,
                              )!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (reminder == null)
                    Row(
                      children: [
                        Expanded(
                          child: _Button(
                            label: 'pet_remind_every_4_weeks'.tr,
                            filled: true,
                            busy: pets.reminderSaving,
                            onTap: () => _setReminder(28),
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        _Button(
                          label: 'buy_again'.tr,
                          onTap: () => MartProductScreen.open(item),
                        ),
                      ],
                    )
                  else
                    _ReminderRow(
                      reminder: reminder,
                      onChange: () => _ReminderSheet.show(context, reminder),
                      onBuy: () => MartProductScreen.open(item),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _setReminder(int? days) async {
    final bool ok = await Get.find<PetController>().setUsualReminder(days);
    if (!ok) showCustomSnackBar('pet_reminder_failed'.tr);
  }
}

class _ReminderRow extends StatelessWidget {
  final PetReminderModel reminder;
  final VoidCallback onChange;
  final VoidCallback onBuy;

  const _ReminderRow({
    required this.reminder,
    required this.onChange,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime? next = reminder.nextAt;
    final String when =
        next == null
            ? ''
            : ' · ${'pet_reminder_next'.trParams({'date': DateFormat('MMM d', Get.locale?.languageCode).format(next)})}';
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 6, 0),
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: WaddyColors.primaryLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${PetCopy.everyWeeks(reminder.weeks)}$when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBold.copyWith(
                      fontSize: 12,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
                Pressable(
                  onTap: onChange,
                  semanticLabel: 'edit'.tr,
                  scale: WaddyMotion.pressControl,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall + 2,
                      ),
                    ),
                    child: Text(
                      'edit'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 12,
                        color: WaddyColors.inkMid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        _Button(label: 'buy_again'.tr, onTap: onBuy),
      ],
    );
  }
}

/// Every 2 / 3 / 4 / 6 weeks, or off.
class _ReminderSheet extends StatelessWidget {
  final PetReminderModel current;

  const _ReminderSheet({required this.current});

  static Future<void> show(BuildContext context, PetReminderModel current) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pick(int? days) async {
      Get.back();
      await PetUsualCard._setReminder(days);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'pet_reminder_how_often'.tr,
            style: waddyBold.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WaddyColors.ink,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          for (final int days in PetReminderModel.intervals)
            Pressable(
              onTap: () => pick(days),
              semanticLabel: PetCopy.everyWeeks(days ~/ 7),
              scale: WaddyMotion.pressControl,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      days == current.intervalDays
                          ? WaddyColors.primarySurface
                          : WaddyColors.surface,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  border: Border.all(
                    color:
                        days == current.intervalDays
                            ? WaddyColors.primary
                            : WaddyColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        PetCopy.everyWeeks(days ~/ 7),
                        style: waddyBold.copyWith(
                          fontSize: 14,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                    if (days == current.intervalDays)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: WaddyColors.primary,
                      ),
                  ],
                ),
              ),
            ),
          Pressable(
            onTap: () => pick(null),
            semanticLabel: 'pet_reminder_off'.tr,
            minSize: Dimensions.minTapTarget,
            child: Text(
              'pet_reminder_off'.tr,
              textAlign: TextAlign.center,
              style: waddyBold.copyWith(
                fontSize: 14,
                color: WaddyColors.coralInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border:
              filled
                  ? null
                  : Border.all(color: WaddyColors.primary, width: 1.5),
          boxShadow:
              filled
                  ? const [
                    BoxShadow(color: WaddyColors.mint, offset: Offset(0, 2)),
                  ]
                  : null,
        ),
        child:
            busy
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : WaddyColors.primary,
                  ),
                ),
      ),
    );
  }
}

/// "When's Luna's birthday?" Shown under the hub's pet card while the
/// primary pet has none. Opens the pet's details on the birthday question
/// (D5: asked here, never in onboarding).
class PetBirthdayNudge extends StatelessWidget {
  const PetBirthdayNudge({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PetController>(
      id: PetController.idPets,
      builder: (pets) {
        final UserPetModel? pet = pets.primaryPet;
        if (pet == null || pet.id == null || pet.birthDate != null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Pressable(
            onTap: () => PetDetailsScreen.open(pet, askBirthday: true),
            semanticLabel: 'pet_birthday_nudge'.trParams({'name': pet.name}),
            scale: WaddyMotion.pressCard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                border: Border.all(color: WaddyColors.divider),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedBirthdayCake,
                    size: 22,
                    color: WaddyColors.primary,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Expanded(
                    child: Text(
                      'pet_birthday_nudge'.trParams({'name': pet.name}),
                      style: waddyBold.copyWith(
                        fontSize: 13,
                        color: WaddyColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: WaddyColors.inkLight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
