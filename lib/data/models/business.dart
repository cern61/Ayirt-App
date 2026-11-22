/// business_cards görünümünden gelen işletme (puan ortalamasıyla birlikte)
class BusinessCard {
  final String id;
  final String name;
  final String description;
  final String? city;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final int? categoryId;
  final String? categoryName;
  final int slotMinutes;
  final int capacityPerSlot;
  final double ratingAvg;
  final int ratingCount;

  const BusinessCard({
    required this.id,
    required this.name,
    required this.description,
    this.city,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
    this.categoryId,
    this.categoryName,
    required this.slotMinutes,
    required this.capacityPerSlot,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory BusinessCard.fromMap(Map<String, dynamic> m) => BusinessCard(
        id: m['id'] as String,
        name: m['name'] as String,
        description: (m['description'] as String?) ?? '',
        city: m['city'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        logoUrl: m['logo_url'] as String?,
        categoryId: m['category_id'] as int?,
        categoryName: m['category_name'] as String?,
        slotMinutes: (m['slot_minutes'] as int?) ?? 30,
        capacityPerSlot: (m['capacity_per_slot'] as int?) ?? 1,
        ratingAvg: (m['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (m['rating_count'] as int?) ?? 0,
      );

  /// Tek kişilik mi (kuaför gibi) yoksa çok kişilik mi (restoran, ders gibi)?
  bool get isMultiCapacity => capacityPerSlot > 1;
}

class Service {
  final String id;
  final String name;
  final int durationMin;
  final double? price;
  final bool isActive;

  const Service({required this.id, required this.name, required this.durationMin, this.price, this.isActive = true});

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        id: m['id'] as String,
        name: m['name'] as String,
        durationMin: (m['duration_min'] as int?) ?? 30,
        price: (m['price'] as num?)?.toDouble(),
        isActive: (m['is_active'] as bool?) ?? true,
      );
}

class Review {
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const Review({required this.customerName, required this.rating, this.comment, required this.createdAt});

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        customerName: (m['customer_name'] as String?) ?? 'Müşteri',
        rating: (m['rating'] as num).toInt(),
        comment: m['comment'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// get_available_slots RPC'sinden dönen tek saat dilimi
class Slot {
  /// Sunucudan gelen ham değer. Rezervasyon yaparken AYNEN geri gönderilir
  /// (sunucu saatleri birebir karşılaştırdığı için dönüştürmüyoruz).
  final String startRaw;
  final DateTime start;
  final DateTime end;
  final int remaining;

  const Slot({required this.startRaw, required this.start, required this.end, required this.remaining});

  factory Slot.fromMap(Map<String, dynamic> m) => Slot(
        startRaw: m['slot_start'] as String,
        start: DateTime.parse(m['slot_start'] as String),
        end: DateTime.parse(m['slot_end'] as String),
        remaining: (m['remaining'] as num).toInt(),
      );

  bool get isFull => remaining <= 0;
}
