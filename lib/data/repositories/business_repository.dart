import '../../core/formatters.dart';
import '../../core/supabase_client.dart';
import '../models/business.dart';
import '../models/category.dart';

/// Müşterinin işletmeleri bulup incelemesi için tüm sorgular
class BusinessRepository {
  Future<List<BusinessCategory>> fetchCategories() async {
    final rows = await supabase.from('categories').select().order('sort_order', ascending: true);
    return rows.map(BusinessCategory.fromMap).toList();
  }

  /// Arama metni ve/veya kategoriye göre işletmeler.
  /// İkisi de boşsa "popüler" liste döner (en çok yorum + en yüksek puan).
  Future<List<BusinessCard>> searchBusinesses({String query = '', int? categoryId, int limit = 30}) async {
    var q = supabase.from('business_cards').select().eq('is_active', true);

    final text = _sanitize(query);
    if (text.isNotEmpty) {
      // Ad, açıklama veya şehirde geçiyorsa bul (büyük/küçük harf duyarsız)
      // PostgREST "or" içinde joker karakter olarak * kullanılır (% yerine)
      q = q.or('name.ilike.*$text*,description.ilike.*$text*,city.ilike.*$text*');
    }
    if (categoryId != null) {
      q = q.eq('category_id', categoryId);
    }

    final rows = await q
        .order('rating_count', ascending: false)
        .order('rating_avg', ascending: false)
        .limit(limit);
    return rows.map(BusinessCard.fromMap).toList();
  }

  Future<BusinessCard?> fetchBusiness(String id) async {
    final row = await supabase.from('business_cards').select().eq('id', id).maybeSingle();
    return row == null ? null : BusinessCard.fromMap(row);
  }

  Future<List<Service>> fetchServices(String businessId) async {
    final rows = await supabase
        .from('services')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name', ascending: true);
    return rows.map(Service.fromMap).toList();
  }

  Future<List<Review>> fetchReviews(String businessId, {int limit = 20}) async {
    final rows = await supabase
        .from('reviews')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Review.fromMap).toList();
  }

  /// Seçilen günün müsait saatleri (veritabanı hesaplar)
  Future<List<Slot>> fetchSlots(String businessId, DateTime day) async {
    final rows = await supabase.rpc('get_available_slots', params: {
      'p_business': businessId,
      'p_day': toSqlDate(day),
    });
    return (rows as List).map((r) => Slot.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Rezervasyon oluştur. Çakışma/kapasite kontrolü veritabanında yapılır;
  /// sorun varsa Türkçe hata mesajıyla PostgrestException fırlatır.
  Future<void> createBooking({
    required String businessId,
    required Slot slot,
    String? serviceId,
    int partySize = 1,
    String? note,
  }) async {
    await supabase.rpc('create_booking', params: {
      'p_business': businessId,
      'p_start': slot.startRaw,
      'p_service': serviceId,
      'p_party_size': partySize,
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  /// PostgREST'in "or" sözdizimini bozacak karakterleri temizle
  String _sanitize(String s) => s.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
}
