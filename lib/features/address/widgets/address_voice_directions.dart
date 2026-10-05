import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:waddy_app/util/loud_speaker_audio_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

enum _VoiceState { idle, recording, recorded, playing }

/// "Tap to record voice directions" pill from the Address Details design:
/// one tap starts, one tap stops (or it stops itself at [maxSeconds]); once
/// recorded, the round button plays it back and Re-record / Delete sit below.
///
/// Holds either a fresh local file ([localPath]) or the address's saved note
/// ([remoteUrl]); the parent owns which one is current.
class AddressVoiceDirections extends StatefulWidget {
  final String? localPath;
  final String? remoteUrl;
  final ValueChanged<String> onRecorded;
  final VoidCallback onDeleted;

  static const int maxSeconds = 60;

  const AddressVoiceDirections({
    super.key,
    required this.localPath,
    required this.remoteUrl,
    required this.onRecorded,
    required this.onDeleted,
  });

  @override
  State<AddressVoiceDirections> createState() => _AddressVoiceDirectionsState();
}

class _AddressVoiceDirectionsState extends State<AddressVoiceDirections> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  bool _recorderOpen = false;
  Timer? _ticker;
  String? _pendingPath;

  _VoiceState _state = _VoiceState.idle;
  int _elapsed = 0;
  Duration _length = Duration.zero;
  Duration _position = Duration.zero;

  bool get _hasNote => widget.localPath != null || widget.remoteUrl != null;

  @override
  void initState() {
    super.initState();
    useLoudSpeaker(_player);
    if (_hasNote) {
      _state = _VoiceState.recorded;
      _loadLength();
    }
    _subs.add(
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
    );
    _subs.add(
      _player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _length = d);
      }),
    );
    _subs.add(
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _state = _VoiceState.recorded;
            _position = Duration.zero;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (_recorderOpen) _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  Source? get _source =>
      widget.localPath != null
          ? DeviceFileSource(widget.localPath!)
          : widget.remoteUrl != null
          ? UrlSource(widget.remoteUrl!)
          : null;

  Future<void> _loadLength() async {
    final Source? source = _source;
    if (source == null) return;
    try {
      await _player.setSource(source);
      final Duration? d = await _player.getDuration();
      if (d != null && mounted) setState(() => _length = d);
    } catch (_) {
      // The length label is cosmetic; playback still works without it.
    }
  }

  /// Same native channel the checkout voice note uses. Without the plugin
  /// (a platform that doesn't ship it) the recorder asks for itself.
  Future<bool> _micAllowed() async {
    const channel = MethodChannel('com.hamdiesolutions.waddi/permissions');
    try {
      String status = await channel.invokeMethod('checkMicPermission');
      if (status == 'denied') {
        status = await channel.invokeMethod('requestMicPermission');
      }
      if (status == 'granted') return true;
      showCustomSnackBar(
        status == 'denied_forever'
            ? 'microphone_permission_denied'.tr
            : 'you_have_to_allow'.tr,
      );
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> _start() async {
    if (!await _micAllowed()) return;
    try {
      await _player.stop();
      if (!_recorderOpen) {
        await _recorder.openRecorder();
        _recorderOpen = true;
      }
      final dir = await getTemporaryDirectory();
      _pendingPath =
          '${dir.path}/address_voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(
        toFile: _pendingPath,
        codec: Codec.aacADTS,
        bitRate: 64000,
        sampleRate: 44100,
      );
      HapticFeedback.mediumImpact();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= AddressVoiceDirections.maxSeconds) _stop();
      });
      if (mounted) {
        setState(() {
          _elapsed = 0;
          _state = _VoiceState.recording;
        });
      }
    } catch (e) {
      debugPrint('Address voice: record failed: $e');
      showCustomSnackBar('something_went_wrong'.tr);
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    try {
      await _recorder.stopRecorder();
    } catch (e) {
      debugPrint('Address voice: stop failed: $e');
    }
    HapticFeedback.lightImpact();
    final String? path = _pendingPath;
    if (!mounted || path == null) return;
    // A tap-and-release under a second is a misfire, not directions.
    if (_elapsed < 1) {
      setState(
        () => _state = _hasNote ? _VoiceState.recorded : _VoiceState.idle,
      );
      return;
    }
    setState(() {
      _state = _VoiceState.recorded;
      _length = Duration(seconds: _elapsed);
      _position = Duration.zero;
    });
    widget.onRecorded(path);
  }

  Future<void> _togglePlay() async {
    if (_state == _VoiceState.playing) {
      await _player.pause();
      if (mounted) setState(() => _state = _VoiceState.recorded);
      return;
    }
    final Source? source = _source;
    if (source == null) return;
    try {
      await _player.play(source);
      if (mounted) setState(() => _state = _VoiceState.playing);
    } catch (e) {
      debugPrint('Address voice: playback failed: $e');
    }
  }

  Future<void> _delete() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _length = Duration.zero;
      _position = Duration.zero;
    });
    widget.onDeleted();
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool recording = _state == _VoiceState.recording;
    final bool recorded =
        _state == _VoiceState.recorded || _state == _VoiceState.playing;
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ?? WaddyColors.ink;

    final String label =
        recording
            ? '${'recording'.tr}… ${_clock(_elapsed)} / ${_clock(AddressVoiceDirections.maxSeconds)}'
            : recorded
            ? '${'voice_directions'.tr} · ${_clock((_state == _VoiceState.playing ? _position : _length).inSeconds)}'
            : 'tap_to_record_voice_directions'.tr;

    final Widget pill = Semantics(
      button: true,
      liveRegion: recording,
      label: label,
      child: Material(
        color:
            recording ? WaddyColors.mintSurface : Theme.of(context).cardColor,
        shape: StadiumBorder(
          side: BorderSide(
            color:
                recording
                    ? WaddyColors.mintInk
                    : recorded
                    ? WaddyColors.mintInk
                    : WaddyColors.divider,
            width: recording ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          // Recorded: the pill plays, like the round button; re-recording is
          // its own link so a stray tap can't wipe the note.
          onTap:
              recording
                  ? _stop
                  : recorded
                  ? _togglePlay
                  : _start,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Dimensions.minTapTarget + Dimensions.paddingSizeSmall,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeExtraSmall,
                Dimensions.paddingSizeExtraSmall,
                Dimensions.paddingSizeExtraSmall,
              ),
              child: Row(
                children: [
                  if (recording) ...[
                    const _RecDot(),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: recording ? WaddyColors.primary : ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _RoundAction(
                    state: _state,
                    onTap:
                        recording
                            ? _stop
                            : recorded
                            ? _togglePlay
                            : _start,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            pill,
            if (_state == _VoiceState.idle)
              const PositionedDirectional(
                top: -Dimensions.paddingSizeSmall,
                start: Dimensions.paddingSizeLarge,
                child: _NewBadge(),
              ),
          ],
        ),
        if (recorded)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Dimensions.paddingSizeSmall,
            ),
            child: Row(
              children: [
                _LinkButton(text: 're_record'.tr, onTap: _start),
                _LinkButton(
                  text: 'delete_voice_note'.tr,
                  onTap: _delete,
                  color: WaddyColors.coralInk,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Round button at the pill's end: mic at rest, stop while recording, play
/// or pause once there's a note. Full mint only while it's the live control.
class _RoundAction extends StatelessWidget {
  final _VoiceState state;
  final VoidCallback onTap;
  const _RoundAction({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool recording = state == _VoiceState.recording;
    final bool idle = state == _VoiceState.idle;
    final List<List<dynamic>> icon =
        recording
            ? HugeIcons.strokeRoundedStop
            : idle
            ? HugeIcons.strokeRoundedMic01
            : state == _VoiceState.playing
            ? HugeIcons.strokeRoundedPause
            : HugeIcons.strokeRoundedPlay;
    return Material(
      color:
          recording || !idle ? WaddyColors.mint : WaddyColors.mintSurfaceDeep,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: Dimensions.minTapTarget,
          height: Dimensions.minTapTarget,
          child: Center(
            child: HugeIcon(
              icon: icon,
              color: WaddyColors.primary,
              size: Dimensions.paddingSizeLarge,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing live dot while the mic is open.
class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: Dimensions.paddingSizeSmall,
        height: Dimensions.paddingSizeSmall,
        decoration: const BoxDecoration(
          color: WaddyColors.coral,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeSmall,
        vertical: Dimensions.paddingSizeExtraSmall / 2,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.primary,
        borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
      ),
      child: Text(
        'new'.tr,
        style: waddyBold.copyWith(
          fontSize: Dimensions.fontSizeOverSmall,
          color: WaddyColors.mint,
          // Tracking breaks Arabic joins.
          letterSpacing: Get.find<LocalizationController>().isLtr ? 0.4 : 0,
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  const _LinkButton({
    required this.text,
    required this.onTap,
    this.color = WaddyColors.mintInk,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(
          Dimensions.minTapTarget,
          Dimensions.minTapTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
        ),
      ),
      child: Text(
        text,
        style: waddyBold.copyWith(
          fontSize: Dimensions.fontSizeSmall,
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
