import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    _Tab(path: '/', icon: Icons.location_on_outlined, activeIcon: Icons.location_on, label: 'Now'),
    _Tab(path: '/map', icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _Tab(path: '/guide', icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories, label: 'Guide'),
    _Tab(path: '/people', icon: Icons.people_outline, activeIcon: Icons.people, label: 'People'),
    _Tab(path: '/circles', icon: Icons.hub_outlined, activeIcon: Icons.hub, label: 'Circles'),
    _Tab(path: '/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (loc == _tabs[i].path ||
          (loc.startsWith(_tabs[i].path) && _tabs[i].path != '/')) {
        return i;
      }
      if (_tabs[i].path == '/' && loc == '/') return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexFor(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0EBE0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_tabs[i].path),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: HapaColors.ochre,
          unselectedItemColor: const Color(0xFF9E9590),
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          elevation: 0,
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon, size: 22),
                    activeIcon: Icon(t.activeIcon, size: 22, color: HapaColors.ochre),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({required this.path, required this.icon, required this.activeIcon, required this.label});
}
