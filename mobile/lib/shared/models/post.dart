class PostAuthor {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? userType;
  final int trustScore;
  final bool isVerified;

  const PostAuthor({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.userType,
    this.trustScore = 0,
    this.isVerified = false,
  });

  static String? _str(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  factory PostAuthor.fromJson(Map<String, dynamic> j) => PostAuthor(
        id: j['id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Hapa User',
        avatarUrl: _str(j['avatar_url']),
        bio: j['bio'] as String?,
        userType: j['user_type'] as String?,
        trustScore: j['trust_score'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
      );
}

class PostBusiness {
  final String id;
  final String name;
  final String? category;
  final String? coverUrl;
  final double? ratingAvg;
  final String? address;

  const PostBusiness({
    required this.id,
    required this.name,
    this.category,
    this.coverUrl,
    this.ratingAvg,
    this.address,
  });

  factory PostBusiness.fromJson(Map<String, dynamic> j) => PostBusiness(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String?,
        coverUrl: j['cover_url'] as String?,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
        address: j['address'] as String?,
      );
}

class PostViewer {
  final bool beenHere;
  final bool liked;
  final bool pulsed;
  final bool saved;
  const PostViewer({this.beenHere = false, this.liked = false, this.pulsed = false, this.saved = false});
  factory PostViewer.fromJson(Map<String, dynamic> j) => PostViewer(
        beenHere: j['been_here'] as bool? ?? false,
        liked: j['liked'] as bool? ?? false,
        pulsed: j['pulsed'] as bool? ?? false,
        saved: j['saved'] as bool? ?? false,
      );
}

class Post {
  final String id;
  final String userId;
  final String? userDisplayName;
  final String? userAvatarUrl;
  final PostAuthor? author;
  final PostBusiness? business;
  final PostViewer viewer;
  final String postType;
  final String? title;
  final String? body;
  final String? mediaUrl;
  final List<String> mediaUrls;
  final double? lat;
  final double? lng;
  final String? city;
  final String? neighbourhood;
  final List<String> interestTags;
  final int beenHereCount;
  final int likeCount;
  final int commentCount;
  final int pulseCount;
  final double distanceM;
  final DateTime createdAt;
  final String? businessId;
  final String? businessName;
  final bool isFlash;
  final DateTime? flashExpiresAt;

  const Post({
    required this.id,
    required this.userId,
    this.userDisplayName,
    this.userAvatarUrl,
    this.author,
    this.business,
    this.viewer = const PostViewer(),
    required this.postType,
    this.title,
    this.body,
    this.mediaUrl,
    this.mediaUrls = const [],
    this.lat,
    this.lng,
    this.city,
    this.neighbourhood,
    this.interestTags = const [],
    this.beenHereCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.pulseCount = 0,
    this.distanceM = 0,
    required this.createdAt,
    this.businessId,
    this.businessName,
    this.isFlash = false,
    this.flashExpiresAt,
  });

  Post copyWith({
    int? beenHereCount,
    int? likeCount,
    int? commentCount,
    int? pulseCount,
    PostViewer? viewer,
  }) =>
      Post(
        id: id, userId: userId, userDisplayName: userDisplayName, userAvatarUrl: userAvatarUrl,
        author: author, business: business,
        viewer: viewer ?? this.viewer,
        postType: postType, title: title, body: body,
        mediaUrl: mediaUrl, mediaUrls: mediaUrls,
        lat: lat, lng: lng, city: city, neighbourhood: neighbourhood,
        interestTags: interestTags,
        beenHereCount: beenHereCount ?? this.beenHereCount,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        pulseCount: pulseCount ?? this.pulseCount,
        distanceM: distanceM, createdAt: createdAt,
        businessId: businessId, businessName: businessName,
        isFlash: isFlash, flashExpiresAt: flashExpiresAt,
      );

  bool get isBusinessPost => businessId != null && businessId!.isNotEmpty;
  String get displayName => (isBusinessPost && businessName != null && businessName!.isNotEmpty)
      ? businessName!
      : (userDisplayName ?? author?.displayName ?? 'Hapa User');
  String? get displayAvatar => isBusinessPost
      ? (business?.coverUrl ?? userAvatarUrl ?? author?.avatarUrl)
      : (userAvatarUrl ?? author?.avatarUrl);

  static String? _str(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorMap = j['author'] as Map<String, dynamic>?;
    final bizMap = j['business'] as Map<String, dynamic>?;
    final viewerMap = j['viewer'] as Map<String, dynamic>?;

    // Support both flat fields (feed) and nested (detail)
    final mediaUrls = (j['media_urls'] as List?)?.cast<String>() ?? [];
    final firstMedia = j['media_url'] as String? ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null);

    return Post(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? (authorMap?['id'] as String? ?? ''),
      userDisplayName: j['user_display_name'] as String? ?? authorMap?['display_name'] as String?,
      userAvatarUrl: _str(j['user_avatar_url']) ?? _str(authorMap?['avatar_url']),
      author: authorMap != null ? PostAuthor.fromJson(authorMap) : null,
      business: bizMap != null ? PostBusiness.fromJson(bizMap) : null,
      viewer: viewerMap != null ? PostViewer.fromJson(viewerMap) : const PostViewer(),
      postType: j['post_type'] as String? ?? 'location_post',
      title: j['title'] as String?,
      body: j['body'] as String? ?? j['content'] as String?,
      mediaUrl: firstMedia,
      mediaUrls: mediaUrls,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      city: j['city'] as String?,
      neighbourhood: j['neighbourhood'] as String?,
      interestTags: (j['interest_tags'] as List?)?.cast<String>() ?? [],
      beenHereCount: j['been_here_count'] as int? ?? 0,
      likeCount: j['like_count'] as int? ?? 0,
      commentCount: j['comment_count'] as int? ?? 0,
      pulseCount: j['pulse_count'] as int? ?? 0,
      distanceM: (j['distance_m'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String),
      businessId: j['business_id'] as String? ?? bizMap?['id'] as String?,
      businessName: j['business_name'] as String? ?? bizMap?['name'] as String?,
      isFlash: j['is_flash'] as bool? ?? (j['post_type'] == 'flash'),
      flashExpiresAt: j['flash_expires_at'] != null ? DateTime.tryParse(j['flash_expires_at']) : null,
    );
  }
}

class PostComment {
  final String id;
  final String postId;
  final String? parentId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final List<String> mediaUrls;
  final int likeCount;
  final int replyCount;
  final bool viewerLiked;
  final bool isDeleted;
  final DateTime createdAt;
  final List<PostComment> replies;

  const PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    this.mediaUrls = const [],
    this.likeCount = 0,
    this.replyCount = 0,
    this.viewerLiked = false,
    this.isDeleted = false,
    required this.createdAt,
    this.replies = const [],
  });

  static String? _str(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: j['id'] as String,
        postId: j['post_id'] as String? ?? '',
        parentId: j['parent_id'] as String?,
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Hapa User',
        avatarUrl: _str(j['avatar_url']),
        content: j['content'] as String? ?? '',
        mediaUrls: (j['media_urls'] as List?)?.cast<String>() ?? [],
        likeCount: j['like_count'] as int? ?? 0,
        replyCount: j['reply_count'] as int? ?? 0,
        viewerLiked: j['viewer_liked'] as bool? ?? false,
        isDeleted: j['is_deleted'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        replies: (j['replies'] as List?)
                ?.map((r) => PostComment.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );

  PostComment copyWith({
    int? likeCount,
    bool? viewerLiked,
    List<PostComment>? replies,
    int? replyCount,
    bool? isDeleted,
    String? content,
  }) =>
      PostComment(
        id: id,
        postId: postId,
        parentId: parentId,
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        content: content ?? this.content,
        mediaUrls: mediaUrls,
        likeCount: likeCount ?? this.likeCount,
        replyCount: replyCount ?? this.replyCount,
        viewerLiked: viewerLiked ?? this.viewerLiked,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        replies: replies ?? this.replies,
      );
}
