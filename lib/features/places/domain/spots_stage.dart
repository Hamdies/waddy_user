/// How far into the week's race the board actually is.
///
/// This exists because the Spots home used to be a fixed five-section template
/// rendered over a variable dataset: countdown, ranked top 3, voter podium,
/// live ticker and winners strip all drew at full height whether the round had
/// two votes or two hundred. With a near-empty board that produced a screen
/// that contradicted itself — an "EARLY LEAD" sticker over a 1-vote tie, three
/// hundred pixels above a ticker admitting "VOTING IS WARMING UP" — and buried
/// the venue list, the only thing a cold round can actually offer, below about
/// 1900px of theatre about a race nobody had run yet.
///
/// One derived value now drives the composition instead. Sections are unlocked
/// as the round earns them, so the screen can never claim more than the data
/// supports, and the full stadium means something by the time it appears.
///
/// This replaces the old `_kWarmupVotes` guard in `weekly_top3_section.dart`,
/// which swapped *copy* inside a structure that never changed.
enum SpotsStage {
  /// Nobody has really voted yet. No ranking exists, so none is drawn: an
  /// invitation, one action, and the places list.
  cold,

  /// A real contest, honestly scaled. The board appears — ties rendered as
  /// ties — along with the user's own standing.
  warm,

  /// The race is genuinely live. Everything unlocks: podium, ticker, winners.
  hot;

  bool get isCold => this == SpotsStage.cold;
  bool get isWarm => this == SpotsStage.warm;
  bool get isHot => this == SpotsStage.hot;

  /// True once there is a board worth ranking — warm or hotter.
  bool get hasBoard => this != SpotsStage.cold;

  /// Total votes across the board below which the race has not started.
  static const int warmThreshold = 5;

  /// Total votes at which the race is live enough for the full stadium.
  static const int hotThreshold = 25;

  /// Classify a round by its total vote count across the standings.
  static SpotsStage fromHeat(int heat) {
    if (heat < warmThreshold) return SpotsStage.cold;
    if (heat < hotThreshold) return SpotsStage.warm;
    return SpotsStage.hot;
  }
}
