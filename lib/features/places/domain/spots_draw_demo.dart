import 'dart:math';

import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/models/place_prize_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';

/// A full-looking claw draw built from whatever real data exists.
///
/// The live rounds have **one prize each**, and one ball in a twelve-slot
/// machine is not something you can judge the screen by — the pile, the
/// overflow plate and the losing balls all stay invisible at that size. This
/// pads the round out with plausible-looking strangers so the experience can
/// be evaluated at the size it will eventually run at.
///
/// **Debug only, and client-side only.** Nothing here is written anywhere:
/// `SpotsDrawDemo` builds a [SpotsDraw] in memory and hands it to the screen.
/// The database is not touched, so there is nothing to clean up afterwards —
/// which is the whole point, given that seeding test rows into production is
/// what produced the "9" period in the first place.
///
/// The signed-in user is always pull #1 in a winning demo. [fromPrize] keeps
/// their real `my_prize_id`, so the whole win path — confetti, the win sting,
/// the route into the voucher — is the genuine one rather than a mock of it.
/// [winning] is the same shape for an account that has no prize row to lend,
/// and gives up only the voucher route.
class SpotsDrawDemo {
  const SpotsDrawDemo._();

  /// How many the claw takes, unless a caller says otherwise.
  ///
  /// Three, not five. Five slots put five names across the prize chute on a
  /// phone, which is where "Mariam Abdelrahman" had to be clamped to fit and
  /// where the row of faces stops reading as individuals and starts reading
  /// as a strip. Three gives each winner room to be a person, and takes ~9
  /// seconds of performance rather than ~15 — which is the difference between
  /// a show and a wait.
  ///
  /// One constant so the demo entry points cannot drift apart: a WIN demo
  /// pulling five and a LOSE demo pulling three would be comparing two
  /// different screens.
  static const int defaultPulls = 3;

  /// Egyptian first names + last initials, in the same masked shape the
  /// backend sends ("Farida N."). Deliberately ordinary: a machine full of
  /// obviously-fake names reads as a mock and stops testing anything.
  static const List<String> _names = [
    'Farida N.',
    'Youssef K.',
    'Nour E.',
    'Omar H.',
    'Salma T.',
    'Karim A.',
    'Hana M.',
    'Tarek S.',
    'Dina R.',
    'Mostafa G.',
    'Laila Z.',
    'Aya M.',
    'Ziad F.',
    'Mariam W.',
    'Hassan B.',
    'Nada Q.',
    'Amr L.',
    'Rana D.',
  ];

  /// Build a padded draw around the user's real prize.
  ///
  /// [prize] is their genuine voucher — its id is what the winner row routes
  /// to. [entrants] is how full the machine should look; [pulls] is how many
  /// the claw takes, defaulting to the live `winners_per_week`.
  static SpotsDraw fromPrize(
    PlacePrize prize, {
    String? myName,
    String? myImage,
    int entrants = 12,
    int pulls = defaultPulls,
    int seed = 27,
    int? poolSize,
  }) => _build(
    myName: myName,
    myImage: myImage,
    entrants: entrants,
    pulls: pulls,
    seed: seed,
    poolSize: poolSize,
    myPrizeId: prize.id,
  );

  /// The winning shape, shared by [fromPrize] and [winning].
  ///
  /// The only difference between the two is which prize id comes out the far
  /// end — a real voucher or a sentinel — so everything else lives here
  /// rather than in two copies that would drift.
  static SpotsDraw _build({
    required int? myPrizeId,
    String? myName,
    String? myImage,
    int entrants = 12,
    int pulls = defaultPulls,
    int seed = 27,
    int? poolSize,
  }) {
    final rng = Random(seed);

    // The real user is entrant 0 and winner 0. Their user id is negative so it
    // can never collide with a padded id or be mistaken for a server value.
    const myId = -1;
    final me = DrawEntrant(
      userId: myId,
      name: (myName == null || myName.trim().isEmpty) ? 'You' : myName.trim(),
      votes: 3 + rng.nextInt(12),
      isMe: true,
      // Your own real avatar, so the ball the claw picks up is actually you.
      image: myImage,
    );

    final padding = _padding(entrants - 1, rng);
    final all = [me, ...padding];

    // Real winner first, then fakes — the order the claw pulls in.
    final winnerIds = <int>[myId];
    final pool = List<DrawEntrant>.from(padding)..shuffle(rng);
    for (final e in pool.take((pulls - 1).clamp(0, padding.length))) {
      winnerIds.add(e.userId);
    }

    return SpotsDraw.fromServer(
      entrants: all,
      winnerIds: winnerIds,
      pullCount: winnerIds.length,
      // The real thing: a thousand-odd voters in the machine, twelve on
      // screen. The overflow plate states the rest, so nothing is hidden —
      // and because the winners are always among the visible balls, the claw
      // never has to conjure a face that was not already there.
      totalEntrants: poolSize ?? (900 + rng.nextInt(400)),
      myPrizeId: myPrizeId,
    );
  }

