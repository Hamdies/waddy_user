import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';

/// The Rive "level up" celebration — a burst of rays and stars behind the
/// artboard's own "Level up!" headline and XP readout.
///
/// The artboard ships a view model ("Level", "currentXP", "nextlevelXP") whose
/// defaults read 0 XP. [level], [currentXp] and [nextLevelXp] are bound into it
/// on load so the animation shows the user's real progression rather than
/// placeholder values — which is why this needs rive 0.14 (`rive_native`); the
/// 0.13 runtime has no data binding, and could not render this file's nested
/// artboards at all.
///
/// Copy is localized via **view-model instance selection**, not per-string
/// writes: the artboard's Canvas view model has two instances baked in the
/// editor — "Instance" (English copy) and "Instance 1" (Arabic copy) — with
/// identical property names but different text values. [DataBind.byName]
/// picks the instance matching the app's locale at load time, so no string
/// property is ever written from Dart. See [[rive-localization-approach]].
class LevelUpRiveBurst extends StatefulWidget {
  /// The level being celebrated.
  final int level;

  /// Lifetime XP to show against "Current XP".
  final int currentXp;

  /// XP at which the next level unlocks — the "Next level at" figure.
  final int nextLevelXp;

  const LevelUpRiveBurst({
    super.key,
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
  });

  @override
  State<LevelUpRiveBurst> createState() => LevelUpRiveBurstState();
}

class LevelUpRiveBurstState extends State<LevelUpRiveBurst> {
  static const String _asset = 'assets/animation/level_upـwaddy_f.riv';

  /// Canvas view-model instance names baked in the Rive editor, keyed by
  /// GetX locale language code.
  static const Map<String, String> _instanceByLanguage = {
    'ar': 'Instance 1',
    'en': 'Instance',
  };

  late final FileLoader _fileLoader = FileLoader.fromAsset(
    _asset,
    riveFactory: Factory.rive,
  );

  ViewModelInstance? _viewModel;

  String get _instanceName {
    final code = Get.locale?.languageCode;
    final name = _instanceByLanguage[code] ?? 'Instance';
    debugPrint('LevelUpRiveBurst: Get.locale=$code -> instance "$name"');
    return name;
  }

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  /// Push the user's real numbers into the artboard's view model. The copy
  /// itself (headline, labels) comes baked into whichever instance
  /// [_instanceName] selected — no string is written from Dart. Every
  /// property is optional: a file that doesn't expose one simply keeps its
  /// own default rather than failing the whole bind.
  void _bind(ViewModelInstance? vm) {
    if (vm == null) return;
    _viewModel = vm;
    debugPrint(
      'LevelUpRiveBurst: bound headline="${vm.string('headline')?.value}" '
      'congrats="${vm.string('congrats')?.value}"',
    );
    _setNumber(vm, 'Level', widget.level);
    _setNumber(vm, 'currentXP', widget.currentXp);
    _setNumber(vm, 'nextlevelXP', widget.nextLevelXp);
  }

  void _setNumber(ViewModelInstance vm, String path, int value) {
    // The file drives some values through number properties and some through
    // string converters, so try both rather than assuming one shape.
    final number = vm.number(path);
    if (number != null) {
      number.value = value.toDouble();
      return;
    }
    vm.string(path)?.value = value.toString();
  }

  /// Restart the burst from the top, if the file exposes a `Replay` trigger.
  void replay() => _viewModel?.trigger('Replay')?.trigger();

  @override
  Widget build(BuildContext context) {
    // Respect the platform "reduce motion" setting: a full-screen particle
    // burst is exactly the kind of motion that setting exists to suppress.
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    return RiveWidgetBuilder(
      fileLoader: _fileLoader,
      artboardSelector: const ArtboardNamed('Canvas Mobile'),
      // Selected once here, at whatever locale is active when the celebration
      // opens — this screen is a one-shot dialog (see LevelUpScreen.showQueue),
      // not a long-lived surface someone would language-switch underneath.
      dataBind: DataBind.byName(_instanceName),
      onLoaded: (state) => _bind(state.viewModelInstance),
      // A failed load must not take the celebration down with it — the screen's
      // own confetti and button still carry the moment.
      onFailed:
          (error, stackTrace) =>
              debugPrint('LevelUpRiveBurst failed to load $_asset: $error'),
      builder:
          (context, state) => switch (state) {
            RiveLoaded() => RiveWidget(
              controller: state.controller,
              fit: Fit.cover,
            ),
            _ => const SizedBox.shrink(),
          },
    );
  }
}
