import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/business.dart';
import '../../data/repositories/business_repository.dart';
import '../../shared/ui_parts.dart';

/// İşletme detayı: bilgiler, hizmetler, yorumlar + "Rezervasyon yap" butonu
class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  final _repo = BusinessRepository();

  BusinessCard? _business;
  List<Service> _services = [];
  List<Review> _reviews = [];
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
      // Üç sorguyu aynı anda gönder
      final results = await Future.wait([
        _repo.fetchBusiness(widget.businessId),
        _repo.fetchServices(widget.businessId),
        _repo.fetchReviews(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _business = results[0] as BusinessCard?;
        _services = results[1] as List<Service>;
        _reviews = results[2] as List<Review>;
        if (_business == null) _error = 'İşletme bulunamadı ya da şu an hizmet vermiyor.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _business;

    return Scaffold(
      appBar: AppBar(title: Text(b?.name ?? 'İşletme')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    message: _error!,
                    action: OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _Header(business: b!),
                      if (b.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(b.description, style: const TextStyle(height: 1.4)),
                      ],
                      const SizedBox(height: 16),
                      _ContactCard(business: b),
                      const SizedBox(height: 24),
                      _SectionTitle('Hizmetler'),
                      if (_services.isEmpty)
                        const Text('İşletme henüz hizmet eklemedi.', style: TextStyle(color: Colors.grey))
                      else
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(children: [
                            for (final s in _services)
                              ListTile(
                                title: Text(s.name),
                                subtitle: Text('${s.durationMin} dk'),
                                trailing: Text(fmtPrice(s.price),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                          ]),
                        ),
                      const SizedBox(height: 24),
                      _SectionTitle('Yorumlar (${b.ratingCount})'),
                      if (_reviews.isEmpty)
                        const Text('Henüz yorum yok. İlk yorumu sen yap!', style: TextStyle(color: Colors.grey))
                      else
                        for (final r in _reviews) _ReviewTile(review: r),
                    ],
                  ),
                ),
      bottomNavigationBar: b == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/customer/business/${b.id}/book'),
                    icon: const Icon(Icons.event_available),
                    label: const Text('Rezervasyon yap'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.business});
  final BusinessCard business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Row(children: [
      BusinessAvatar(name: b.name, logoUrl: b.logoUrl, size: 76),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (b.categoryName != null) Text(b.categoryName!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          RatingBadge(avg: b.ratingAvg, count: b.ratingCount),
        ]),
      ),
    ]);
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.business});
  final BusinessCard business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final address = [b.address, b.city].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final rows = <Widget>[
      if (address.isNotEmpty) _row(Icons.location_on_outlined, address),
      if (b.phone != null && b.phone!.isNotEmpty) _row(Icons.phone_outlined, b.phone!),
      if (b.email != null && b.email!.isNotEmpty) _row(Icons.mail_outline, b.email!),
      _row(Icons.schedule, b.isMultiCapacity
          ? '${b.slotMinutes} dk\'lık seanslar · seans başına ${b.capacityPerSlot} kişi'
          : '${b.slotMinutes} dk\'lık randevular'),
    ];
    return Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(8), child: Column(children: rows)));
  }

  Widget _row(IconData icon, String text) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(text),
        visualDensity: VisualDensity.compact,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            for (var i = 1; i <= 5; i++)
              Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: Colors.amber),
          ]),
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.comment!),
          ],
          const SizedBox(height: 4),
          Text(fmtDateTime(r.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]),
      ),
    );
  }
}
