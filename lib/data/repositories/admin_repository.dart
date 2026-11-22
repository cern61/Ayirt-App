import '../../core/supabase_client.dart';
import '../models/booking.dart';
import '../models/category.dart';
import '../models/my_business.dart';
import '../models/profile.dart';

/// Dashboard sayıları (admin_stats RPC)
class AdminStats {
  final int customers;
  final int businesses;
  final int activeBusinesses;
  final int bookingsTotal;
  final int bookingsToday;
  final int bookingsPending;

  const AdminStats({
    required this.customers,
    required this.businesses,
    required this.activeBusinesses,
    required this.bookingsTotal,
    required this.bookingsToday,
    required this.bookingsPending,
  });

  factory AdminStats.fromMap(Map<String, dynamic> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return AdminStats(
      customers: n('customers'),
      businesses: n('businesses'),
      activeBusinesses: n('active_businesses'),
      bookingsTotal: n('bookings_total'),
      bookingsToday: n('bookings_today'),
      bookingsPending: n('bookings_pending'),
    );
  }
}

/// Admin listesindeki işletme: işletme + sahibi + kategori adı
class AdminBusiness {
  final MyBusiness business;
  final String? ownerName;
  final String? ownerEmail;
  final String? categoryName;

  const AdminBusiness({required this.business, this.ownerName, this.ownerEmail, this.categoryName});

  factory AdminBusiness.fromMap(Map<String, dynamic> m) {
    final owner = m['profiles'] as Map<String, dynamic>?;
    final cat = m['categories'] as Map<String, dynamic>?;
    return AdminBusiness(
      business: MyBusiness.fromMap(m),
      ownerName: owner?['full_name'] as String?,
      ownerEmail: owner?['email'] as String?,
      categoryName: cat?['name'] as String?,
    );
  }
}

/// Admin işlemleri. Güvenlik veritabanında: is_admin() olmayan biri bu
/// sorguları çalıştırsa bile sadece kendi verisini görür / hiçbir şey değiştiremez.
class AdminRepository {
  static const _bookingSelect =
      '*, businesses(name, logo_url), services(name), reviews(id), profiles(full_name, phone)';

  String _sanitize(String s) => s.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  // ---------------- Dashboard ----------------

  Future<AdminStats> fetchStats() async {
    final res = await supabase.rpc('admin_stats');
    return AdminStats.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<List<Booking>> fetchRecentBookings({int limit = 10}) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Booking.fromMap).toList();
  }

  // ---------------- Müşteriler ----------------

  Future<List<Profile>> fetchCustomers({String query = ''}) async {
    var q = supabase.from('profiles').select().eq('role', 'customer');
    final t = _sanitize(query);
    if (t.isNotEmpty) q = q.or('full_name.ilike.*$t*,email.ilike.*$t*,phone.ilike.*$t*');
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map(Profile.fromMap).toList();
  }

  Future<void> updateCustomer(String id, {required String fullName, String? phone}) async {
    await supabase.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    }).eq('id', id);
  }

  Future<List<Booking>> fetchCustomerBookings(String customerId) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .eq('customer_id', customerId)
        .order('start_at', ascending: false)
        .limit(50);
    return rows.map(Booking.fromMap).toList();
  }

  // ---------------- İşletmeler ----------------

  /// [active]: null → hepsi, true → aktifler, false → askıdakiler
  Future<List<AdminBusiness>> fetchBusinesses({String query = '', bool? active}) async {
    var q = supabase.from('businesses').select('*, profiles(full_name, email), categories(name)');
    final t = _sanitize(query);
    if (t.isNotEmpty) q = q.or('name.ilike.*$t*,city.ilike.*$t*,email.ilike.*$t*');
    if (active != null) q = q.eq('is_active', active);
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map(AdminBusiness.fromMap).toList();
  }

  Future<void> setBusinessActive(String id, bool active) async {
    await supabase.from('businesses').update({'is_active': active}).eq('id', id);
  }

  Future<void> updateBusiness(
    String id, {
    required String name,
    int? categoryId,
    String? city,
    String? phone,
  }) async {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    await supabase.from('businesses').update({
      'name': name.trim(),
      'category_id': categoryId,
      'city': clean(city),
      'phone': clean(phone),
    }).eq('id', id);
  }

  Future<List<Booking>> fetchBusinessBookings(String businessId) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingSelect)
        .eq('business_id', businessId)
        .order('start_at', ascending: false)
        .limit(50);
    return rows.map(Booking.fromMap).toList();
  }

  // ---------------- Kategoriler ----------------

  Future<List<BusinessCategory>> fetchCategories() async {
    final rows = await supabase.from('categories').select().order('sort_order', ascending: true);
    return rows.map(BusinessCategory.fromMap).toList();
  }

  Future<void> saveCategory({int? id, required String name, required String icon, required int sortOrder}) async {
    final data = {'name': name.trim(), 'icon': icon, 'sort_order': sortOrder};
    if (id == null) {
      await supabase.from('categories').insert(data);
    } else {
      await supabase.from('categories').update(data).eq('id', id);
    }
  }

  /// Silinen kategorideki işletmelerin kategorisi boş kalır (işletmeler silinmez)
  Future<void> deleteCategory(int id) async {
    await supabase.from('categories').delete().eq('id', id);
  }
}
