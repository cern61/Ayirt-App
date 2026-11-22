import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session_controller.dart';
import '../../data/models/business.dart';
import '../../data/models/category.dart';
import '../../data/repositories/business_repository.dart';
import '../../shared/ui_parts.dart';

/// 1.1 İşletme arama ekranı:
///   en üstte arama çubuğu → altında kategoriler → altında popüler işletmeler
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _repo = BusinessRepository();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<BusinessCategory> _categories = [];
  List<BusinessCard> _businesses = [];
  int? _selectedCategoryId;
  bool _loading = true;
  String? _error;

  bool get _isFiltering => _searchCtrl.text.trim().isNotEmpty || _selectedCategoryId != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.fetchCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {/* kategoriler gelmezse ekran yine çalışsın */}
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.searchBusinesses(query: _searchCtrl.text, categoryId: _selectedCategoryId);
      if (mounted) setState(() => _businesses = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Her tuşta değil, yazmayı bırakınca (350 ms) ara
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadBusinesses);
    setState(() {}); // temizle (x) butonunu göstermek için
  }

  void _selectCategory(int? id) {
    setState(() => _selectedCategoryId = _selectedCategoryId == id ? null : id);
    _loadBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadBusinesses,
      child: CustomScrollView(
        slivers: [
          // ---- Arama çubuğu ----
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'İşletme, hizmet veya şehir ara…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),

          // ---- Kategoriler ----
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categories.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final c = _categories[i];
                    return _CategoryTile(
                      category: c,
                      selected: c.id == _selectedCategoryId,
                      onTap: () => _selectCategory(c.id),
                    );
                  },
                ),
              ),
            ),

          // ---- Başlık ----
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                _isFiltering ? 'Sonuçlar' : 'Popüler işletmeler',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ---- Liste ----
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.wifi_off,
                message: _error!,
                action: OutlinedButton(onPressed: _loadBusinesses, child: const Text('Tekrar dene')),
              ),
            )
          else if (_businesses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.storefront_outlined,
                message: _isFiltering ? 'Aramana uygun işletme bulunamadı.' : 'Henüz kayıtlı işletme yok.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: _businesses.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _BusinessTile(
                  business: _businesses[i],
                  onTap: () => context.push('/customer/business/${_businesses[i].id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});
  final BusinessCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 84,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : Colors.grey.shade200),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(category.iconData, color: selected ? Colors.white : scheme.primary),
          const SizedBox(height: 6),
          Text(
            category.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.1, color: selected ? Colors.white : Colors.black87),
          ),
        ]),
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({required this.business, required this.onTap});
  final BusinessCard business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final subtitle = [b.categoryName, b.city].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            BusinessAvatar(name: b.name, logoUrl: b.logoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                RatingBadge(avg: b.ratingAvg, count: b.ratingCount),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}
