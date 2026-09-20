import 'dart:math';

import 'package:waddy_app/features/places/domain/models/draw_entrant_model.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';

/// Preview data for the claw draw. **Off unless compiled on.**
///
/// ```
/// flutter run --dart-define=SPOTS_DRAW_PREVIEW=true
/// ```
///
/// Declared with [bool.fromEnvironment] rather than a hand-edited
/// `const bool ... = false`, which is how the rest of this codebase does it
/// (`kPreviewRankedChart`, `kPreviewGroceryShelf`). Those are guarded by
/// `kDebugMode` so a forgotten `true` cannot reach users — but it can still be
/// committed, and a screenshot of fake data can still cost someone an hour.
/// A `fromEnvironment` default is false at *compile* time, so everything below
/// is tree-shaken out of any build that did not explicitly ask for it, and
/// there is no line anyone can flip by accident.
///
/// When on, the screen shows a `PREVIEW DATA` ribbon. See
/// `docs/spots_claw_draw_plan.md` §5.
const bool kSpotsDrawPreview = bool.fromEnvironment('SPOTS_DRAW_PREVIEW');

/// The twelve voters from the source design, verbatim.
///
/// Names are already in the masked "first + last initial" form the backend
/// sends, because that is what the screen actually receives — a fixture of
/// full names would flatter the layout and hide nothing.
const List<DrawEntrant> _designTwelve = [
  DrawEntrant(userId: 1, name: 'Farida N.', handle: '@faridaaa', votes: 14),
  DrawEntrant(userId: 2, name: 'Youssef K.', handle: '@yk', votes: 12),
  DrawEntrant(userId: 3, name: 'Nour E.', handle: '@nouresh', votes: 11),
  DrawEntrant(userId: 4, name: 'Omar H.', handle: '@omarh', votes: 10),
  DrawEntrant(userId: 5, name: 'Salma T.', handle: '@salmat', votes: 9),
  DrawEntrant(userId: 6, name: 'Karim A.', handle: '@karimaa', votes: 8),
  DrawEntrant(userId: 7, name: 'Hana M.', handle: '@hanam', votes: 7),
  DrawEntrant(userId: 8, name: 'Tarek S.', handle: '@tareks', votes: 6),
  DrawEntrant(userId: 9, name: 'Dina R.', handle: '@dinar', votes: 6),
  DrawEntrant(userId: 10, name: 'Mostafa G.', handle: '@mostafag', votes: 5),
  DrawEntrant(userId: 11, name: 'Laila Z.', handle: '@lailaz', votes: 5),
  DrawEntrant(userId: 12, name: 'Aya M.', handle: '@ayam', votes: 4),
];

/// Every fixture is the `CLAW-Z2` payload shape, so swapping a fixture for a
/// live response is a source change rather than a remodel.
class SpotsDrawFixtures {
  const SpotsDrawFixtures._();

  /// The live default: five pulls, twelve entrants, user not among them.
  static SpotsDraw get happyPath => SpotsDraw.fromServer(
    entrants: _designTwelve,
    winnerIds: const [3, 7, 1, 11, 5],
    pullCount: 5,
    totalEntrants: 12,
  );

  /// The design's three pulls, kept as a second case.
  static SpotsDraw get threePulls => SpotsDraw.fromServer(
    entrants: _designTwelve,
    winnerIds: const [1, 8, 4],
    pullCount: 3,
    totalEntrants: 12,
  );

  /// The user wins. Confetti fires, one row routes to the prize.
  static SpotsDraw get iWon {
    final pool = [
      const DrawEntrant(
        userId: 3,
        name: 'Nour E.',
        handle: '@nouresh',
        votes: 11,
        isMe: true,
      ),
      ..._designTwelve.where((e) => e.userId != 3),
    ];
    return SpotsDraw.fromServer(
      entrants: pool,
      winnerIds: const [3, 7, 1, 11, 5],
      pullCount: 5,
      totalEntrants: 12,
      myPrizeId: 331,
    );
  }

