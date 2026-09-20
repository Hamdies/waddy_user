import 'package:waddy_app/util/image_url.dart';

/// One ball in the claw machine — a voter who was in the week's prize draw.
///
/// The backend's `PrizeDrawService` runs the real draw at crown time and keeps
/// only the winners in `place_prizes`. `CLAW-Z1` adds the entrant rows so the
/// losing balls exist too; without them the screen is a list, not a machine.
///
/// Names arrive already masked ("Farida N.") by the same first-plus-initial
/// rule `LeaderboardService::getRecentPrizeWinners()` uses. The client never
/// un-masks and never re-masks — one rule, applied server-side, for the same
/// people in both places.
class DrawEntrant {
  final int userId;
  final String name;

  /// `@handle`, already including the `@` when the server sends one.
  final String handle;

  /// Their vote count that period. Shown on the winner row, not the ball.
  final int votes;

  /// Profile photo, absolute URL, or null.
  ///
  /// This is the joke: the machine is full of actual faces, and the claw picks
  /// one of them up. [initials] is the fallback for a user with no photo — a
  /// grey circle would break the gag, so the ball still says *who* it is.
  final String? image;

  /// Pull order: 0 = never pulled, 1..N = the order the claw took them.
  ///
  /// This is the server's decision replayed, not a client outcome. See
  /// `SpotsDraw.fromServer`.
  final int rank;

  /// True when this entrant is the signed-in user. Guests get `false` for
  /// everyone — the endpoint only sets it on an authed request.
  final bool isMe;

  const DrawEntrant({
    required this.userId,
    required this.name,
    this.handle = '',
    this.votes = 0,
    this.rank = 0,
    this.isMe = false,
    this.image,
  });

  bool get pulled => rank > 0;

  /// First letter of the first word + first letter of the last word, upper.
  ///
  /// The design's `ini()` is `n.split(" ")` then `w[0][0]`, which throws on an
  /// empty name and on a leading space. Real display names carry both: the
  /// backend masks to `"{first} {lastInitial}"` and a user with no `f_name`
  /// produces a leading space or an empty string. A crash in a getter called
  /// once per ball would take the whole screen down, so every degenerate case
  /// falls back to `?` instead.
  ///
  /// Split is on whitespace rather than `' '` so a tab or a non-breaking space
  /// in a pasted name doesn't become part of an "initial", and the first rune
  /// is taken rather than the first code unit so a name outside the BMP
  /// doesn't slice into half a surrogate pair.
  String get initials {
    final words =
        name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';

    String head(String word) => String.fromCharCode(word.runes.first);

    if (words.length == 1) return head(words.first).toUpperCase();
    return '${head(words.first)}${head(words.last)}'.toUpperCase();
  }

  /// The masked name, further clamped to fit a chute slot.
  ///
  /// The server already masks to `"{first} {lastInitial}"`, which fits the
  /// 5-slot prize chute for almost every name — "Hassan B.", "Aya M.". It
  /// does not bound the *first* name, so a long one ("Mariam Abdelrahman" →
  /// "Mariam A.") still overflowed its slot and ellipsized to "Mariam ...",
  /// dropping the initial. That reads as a layout failure sitting between
  /// four names that fit, and it loses the one character that distinguishes
  /// two Mariams.
  ///
  /// So an over-long first name is truncated and the initial is *kept*:
  /// "Mariamm A." rather than "Mariam ...". The initial is the part that
  /// disambiguates, so it is the part that survives.
  ///
  /// This is presentation only — it never un-masks, and the masking rule
  /// itself stays server-side where both this screen and the leaderboard
  /// read it from.
  String get shortName {
    final trimmed = name.trim();
    if (trimmed.runes.length <= _chuteNameMax) return trimmed;

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 2) {
      // One long word and no initial to protect: a plain clamp is all there
      // is to do, with an ellipsis so it still reads as shortened.
      return '${String.fromCharCodes(trimmed.runes.take(_chuteNameMax - 1))}…';
    }

    // Keep the trailing element whole and spend what is left on the first
    // name. `runes` throughout rather than `substring`/`length`, so a name
    // outside the BMP is measured in characters and never sliced into half a
    // surrogate pair.
    //
    // The tail is normally a masked initial ("A."), which is short by
    // construction. A fixture — or a server that ever stops masking — can
    // hand over a full surname instead, and spending the budget on that
    // would clip the *first* name down to nothing while preserving a word
    // nobody needs. So a tail that cannot fit is itself reduced to an
    // initial, which is what the masking rule would have produced anyway.
    final tail =
        words.last.runes.length > 3
            ? '${String.fromCharCode(words.last.runes.first).toUpperCase()}.'
            : words.last;

    final budget = _chuteNameMax - tail.runes.length - 2; // space + ellipsis
    if (budget <= 0) {
      return '${String.fromCharCodes(trimmed.runes.take(_chuteNameMax - 1))}…';
    }
    final headRunes = words.first.runes;
    // Only ellipsize the first name if it was actually shortened.
    final head =
        headRunes.length <= budget
            ? words.first
            : '${String.fromCharCodes(headRunes.take(budget))}…';
    return '$head $tail';
  }

  /// Characters a chute slot holds at default text scale before the label
  /// ellipsizes. Measured against the 10pt bold the slot uses, not guessed.
  static const int _chuteNameMax = 12;

  factory DrawEntrant.fromJson(Map<String, dynamic> json) {
    return DrawEntrant(
      userId: _asInt(json['user_id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      handle: (json['handle'] ?? '').toString(),
      votes: _asInt(json['votes']) ?? 0,
      rank: _asInt(json['rank']) ?? 0,
      isMe: json['is_me'] == true,
      // Same two-candidate pick every other model in this module uses: the
      // API serialises `image_full_url`, older payloads only `image`.
      image: pickImageUrl([json['image_full_url'], json['image']]),
    );
  }

  DrawEntrant copyWith({int? rank}) => DrawEntrant(
    userId: userId,
    name: name,
    handle: handle,
    votes: votes,
    rank: rank ?? this.rank,
    isMe: isMe,
    image: image,
  );

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
