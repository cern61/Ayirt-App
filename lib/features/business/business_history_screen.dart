import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/my_business_repository.dart';
import '../../shared/ui_parts.dart';
import 'business_bookings_screen.dart';

/// İşletmenin önceki rezervasyon geçmişi (son 100 kayıt, en yeni en üstte)
class BusinessHistoryScreen extends StatefulWidget {
  const BusinessHistoryScreen({super.key});

  @override
  State<BusinessHistoryScreen> createState() => _BusinessHistoryScreenState();
}

class _BusinessHistoryScreenState extends State<BusinessHistoryScreen> {
  final _repo = MyBusinessRepository();
  List<Booking> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final business = await _repo.fetchMyBusiness();
      final list = await _repo.fetchHistory(business.id);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Küçük özet
    int count(BookingStatus s) => _items.where((b) => b.status == s).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon geçmişi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: EmptyState(icon: Icons.error_outline, message: _error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Chip(label: Text('Toplam: ${_items.length}')),
                        Chip(label: Text('Tamamlanan: ${count(BookingStatus.completed)}')),
                        Chip(label: Text('İptal: ${count(BookingStatus.cancelled)}')),
                      ]),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const EmptyState(icon: Icons.history, message: 'Henüz rezervasyon yok.')
                      else
                        for (final b in _items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: BusinessBookingCard(booking: b, showDate: true),
                          ),
                    ],
                  ),
                ),
    );
  }
}