  /// The user voted and lost. `isMe` is set but no prize id — the case that
  /// must NOT celebrate.
  static SpotsDraw get iLost {
    final pool = [
      const DrawEntrant(
        userId: 12,
        name: 'Aya M.',
        handle: '@ayam',
        votes: 4,
        isMe: true,
      ),
      ..._designTwelve.where((e) => e.userId != 12),
    ];
    return SpotsDraw.fromServer(
      entrants: pool,
      winnerIds: const [3, 7, 1, 11, 5],
      pullCount: 5,
      totalEntrants: 12,
    );
  }

  /// Fewer entrants than the server's pull count.
  static SpotsDraw get twoEntrants => SpotsDraw.fromServer(
    entrants: _designTwelve.take(2).toList(),
    winnerIds: const [1, 2],
    pullCount: 5,
    totalEntrants: 2,
  );

  /// Nobody voted.
  static SpotsDraw get empty =>
      SpotsDraw.fromServer(entrants: const [], winnerIds: const []);

  /// Eighteen entrants — the pile overflows its twelve slots.
  static SpotsDraw get overflow {
    final extra = List.generate(
      6,
      (i) => DrawEntrant(
        userId: 100 + i,
        name: 'Voter ${13 + i}',
        handle: '@v${13 + i}',
        votes: 3,
      ),
    );
    return SpotsDraw.fromServer(
      entrants: [..._designTwelve, ...extra],
      winnerIds: const [3, 7, 1, 11, 5],
      pullCount: 5,
      totalEntrants: 18,
    );
  }

  /// A real pool the server sampled down: 60 stored, 143 actually voted.
  static SpotsDraw get sampled => SpotsDraw.fromServer(
    entrants: [
      ..._designTwelve,
      ...List.generate(
        48,
        (i) => DrawEntrant(
          userId: 200 + i,
          name: 'Voter ${13 + i}',
          handle: '@v${13 + i}',
          votes: 2,
        ),
      ),
    ],
    winnerIds: const [3, 7, 1, 11, 5],
    pullCount: 5,
    totalEntrants: 143,
  );

  /// The names that crash the design's `ini()`.
  static SpotsDraw get awkwardNames => SpotsDraw.fromServer(
    entrants: const [
      DrawEntrant(userId: 1, name: 'Farida', handle: '@f', votes: 9),
      DrawEntrant(userId: 2, name: '', handle: '', votes: 8),
      DrawEntrant(userId: 3, name: '   ', handle: '@spaces', votes: 7),
      DrawEntrant(userId: 4, name: ' N.', handle: '@leading', votes: 6),
      DrawEntrant(
        userId: 5,
        name: 'Abdelrahman Mohamed Abdelaziz Elsayed',
        handle: '@averylonghandleindeed',
        votes: 5,
      ),
      DrawEntrant(userId: 6, name: 'فريدة نبيل', handle: '@ar', votes: 4),
    ],
    winnerIds: const [2, 5, 3],
    pullCount: 3,
    totalEntrants: 6,
  );

  /// A backfilled period (`CLAW-Z4`): winners known, losers never recorded.
  /// This will exist in production on day one.
  static SpotsDraw get backfilled => SpotsDraw.fromServer(
    entrants:
        _designTwelve.where((e) => const [3, 7, 1].contains(e.userId)).toList(),
    winnerIds: const [3, 7, 1],
    pullCount: 5,
    totalEntrants: null,
  );

  /// The design's on-device pick, seeded so a preview is reproducible. The
  /// only caller of [SpotsDraw.local] outside tests.
  static SpotsDraw randomised([int seed = 42]) =>
      SpotsDraw.local(entrants: _designTwelve, pulls: 5, random: Random(seed));

  /// Everything above, for a gallery or a sweep test.
  static Map<String, SpotsDraw> get all => {
    'happy path (5)': happyPath,
    'three pulls': threePulls,
    'I won': iWon,
    'I lost': iLost,
    'two entrants': twoEntrants,
    'empty': empty,
    'overflow (18)': overflow,
    'sampled (143)': sampled,
    'awkward names': awkwardNames,
    'backfilled': backfilled,
  };
}
