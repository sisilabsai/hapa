class Business {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? address;
  final String city;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? whatsapp;
  final String? website;
  final String? logoUrl;
  final String? coverUrl;
  final List<String> galleryUrls;
  final double? avgRating;
  final int reviewCount;
  final String tier;
  final int priceTier;
  final String? openingHours;
  final bool isVerified;
  final double? distanceMeters;

  const Business({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.address,
    required this.city,
    this.lat,
    this.lng,
    this.phone,
    this.whatsapp,
    this.website,
    this.logoUrl,
    this.coverUrl,
    this.galleryUrls = const [],
    this.avgRating,
    this.reviewCount = 0,
    this.tier = 'free',
    this.priceTier = 1,
    this.openingHours,
    this.isVerified = false,
    this.distanceMeters,
  });

  static String? _str(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  // Primary photo: logo_url > cover_url (so either field from the API works)
  String? get primaryPhotoUrl => _str(logoUrl) ?? _str(coverUrl);

  // All photos for the gallery: [primary] + gallery_urls
  List<String> get allPhotos {
    final primary = primaryPhotoUrl;
    final extras = galleryUrls.where((u) => u.isNotEmpty).toList();
    return [if (primary != null) primary, ...extras];
  }

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        phone: json['phone'] as String?,
        whatsapp: json['whatsapp'] as String?,
        website: json['website'] as String?,
        logoUrl: _str(json['logo_url']),
        coverUrl: _str(json['cover_url']),
        galleryUrls: (json['gallery_urls'] as List?)?.cast<String>() ?? [],
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        reviewCount: json['review_count'] as int? ?? 0,
        tier: json['tier'] as String? ?? 'free',
        priceTier: json['price_tier'] as int? ?? 1,
        openingHours: json['opening_hours'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      );

  String get priceLabel => '\$' * priceTier;
}
