import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/screens/pet_onboarding_screen.dart';
import 'package:waddy_app/features/pets/widgets/pet_age_counter.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// One pet's profile: what onboarding didn't ask (PET-06, D5).
///
/// - Birthday: a real date, or "about N years old" saved as an estimate.
///   Birthday pushes only fire on a real date; an estimate still moves the
///   life stage on.
/// - Breed and weight: what sizes the food (and, later, the run-out estimate).
/// - Reminders about this pet: the per-pet off switch for lifecycle pushes.
///
/// Name, species, sex, age band and diet are edited through the onboarding
/// steps ("Edit basics"), so there is one form for them, not two.
class PetDetailsScreen extends StatefulWidget {
  final UserPetModel pet;

  /// Opens the birthday question on arrival (the hub's "When's Luna's
  /// birthday?" nudge).
  final bool askBirthday;

  const PetDetailsScreen({
    super.key,
    required this.pet,
    this.askBirthday = false,
  });

  static Future<void> open(UserPetModel pet, {bool askBirthday = false}) async {
    await Get.to(() => PetDetailsScreen(pet: pet, askBirthday: askBirthday));
  }

  @override
  State<PetDetailsScreen> createState() => _PetDetailsScreenState();
}

class _PetDetailsScreenState extends State<PetDetailsScreen> {
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  DateTime? _birthDate;
  bool _estimate = false;
  late bool _notify;
  bool _saving = false;

  PetController get _pets => Get.find<PetController>();

  /// The saved pet as it is now: an edit through "Edit basics" replaces it.
  UserPetModel get _pet =>
      _pets.pets?.firstWhereOrNull((p) => p.id == widget.pet.id) ?? widget.pet;

