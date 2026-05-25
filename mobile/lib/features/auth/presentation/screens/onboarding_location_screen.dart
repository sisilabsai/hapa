import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

enum _DetectState { detecting, found, denied, error }

class OnboardingLocationScreen extends ConsumerStatefulWidget {
  const OnboardingLocationScreen({super.key});

  @override
  ConsumerState<OnboardingLocationScreen> createState() =>
      _OnboardingLocationScreenState();
}

class _OnboardingLocationScreenState
    extends ConsumerState<OnboardingLocationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  _DetectState _state = _DetectState.detecting;
  String? _cityName;
  String? _countryName;
  bool _isLaunched = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _detectCity();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectCity() async {
    setState(() => _state = _DetectState.detecting);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _state = _DetectState.denied);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final client = ref.read(apiClientProvider);
      final city = await client.get<Map<String, dynamic>>(
        '/v1/location/city',
        queryParams: {
          'lat': pos.latitude.toString(),
          'lng': pos.longitude.toString(),
        },
        fromJson: (d) => d as Map<String, dynamic>,
      );

      if (mounted) {
        setState(() {
          _state = _DetectState.found;
          _cityName = city['name'] as String?;
          _countryName = city['country'] as String?;
          _isLaunched = city['is_launched'] as bool? ?? false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _state = _DetectState.error);
    }
  }

  Future<void> _openCitySearch() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySearchSheet(client: ref.read(apiClientProvider)),
    );
    if (result != null && mounted) {
      setState(() {
        _state = _DetectState.found;
        _cityName = result['name'] as String?;
        _countryName = result['country'] as String?;
        _isLaunched = result['is_launched'] as bool? ?? false;
      });
    }
  }

  void _confirm() {
    if (_cityName == null) return;
    context.push('/auth/onboarding/identity', extra: {
      'city': _cityName!,
      'country': _countryName ?? '',
      'is_launched': _isLaunched,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140F08),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              painter: _PulsePainter(_pulseCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Image.asset(
                    'assets/branding/hapa-wordmark-horizontal.png',
                    height: 22,
                  ),
                  const Spacer(flex: 3),
                  _buildContent(),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _DetectState.detecting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINDING YOUR CITY',
              style: TextStyle(
                color: HapaColors.ochre.withValues(alpha: 0.55),
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: HapaColors.ochre.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Locating...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        );

      case _DetectState.found:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HAPA IS LIVE IN',
              style: TextStyle(
                color: HapaColors.ochre.withValues(alpha: 0.55),
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_cityName?.toUpperCase() ?? ''}.',
              style: const TextStyle(
                color: HapaColors.ochre,
                fontSize: 52,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            if (!_isLaunched) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: HapaColors.ochre.withValues(alpha: 0.12),
                child: Text(
                  'COMING SOON',
                  style: TextStyle(
                    color: HapaColors.ochre.withValues(alpha: 0.65),
                    fontSize: 9,
                    fontFamily: 'JetBrainsMono',
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(width: 36, height: 1, color: HapaColors.ochre.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              'YOU ARE HERE',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HapaColors.ochre,
                  foregroundColor: const Color(0xFF140F08),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "I'M HERE",
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: _openCitySearch,
                child: Text(
                  'Not $_cityName? Choose your city',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        );

      case _DetectState.denied:
      case _DetectState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHERE ARE YOU?',
              style: TextStyle(
                color: HapaColors.ochre.withValues(alpha: 0.55),
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _state == _DetectState.denied
                  ? 'Location access is needed to find your city.'
                  : 'Could not detect your city automatically.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openCitySearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HapaColors.ochre,
                  foregroundColor: const Color(0xFF140F08),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: const Text(
                  'CHOOSE YOUR CITY',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
            if (_state == _DetectState.error) ...[
              const SizedBox(height: 18),
              Center(
                child: GestureDetector(
                  onTap: _detectCity,
                  child: Text(
                    'Try detecting again',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }
}

// Sonar pulse rings painter
class _PulsePainter extends CustomPainter {
  final double value;

  const _PulsePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final maxRadius = size.shortestSide * 0.88;

    for (int i = 0; i < 4; i++) {
      final phase = (value + i / 4.0) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase) * 0.22;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = HapaColors.ochre.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Center dot
    canvas.drawCircle(
      center,
      5,
      Paint()..color = HapaColors.ochre.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      center,
      3,
      Paint()..color = HapaColors.ochre,
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.value != value;
}

// City search bottom sheet
class _CitySearchSheet extends StatefulWidget {
  final ApiClient client;
  const _CitySearchSheet({required this.client});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _ctrl = TextEditingController();
  List<_CityResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final data = await widget.client.get<Map<String, dynamic>>(
        '/v1/location/cities',
        queryParams: {'q': q},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      final list = data['cities'] as List? ?? [];
      if (mounted) {
        setState(() {
          _results = list.map((e) => _CityResult.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A140A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 3,
              color: Colors.grey.shade700,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: HapaColors.ochre,
                decoration: InputDecoration(
                  fillColor: const Color(0xFF2A1E10),
                  filled: true,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Search cities...',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: HapaColors.ochre, size: 20),
                  suffixIcon: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: HapaColors.ochre.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final city = _results[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, {
                      'name': city.name,
                      'country': city.country,
                      'is_launched': city.isLaunched,
                    }),
                    leading: const Icon(Icons.location_city_outlined,
                        color: HapaColors.ochre, size: 20),
                    title: Text(
                      city.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      city.country,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    trailing: city.isLaunched
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: HapaColors.ochre.withValues(alpha: 0.15),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: HapaColors.ochre,
                                fontSize: 9,
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityResult {
  final String name;
  final String country;
  final bool isLaunched;

  const _CityResult({
    required this.name,
    required this.country,
    required this.isLaunched,
  });

  factory _CityResult.fromJson(Map<String, dynamic> j) => _CityResult(
        name: j['name'] as String? ?? '',
        country: j['country'] as String? ?? '',
        isLaunched: j['is_launched'] as bool? ?? false,
      );
}