  /// A win with no real voucher behind it.
  ///
  /// The debug WIN button used to fall back to [losing] when the account had
  /// no prize row, on the reasoning that there was nothing to route to. That
  /// made the button labelled WIN produce a loss — confetti suppressed, "NOT
  /// THIS WEEK" on the CTA — which is the one thing it exists to show.
  ///
  /// The voucher route is the only part that genuinely needs a real prize, so
  /// that is the only part this gives up: [myPrizeId] is a sentinel, the
  /// screen takes every win path, and tapping through to the voucher is the
  /// one thing that will not find anything. Everything before it — the claw
  /// pulling *you*, the confetti, the win sting, "YOU WON" — is the real
  /// path rather than a mock of it.
  static SpotsDraw winning({
    String? myName,
    String? myImage,
    int entrants = 12,
    int pulls = defaultPulls,
    int seed = 11,
    int? poolSize,
  }) => _build(
    myName: myName,
    myImage: myImage,
    entrants: entrants,
    pulls: pulls,
    seed: seed,
    poolSize: poolSize,
    // Negative, like the demo user ids: it can never collide with a real
    // prize row, so a stray tap fails to find one rather than opening
    // somebody else's voucher.
    myPrizeId: -1,
  );

  /// A draw with no real prize in it — the losing experience.
  ///
  /// Worth having its own entry point: the consolation panel and the absence
  /// of confetti are the half of this screen a winner never sees, and they are
  /// the easier half to get wrong.
  static SpotsDraw losing({
    String? myName,
    String? myImage,
    int entrants = 12,
    int pulls = defaultPulls,
    int seed = 4,
    int? poolSize,
  }) {
    final rng = Random(seed);

    const myId = -1;
    final me = DrawEntrant(
      userId: myId,
      name: (myName == null || myName.trim().isEmpty) ? 'You' : myName.trim(),
      votes: 2 + rng.nextInt(9),
      isMe: true,
      image: myImage,
    );

    final padding = _padding(entrants - 1, rng);
    final pool = List<DrawEntrant>.from(padding)..shuffle(rng);

    return SpotsDraw.fromServer(
      entrants: [me, ...padding],
      // The user is in the machine and is never pulled.
      winnerIds:
          pool
              .take(pulls.clamp(0, padding.length))
              .map((e) => e.userId)
              .toList(),
      pullCount: pulls,
      totalEntrants: poolSize ?? (900 + rng.nextInt(400)),
      // No prize: the gate that must keep the confetti off.
      myPrizeId: null,
    );
  }

  /// Stand-in faces for the padded entrants.
  ///
  /// The whole point of the screen is that the machine is full of *people*, so
  /// a demo of grey monograms would be testing the wrong thing. These come
  /// from pravatar, a free placeholder-avatar service: real-looking portraits,
  /// no account, no attribution, stable per index so a given fake voter keeps
  /// their face across runs.
  ///
  /// **Debug-only, and it needs a network.** Offline, `CustomImage` falls back
  /// to its placeholder and the ball shows initials — which is exactly the
  /// no-photo path a real user without an avatar takes, so it is still a valid
  /// thing to look at.
  static String _demoFace(int index) =>
      'https://i.pravatar.cc/150?img=${(index % 70) + 1}';

  static List<DrawEntrant> _padding(int count, Random rng) {
    final names = List<String>.from(_names)..shuffle(rng);
    final faces = List<int>.generate(70, (i) => i)..shuffle(rng);

    return List.generate(count.clamp(0, _names.length), (i) {
      return DrawEntrant(
        // Negative ids throughout: a demo entrant can never be confused with a
        // real user, and a stray one would fail loudly rather than silently
        // matching somebody.
        userId: -(i + 2),
        name: names[i % names.length],
        votes: 1 + rng.nextInt(14),
        // Every third one deliberately has no photo, so the initials fallback
        // is always on screen somewhere rather than only in theory.
        image: i % 3 == 2 ? null : _demoFace(faces[i % faces.length]),
      );
    });
  }
}
