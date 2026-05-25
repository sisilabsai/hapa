import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _MapPlace {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double? rating;
  final String? address;
  final String? coverUrl;
  final double distanceM;

  const _MapPlace({
    required this.id, required this.name, required this.category,
    required this.lat, required this.lng, this.rating,
    this.address, this.coverUrl, required this.distanceM,
  });

  factory _MapPlace.fromJson(Map<String, dynamic> j) => _MapPlace(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    category: j['category'] as String? ?? 'general',
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    rating: (j['rating_avg'] as num?)?.toDouble(),
    address: j['address'] as String?,
    coverUrl: j['cover_url'] as String?,
    distanceM: (j['distance_m'] as num?)?.toDouble() ?? 0,
  );
}

class _MapPost {
  final String id;
  final String postType;
  final String body;
  final double lat;
  final double lng;
  final String? authorName;
  final String? authorAvatar;
  final int likeCount;

  const _MapPost({
    required this.id, required this.postType, required this.body,
    required this.lat, required this.lng, this.authorName,
    this.authorAvatar, required this.likeCount,
  });

  factory _MapPost.fromJson(Map<String, dynamic> j) => _MapPost(
    id: j['id'] as String,
    postType: j['post_type'] as String? ?? 'local_tip',
    body: j['body'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    authorName: j['user_display_name'] as String?,
    authorAvatar: j['user_avatar_url'] as String?,
    likeCount: j['like_count'] as int? ?? 0,
  );
}

sealed class _Preview {}
class _PlacePreview extends _Preview { final _MapPlace place; _PlacePreview(this.place); }
class _PostPreview extends _Preview { final _MapPost post; _PostPreview(this.post); }

// ── Providers ─────────────────────────────────────────────────────────────────

typedef _Coords = ({double lat, double lng});

final _locationProvider = FutureProvider<Position?>((ref) async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  } catch (_) {
    return null;
  }
});

