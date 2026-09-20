import 'package:waddy_app/util/image_url.dart';

class PlaceSubmission {
  final int id;
  final int? userId;
  final String name;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final String? address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? website;
  final String? instagram;
  final String? image;
  final String status; // pending, approved, rejected
  final String? adminNote;
  final DateTime? createdAt;

  PlaceSubmission({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.categoryId,
    this.categoryName,
    this.address,
    this.lat,
    this.lng,
    this.phone,
    this.website,
    this.instagram,
    this.image,
    this.status = 'pending',
    this.adminNote,
    this.createdAt,
  });

  factory PlaceSubmission.fromJson(Map<String, dynamic> json) {
    return PlaceSubmission(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      name: json['name'] ?? '',
      description: json['description'],
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? json['category']?['name'],
      address: json['address'],
      lat: _parseDouble(json['lat'] ?? json['latitude']),
      lng: _parseDouble(json['lng'] ?? json['longitude']),
      phone: json['phone'],
      website: json['website'],
      instagram: json['instagram'],
      image: pickImageUrl([json['image_full_url'], json['image']]),
      status: json['status'] ?? 'pending',
      adminNote: json['admin_note'],
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category_id': categoryId,
    'address': address,
    'lat': lat,
    'lng': lng,
    'phone': phone,
    'website': website,
    'instagram': instagram,
    'image': image,
    'status': status,
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

class PlaceSubmissionList {
  final List<PlaceSubmission> submissions;
  final int? totalSize;

  PlaceSubmissionList({required this.submissions, this.totalSize});

  factory PlaceSubmissionList.fromJson(Map<String, dynamic> json) {
    return PlaceSubmissionList(
      submissions:
          json['data'] != null
              ? (json['data'] as List)
                  .map((item) => PlaceSubmission.fromJson(item))
                  .toList()
              : [],
      totalSize: json['total_size'] ?? json['total'],
    );
  }
}
