import '../../core/supabase_client.dart';
import '../models/booking.dart';

class BookingRepository {
  /// Birlikte getirilecek ilişkili tablolar (PostgREST "embed")
  static const _select =
      '*, businesses(name, logo_url), services(name), reviews(id), profiles(full_name, phone)';

  /// Giriş yapan müşterinin rezervasyonları (en yeni en üstte)
  Future<List<Booking>> fetchMyBookings() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('bookings')
        .select(_select)
        .eq('customer_id', uid)
        .order('start_at', ascending: false);
    return rows.map(Booking.fromMap).toList();
  }

  Future<void> cancel(String bookingId) async {
    await supabase.rpc('update_booking_status', params: {
      'p_booking': bookingId,
      'p_status': 'cancelled',
    });
  }

  Future<void> addReview({
    required Booking booking,
    required int rating,
    String? comment,
  }) async {
    await supabase.from('reviews').insert({
      'booking_id': booking.id,
      'business_id': booking.businessId,
      'customer_id': supabase.auth.currentUser!.id,
      'rating': rating,
      'comment': (comment == null || comment.trim().isEmpty) ? null : comment.trim(),
    });
  }
}
