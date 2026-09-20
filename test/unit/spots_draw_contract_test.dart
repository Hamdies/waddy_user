import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/places/domain/spots_draw.dart';

/// `CLAW-Z2` — the client's half of the endpoint contract.
///
/// These payloads are hand-built to match what
/// `Modules/PlacesToVisit/Http/Controllers/Api/DrawController@show` emits,
/// field for field. They are the cheapest available guard against the two
/// halves drifting: if someone renames `winner_ids` or starts sending
/// `total_entrants` as a string, this fails here rather than as an empty
/// machine on a device.
///
/// It is a contract test, not an integration test — it cannot prove the server
/// still sends this shape. That is what the payload comment in DrawController
/// is for.
String _payload({
  String period = '2026-W27',
  int pullCount = 3,
  Object? totalEntrants = 12,
  Object? myPrizeId,
  List<Map<String, Object?>>? entrants,
  List<Object>? winnerIds,
}) {
  return jsonEncode({
    'success': true,
    'data': {
      'period': period,
      'place': {'id': 12, 'title': 'Cairo Coffee', 'image': 'x.jpg'},
      'pull_count': pullCount,
      'total_entrants': totalEntrants,
      'entrants':
          entrants ??
          [
            {
              'user_id': 88,
              'name': 'Farida N.',
              'handle': '',
              'votes': 14,
              'rank': 1,
              'is_me': false,
            },
            {
              'user_id': 41,
              'name': 'Youssef K.',
              'handle': '',
              'votes': 12,
              'rank': 2,
              'is_me': true,
            },
            {
              'user_id': 7,
              'name': 'Nour E.',
              'handle': '',
              'votes': 9,
              'rank': 3,
              'is_me': false,
            },
            {
              'user_id': 19,
              'name': 'Omar H.',
              'handle': '',
              'votes': 4,
              'rank': 0,
              'is_me': false,
            },
          ],
      'winner_ids': winnerIds ?? [88, 41, 7],
      'my_prize_id': myPrizeId,
    },
  });
}

SpotsDraw _parse(String body) =>
    SpotsDraw.fromApi(jsonDecode(body) as Map<String, dynamic>);

