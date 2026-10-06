import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// The hero card's streak badge — a small looping Rive animation whose flame
/// carries the user's real current-streak count, replacing what used to be a
/// static giant watermark number.
///
/// The artboard ships a `UserStreakVM` view model (single instance, "Instance")
/// with a `streak` number property wired through a "Convert to String"
/// data-bind converter to the on-artboard digits — so binding a plain number
/// is enough; no string is ever written from Dart. See [[rive-014-api]] and
/// [[rive-localization-approach]].
class StreakRiveBadge extends StatefulWidget {
  /// The user's current streak, in days.
  final int streak;

  const StreakRiveBadge({super.key, required this.streak});

  @override
  State<StreakRiveBadge> createState() => _StreakRiveBadgeState();
}

class _StreakRiveBadgeState extends State<StreakRiveBadge> {
  static const String _asset = 'assets/animation/streak_w.riv';

  late final FileLoader _fileLoader = FileLoader.fromAsset(
    _asset,
    riveFactory: Factory.rive,
  );

  ViewModelInstance? _viewModel;

  // FileLoader.file() awaits the asset decode, then does
  // `_loadCompleter!.complete(file)`. If dispose() runs first it nulls that
  // completer, and the still-pending await crashes with a null-check error
  // when it resumes (rive 0.14.11, file_loader.dart:91). Only dispose the
  // loader once the load has actually settled; otherwise leak this one small
  // in-flight loader rather than risk the crash. See [[spots-marks]].
  bool _settled = false;

  @override
  void dispose() {
    if (_settled) _fileLoader.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StreakRiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streak != widget.streak) {
      _push(widget.streak);
    }
  }

  void _bind(ViewModelInstance? vm) {
    if (vm == null) return;
    _viewModel = vm;
    _push(widget.streak);
  }

  void _push(int streak) {
    final vm = _viewModel;
    if (vm == null) return;
    final number = vm.number('streak');
    if (number != null) {
      number.value = streak.toDouble();
      return;
    }
    vm.string('streak')?.value = streak.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    return RiveWidgetBuilder(
      fileLoader: _fileLoader,
      dataBind: DataBind.byName('Instance'),
      onLoaded: (state) {
        _settled = true;
        _bind(state.viewModelInstance);
      },
      onFailed: (error, stackTrace) {
        _settled = true;
        debugPrint('StreakRiveBadge failed to load $_asset: $error');
      },
      builder:
          (context, state) => switch (state) {
            RiveLoaded() => RiveWidget(
              controller: state.controller,
              fit: Fit.contain,
            ),
            _ => const SizedBox.shrink(),
          },
    );
  }
}
