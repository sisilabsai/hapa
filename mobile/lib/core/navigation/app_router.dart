import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/onboarding_location_screen.dart';
import '../../features/auth/presentation/screens/onboarding_identity_screen.dart';
import '../../features/auth/presentation/screens/onboarding_interests_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../shared/models/post.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/places/presentation/screens/place_detail_screen.dart';
import '../../features/guide/presentation/screens/guide_screen.dart';
import '../../features/people/presentation/screens/people_screen.dart';
import '../../features/creator/presentation/screens/creator_profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/create_post/presentation/screens/create_post_screen.dart';
import '../../features/circles/presentation/screens/circles_screen.dart';
import '../../features/circles/presentation/screens/circle_detail_screen.dart';
import '../../features/business/presentation/screens/business_dashboard_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userAsync = ref.watch(userNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull ?? false;
      final loc = state.matchedLocation;
      final isOnboardingPath = loc.startsWith('/auth/onboarding');
      final isAuthPath = loc.startsWith('/auth') && !isOnboardingPath;

      // Not authenticated → send to login
      if (!isAuth) {
        return isAuthPath ? null : '/auth/phone';
      }

      // Authenticated + on login screen → check onboarding status
      if (isAuthPath) {
        final user = userAsync.valueOrNull;
        if (user == null) return null; // still loading — wait
        return user.needsOnboarding ? '/auth/onboarding' : '/';
      }

      // Authenticated + on main app → redirect to onboarding if incomplete
      if (!isOnboardingPath) {
        final user = userAsync.valueOrNull;
        if (user != null && user.needsOnboarding) return '/auth/onboarding';
      }

      // Authenticated + on onboarding → redirect to feed if already completed
      if (isOnboardingPath) {
        final user = userAsync.valueOrNull;
        if (user != null && !user.needsOnboarding) return '/';
      }

      return null;
    },
    routes: [
      // Auth
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            phone: extra['phone'] as String? ?? '',
            devCode: extra['devCode'] as String?,
          );
        },
      ),

      // Onboarding
      GoRoute(
        path: '/auth/onboarding',
        builder: (_, __) => const OnboardingLocationScreen(),
      ),
      GoRoute(
        path: '/auth/onboarding/identity',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OnboardingIdentityScreen(
            city: extra['city'] as String? ?? '',
            country: extra['country'] as String? ?? '',
            isLaunched: extra['is_launched'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/auth/onboarding/interests',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OnboardingInterestsScreen(
            city: extra['city'] as String? ?? '',
            country: extra['country'] as String? ?? '',
            isLaunched: extra['is_launched'] as bool? ?? false,
            userType: extra['user_type'] as String? ?? 'resident',
            name: extra['name'] as String? ?? '',
          );
        },
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/guide', builder: (_, __) => const GuideScreen()),
          GoRoute(path: '/people', builder: (_, __) => const PeopleScreen()),
          GoRoute(path: '/circles', builder: (_, __) => const CirclesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: '/posts/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreatePostScreen(
            initialLat: extra?['lat'] as double?,
            initialLng: extra?['lng'] as double?,
            feedCoords: extra?['feedCoords'] as (double, double)?,
          );
        },
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['id']!,
          initialPost: state.extra as Post?,
        ),
      ),
      GoRoute(
        path: '/places/:id',
        builder: (_, state) => PlaceDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/creators/:id',
        builder: (_, state) => CreatorProfileScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/circles/:id',
        builder: (_, state) => CircleDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/business/dashboard',
        builder: (_, __) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
    ],
  );
});
