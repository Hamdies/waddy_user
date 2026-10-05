/// What a level prize *is*, parsed once from the wire's `prize_type` string
/// (X-38). The screens used to compare `type.toLowerCase()` against string
/// literals in about eight places; they ask this instead. The UI half (icon,
/// label, value line) is `prize_visual.dart`.
///
/// Prize types are fixed by X-25: badge, free delivery, fixed-amount discount,
/// wallet credit. [other] absorbs anything older or unknown.
enum PrizeKind {
  freeDelivery,
  discount,
  walletCredit,
  badge,
  other;

  static PrizeKind parse(String? type) {
    switch (type?.toLowerCase()) {
      case 'free_delivery':
        return PrizeKind.freeDelivery;
      case 'discount':
        return PrizeKind.discount;
      case 'wallet_credit':
        return PrizeKind.walletCredit;
      case 'badge':
        return PrizeKind.badge;
      default:
        return PrizeKind.other;
    }
  }
}
