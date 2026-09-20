import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String? path) onRecordingChanged;
  final String? existingRecordingPath;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingChanged,
    this.existingRecordingPath,
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _initRecorder();

    if (widget.existingRecordingPath != null) {
      _recordingPath = widget.existingRecordingPath;
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

  Future<void> _loadRecordingDuration() async {
    if (_recordingPath != null) {
      try {
        await _player.setSourceDeviceFile(_recordingPath!);
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
              Icon(
                Icons.mic_off_rounded,
                color: Theme.of(Get.context!).primaryColor,
                size: 100,
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
    if (_recordingPath == null) return;
    try {
      await _player.play(DeviceFileSource(_recordingPath!));
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
      _state = RecordingState.idle;
    });
    widget.onRecordingChanged(null);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
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
          color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: Theme.of(context).primaryColor,
                size: 22,
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
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'max'.tr} ${_maxDurationSeconds}s',
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: Theme.of(context).hintColor,
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
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
                  color: Colors.red.withValues(
                    alpha: 0.15 + (_pulseController.value * 0.15),
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.red,
                  size: 22,
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
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Text(
                      ' / ${_maxDurationSeconds}s',
                      style: waddyRegular.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _stopRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 20,
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
        color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: isPlaying ? _pausePlayback : _playRecording,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
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
                      Theme.of(context).primaryColor,
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
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          InkWell(
            onTap: _deleteRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade600,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum RecordingState { idle, recording, recorded, playing }
