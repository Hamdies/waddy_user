import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';

/// One node of the pets category tree (`/api/v1/pets/categories`).
///
/// Mains are species (`cat`, `dog`… and `all` for what several share);
/// children are needs (`cat.food`, `cat.treats`…). [code] is the stable key
/// the app reads; [name] is whatever the admin calls it today (PET-02).
class PetCategoryModel {
  final int id;
  final String code;
  final String name;
  final String? imageUrl;
  final List<PetCategoryModel> children;

  const PetCategoryModel({
    required this.id,
    required this.code,
    required this.name,
    this.imageUrl,
    this.children = const [],
  });

  static PetCategoryModel? fromJson(Map<String, dynamic> json) {
    final int? id =
        json['id'] is int ? json['id'] : int.tryParse('${json['id']}');
    final String? code = json['code']?.toString();
    if (id == null || code == null || code.isEmpty) return null;
    final dynamic kids = json['children'];
    return PetCategoryModel(
      id: id,
      code: code,
      name: '${json['name'] ?? ''}',
      imageUrl: json['image_full_url']?.toString(),
      children:
          kids is List
              ? kids
                  .whereType<Map>()
                  .map(
                    (e) =>
                        PetCategoryModel.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .whereType<PetCategoryModel>()
                  .toList()
              : const [],
    );
  }

  /// The species this main category is for; null for `all` and for subs.
  PetSpecies? get species => PetSpecies.of(code);

  /// The need part of a sub's code: `food` for `cat.food`.
  String get need => code.contains('.') ? code.split('.').last : code;

  PetCategoryModel? child(String need) {
    for (final PetCategoryModel c in children) {
      if (c.need == need) return c;
    }
    return null;
  }

  /// As the store page's category list wants it.
  CategoryModel toCategoryModel() =>
      CategoryModel(id: id, name: name, imageFullUrl: imageUrl);
}
