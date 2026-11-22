import 'package:flutter/material.dart';

class BusinessCategory {
  final int id;
  final String name;
  final String icon;
  final int sortOrder;

  const BusinessCategory({required this.id, required this.name, required this.icon, this.sortOrder = 0});

  factory BusinessCategory.fromMap(Map<String, dynamic> map) => BusinessCategory(
        id: map['id'] as int,
        name: map['name'] as String,
        icon: (map['icon'] as String?) ?? 'store',
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  IconData get iconData => iconFor(icon);

  /// Admin panelinde seçilebilen ikonlar (veritabanında adı saklanır)
  static const iconOptions = <String, IconData>{
    'content_cut': Icons.content_cut,
    'spa': Icons.spa,
    'medical_services': Icons.medical_services,
    'fitness_center': Icons.fitness_center,
    'restaurant': Icons.restaurant,
    'sports_soccer': Icons.sports_soccer,
    'school': Icons.school,
    'pets': Icons.pets,
    'local_car_wash': Icons.local_car_wash,
    'photo_camera': Icons.photo_camera,
    'celebration': Icons.celebration,
    'music_note': Icons.music_note,
    'self_improvement': Icons.self_improvement,
    'build': Icons.build,
    'store': Icons.storefront,
  };

  static IconData iconFor(String name) => iconOptions[name] ?? Icons.storefront;
}
