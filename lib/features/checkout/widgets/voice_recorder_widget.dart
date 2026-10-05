import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:waddy_app/util/loud_speaker_audio_context.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:flutter/services.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/theme/light_theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String? path) onRecordingChanged;
  final String? existingRecordingPath;

  /// A voice note already saved on the delivery address. Shown ready to play
  /// when there is no fresh recording; the backend attaches it to the order
  /// by itself (PlaceNewOrder copies the address's note when none is
  /// uploaded), so recording a new one is an override, not a requirement.
  final String? savedRemoteUrl;

  /// Render as one square tile for the delivery-instructions row instead of
  /// the full-width panel.
  final bool asTile;
  final double tileWidth;
  final double tileHeight;

  /// Any tap inside the widget. Lets the parent retire its hint.
  final VoidCallback? onInteract;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingChanged,
    this.existingRecordingPath,
    this.savedRemoteUrl,
    this.asTile = false,
    this.tileWidth = 88,
    this.tileHeight = 84,
    this.onInteract,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _recorderInitialized = false;

  RecordingState _state = RecordingState.idle;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _pulseController;

  static const int _maxDurationSeconds = 30;

  @override
  void initState() {
    super.initState();
    useLoudSpeaker(_player);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _initRecorder();

    if (widget.existingRecordingPath != null) {
      _recordingPath = widget.existingRecordingPath;
      _state = RecordingState.recorded;
      _loadRecordingDuration();
    } else if (_hasRemote) {
      _state = RecordingState.recorded;
      _loadRecordingDuration();
    }

    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _playbackPosition = position);
      }
    });

    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _playbackDuration = duration);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = RecordingState.recorded;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorderInitialized = true;
  }

  bool get _hasRemote =>
      widget.savedRemoteUrl != null && widget.savedRemoteUrl!.isNotEmpty;

  /// Playing the address's saved note rather than a fresh recording.
  bool get _playingRemote => _recordingPath == null && _hasRemote;

  Future<void> _loadRecordingDuration() async {
    if (_recordingPath != null || _hasRemote) {
      try {
        if (_recordingPath != null) {
          await _player.setSourceDeviceFile(_recordingPath!);
        } else {
          await _player.setSourceUrl(widget.savedRemoteUrl!);
        }
        final duration = await _player.getDuration();
        if (duration != null && mounted) {
          setState(() => _recordingDuration = duration);
        }
      } catch (e, s) {
        // The duration label is cosmetic — the recording still plays and still
        // attaches to the order without it.
        swallow('read voice recording duration', e, s);
      }
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    if (_recorderInitialized) {
      _recorder.closeRecorder();
    }
    _player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkMicPermission(Function onGranted) async {
    const channel = MethodChannel('com.hamdiesolutions.waddi/permissions');
    try {
      final String status = await channel.invokeMethod('checkMicPermission');
      if (status == 'granted') {
        onGranted();
      } else if (status == 'denied') {
        final String result = await channel.invokeMethod(
          'requestMicPermission',
        );
        if (result == 'granted') {
          onGranted();
        } else if (result == 'denied_forever') {
          Get.dialog(_buildPermissionDialog());
        } else {
          showCustomSnackBar('you_have_to_allow'.tr);
        }
      } else if (status == 'denied_forever') {
        Get.dialog(_buildPermissionDialog());
      }
    } on MissingPluginException {
      onGranted();
    }
  }

  Widget _buildPermissionDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      insetPadding: const EdgeInsets.all(Dimensions.paddingSizeExtremeLarge),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckoutIcon(
                icon: HugeIcons.strokeRoundedMicOff01,
                color: WaddyColors.primary,
                size: 64,
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Text(
                'microphone_permission_denied'.tr,
                textAlign: TextAlign.center,
                style: waddyMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      buttonText: 'close'.tr,
                      transparent: true,
                      onPressed: () => Navigator.pop(Get.context!),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(
                    child: CustomButton(
                      buttonText: 'settings'.tr,
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                        Get.back();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    _checkMicPermission(() async {
      try {
        if (!_recorderInitialized) await _initRecorder();

        final dir = await getTemporaryDirectory();
        _recordingPath =
            '${dir.path}/voice_instruction_${DateTime.now().millisecondsSinceEpoch}.aac';

        await _recorder.startRecorder(
          toFile: _recordingPath,
          codec: Codec.aacADTS,
          bitRate: 128000,
          sampleRate: 44100,
        );

        _recordingDuration = Duration.zero;
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration += const Duration(seconds: 1);
            });
            if (_recordingDuration.inSeconds >= _maxDurationSeconds) {
              _stopRecording();
            }
          }
        });

        _pulseController.repeat(reverse: true);
        if (mounted) setState(() => _state = RecordingState.recording);
      } catch (e) {
        debugPrint('Recording error: $e');
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      _durationTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();

      await _recorder.stopRecorder();
      if (_recordingPath != null && mounted) {
        setState(() {
          _state = RecordingState.recorded;
        });
        widget.onRecordingChanged(_recordingPath);
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null && !_hasRemote) return;
    try {
      await _player.play(
        _recordingPath != null
            ? DeviceFileSource(_recordingPath!)
            : UrlSource(widget.savedRemoteUrl!),
      );
      setState(() => _state = RecordingState.playing);
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  Future<void> _pausePlayback() async {
    await _player.pause();
    setState(() => _state = RecordingState.recorded);
  }

  Future<void> _deleteRecording() async {
    await _player.stop();
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, s) {
        // Best-effort cleanup of a temp recording the user already discarded.
        swallow('discard temp voice recording', e, s);
      }
    }
    setState(() {
      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _playbackPosition = Duration.zero;
      // Discarding a fresh recording falls back to the address's saved note.
      _state = _hasRemote ? RecordingState.recorded : RecordingState.idle;
    });
    if (_hasRemote) _loadRecordingDuration();
    widget.onRecordingChanged(null);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asTile) return _buildTile(context);
    switch (_state) {
      case RecordingState.idle:
        return _buildIdleState(context);
      case RecordingState.recording:
        return _buildRecordingState(context);
      case RecordingState.recorded:
      case RecordingState.playing:
        return _buildPlaybackState(context);
    }
  }

  Widget _buildIdleState(BuildContext context) {
    return InkWell(
      onTap: _startRecording,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: WaddyColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: WaddyColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: WaddyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CheckoutIcon(
                icon: HugeIcons.strokeRoundedMic01,
                color: WaddyColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'tap_to_record_voice'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: WaddyColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'max'.tr} ${_maxDurationSeconds}s',
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: WaddyColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: WaddyColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WaddyColors.error.withValues(
                    alpha: 0.15 + (_pulseController.value * 0.15),
                  ),
                  shape: BoxShape.circle,
                ),
                child: const CheckoutIcon(
                  icon: HugeIcons.strokeRoundedMic01,
                  color: WaddyColors.error,
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'recording'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: WaddyColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: WaddyColors.coralInk,
                      ),
                    ),
                    Text(
                      ' / ${_maxDurationSeconds}s',
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: WaddyColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkResponse(
            onTap: _stopRecording,
            radius: 22,
            // Drawn at 36, hit at 44.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: WaddyColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const CheckoutIcon(
                    icon: HugeIcons.strokeRoundedStop,
                    color: WaddyColors.surface,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackState(BuildContext context) {
    final bool isPlaying = _state == RecordingState.playing;
    final double progress =
        _playbackDuration.inMilliseconds > 0
            ? _playbackPosition.inMilliseconds /
                _playbackDuration.inMilliseconds
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: WaddyColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: WaddyColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          InkResponse(
            onTap: isPlaying ? _pausePlayback : _playRecording,
            radius: 22,
            // Drawn at 40, hit at 44.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: WaddyColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: CheckoutIcon(
                    icon:
                        isPlaying
                            ? HugeIcons.strokeRoundedPause
                            : HugeIcons.strokeRoundedPlay,
                    color: WaddyColors.surface,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      WaddyColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPlaying
                      ? _formatDuration(_playbackPosition)
                      : _formatDuration(_recordingDuration),
                  style: waddyRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: WaddyColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          InkResponse(
            onTap: _deleteRecording,
            radius: 22,
            // Drawn at 36, hit at 44.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: WaddyColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CheckoutIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    color: WaddyColors.coralInk,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tile mode ──────────────────────────────────────────────────────────
  //
  // One square in the delivery-instructions row: a big glyph and an action
  // on top, the label underneath. Tap the tile to record, stop, play or
  // pause; the corner action deletes a fresh recording, or records over the
  // address's saved note.
  Widget _buildTile(BuildContext context) {
    final bool recording = _state == RecordingState.recording;
    final bool playing = _state == RecordingState.playing;
    final bool hasAudio =
        _state == RecordingState.recorded || _state == RecordingState.playing;
    final bool active = recording || hasAudio;

    final Widget glyph;
    final VoidCallback onTap;
    final Widget label;
    Widget? corner;

    if (recording) {
      glyph = FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.35).animate(_pulseController),
        child: const CheckoutIcon(
          icon: HugeIcons.strokeRoundedStopCircle,
          size: 22,
          color: WaddyColors.error,
        ),
      );
      onTap = _stopRecording;
      label = _tileLabel(
        'recording'.tr,
        _formatDuration(_recordingDuration),
        WaddyColors.error,
      );
    } else if (hasAudio) {
      glyph = CheckoutIcon(
        icon:
            playing
                ? HugeIcons.strokeRoundedPause
                : HugeIcons.strokeRoundedPlay,
        size: 24,
        color: WaddyColors.mintInk,
      );
      onTap = playing ? _pausePlayback : _playRecording;
      label = _tileLabel(
        'play'.tr,
        _formatDuration(
          playing
              ? _playbackPosition
              : (_recordingDuration > Duration.zero
                  ? _recordingDuration
                  : _playbackDuration),
        ),
        WaddyColors.mintInk,
      );
      corner = _TileCornerButton(
        icon:
            _playingRemote
                ? HugeIcons.strokeRoundedMic01
                : HugeIcons.strokeRoundedDelete02,
        semanticLabel: _playingRemote ? 'record_again'.tr : 'delete'.tr,
        onTap: () {
          widget.onInteract?.call();
          if (_playingRemote) {
            _player.stop();
            _startRecording();
          } else {
            _deleteRecording();
          }
        },
      );
    } else {
      glyph = const CheckoutIcon(
        icon: HugeIcons.strokeRoundedMic01,
        size: 22,
        color: WaddyColors.ink,
      );
      onTap = _startRecording;
      label = Text(
        'directions_to_reach'.tr,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: waddyMedium.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          color: WaddyColors.ink,
          height: 1.2,
        ),
      );
    }

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () {
          widget.onInteract?.call();
          onTap();
        },
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.tileWidth,
          height: widget.tileHeight,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: active ? WaddyColors.mintSurface : WaddyColors.surface,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(
              color:
                  recording
                      ? WaddyColors.error
                      : active
                      ? WaddyColors.primary
                      : WaddyColors.divider,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [glyph, const Spacer(), if (corner != null) corner],
              ),
              label,
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileLabel(String title, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: waddyBold.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: color,
          ),
        ),
        Text(
          time,
          textDirection: TextDirection.ltr,
          style: waddyBold.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: WaddyColors.ink,
          ),
        ),
      ],
    );
  }
}

enum RecordingState { idle, recording, recorded, playing }

class _TileCornerButton extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String semanticLabel;
  final VoidCallback onTap;
  const _TileCornerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Its own gesture arena winner, so it does not also fire the tile.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 32 is as far as this can grow inside the 88x84 tile without
        // pushing the label out; 2 of padding made it a 24pt target.
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CheckoutIcon(icon: icon, size: 20, color: WaddyColors.ink),
        ),
      ),
    );
  }
}
