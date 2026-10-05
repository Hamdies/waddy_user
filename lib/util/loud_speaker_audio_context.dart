import 'package:audioplayers/audioplayers.dart';

/// Every recorded voice note in this app (checkout, address directions, order
/// tracking) plays back through [AudioPlayer]'s default context, which is the
/// iOS earpiece the moment a `flutter_sound` recorder session is anywhere
/// alive in the process — `playAndRecord`, the category that session sets,
/// defaults to the receiver unless told otherwise. Android has no such
/// default; [AudioContextAndroid]'s defaults already route to the main
/// speaker.
///
/// Apply this to every [AudioPlayer] used for playback in the app, right
/// after construction, so a note is always audible without the phone held to
/// an ear.
final AudioContext loudSpeakerAudioContext = AudioContext(
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playAndRecord,
    options: const {
      AVAudioSessionOptions.defaultToSpeaker,
      AVAudioSessionOptions.mixWithOthers,
    },
  ),
);

/// Sets [loudSpeakerAudioContext] on [player]. Fire-and-forget: a failure
/// here means audio still plays, just possibly through the earpiece, so it is
/// never worth blocking or surfacing to the user over.
Future<void> useLoudSpeaker(AudioPlayer player) {
  return player.setAudioContext(loudSpeakerAudioContext);
}
