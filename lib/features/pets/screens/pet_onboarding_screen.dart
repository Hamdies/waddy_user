import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/common/widgets/confetti_burst.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/emoji_burst.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/features/pets/controllers/pet_controller.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';
import 'package:waddy_app/features/pets/widgets/pet_age_counter.dart';
import 'package:waddy_app/features/pets/widgets/pet_visuals.dart';
import 'package:intl/intl.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/motion.dart';
import 'package:waddy_app/util/styles.dart';

/// "Meet your pet" (Claude Design "Pet Module v2", screen 00).
///
///   1 species → 2 photo, name, sex → 3 birthday → 4 food → 5 nice to meet you
///
/// Saved at the end of step 4: to the account when signed in, as the device
/// draft for a guest, photo included (sent after sign-in, see
/// `PetController`). Sex is asked on step 2 because every personalised
/// Arabic string depends on it (PET-07). The photo is required: it is the
/// polaroid on the hub. The birthday is its own step (D5 revised 10-02):
/// an exact date, or "about N years old" saved as an estimate; the age band
/// is derived from it rather than asked.
///
/// With [editing] the same steps edit an existing pet.
class PetOnboardingScreen extends StatefulWidget {
  final UserPetModel? editing;

  const PetOnboardingScreen({super.key, this.editing});

  static Future<void> open({UserPetModel? editing}) async {
    await Get.to(
      () => PetOnboardingScreen(editing: editing),
      fullscreenDialog: true,
    );
  }

  @override
  State<PetOnboardingScreen> createState() => _PetOnboardingScreenState();
}

class _PetOnboardingScreenState extends State<PetOnboardingScreen> {
  static const int _steps = 5;

  /// The step that saves the pet.
  static const int _saveStep = 4;

  final TextEditingController _name = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _step = 1;

  /// Null until the user taps one: nothing is pre-selected, so choosing is
  /// the user's own act (an edit starts from the saved pet's species).
  PetSpecies? _pickedSpecies;

  /// The pick, for the steps after the first — which cannot be reached
  /// without one; the fallback only keeps the type non-null.
  PetSpecies get _species => _pickedSpecies ?? PetSpecies.cat;
  PetSex _sex = PetSex.unknown;
  DateTime? _birthDate;
  bool _estimate = false;
  PetDiet _diet = PetDiet.dry;
  XFile? _photo;
  bool _saving = false;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final UserPetModel? pet = widget.editing;
    if (pet != null) {
      _name.text = pet.name;
      _pickedSpecies = pet.species;
      _sex = pet.sex;
      _birthDate = pet.birthDate;
      _estimate = pet.birthDateIsEstimate;
      _diet = pet.diet ?? PetDiet.dry;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _trimmedName => _name.text.trim();

  bool get _hasPhoto =>
      _photo != null || (widget.editing?.photoUrl?.isNotEmpty ?? false);

  bool get _canContinue => switch (_step) {
    1 => _pickedSpecies != null,
    2 => _trimmedName.isNotEmpty && _hasPhoto,
    3 => _birthDate != null,
    _ => true,
  };

  /// The age band, from the birthday: under 1 baby, 7+ senior.
  PetAgeBand get _age {
    final DateTime? born = _birthDate;
    if (born == null) return widget.editing?.ageBand ?? PetAgeBand.adult;
    final DateTime now = DateTime.now();
    int years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years--;
    }
    if (years < 1) return PetAgeBand.baby;
    return years >= 7 ? PetAgeBand.senior : PetAgeBand.adult;
  }

  /// An edit starts from the saved pet, so what this flow doesn't ask
  /// (birthday, breed, weight, the notify switch) goes back unchanged.
  UserPetModel get _draft {
    final UserPetModel? base = widget.editing;
    if (base == null) {
      return UserPetModel(
        name: _trimmedName,
        species: _species,
        sex: _sex,
        ageBand: _age,
        birthDate: _birthDate,
        birthDateIsEstimate: _estimate,
        diet: _diet,
      );
    }
    return base.copyWith(
      name: _trimmedName,
      species: _species,
      sex: _sex,
      ageBand: _age,
      birthDate: _birthDate,
      birthDateIsEstimate: _estimate,
      diet: _diet,
    );
  }