  @override
  void initState() {
    super.initState();
    final UserPetModel pet = widget.pet;
    _breed = TextEditingController(text: pet.breed ?? '');
    _weight = TextEditingController(
      text: pet.weightKg == null ? '' : _trimZeros(pet.weightKg!),
    );
    _birthDate = pet.birthDate;
    _estimate = pet.birthDateIsEstimate;
    _notify = pet.notify;
    if (widget.askBirthday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askBirthday();
      });
    }
  }

  @override
  void dispose() {
    _breed.dispose();
    _weight.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _save() async {
    if (_saving) return;
    final String weightText = _weight.text.trim().replaceAll(',', '.');
    final double? weight =
        weightText.isEmpty ? null : double.tryParse(weightText);
    if (weightText.isNotEmpty &&
        (weight == null || weight <= 0 || weight > 200)) {
      showCustomSnackBar('pet_weight_invalid'.tr);
      return;
    }
    setState(() => _saving = true);
    final bool ok = await _pets.savePet(
      _pet.copyWith(
        birthDate: _birthDate,
        birthDateIsEstimate: _estimate,
        breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
        weightKg: weight,
        notify: _notify,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.back();
    } else {
      showCustomSnackBar('pet_save_failed'.tr);
    }
  }

  Future<void> _askBirthday() async {
    final _BirthdayAnswer? answer = await showModalBottomSheet<_BirthdayAnswer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BirthdaySheet(name: _pet.name),
    );
    if (answer == null || !mounted) return;
    if (answer.years != null) {
      final DateTime now = DateTime.now();
      setState(() {
        _birthDate = DateTime(now.year - answer.years!, now.month, 1);
        _estimate = true;
      });
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _estimate ? null : _birthDate,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'pet_birthday_pick'.trParams({'name': _pet.name}),
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _estimate = false;
      });
    }
  }

  String get _birthdayLabel {
    final DateTime? date = _birthDate;
    if (date == null) return 'pet_birthday_add'.tr;
    if (_estimate) {
      return PetCopy.aboutYears(DateTime.now().year - date.year);
    }
    return DateFormat.yMMMd(Get.locale?.languageCode).format(date);
  }

  Future<void> _confirmDelete() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('pet_delete_title'.trParams({'name': _pet.name})),
            content: Text('pet_delete_body'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'remove'.tr,
                  style: const TextStyle(color: WaddyColors.coralInk),
                ),
              ),
            ],
          ),
    );
    if (yes != true) return;
    final bool ok = await _pets.deletePet(_pet);
    if (!mounted) return;
    if (ok) {
      Get.back();
    } else {
      showCustomSnackBar('pet_save_failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PetController>(
      id: PetController.idPets,
      builder: (_) {
        final UserPetModel pet = _pet;
        final String stage = switch (pet.lifeStage ?? pet.ageBand) {
          PetAgeBand.baby => switch (pet.species) {
            PetSpecies.cat => 'pet_age_kitten'.tr,
            PetSpecies.dog => 'pet_age_puppy'.tr,
            _ => 'pet_age_baby'.tr,
          },
          PetAgeBand.adult => 'pet_age_adult'.tr,
          PetAgeBand.senior => 'pet_age_senior'.tr,
          null => '',
        };
        return Scaffold(
          backgroundColor: WaddyColors.canvas,
          appBar: AppBar(
            backgroundColor: WaddyColors.canvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              pet.name,
              style: waddyBold.copyWith(fontSize: 17, color: WaddyColors.ink),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  PetAvatar(
                    species: pet.species,
                    photoUrl: pet.photoUrl,
                    size: 80,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeDefault),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            pet.species.label,
                            if (stage.isNotEmpty) stage,
                            if (pet.sex != PetSex.unknown)
                              'pet_sex_${pet.sex.wire}'.tr,
                          ].join(' · '),
                          style: waddyMedium.copyWith(
                            fontSize: 13,
                            color: WaddyColors.inkMid,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        Pressable(
                          onTap: () => PetOnboardingScreen.open(editing: pet),
                          semanticLabel: 'pet_edit_basics'.tr,
                          scale: WaddyMotion.pressControl,
                          child: Text(
                            'pet_edit_basics'.tr,
                            style: waddyBold.copyWith(
                              fontSize: 13,
                              color: WaddyColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              _label('pet_birthday'.tr),
              Pressable(
                onTap: _askBirthday,
                semanticLabel: 'pet_birthday'.tr,
                scale: WaddyMotion.pressCard,
                child: _box(
                  child: Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedBirthdayCake,
                        size: 20,
                        color: WaddyColors.primary,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeMedium),
                      Expanded(
                        child: Text(
                          _birthdayLabel,
                          style: waddyBold.copyWith(
                            fontSize: 14,
                            color:
                                _birthDate == null
                                    ? WaddyColors.primary
                                    : WaddyColors.ink,
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
              if (_estimate && _birthDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'pet_birthday_estimate_note'.tr,
                    style: waddyRegular.copyWith(
                      fontSize: 12,
                      color: WaddyColors.inkLight,
                    ),
                  ),
                ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _label('pet_breed'.tr),
              _field(_breed, hint: 'pet_breed_hint'.tr, maxLength: 64),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _label('pet_weight'.tr),
              _field(
                _weight,
                hint: 'pet_weight_hint'.tr,
                maxLength: 6,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                suffix: 'kg'.tr,
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _box(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'pet_notify_title'.trParams({'name': pet.name}),
                            style: waddyBold.copyWith(
                              fontSize: 14,
                              color: WaddyColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'pet_notify_sub'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _notify,
                      activeTrackColor: WaddyColors.primary,
                      onChanged: (v) => setState(() => _notify = v),
                    ),
                  ],
                ),
              ),
              if (!pet.isPrimary && pet.id != null) ...[
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Pressable(
                  onTap: () => _pets.setPrimary(pet),
                  semanticLabel: 'pet_make_main'.trParams({'name': pet.name}),
                  scale: WaddyMotion.pressCard,
                  child: _box(
                    child: Text(
                      'pet_make_main'.trParams({'name': pet.name}),
                      style: waddyBold.copyWith(
                        fontSize: 14,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              Pressable(
                onTap: _confirmDelete,
                semanticLabel: 'pet_delete_title'.trParams({'name': pet.name}),
                minSize: Dimensions.minTapTarget,
                child: Text(
                  'pet_delete_title'.trParams({'name': pet.name}),
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    fontSize: 14,
                    color: WaddyColors.coralInk,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Pressable(
              onTap: _saving ? null : _save,
              semanticLabel: 'save'.tr,
              scale: WaddyMotion.pressControl,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WaddyColors.primary,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  boxShadow: const [
                    BoxShadow(color: WaddyColors.mint, offset: Offset(0, 3)),
                  ],
                ),
                child:
                    _saving
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          'save'.tr,
                          style: waddyBold.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: waddyBold.copyWith(fontSize: 13, color: WaddyColors.inkMid),
    ),
  );

  Widget _box({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: WaddyColors.surface,
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      border: Border.all(color: WaddyColors.divider),
    ),
    child: child,
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    required int maxLength,
    TextInputType? keyboard,
    String? suffix,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      borderSide: const BorderSide(color: WaddyColors.divider),
    );
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboard,
      style: waddyBold.copyWith(fontSize: 14, color: WaddyColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        suffixText: suffix,
        filled: true,
        fillColor: WaddyColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: WaddyColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// The answer from [_BirthdaySheet]: a date to pick, or a rough age.
class _BirthdayAnswer {
  final int? years;
  const _BirthdayAnswer.pickDate() : years = null;
  const _BirthdayAnswer.roughly(this.years);
}

/// Most owners of a rescue don't know the day. This lets them say "about 3"
/// instead of inventing a date that would then get a birthday push.
class _BirthdaySheet extends StatefulWidget {
  final String name;

  const _BirthdaySheet({required this.name});

  @override
  State<_BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<_BirthdaySheet> {
  int? _years;

  Widget _button(String label, {required bool filled, VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? WaddyColors.primary : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border:
              filled
                  ? null
                  : Border.all(color: WaddyColors.primary, width: 1.5),
        ),
        child: Text(
          label,
          style: waddyBold.copyWith(
            fontSize: 14,
            color: filled ? Colors.white : WaddyColors.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'pet_birthday_q'.trParams({'name': widget.name}),
              style: waddyBold.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: WaddyColors.ink,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            _button(
              'pet_birthday_know_date'.tr,
              filled: true,
              onTap:
                  () =>
                      Navigator.pop(context, const _BirthdayAnswer.pickDate()),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            Text(
              'pet_birthday_roughly'.tr,
              style: waddyBold.copyWith(
                fontSize: 13,
                color: WaddyColors.inkMid,
              ),
            ),
            const SizedBox(height: 10),
            PetAgeCounter(
              years: _years,
              onChanged: (y) => setState(() => _years = y),
            ),
            if (_years != null) ...[
              const SizedBox(height: Dimensions.paddingSizeMedium),
              _button(
                'pet_use_this_age'.tr,
                filled: false,
                onTap:
                    () =>
                        Navigator.pop(context, _BirthdayAnswer.roughly(_years)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
