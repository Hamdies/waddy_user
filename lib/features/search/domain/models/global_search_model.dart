import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/util/parse.dart';

/// The three kinds of place the global search sorts results into. Modules are
/// finer than this (pharmacy, pets, e-commerce…); a shopper's mental model is
/// "somewhere to eat", "somewhere for groceries" and "a shop".
enum SearchKind {
  restaurants,
  groceries,
  shops;

  static SearchKind of(ModuleType type) {
    switch (type) {
      case ModuleType.food:
        return SearchKind.restaurants;
      case ModuleType.grocery:
        return SearchKind.groceries;
      default:
        return SearchKind.shops;
    }
  }
}

/// How much of the world a live search covers. [all] is the module-less
/// dashboard; the others are one module's own search, which drops the kind tabs
/// and speaks in that module's nouns.
enum SearchScope { all, restaurants, groceries }

/// One store from `GET /search/global` with the products of it that matched.
class GlobalSearchStore {
  final int? id;
  final String name;
  final String? logoUrl;
  final int? moduleId;
  final SearchKind kind;

  /// Parsed from the seller's hand-typed "25-35 min"; 0 when unstated.
  final int minDeliveryTime;
  final int maxDeliveryTime;
  final double? distanceKm;
  final bool open;
  final bool freeDelivery;
  final List<String> cuisines;
  final double avgRating;
  final int ratingCount;

  /// Whole percent of the deepest live markdown, 0 for none.
  final int offerPercent;
  final List<Item> items;

  const GlobalSearchStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.moduleId,
    required this.kind,
    required this.minDeliveryTime,
    required this.maxDeliveryTime,
    required this.distanceKm,
    required this.open,
    required this.freeDelivery,
    required this.cuisines,
    required this.avgRating,
    required this.ratingCount,
    required this.offerPercent,
    required this.items,
  });

  bool get hasOffer => offerPercent > 0;

  /// What "Top rated" keeps: a high average that enough people stand behind.
  /// One five-star review is not a ranking.
  static const double topRating = 4.7;
  static const int _minRatings = 5;
  bool get isTopRated => avgRating >= topRating && ratingCount >= _minRatings;

  factory GlobalSearchStore.fromJson(Map<String, dynamic> json) {
    final List<int> window = _window(json['delivery_time']);
    return GlobalSearchStore(
      id: Parse.lenientInt(json['id']),
      name: (json['name'] ?? '').toString(),
      logoUrl: json['logo_full_url']?.toString(),
      moduleId: Parse.lenientInt(json['module_id']),
      kind: SearchKind.of(
        ModuleType.of(
          json['module_type']?.toString(),
          variant: json['variant']?.toString(),
        ),
      ),
      minDeliveryTime: window[0],
      maxDeliveryTime: window[1],
      distanceKm:
          json['distance'] == null
              ? null
              : (json['distance'] as num).toDouble(),
      open: json['open'] == true,
      freeDelivery: json['free_delivery'] == true,
      cuisines: <String>[
        for (final dynamic c
            in (json['cuisines'] as List<dynamic>? ?? const <dynamic>[]))
          c.toString(),
      ],
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      ratingCount: Parse.lenientInt(json['rating_count']),
      offerPercent: Parse.lenientInt(json['offer_percent']),
      items: <Item>[
        for (final dynamic raw
            in (json['items'] as List<dynamic>? ?? const <dynamic>[]))
          Item.fromJson(raw as Map<String, dynamic>),
      ],
    );
  }

  /// "25-35 min" / "30" / null → (min, max), zeros when unstated.
  static List<int> _window(dynamic raw) {
    final Iterable<RegExpMatch> numbers = RegExp(
      r'\d+',
    ).allMatches('${raw ?? ''}');
    final List<int> n = numbers.map((m) => int.parse(m.group(0)!)).toList();
    if (n.isEmpty) return <int>[0, 0];
    return n.length == 1 ? <int>[0, n[0]] : <int>[n[0], n[1]];
  }
}
