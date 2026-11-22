import '../../core/formatters.dart';
import '../../core/supabase_client.dart';
import '../models/booking.dart';
import '../models/business.dart';
import '../models/my_business.dart';

/// İşletme sahibinin kendi işletmesini yönettiği tüm sorgular.
/// Güvenlik: RLS sayesinde sadece KENDİ işletmesinin verisine yazabilir.
class MyBusinessRepository {
  // ---------------- İşletme bilgileri ----------------

  Future<MyBusiness> fetchMyBusiness() async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase.from('businesses').select().eq('owner_id', uid).single();
    return MyBusiness.fromMap(row);
  }

  Future<void> updateInfo(
    String businessId, {
    required String name,
    int? categoryId,
    required String description,
    String? phone,
    String? email,
    String? city,
    String? address,
  }) async {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    await supabase.from('businesses').update({
      'name': name.trim(),
      'category_id': categoryId,
      'description': description.trim(),
      'phone': clean(phone),
      'email': clean(email),
      'city': clean(city),
      'address': clean(address),
    }).eq('id', businessId);
  }

  Future<void> setLogo(String businessId, String url) async {
    await supabase.from('businesses').update({'logo_url': url}).eq('id', businessId);
  }

  // ---------------- Takvim ayarları ----------------

  Future<void> updateCalendarSettings(String businessId, {required int slotMinutes, required int capacity}) async {
    await supabase
        .from('businesses')
        .update({'slot_minutes': slotMinutes, 'capacity_per_slot': capacity}).eq('id', businessId);
  }

  Future<List<WorkingHour>> fetchWorkingHours(String businessId) async {
    final rows = await supabase
        .from('working_hours')
        .select()
        .eq('business_id', businessId)
        .order('weekday', ascending: true);
    final list = rows.map(WorkingHour.fromMap).toList();
    // Eksik gün varsa (olmamalı ama) varsayılanla tamamla
    for (var d = 1; d <= 7; d++) {
      if (!list.any((h) => h.weekday == d)) {
        list.add(WorkingHour(
          weekday: d,
          isOpen: d <= 6,
          open: parseTime('09:00'),
          close: parseTime('18:00'),
        ));
      }
    }
    list.sort((a, b) => a.weekday.compareTo(b.weekday));
    return list;
  }

  Future<void> saveWorkingHours(String businessId, List<WorkingHour> hours) async {
    await supabase
        .from('working_hours')
        .upsert(hours.map((h) => h.toMap(businessId)).toList(), onConflict: 'business_id,weekday');
  }

  Future<List<ClosedDate>> fetchClosedDates(String businessId) async {
    final rows = await supabase
        .from('closed_dates')
        .select()
        .eq('business_id', businessId)
        .gte('day', toSqlDate(todayTr()))
        .order('day', ascending: true);
    return rows.map(ClosedDate.fromMap).toList();
  }

  Future<void> addClosedDate(String businessId, DateTime day, String? reason) async {
    await supabase.from('closed_dates').upsert({
      'business_id': businessId,
      'day': toSqlDate(day),
      'reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
    }, onConflict: 'business_id,day');
  }

  Future<void> removeClosedDate(String businessId, DateTime day) async {
    await supabase.from('closed_dates').delete().eq('business_id', businessId).eq('day', toSqlDate(day));
  }

  // ---------------- Hizmetler ----------------

  Future<List<Service>> fetchAllServices(String businessId) async {
    final rows = await supabase
        .from('services')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: true);
    return rows.map(Service.fromMap).toList();
  }

  Future<void> saveService(
    String businessId, {
    String? id, // null → yeni hizmet
    required String name,
    required int durationMin,
    double? price,
    required bool isActive,
  }) async {
    final data = {
      'business_id': businessId,
      'name': name.trim(),
      'duration_min': durationMin,
      'price': price,
      'is_active': isActive,
    };
    if (id == null) {
      await supabase.from('services').insert(data);
    } else {
      await supabase.from('services').update(data).eq('id', id);
    }
  }

  Future<void> deleteService(String id) async {
    await supabase.from('services').delete().eq('id', id);
  }

  // ---------------- Rezervasyonlar ----------------

  static const _bookingSelect = '*, services(name), profiles(full_name, phone), reviews(id)';

  /// Seçilen günün (Türkiye saatiyle) tüm rezervasyonları
  Future<List<Booking>> fetchBookingsForDay(String businessId, DateTime day) async {
    // Türkiye'de gece 00:00 = UTC 21:00 (bir önceki gün)
    final startUtc = DateTime.utc(day.year, day.month, day.day).subtract(const Duration(hours: 3));
    final endUtc = startUtc.add(const Duration(days: 1));
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .eq('business_id', businessId)
        .gte('start_at', startUtc.toIso8601String())
        .lt('start_at', endUtc.toIso8601String())
        .order('start_at', ascending: true);
    return rows.map(Booking.fromMap).toList();
  }

  /// Onay bekleyen (gelecekteki) tüm rezervasyonlar
  Future<List<Booking>> fetchPending(String businessId) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .eq('business_id', businessId)
        .eq('status', 'pending')
        .gte('start_at', DateTime.now().toUtc().toIso8601String())
        .order('start_at', ascending: true);
    return rows.map(Booking.fromMap).toList();
  }

  /// Tüm geçmiş (en yeni en üstte)
  Future<List<Booking>> fetchHistory(String businessId, {int limit = 100}) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .eq('business_id', businessId)
        .order('start_at', ascending: false)
        .limit(limit);
    return rows.map(Booking.fromMap).toList();
  }

  Future<void> setStatus(String bookingId, BookingStatus status) async {
    await supabase.rpc('update_booking_status', params: {
      'p_booking': bookingId,
      'p_status': status.name,
    });
  }
}
