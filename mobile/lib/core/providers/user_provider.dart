import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'auth_provider.dart';

String? _nonEmpty(dynamic v) {
  final s = v as String?;
  return (s == null || s.isEmpty) ? null : s;
}

class CurrentUser {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String userType;
  final String tier;
  final String? currentCity;
  final String? homeCity;
  final String language;
  final List<String> interestTags;
  final int trustScore;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final bool needsOnboarding;

  const CurrentUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    required this.userType,
    required this.tier,
    this.currentCity,
    this.homeCity,
    this.language = 'en',
    this.interestTags = const [],
    this.trustScore = 0,
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.needsOnboarding = false,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> j) {
    final dn = j['display_name'] as String? ?? '';
    return CurrentUser(
        id: j['id'] as String? ?? '',
        displayName: dn.isEmpty ? 'Hapa User' : dn,
        needsOnboarding: dn.isEmpty,
        username: _nonEmpty(j['username']),
        avatarUrl: _nonEmpty(j['avatar_url']),
        bio: _nonEmpty(j['bio']),
        userType: j['user_type'] as String? ?? 'resident',
        tier: j['tier'] as String? ?? 'member',
        currentCity: _nonEmpty(j['current_city']),
        homeCity: _nonEmpty(j['home_city']),
        language: j['language'] as String? ?? 'en',
        interestTags: (j['interest_tags'] as List?)?.cast<String>() ?? [],
        trustScore: j['trust_score'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        followerCount: j['follower_count'] as int? ?? 0,
        followingCount: j['following_count'] as int? ?? 0,
      );
  }

  CurrentUser copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? userType,
    String? homeCity,
    String? language,
    List<String>? interestTags,
  }) =>
      CurrentUser(
        id: id,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        userType: userType ?? this.userType,
        tier: tier,
        currentCity: currentCity,
        homeCity: homeCity ?? this.homeCity,
        language: language ?? this.language,
        interestTags: interestTags ?? this.interestTags,
        trustScore: trustScore,
        isVerified: isVerified,
        followerCount: followerCount,
        followingCount: followingCount,
      );
}

class UserNotifier extends StateNotifier<AsyncValue<CurrentUser>> {
  final ApiClient _client;

  UserNotifier(this._client) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final data = await _client.get<CurrentUser>(
        '/v1/users/me',
        fromJson: (d) => CurrentUser.fromJson(d as Map<String, dynamic>),
      );
      if (mounted) state = AsyncValue.data(data);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? userType,
    String? homeCity,
    String? language,
    List<String>? interestTags,
    String? avatarUrl,
  }) async {
    final current = state.value;
    if (current == null) return false;
    try {
      await _client.put(
        '/v1/users/me',
        body: {
          'display_name': displayName ?? current.displayName,
          'bio': bio ?? current.bio ?? '',
          'user_type': userType ?? current.userType,
          'home_city': homeCity ?? current.homeCity ?? '',
          'language': language ?? current.language,
          'interest_tags': interestTags ?? current.interestTags,
          'avatar_url': avatarUrl ?? '',
        },
        fromJson: (_) => null,
      );
      if (mounted) {
        state = AsyncValue.data(current.copyWith(
          displayName: displayName,
          bio: bio,
          userType: userType,
          homeCity: homeCity,
          language: language,
          interestTags: interestTags,
          avatarUrl: avatarUrl,
        ));
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<CurrentUser>>(
  (ref) => UserNotifier(ref.watch(apiClientProvider)),
);

final currentUserProvider = Provider<CurrentUser?>((ref) {
  return ref.watch(userNotifierProvider).valueOrNull;
});