final _placesProvider = FutureProvider.family<List<_MapPlace>, _Coords>((ref, coords) async {
  final client = ref.watch(apiClientProvider);
  return client.get(
    '/v1/places',
    queryParams: {'lat': coords.lat, 'lng': coords.lng, 'radius': 3000},
    fromJson: (d) => (d['places'] as List? ?? [])
        .map((p) => _MapPlace.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
});

final _postsProvider = FutureProvider.family<List<_MapPost>, _Coords>((ref, coords) async {
  final client = ref.watch(apiClientProvider);
  return client.get(
    '/v1/feed',
    queryParams: {'lat': coords.lat, 'lng': coords.lng, 'radius': 4000, 'limit': 80},
    fromJson: (d) => (d['items'] as List? ?? [])
        .map((p) => _MapPost.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
});

// ── Category meta ─────────────────────────────────────────────────────────────

const _placeColors = {
  'restaurant': HapaColors.ochre,
  'cafe':       Color(0xFFB45309),
  'bar':        Color(0xFF7C3AED),
  'nightclub':  Color(0xFF8B5CF6),
  'hotel':      Color(0xFF0891B2),
  'market':     Color(0xFF16A34A),
  'salon':      Color(0xFFDB2777),
  'gym':        Color(0xFFDC2626),
};

Color _placeColor(String cat) => _placeColors[cat] ?? HapaColors.ochre;

const _postTypeColors = {
  'local_tip':  HapaColors.ochre,
  'flash':      Color(0xFFEF4444),
  'review':     Color(0xFF10B981),
  'question':   Color(0xFF6366F1),
};
Color _postColor(String type) => _postTypeColors[type] ?? HapaColors.ochre;

const _postTypeIcons = {
  'local_tip': Icons.lightbulb_outline,
  'flash':     Icons.bolt,
  'review':    Icons.star_outline,
  'question':  Icons.help_outline,
};
IconData _postIcon(String type) => _postTypeIcons[type] ?? Icons.article_outlined;

// ── Screen ────────────────────────────────────────────────────────────────────

enum _MapFilter { all, places, posts }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapCtrl = MapController();
  _Coords? _searchCoords;
  _Preview? _selected;
  _MapFilter _filter = _MapFilter.all;
  bool _showSearchArea = false;
  LatLng? _userLatLng;

  _Coords? get _coords => _searchCoords;

  void _onMapEvent(MapEvent e) {
    if (e is MapEventMove && _userLatLng != null) {
      final dist = const Distance().distance(_userLatLng!, e.camera.center);
      setState(() => _showSearchArea = dist > 800);
    }
  }

  void _searchThisArea() {
    final center = _mapCtrl.camera.center;
    setState(() {
      _searchCoords = (lat: center.latitude, lng: center.longitude);
      _showSearchArea = false;
      _selected = null;
    });
  }

  void _recenter() {
    if (_userLatLng != null) {
      _mapCtrl.move(_userLatLng!, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locAsync = ref.watch(_locationProvider);

    return locAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: HapaColors.ochre)),
      ),
      error: (_, __) => _LocationError(),
      data: (pos) {
        final center = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : const LatLng(0.3476, 32.5825);

        if (pos != null && _userLatLng == null) {
          _userLatLng = center;
          _searchCoords ??= (lat: center.latitude, lng: center.longitude);
        }

        final coords = _coords;

        final placesAsync = coords != null ? ref.watch(_placesProvider(coords)) : null;
        final postsAsync = coords != null ? ref.watch(_postsProvider(coords)) : null;

        final places = placesAsync?.valueOrNull ?? [];
        final posts = postsAsync?.valueOrNull ?? [];

        final showPlaces = _filter == _MapFilter.all || _filter == _MapFilter.places;
        final showPosts = _filter == _MapFilter.all || _filter == _MapFilter.posts;

        return Scaffold(
          body: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  onTap: (_, __) => setState(() => _selected = null),
                  onMapEvent: _onMapEvent,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.hapa.app',
                  ),

                  // Post markers
                  if (showPosts)
                    MarkerLayer(
                      markers: posts.map((p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 36, height: 36,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = _PostPreview(p)),
                          child: _PostMarker(
                            postType: p.postType,
                            isSelected: _selected is _PostPreview && (_selected as _PostPreview).post.id == p.id,
                          ),
                        ),
                      )).toList(),
                    ),

                  // Place markers
                  if (showPlaces)
                    MarkerLayer(
                      markers: places.map((pl) => Marker(
                        point: LatLng(pl.lat, pl.lng),
                        width: 42, height: 52,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = _PlacePreview(pl)),
                          child: _PlaceMarker(
                            category: pl.category,
                            isSelected: _selected is _PlacePreview && (_selected as _PlacePreview).place.id == pl.id,
                          ),
                        ),
                      )).toList(),
                    ),

                  // User location
                  if (pos != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: center,
                        width: 44, height: 44,
                        child: _UserMarker(),
                      ),
                    ]),
                ],
              ),

              // Top overlay: filter pills + search-area button
              SafeArea(
                child: Column(
                  children: [
                    // Filter bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: _MapFilter.values.map((f) {
                                  final label = f == _MapFilter.all ? 'All' : f == _MapFilter.places ? 'Places' : 'Posts';
                                  final icon = f == _MapFilter.all ? Icons.layers_outlined : f == _MapFilter.places ? Icons.storefront_outlined : Icons.article_outlined;
                                  final isActive = _filter == f;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() { _filter = f; _selected = null; }),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isActive ? HapaColors.deep : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(icon, size: 13, color: isActive ? Colors.white : Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w600,
                                                color: isActive ? Colors.white : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search this area pill
                    if (_showSearchArea)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GestureDetector(
                          onTap: _searchThisArea,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: HapaColors.deep,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Search this area', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Loading indicator
              if ((placesAsync?.isLoading ?? false) || (postsAsync?.isLoading ?? false))
                const Positioned(
                  top: 100, left: 0, right: 0,
                  child: Center(child: _LoadingPill()),
                ),

              // FABs
              Positioned(
                right: 16,
                bottom: (_selected != null ? 210 : 32),
                child: Column(
                  children: [
                    _MapFab(icon: Icons.my_location_rounded, onTap: _recenter),
                    if (coords != null) ...[
                      const SizedBox(height: 8),
                      _MapFab(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          ref.invalidate(_placesProvider(coords));
                          ref.invalidate(_postsProvider(coords));
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Preview card
              if (_selected != null)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _PreviewCard(
                    preview: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onOpen: (id, isPlace) {
                      if (isPlace) {
                        context.push('/places/$id');
                      } else {
                        context.push('/posts/$id');
                      }
                    },
                  ),
                ),

              // Count badge (bottom left)
              if (_selected == null)
                Positioned(
                  left: 16, bottom: 32,
                  child: _CountBadge(
                    places: showPlaces ? places.length : 0,
                    posts: showPosts ? posts.length : 0,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Markers ───────────────────────────────────────────────────────────────────

class _UserMarker extends StatefulWidget {
  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            ),
          ),
        ),
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  final String category;
  final bool isSelected;
  const _PlaceMarker({required this.category, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = _placeColor(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 46 : 38,
          height: isSelected ? 46 : 38,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.5 : 0.2),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(Icons.storefront, size: isSelected ? 22 : 18, color: isSelected ? Colors.white : color),
        ),
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _PostMarker extends StatelessWidget {
  final String postType;
  final bool isSelected;
  const _PostMarker({required this.postType, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = _postColor(postType);
    final icon = _postIcon(postType);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelected ? 38 : 30,
      height: isSelected ? 38 : 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isSelected ? 10 : 8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: isSelected ? 10 : 4)],
      ),
      child: Icon(icon, size: isSelected ? 20 : 16, color: Colors.white),
    );
  }
}

// ── Preview Card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final _Preview preview;
  final VoidCallback onClose;
  final void Function(String id, bool isPlace) onOpen;
  const _PreviewCard({required this.preview, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: switch (preview) {
        _PlacePreview p => _PlaceCard(place: p.place, onClose: onClose, onOpen: () => onOpen(p.place.id, true)),
        _PostPreview p => _PostCard(post: p.post, onClose: onClose, onOpen: () => onOpen(p.post.id, false)),
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final _MapPlace place;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _PlaceCard({required this.place, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _placeColor(place.category);
    final dist = place.distanceM < 1000
        ? '${place.distanceM.toInt()}m away'
        : '${(place.distanceM / 1000).toStringAsFixed(1)}km away';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(place.category.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8, fontFamily: 'JetBrainsMono')),
                ),
                const SizedBox(width: 8),
                Icon(Icons.near_me, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(dist, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 4),
              Text(place.name, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w700, color: HapaColors.deep)),
              if (place.address != null)
                Text(place.address!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (place.rating != null)
            Column(children: [
              const Icon(Icons.star_rounded, color: HapaColors.ochre, size: 18),
              Text(place.rating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          const SizedBox(width: 8),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 20, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: HapaColors.deep, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('View Place', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
          ),
        ),
      ]),
    );
  }
}

class _PostCard extends StatelessWidget {
  final _MapPost post;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _PostCard({required this.post, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _postColor(post.postType);
    final icon = _postIcon(post.postType);
    final typeLabel = post.postType.replaceAll('_', ' ').toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8, fontFamily: 'JetBrainsMono')),
              if (post.authorName != null)
                Text(post.authorName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          Row(children: [
            Icon(Icons.favorite_outline, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 3),
            Text('${post.likeCount}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(width: 8),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 20, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 10),
        Text(post.body, style: const TextStyle(fontSize: 13, color: HapaColors.deep, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Read Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
          ),
        ),
      ]),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, size: 20, color: HapaColors.deep),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  final int places;
  final int posts;
  const _CountBadge({required this.places, required this.posts});

  @override
  Widget build(BuildContext context) {
    if (places == 0 && posts == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (places > 0) ...[
          const Icon(Icons.storefront, size: 12, color: HapaColors.ochre),
          const SizedBox(width: 3),
          Text('$places', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HapaColors.deep)),
        ],
        if (places > 0 && posts > 0)
          const Text('  ·  ', style: TextStyle(fontSize: 11, color: Color(0xFFD1C5B4))),
        if (posts > 0) ...[
          const Icon(Icons.article_outlined, size: 12, color: Color(0xFF6366F1)),
          const SizedBox(width: 3),
          Text('$posts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HapaColors.deep)),
        ],
      ]),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.ochre)),
      SizedBox(width: 8),
      Text('Loading…', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _LocationError extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_off_rounded, size: 52, color: HapaColors.muted),
          const SizedBox(height: 16),
          const Text('Location unavailable', style: TextStyle(fontFamily: 'Fraunces', fontSize: 18, fontWeight: FontWeight.w700, color: HapaColors.deep)),
          const SizedBox(height: 8),
          Text('Enable location access to see what\'s near you.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}
