import 'package:waddy_app/features/pets/domain/models/user_pet_model.dart';

/// One vet on a clinic's page ("Meet the vets"). No photo yet: the page
/// shows their initial.
class ClinicVet {
  final String name;
  final String? role;
  final int? years;

  const ClinicVet({required this.name, this.role, this.years});

  static ClinicVet? fromJson(dynamic json) {
    if (json is! Map) return null;
    final String name = '${json['name'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    final String? role = json['role']?.toString().trim();
    return ClinicVet(
      name: name,
      role: role == null || role.isEmpty ? null : role,
      years: int.tryParse('${json['years']}'),
    );
  }
}

/// A vet clinic near the customer (`/api/v1/pets/clinics`).
///
/// Clinics are info only: call, WhatsApp, directions. There is no cart and
/// no order (PET-04).
class VetClinicModel {
  final int id;
  final String name;
  final String? description;
  final String? address;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final String? phone;

  /// International digits for `wa.me/…`. Null for a landline or no number,
  /// and then the app hides the WhatsApp button (PET-12).
  final String? whatsapp;
  final String? website;
  final String? instagram;
  final String? imageUrl;
  final String? coverUrl;

  /// Today's `{open, close, closed}` entry from the clinic's hours, as the
  /// server read it in its own timezone.
  final Map<String, dynamic>? todayHours;

  /// The week, `monday`…`sunday` → `{open, close, closed}`.
  final Map<String, dynamic> openingHours;

  /// Starting price (EGP) per service key, where the clinic gave one.
  final Map<String, double> servicePrices;
  final List<ClinicVet> vets;

  /// Null when the clinic has no hours on file: say nothing, don't guess.
  final bool? isOpenNow;

  /// Null until the clinic has enough reviews to mean something (PET-11).
  final double? rating;
  final int reviewsCount;

  /// The animals it treats, as ticked in admin. Empty = not stated (PET-19).
  final List<PetSpecies> species;

  /// Service keys (`emergency_24h`, `home_visit`…). See `ClinicServiceView`.
  final List<String> services;

  const VetClinicModel({
    required this.id,
    required this.name,
    this.description,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.phone,
    this.whatsapp,
    this.website,
    this.instagram,
    this.imageUrl,
    this.coverUrl,
    this.todayHours,
    this.openingHours = const {},
    this.servicePrices = const {},
    this.vets = const [],
    this.isOpenNow,
    this.rating,
    this.reviewsCount = 0,
    this.species = const [],
    this.services = const [],
  });

  factory VetClinicModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) => v == null ? null : double.tryParse('$v');
    final dynamic today = json['today_hours'];
    return VetClinicModel(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      name: '${json['name'] ?? ''}',
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      latitude: toDouble(json['latitude']) ?? 0,
      longitude: toDouble(json['longitude']) ?? 0,
      distanceKm: toDouble(json['distance_km']),
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      website: json['website']?.toString(),
      instagram: json['instagram']?.toString(),
      imageUrl: json['image']?.toString(),
      coverUrl: json['cover_image']?.toString(),
      todayHours: today is Map ? Map<String, dynamic>.from(today) : null,
      openingHours:
          json['opening_hours'] is Map
              ? Map<String, dynamic>.from(json['opening_hours'])
              : const {},
      servicePrices:
          json['service_prices'] is Map
              ? {
                for (final MapEntry e
                    in (json['service_prices'] as Map).entries)
                  if (toDouble(e.value) != null) '${e.key}': toDouble(e.value)!,
              }
              : const {},
      vets:
          json['vets'] is List
              ? (json['vets'] as List)
                  .map(ClinicVet.fromJson)
                  .whereType<ClinicVet>()
                  .toList()
              : const [],
      isOpenNow: json['is_open_now'] is bool ? json['is_open_now'] : null,
      rating: toDouble(json['rating']),
      species:
          json['species'] is List
              ? (json['species'] as List)
                  .map((e) => PetSpecies.of('$e'))
                  .whereType<PetSpecies>()
                  .toList()
              : const [],
      services:
          json['services'] is List
              ? (json['services'] as List).map((e) => '$e').toList()
              : const [],
      reviewsCount:
          json['reviews_count'] is int
              ? json['reviews_count']
              : int.tryParse('${json['reviews_count']}') ?? 0,
    );
  }

  /// "Open until 22:00" / "Opens 16:00" material: today's close or open
  /// time, or null when the hours don't say.
  bool get is24h => services.contains('emergency_24h');
  bool get homeVisits => services.contains('home_visit');

  /// Whether it treats [s]. A clinic that hasn't said counts as yes: an
  /// empty list is missing data, not "treats nothing".
  bool treats(PetSpecies s) => species.isEmpty || species.contains(s);

  String? get closesAt => todayHours?['close']?.toString();
  String? get opensAt => todayHours?['open']?.toString();
  bool get closedToday => isClosedFlag(todayHours?['closed']);

  /// The admin form stores a ticked "closed" box as the string "1", the
  /// seeders as `true`: both mean closed.
  static bool isClosedFlag(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true';
}
