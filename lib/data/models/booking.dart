enum BookingStatus {
  pending,
  confirmed,
  cancelled,
  completed;

  static BookingStatus fromString(String? s) =>
      BookingStatus.values.firstWhere((v) => v.name == s, orElse: () => BookingStatus.pending);

  String get label => switch (this) {
        BookingStatus.pending => 'Onay bekliyor',
        BookingStatus.confirmed => 'Onaylandı',
        BookingStatus.cancelled => 'İptal edildi',
        BookingStatus.completed => 'Tamamlandı',
      };
}

class Booking {
  final String id;
  final String businessId;
  final String businessName;
  final String? businessLogo;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? serviceName;
  final DateTime start;
  final DateTime end;
  final int partySize;
  final BookingStatus status;
  final String? note;
  final bool hasReview;

  const Booking({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.businessLogo,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.serviceName,
    required this.start,
    required this.end,
    required this.partySize,
    required this.status,
    this.note,
    required this.hasReview,
  });

  /// Sorgu: bookings + businesses(name, logo_url) + services(name) + reviews(id) + profiles(...)
  factory Booking.fromMap(Map<String, dynamic> m) {
    final business = m['businesses'] as Map<String, dynamic>?;
    final service = m['services'] as Map<String, dynamic>?;
    final customer = m['profiles'] as Map<String, dynamic>?;
    // reviews tek kayıt (booking_id unique) → PostgREST nesne ya da liste döndürebilir
    final reviews = m['reviews'];
    final hasReview = reviews is List ? reviews.isNotEmpty : reviews != null;

    return Booking(
      id: m['id'] as String,
      businessId: m['business_id'] as String,
      businessName: (business?['name'] as String?) ?? 'İşletme',
      businessLogo: business?['logo_url'] as String?,
      customerId: m['customer_id'] as String,
      customerName: customer?['full_name'] as String?,
      customerPhone: customer?['phone'] as String?,
      serviceName: service?['name'] as String?,
      start: DateTime.parse(m['start_at'] as String),
      end: DateTime.parse(m['end_at'] as String),
      partySize: (m['party_size'] as int?) ?? 1,
      status: BookingStatus.fromString(m['status'] as String?),
      note: m['note'] as String?,
      hasReview: hasReview,
    );
  }

  bool get isUpcoming => end.isAfter(DateTime.now());
  bool get canCancel =>
      (status == BookingStatus.pending || status == BookingStatus.confirmed) && start.isAfter(DateTime.now());
  bool get canReview => status == BookingStatus.completed && !hasReview;
}
