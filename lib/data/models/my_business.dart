import 'package:flutter/material.dart';

/// İşletme sahibinin kendi işletmesi (businesses tablosundaki satırın tamamı)
class MyBusiness {
  final String id;
  final String name;
  final int? categoryId;
  final String description;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? logoUrl;
  final int slotMinutes;
  final int capacityPerSlot;
  final bool isActive;

  const MyBusiness({
    required this.id,
    required this.name,
    this.categoryId,
    required this.description,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.logoUrl,
    required this.slotMinutes,
    required this.capacityPerSlot,
    required this.isActive,
  });

  factory MyBusiness.fromMap(Map<String, dynamic> m) => MyBusiness(
        id: m['id'] as String,
        name: m['name'] as String,
        categoryId: m['category_id'] as int?,
        description: (m['description'] as String?) ?? '',
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        city: m['city'] as String?,
        logoUrl: m['logo_url'] as String?,
        slotMinutes: (m['slot_minutes'] as int?) ?? 30,
        capacityPerSlot: (m['capacity_per_slot'] as int?) ?? 1,
        isActive: (m['is_active'] as bool?) ?? true,
      );
}

/// Haftanın bir gününün çalışma saati. weekday: 1 = Pazartesi … 7 = Pazar
class WorkingHour {
  final int weekday;
  bool isOpen;
  TimeOfDay open;
  TimeOfDay close;

  WorkingHour({required this.weekday, required this.isOpen, required this.open, required this.close});

  factory WorkingHour.fromMap(Map<String, dynamic> m) => WorkingHour(
        weekday: (m['weekday'] as num).toInt(),
        isOpen: (m['is_open'] as bool?) ?? true,
        open: parseTime(m['open_time'] as String? ?? '09:00'),
        close: parseTime(m['close_time'] as String? ?? '18:00'),
      );

  Map<String, dynamic> toMap(String businessId) => {
        'business_id': businessId,
        'weekday': weekday,
        'is_open': isOpen,
        'open_time': formatTime(open),
        'close_time': formatTime(close),
      };

  static const dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  String get dayName => dayNames[weekday - 1];

  int get _openMin => open.hour * 60 + open.minute;
  int get _closeMin => close.hour * 60 + close.minute;
  bool get isValid => !isOpen || _closeMin > _openMin;
}

/// "09:00:00" → TimeOfDay(9, 0)
TimeOfDay parseTime(String s) {
  final parts = s.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// TimeOfDay(9, 0) → "09:00"
String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class ClosedDate {
  final DateTime day;
  final String? reason;

  const ClosedDate({required this.day, this.reason});

  factory ClosedDate.fromMap(Map<String, dynamic> m) =>
      ClosedDate(day: DateTime.parse(m['day'] as String), reason: m['reason'] as String?);
}