void main() {
  group('the happy payload', () {
    test('parses entrants, winners and pull order', () {
      final draw = _parse(_payload());

      expect(draw.entrants.length, 4);
      expect(draw.winnerIds, [88, 41, 7]);
      expect(draw.pullCount, 3);
      expect(draw.totalEntrants, 12);
      expect(draw.phase, DrawPhase.ready);
    });

    test('replays the server order exactly', () {
      final draw = _parse(_payload()).start().finish();
      expect(draw.winners.map((w) => w.userId).toList(), [88, 41, 7]);
      expect(draw.winners.map((w) => w.rank).toList(), [1, 2, 3]);
    });

    test('the loser is not in the winners', () {
      final draw = _parse(_payload()).start().finish();
      expect(draw.losers.map((l) => l.userId), [19]);
    });
  });

  group('the envelope', () {
    test('a bare data object parses the same as the full envelope', () {
      final full = _parse(_payload());
      final bare = SpotsDraw.fromApi(
        (jsonDecode(_payload()) as Map<String, dynamic>)['data']
            as Map<String, dynamic>,
      );

      expect(bare.winnerIds, full.winnerIds);
      expect(bare.entrants.length, full.entrants.length);
      expect(bare.totalEntrants, full.totalEntrants);
    });
  });

  group('the confetti gate', () {
    test('absent my_prize_id means no celebration', () {
      expect(_parse(_payload()).iWon, isFalse);
    });

    test('a null my_prize_id means no celebration', () {
      expect(_parse(_payload(myPrizeId: null)).iWon, isFalse);
    });

    test('an int my_prize_id means the user won', () {
      final draw = _parse(_payload(myPrizeId: 331));
      expect(draw.iWon, isTrue);
      expect(draw.myPrizeId, 331);
    });

    test('is_me alone never wins', () {
      // The trap: user 41 is `is_me` and IS a winner, but with no prize id
      // there is nothing to celebrate or route to.
      final draw = _parse(_payload()).start().finish();
      expect(draw.winners.any((w) => w.isMe), isTrue);
      expect(draw.iWon, isFalse);
    });
  });

  group('a backfilled period (CLAW-Z4)', () {
    test('a null total_entrants falls back to what is visible', () {
      final draw = _parse(_payload(totalEntrants: null));
      expect(draw.totalEntrants, isNull);
      expect(draw.displayTotal, 4);
    });

    test('a winner id with no entrant row is dropped, not thrown on', () {
      final draw = _parse(_payload(winnerIds: [88, 999, 41]));
      expect(draw.winnerIds, [88, 41]);
      expect(() => draw.start().finish(), returnsNormally);
    });
  });

  group('faces', () {
    test('an absolute image url survives the parse', () {
      final draw = _parse(
        _payload(
          entrants: [
            {
              'user_id': 1,
              'name': 'Farida N.',
              'votes': 9,
              'rank': 1,
              'is_me': false,
              'image': 'https://cdn.waddi.test/u/1.jpg',
            },
          ],
          winnerIds: [1],
          pullCount: 1,
        ),
      );
      expect(draw.entrants.first.image, 'https://cdn.waddi.test/u/1.jpg');
    });

    test('image_full_url wins over image', () {
      final draw = _parse(
        _payload(
          entrants: [
            {
              'user_id': 1,
              'name': 'A',
              'rank': 1,
              'image': 'legacy.jpg',
              'image_full_url': 'https://cdn.waddi.test/u/1.jpg',
            },
          ],
          winnerIds: [1],
          pullCount: 1,
        ),
      );
      expect(draw.entrants.first.image, 'https://cdn.waddi.test/u/1.jpg');
    });

    test('a user with no photo parses to null, not empty string', () {
      // The ball branches on null; '' would render an empty network image
      // instead of the initials fallback.
      for (final bad in [null, '', '   ', 'null', 'undefined']) {
        final draw = _parse(
          _payload(
            entrants: [
              {'user_id': 1, 'name': 'A', 'rank': 1, 'image': bad},
            ],
            winnerIds: [1],
            pullCount: 1,
          ),
        );
        expect(draw.entrants.first.image, isNull, reason: 'for \'$bad\'');
      }
    });

    test('the image survives a pull', () {
      // `copyWith` stamps the rank during the run — dropping the face there
      // would empty every winner row at the moment it matters most.
      final draw =
          _parse(
            _payload(
              entrants: [
                {
                  'user_id': 1,
                  'name': 'A',
                  'rank': 0,
                  'image': 'https://cdn.waddi.test/u/1.jpg',
                },
              ],
              winnerIds: [1],
              pullCount: 1,
            ),
          ).start().finish();

      expect(draw.winners.first.image, 'https://cdn.waddi.test/u/1.jpg');
      expect(draw.winners.first.rank, 1);
    });
  });

  group('hostile payloads', () {
    test('an empty draw renders the empty state', () {
      final draw = _parse(
        _payload(entrants: [], winnerIds: [], pullCount: 0, totalEntrants: 0),
      );
      expect(draw.isEmpty, isTrue);
      expect(draw.phase, DrawPhase.done);
      expect(draw.ctaEnabled, isFalse);
    });

    test('missing keys do not throw', () {
      final draw = SpotsDraw.fromApi(<String, dynamic>{'data': {}});
      expect(draw.entrants, isEmpty);
      expect(draw.winnerIds, isEmpty);
      expect(draw.isEmpty, isTrue);
    });

    test('numbers arriving as strings still parse', () {
      // PHP's json_encode can stringify integers depending on column type and
      // driver; `total_entrants` comes straight off a DB column.
      final draw = _parse(_payload(totalEntrants: '143', myPrizeId: '331'));
      expect(draw.totalEntrants, 143);
      expect(draw.myPrizeId, 331);
      expect(draw.iWon, isTrue);
    });

    test('a null entrants list does not throw', () {
      final draw = SpotsDraw.fromApi(<String, dynamic>{
        'data': {'entrants': null, 'winner_ids': null},
      });
      expect(draw.isEmpty, isTrue);
    });

    test('a name the backend could not mask falls back, not crashes', () {
      // DrawController sends `translate('messages.a_waddi_voter')` for a user
      // with no name at all — but a null slipping through must not crash.
      final draw = _parse(
        _payload(
          entrants: [
            {'user_id': 1, 'name': '', 'votes': 2, 'rank': 1, 'is_me': false},
          ],
          winnerIds: [1],
          pullCount: 1,
        ),
      );
      expect(draw.entrants.first.initials, '?');
    });
  });
}
