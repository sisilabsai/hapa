import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _categoryFilterProvider = StateProvider<String?>((ref) => null);

final _placesProvider = FutureProvider<List<Business>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  final category = ref.watch(_categoryFilterProvider);

  Position? pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  } catch (_) {}

  return ref.watch(apiClientProvider).get(
    '/v1/businesses/search',
    queryParams: {
      if (query.isNotEmpty) 'q': query,
      if (category != null) 'category': category,
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
      'radius': 5000,
      'limit': 20,
    },
    fromJson: (d) => (d['businesses'] as List).map((b) => Business.fromJson(b as Map<String, dynamic>)).toList(),
  );
});

const _categories = ['restaurant', 'cafe', 'bar', 'hotel', 'shop', 'salon', 'gym', 'clinic'];

class PlacesSearchScreen extends ConsumerStatefulWidget {
  const PlacesSearchScreen({super.key});

  @override
  ConsumerState<PlacesSearchScreen> createState() => _PlacesSearchScreenState();
}

class _PlacesSearchScreenState extends ConsumerState<PlacesSearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(_placesProvider);
    final selected = ref.watch(_categoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Search places near you…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                ref.read(_searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _CategoryChip(
                    label: 'All',
                    selected: selected == null,
                    onTap: () => ref.read(_categoryFilterProvider.notifier).state = null,
                  );
                }
                final cat = _categories[i - 1];
                return _CategoryChip(
                  label: cat[0].toUpperCase() + cat.substring(1),
                  selected: selected == cat,
                  onTap: () => ref.read(_categoryFilterProvider.notifier).state = cat,
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: HapaColors.ochre)),
              error: (_, __) => const Center(child: Text('Search failed')),
              data: (places) => places.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Text('No places found', style: TextStyle(color: Colors.grey.shade400)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _PlaceRow(business: places[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? HapaColors.ochre : Colors.white,
          border: Border.all(color: selected ? HapaColors.ochre : Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final Business business;
  const _PlaceRow({required this.business});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/places/${business.id}'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            business.logoUrl != null
                ? Image.network(business.logoUrl!, width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _PlaceholderLogo(name: business.name))
                : _PlaceholderLogo(name: business.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(business.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      if (business.avgRating != null)
                        Row(children: [
                          const Icon(Icons.star, size: 12, color: HapaColors.ochre),
                          const SizedBox(width: 2),
                          Text('${business.avgRating!.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${business.category[0].toUpperCase()}${business.category.substring(1)} · ${business.priceLabel}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (business.distanceMeters != null)
                    Text(
                      business.distanceMeters! < 1000
                          ? '${business.distanceMeters!.toInt()}m away'
                          : '${(business.distanceMeters! / 1000).toStringAsFixed(1)}km away',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderLogo extends StatelessWidget {
  final String name;
  const _PlaceholderLogo({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: HapaColors.ochre.withOpacity(0.1),
      alignment: Alignment.center,
      child: Text(name[0], style: const TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w900, color: HapaColors.ochre, fontSize: 20)),
    );
  }
}