  Future<void> _next() async {
    if (!_canContinue || _saving) return;
    if (_step == _saveStep) {
      setState(() => _saving = true);
      final bool ok = await Get.find<PetController>().savePet(
        _draft,
        photo: _photo,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        showCustomSnackBar('pet_save_failed'.tr);
        return;
      }
      // An edit has nothing to introduce: saved is done.
      if (_editing) {
        Get.back();
        return;
      }
    }
    if (_step < _steps) {
      FocusScope.of(context).unfocus();
      _goTo(_step + 1);
      if (_step == _steps) _celebrate();
    } else {
      Get.back();
    }
  }

  void _back() {
    if (_step > 1 && _step < _steps) {
      _goTo(_step - 1);
    } else {
      Get.back();
    }
  }

  /// Moves to [step] from the top of the page: a step left scrolled down
  /// otherwise opened the next one halfway through.
  void _goTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// "Nice to meet you": confetti once the new step has painted, so it
  /// falls over the pet rather than over the step being left.
  void _celebrate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ConfettiBurst.show(context);
    });
  }

  void _pickSpecies(PetSpecies s, BuildContext tile) {
    HapticFeedback.selectionClick();
    EmojiBurst.fromWidget(tile, s.emojis);
    if (s != _pickedSpecies) setState(() => _pickedSpecies = s);
  }

  void _addAnother() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _step = 1;
      _pickedSpecies = null;
      _name.clear();
      _sex = PetSex.unknown;
      _birthDate = null;
      _estimate = false;
      _diet = PetDiet.dry;
      _photo = null;
    });
  }

  Future<void> _pickPhoto() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _photo = file);
  }

  String get _cta => switch (_step) {
    1 when _pickedSpecies == null => 'pet_ob_cta_species_empty'.tr,
    1 => 'pet_ob_cta_species'.trParams({'species': _species.label}),
    2 when !_hasPhoto => 'pet_ob_cta_photo'.tr,
    2 =>
      _trimmedName.isEmpty
          ? 'pet_ob_cta_name_empty'.tr
          : 'pet_ob_cta_name'.trParams({'name': _trimmedName}),
    3 =>
      _birthDate == null
          ? 'pet_ob_cta_birthday_empty'.tr
          : 'pet_ob_cta_next'.tr,
    4 => _editing ? 'save'.tr : 'pet_ob_cta_almost'.tr,
    _ => 'pet_ob_cta_start'.tr,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: AnimatedSwitcher(
                  duration: WaddyMotion.reveal,
                  reverseDuration: WaddyMotion.fast,
                  switchInCurve: WaddyMotion.easeOut,
                  switchOutCurve: Curves.easeIn,
                  // Pinned to the top, not centred: steps differ in height,
                  // and a centred stack slid the incoming one down mid-fade.
                  layoutBuilder:
                      (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                  transitionBuilder: _stepTransition,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: switch (_step) {
                      1 => _speciesStep(),
                      2 => _nameStep(),
                      3 => _birthdayStep(),
                      4 => _aboutStep(),
                      _ => _doneStep(),
                    },
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  /// Steps cross-fade with a short rise: the new one lifts 16pt into
  /// place as it fades in, the old one sinks slightly as it fades out.
  static Widget _stepTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder:
            (_, child) => Transform.translate(
              offset: Offset(0, 16 * (1 - animation.value)),
              child: child,
            ),
      ),
    );
  }

  // ── Chrome ────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _RoundButton(
            icon: _step > 1 && _step < _steps ? Icons.arrow_back : Icons.close,
            semanticLabel: 'back'.tr,
            onTap: _back,
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Row(
              children: [
                for (int i = 1; i <= _steps; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: WaddyMotion.enter,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            i <= _step
                                ? WaddyColors.primary
                                : WaddyColors.divider,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          // Skipping only makes sense before anything is saved.
          Opacity(
            opacity: _step < _saveStep && !_editing ? 1 : 0,
            child: IgnorePointer(
              ignoring: _step >= _saveStep || _editing,
              child: Pressable(
                onTap: () => Get.back(),
                semanticLabel: 'skip'.tr,
                minSize: Dimensions.minTapTarget,
                child: Text(
                  'skip'.tr,
                  style: waddyBold.copyWith(
                    fontSize: 13,
                    color: WaddyColors.inkMid,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final bool enabled = _canContinue && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: enabled ? _next : null,
            semanticLabel: _cta,
            scale: WaddyMotion.pressControl,
            child: AnimatedContainer(
              duration: WaddyMotion.fast,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? WaddyColors.primary : WaddyColors.divider,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                boxShadow:
                    enabled
                        ? const [
                          BoxShadow(
                            color: WaddyColors.mint,
                            offset: Offset(0, 3),
                          ),
                        ]
                        : null,
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
                        _cta,
                        style: waddyBold.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: enabled ? Colors.white : WaddyColors.inkLight,
                        ),
                      ),
            ),
          ),
          if (_step == _steps && !_editing)
            Pressable(
              onTap: _addAnother,
              semanticLabel: 'add_another_pet'.tr,
              minSize: Dimensions.minTapTarget,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'add_another_pet'.tr,
                  textAlign: TextAlign.center,
                  style: waddyBold.copyWith(
                    fontSize: 13,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Steps ─────────────────────────────────────────────────────────────

  Widget _title(String title, String subtitle, {bool center = false}) {
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: waddyBold.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: displayTracking(-0.7),
            color: WaddyColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: waddyRegular.copyWith(
            fontSize: 14,
            height: 1.45,
            color: WaddyColors.inkMid,
          ),
        ),
      ],
    );
  }

  Widget _speciesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('pet_ob_species_title'.tr, 'pet_ob_species_sub'.tr),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // Wide and short: five tiles fit a phone without scrolling.
          childAspectRatio: 1.5,
          children: [
            for (final PetSpecies s in PetSpecies.values)
              // A Builder per tile: the burst rises from the tile tapped.
              Builder(
                builder:
                    (tile) => _SpeciesTile(
                      species: s,
                      selected: s == _pickedSpecies,
                      onTap: () => _pickSpecies(s, tile),
                    ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _nameStep() {
    final List<String> ideas =
        _nameIdeas[_species]![Get.locale?.languageCode == 'ar' ? 1 : 0];
    return Column(
      children: [
        _photoPicker(),
        const SizedBox(height: 20),
        _title(
          'pet_ob_name_title'.trParams({'species': _species.label}),
          'pet_ob_name_sub'.tr,
          center: true,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          maxLength: 16,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          style: waddyBold.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: WaddyColors.primary,
          ),
          decoration: InputDecoration(
            hintText: 'pet_ob_name_hint'.tr,
            counterText: '',
            filled: true,
            fillColor: WaddyColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
              borderSide: const BorderSide(
                color: WaddyColors.primary,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
              borderSide: const BorderSide(
                color: WaddyColors.primary,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge + 2),
              borderSide: const BorderSide(
                color: WaddyColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        // Boy / Girl: one tap, and it is what makes "لونا محتاجة" right.
        Row(
          children: [
            for (final PetSex sex in const [PetSex.male, PetSex.female]) ...[
              if (sex == PetSex.female)
                const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: _OptionTile(
                  label: 'pet_sex_${sex.wire}'.tr,
                  selected: _sex == sex,
                  center: true,
                  onTap:
                      () => setState(
                        () => _sex = _sex == sex ? PetSex.unknown : sex,
                      ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'pet_ob_name_ideas'.tr,
          style: waddyBold.copyWith(fontSize: 12, color: WaddyColors.inkLight),
        ),
        const SizedBox(height: 10),
        // One scrolling row: five names stacked full-width filled the screen.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final String idea in ideas)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Pressable(
                    onTap: () {
                      _name.text = idea;
                      _name.selection = TextSelection.collapsed(
                        offset: idea.length,
                      );
                    },
                    semanticLabel: idea,
                    scale: WaddyMotion.pressControl,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: WaddyColors.divider),
                      ),
                      child: Text(
                        idea,
                        style: waddyBold.copyWith(
                          fontSize: 13,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Required: the pet's photo is its polaroid on the hub. A guest's goes
  /// with the device draft and uploads after sign-in.
  Widget _photoPicker() {
    final Widget avatar = Container(
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: WaddyColors.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.primary.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child:
            _photo != null
                ? Image.file(File(_photo!.path), fit: BoxFit.cover)
                : PetAvatar(
                  species: _species,
                  photoUrl: widget.editing?.photoUrl,
                  size: 128,
                ),
      ),
    );
    return Pressable(
      onTap: _pickPhoto,
      semanticLabel: 'pet_ob_add_photo'.tr,
      scale: WaddyMotion.pressControl,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          PositionedDirectional(
            end: 4,
            bottom: 4,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: WaddyColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: WaddyColors.surface, width: 3),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 16,
                color: WaddyColors.mint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutStep() {
    final String named = _trimmedName.isEmpty ? _species.label : _trimmedName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'pet_ob_about_title'.trParams({'name': named}),
          'pet_ob_about_sub'.tr,
        ),
        const SizedBox(height: 24),
        _groupTitle('pet_ob_diet_q'.tr),
        _optionGrid([
          for (final PetDiet d in PetDiet.values)
            _OptionTile(
              label: 'pet_diet_${d.wire}'.tr,
              sub: 'pet_diet_${d.wire}_sub'.tr,
              selected: _diet == d,
              onTap: () => setState(() => _diet = d),
            ),
        ]),
      ],
    );
  }

  Widget _birthdayStep() {
    final String named = _trimmedName.isEmpty ? _species.label : _trimmedName;
    final DateTime? date = _birthDate;
    final bool exact = date != null && !_estimate;
    final int? roughYears =
        date != null && _estimate ? DateTime.now().year - date.year : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'pet_birthday_q'.trParams({'name': named}),
          'pet_ob_birthday_sub'.tr,
        ),
        const SizedBox(height: 24),
        Pressable(
          onTap: _pickBirthday,
          semanticLabel: 'pet_birthday_know_date'.tr,
          scale: WaddyMotion.pressControl,
          child: AnimatedContainer(
            duration: WaddyMotion.fast,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: exact ? WaddyColors.primarySurface : WaddyColors.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(
                color: exact ? WaddyColors.primary : WaddyColors.divider,
                width: 2,
              ),
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
                    exact
                        ? DateFormat.yMMMd(
                          Get.locale?.languageCode,
                        ).format(date)
                        : 'pet_birthday_know_date'.tr,
                    style: waddyBold.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.primary,
                    ),
                  ),
                ),
                if (exact)
                  const Icon(Icons.check_rounded, color: WaddyColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _groupTitle('pet_birthday_roughly'.tr),
        PetAgeCounter(
          years: roughYears,
          onChanged: (y) {
            final DateTime now = DateTime.now();
            setState(() {
              // The 1st of this month, N years back: an estimate the server
              // never uses for a birthday push.
              _birthDate = DateTime(now.year - y, now.month, 1);
              _estimate = true;
            });
          },
        ),
        if (roughYears != null) ...[
          const SizedBox(height: 12),
          Text(
            'pet_birthday_estimate_note'.tr,
            style: waddyRegular.copyWith(
              fontSize: 12,
              color: WaddyColors.inkLight,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickBirthday() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _estimate ? null : _birthDate,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _estimate = false;
      });
    }
  }

  Widget _groupTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: waddyBold.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: WaddyColors.ink,
      ),
    ),
  );

  Widget _optionGrid(List<Widget> tiles) {
    final List<Widget> rows = [];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _doneStep() {
    final UserPetModel pet = _draft;
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: petWash,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipOval(
                    child:
                        _photo != null
                            ? Image.file(File(_photo!.path), fit: BoxFit.cover)
                            : PetAvatar(
                              species: _species,
                              photoUrl: widget.editing?.photoUrl,
                              size: 160,
                            ),
                  ),
                ),
              ),
              // The design's two scattered motifs: a teal one up top, a
              // mint one low on the other side.
              PositionedDirectional(
                end: -4,
                top: 6,
                child: Transform.rotate(
                  angle: 0.31,
                  child: HugeIcon(
                    icon: _species.icon,
                    size: 40,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
              PositionedDirectional(
                start: 0,
                bottom: 16,
                child: Transform.rotate(
                  angle: -0.38,
                  child: HugeIcon(
                    icon: _species.icon,
                    size: 26,
                    color: WaddyColors.mintDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _title(
          'pet_ob_done_title'.trParams({'name': pet.name}),
          PetCopy.tr('pet_ob_done_sub', pet),
          center: true,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String tag in [
              _species.label,
              if (pet.sex != PetSex.unknown) 'pet_sex_${pet.sex.wire}'.tr,
              _age == PetAgeBand.baby
                  ? (_species == PetSpecies.cat
                      ? 'pet_age_kitten'.tr
                      : _species == PetSpecies.dog
                      ? 'pet_age_puppy'.tr
                      : 'pet_age_baby'.tr)
                  : 'pet_age_${_age.wire}'.tr,
              'pet_diet_${_diet.wire}'.tr,
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: WaddyColors.primarySurface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  tag,
                  style: waddyBold.copyWith(
                    fontSize: 12,
                    color: WaddyColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// "Need ideas?" names, per species: [English, Arabic]. Names are not
  /// translated, they are picked, so each language gets its own list.
  static const Map<PetSpecies, List<List<String>>> _nameIdeas = {
    PetSpecies.cat: [
      ['Mishmish', 'Simba', 'Loz', 'Bosbosa', 'Luna'],
      ['مشمش', 'سمبا', 'لوز', 'بسبوسة', 'لونا'],
    ],
    PetSpecies.dog: [
      ['Rex', 'Lucky', 'Max', 'Bondo2', 'Rocky'],
      ['ركس', 'لاكي', 'ماكس', 'بندق', 'روكي'],
    ],
    PetSpecies.bird: [
      ['Kiwi', 'Sokkar', 'Coco', 'Tweety'],
      ['كيوي', 'سكر', 'كوكو', 'تويتي'],
    ],
    PetSpecies.fish: [
      ['Nemo', 'Bubbles', 'Dory', 'Goldy'],
      ['نيمو', 'فقاعة', 'دوري', 'جولدي'],
    ],
    PetSpecies.small: [
      ['Fofa', 'Peanut', 'Kokky', 'Biscuit'],
      ['فوفا', 'فول سوداني', 'كوكي', 'بسكوتة'],
    ],
  };
}

// ═══════════════════════════════════════════
// PIECES
// ═══════════════════════════════════════════

class _SpeciesTile extends StatelessWidget {
  final PetSpecies species;
  final bool selected;
  final VoidCallback onTap;

  const _SpeciesTile({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: species.label,
      scale: WaddyMotion.pressTile,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1,
        duration: WaddyMotion.enter,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: WaddyMotion.fast,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            gradient: petWash,
            borderRadius: BorderRadius.circular(
              Dimensions.radiusExtraLarge - 2,
            ),
            border: Border.all(
              color: selected ? WaddyColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: HugeIcon(
                        icon: species.icon,
                        size: 34,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    species.label,
                    style: waddyBold.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WaddyColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    species.joke,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: waddyRegular.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      color: WaddyColors.inkMid,
                    ),
                  ),
                ],
              ),
              if (selected)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: WaddyColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: WaddyColors.mint,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final bool center;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: WaddyMotion.pressControl,
      child: AnimatedContainer(
        duration: WaddyMotion.fast,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? WaddyColors.primarySurface : WaddyColors.surface,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: selected ? WaddyColors.primary : WaddyColors.divider,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: waddyBold.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: WaddyColors.primary,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                style: waddyRegular.copyWith(
                  fontSize: 11,
                  height: 1.3,
                  color: WaddyColors.inkMid,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: WaddyMotion.pressControl,
      minSize: Dimensions.minTapTarget,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WaddyColors.surface,
          border: Border.all(color: WaddyColors.divider),
        ),
        child: Icon(icon, size: 18, color: WaddyColors.primary),
      ),
    );
  }
}
