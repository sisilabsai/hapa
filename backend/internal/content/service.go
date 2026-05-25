package content

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/internal/ai"
	"github.com/hapa-world/hapa/internal/moderation"
	"github.com/hapa-world/hapa/internal/search"
	"github.com/hapa-world/hapa/pkg/middleware"
)

type Post struct {
	ID               string     `json:"id"`
	UserID           string     `json:"user_id"`
	PostType         string     `json:"post_type"`
	Content          string     `json:"content"`
	MediaURLs        []string   `json:"media_urls"`
	Lat              float64    `json:"lat"`
	Lng              float64    `json:"lng"`
	City             string     `json:"city"`
	Neighbourhood    string     `json:"neighbourhood,omitempty"`
	BusinessID       *string    `json:"business_id,omitempty"`
	InterestTags     []string   `json:"interest_tags"`
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
	BeenHereCount    int        `json:"been_here_count"`
	LikeCount        int        `json:"like_count"`
	CommentCount     int        `json:"comment_count"`
	ModerationStatus string     `json:"moderation_status"`
	CreatedAt        time.Time  `json:"created_at"`
}

type CreatePostReq struct {
	PostType     string   `json:"post_type"`
	Content      string   `json:"content"`
	MediaURLs    []string `json:"media_urls"`
	Lat          float64  `json:"lat"`
	Lng          float64  `json:"lng"`
	BusinessID   string   `json:"business_id,omitempty"`
	InterestTags []string `json:"interest_tags"`
	ExpiresAt    *time.Time `json:"expires_at,omitempty"` // for Flash
}

type Service struct {
	db     *pgxpool.Pool
	cache  *redis.Client
	search *search.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client, search *search.Client) *Service {
	return &Service{db: db, cache: cache, search: search}
}

// CreatePost creates a post (any type) and queues async moderation
func (s *Service) CreatePost(ctx context.Context, userID string, req CreatePostReq) (*Post, error) {
	if req.Content == "" && len(req.MediaURLs) == 0 {
		return nil, fmt.Errorf("post must have content or media")
	}

	// Detect city from coordinates
	var city, neighbourhood string
	s.db.QueryRow(ctx, `
		SELECT name FROM cities
		ORDER BY ST_Distance(location, ST_SetSRID(ST_Point($2, $1), 4326)::geography)
		LIMIT 1
	`, req.Lat, req.Lng).Scan(&city)

	var bizID *string
	if req.BusinessID != "" {
		bizID = &req.BusinessID
	}

	var post Post
	err := s.db.QueryRow(ctx, `
		INSERT INTO posts (
			user_id, post_type, content, media_urls, location, city, neighbourhood,
			business_id, interest_tags, expires_at, moderation_status
		) VALUES (
			$1, $2::post_type, $3, $4,
			ST_SetSRID(ST_Point($6, $5), 4326)::geography,
			$7, $8, $9, $10, $11, 'approved'
		)
		RETURNING id, user_id, post_type::text, content, media_urls,
		          ST_Y(location::geometry), ST_X(location::geometry),
		          city, neighbourhood, been_here_count, like_count, comment_count,
		          moderation_status::text, created_at
	`,
		userID, req.PostType, req.Content, req.MediaURLs,
		req.Lat, req.Lng, city, neighbourhood,
		bizID, req.InterestTags, req.ExpiresAt,
	).Scan(
		&post.ID, &post.UserID, &post.PostType, &post.Content, &post.MediaURLs,
		&post.Lat, &post.Lng, &post.City, &post.Neighbourhood,
		&post.BeenHereCount, &post.LikeCount, &post.CommentCount,
		&post.ModerationStatus, &post.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create post: %w", err)
	}

	// Async: index in search
	go s.search.IndexPost(context.Background(), &post)

	return &post, nil
}

// BeeenHere records that a user visited a place from a post
func (s *Service) BeenHere(ctx context.Context, postID, userID string) error {
	_, err := s.db.Exec(ctx, `
		WITH ins AS (
			INSERT INTO been_here (post_id, user_id) VALUES ($1, $2)
			ON CONFLICT DO NOTHING
			RETURNING 1
		)
		UPDATE posts SET been_here_count = been_here_count + 1
		WHERE id = $1 AND EXISTS (SELECT 1 FROM ins)
	`, postID, userID)
	return err
}

// PulseFlash increments pulse count on a Flash post
func (s *Service) PulseFlash(ctx context.Context, postID, userID string) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		WITH ins AS (
			INSERT INTO post_pulses (post_id, user_id) VALUES ($1, $2)
			ON CONFLICT DO NOTHING RETURNING 1
		)
		UPDATE posts SET pulse_count = pulse_count + 1
		WHERE id = $1 AND EXISTS (SELECT 1 FROM ins)
		RETURNING pulse_count
	`, postID, userID).Scan(&count)
	return count, err
}

// GetCulturalGuide returns Hapa Guide content for a city (title+body schema)
func (s *Service) GetCulturalGuide(ctx context.Context, city string) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT cn.id, COALESCE(cn.title, ''), cn.content, COALESCE(cn.category, 'general'),
		       cn.upvote_count, COALESCE(cn.is_ai_generated, false),
		       COALESCE(u.display_name, 'Hapa AI'), u.avatar_url
		FROM cultural_notes cn
		LEFT JOIN users u ON u.id = cn.user_id
		WHERE cn.city = $1
		  AND cn.moderation_status = 'approved'
		ORDER BY cn.upvote_count DESC, cn.created_at DESC
		LIMIT 50
	`, city)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []map[string]any
	for rows.Next() {
		var id, title, body, category, displayName string
		var upvotes int
		var isAI bool
		var avatarURL *string
		if err := rows.Scan(&id, &title, &body, &category, &upvotes, &isAI, &displayName, &avatarURL); err == nil {
			notes = append(notes, map[string]any{
				"id": id, "title": title, "body": body, "category": category,
				"upvote_count": upvotes, "is_ai_generated": isAI,
				"author": displayName,
			})
		}
	}
	return notes, nil
}

// SaveAIGuide persists AI-generated guide tips for a city.
func (s *Service) SaveAIGuide(ctx context.Context, city string, tips []ai.GuideTip) error {
	for _, tip := range tips {
		category := tip.Category
		if category == "" {
			category = "general"
		}
		s.db.Exec(ctx, `
			INSERT INTO cultural_notes (city, title, content, category, moderation_status, is_ai_generated)
			VALUES ($1, $2, $3, $4, 'approved', true)
		`, city, tip.Title, tip.Body, category)
	}
	return nil
}

// GetPost returns a single post with author, business and interaction state
func (s *Service) GetPost(ctx context.Context, postID, viewerID string) (map[string]any, error) {
	row := s.db.QueryRow(ctx, `
		SELECT
			p.id, p.user_id, p.post_type::text, p.content, p.media_urls,
			ST_Y(p.location::geometry) AS lat, ST_X(p.location::geometry) AS lng,
			p.city, p.neighbourhood, p.business_id::text, p.interest_tags,
			p.been_here_count, p.like_count, p.comment_count, p.pulse_count,
			p.expires_at, p.created_at,
			u.display_name, u.avatar_url, u.bio, u.user_type::text, u.trust_score, u.is_verified,
			b.name, b.category::text, b.cover_url, b.rating_avg, b.address,
			EXISTS(SELECT 1 FROM been_here WHERE post_id = p.id AND user_id = $2) AS viewer_been_here,
			EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $2) AS viewer_liked,
			EXISTS(SELECT 1 FROM post_pulses WHERE post_id = p.id AND user_id = $2) AS viewer_pulsed,
			EXISTS(SELECT 1 FROM post_saves WHERE post_id = p.id AND user_id = $2) AS viewer_saved
		FROM posts p
		JOIN users u ON u.id = p.user_id
		LEFT JOIN businesses b ON b.id = p.business_id
		WHERE p.id = $1 AND p.moderation_status = 'approved'
	`, postID, viewerID)

	var (
		id, userID, postType, content, city, neighbourhood string
		mediaURLs, tags                                     []string
		lat, lng                                            float64
		bizID, authorBio, authorType, bizName, bizCategory, bizCover, bizAddr *string
		beenHere, likes, comments, pulses                   int
		expiresAt                                           *time.Time
		createdAt                                           time.Time
		authorName, authorAvatar                            *string
		authorAvName                                        string
		authorTrust                                         int
		authorVerified                                      bool
		bizRating                                           *float64
		viewerBeenHere, viewerLiked, viewerPulsed, viewerSaved bool
	)

	if err := row.Scan(
		&id, &userID, &postType, &content, &mediaURLs,
		&lat, &lng, &city, &neighbourhood, &bizID, &tags,
		&beenHere, &likes, &comments, &pulses,
		&expiresAt, &createdAt,
		&authorAvName, &authorAvatar, &authorBio, &authorType, &authorTrust, &authorVerified,
		&bizName, &bizCategory, &bizCover, &bizRating, &bizAddr,
		&viewerBeenHere, &viewerLiked, &viewerPulsed, &viewerSaved,
	); err != nil {
		return nil, fmt.Errorf("post not found")
	}
	_ = authorName

	author := map[string]any{
		"id": userID, "display_name": authorAvName, "avatar_url": authorAvatar,
		"bio": authorBio, "user_type": authorType, "trust_score": authorTrust, "is_verified": authorVerified,
	}
	result := map[string]any{
		"id": id, "user_id": userID, "post_type": postType, "body": content,
		"media_urls": mediaURLs, "lat": lat, "lng": lng,
		"city": city, "neighbourhood": neighbourhood,
		"interest_tags": tags, "been_here_count": beenHere,
		"like_count": likes, "comment_count": comments, "pulse_count": pulses,
		"expires_at": expiresAt, "created_at": createdAt,
		"author": author,
		"viewer": map[string]any{
			"been_here": viewerBeenHere, "liked": viewerLiked, "pulsed": viewerPulsed, "saved": viewerSaved,
		},
	}
	if bizName != nil {
		result["business"] = map[string]any{
			"id": bizID, "name": bizName, "category": bizCategory,
			"cover_url": bizCover, "rating_avg": bizRating, "address": bizAddr,
		}
	}
	return result, nil
}

type CommentNode struct {
	ID          string         `json:"id"`
	PostID      string         `json:"post_id"`
	ParentID    *string        `json:"parent_id,omitempty"`
	UserID      string         `json:"user_id"`
	DisplayName string         `json:"display_name"`
	AvatarURL   *string        `json:"avatar_url,omitempty"`
	Content     string         `json:"content"`
	MediaURLs   []string       `json:"media_urls"`
	LikeCount   int            `json:"like_count"`
	ReplyCount  int            `json:"reply_count"`
	ViewerLiked bool           `json:"viewer_liked"`
	IsDeleted   bool           `json:"is_deleted"`
	CreatedAt   time.Time      `json:"created_at"`
	Replies     []*CommentNode `json:"replies,omitempty"`
}

func (s *Service) GetComments(ctx context.Context, postID, viewerID, sort string, limit, offset int) ([]*CommentNode, error) {
	orderBy := "c.created_at ASC"
	if sort == "top" {
		orderBy = "c.like_count DESC, c.created_at ASC"
	}
	rows, err := s.db.Query(ctx, fmt.Sprintf(`
		SELECT c.id, c.post_id, c.user_id, u.display_name, u.avatar_url,
		       c.content, COALESCE(c.media_urls, '{}'), c.like_count,
		       COALESCE(c.reply_count, 0),
		       EXISTS(SELECT 1 FROM comment_likes WHERE comment_id = c.id AND user_id = $2),
		       COALESCE(c.is_deleted, false), c.created_at
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.post_id = $1 AND c.parent_id IS NULL
		  AND c.moderation_status = 'approved'
		ORDER BY %s
		LIMIT $3 OFFSET $4
	`, orderBy), postID, viewerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []*CommentNode
	for rows.Next() {
		c := &CommentNode{}
		if err := rows.Scan(&c.ID, &c.PostID, &c.UserID, &c.DisplayName, &c.AvatarURL,
			&c.Content, &c.MediaURLs, &c.LikeCount, &c.ReplyCount, &c.ViewerLiked,
			&c.IsDeleted, &c.CreatedAt); err == nil {
			if c.IsDeleted {
				c.Content = "[deleted]"
				c.MediaURLs = nil
			}
			comments = append(comments, c)
		}
	}
	for _, comment := range comments {
		if comment.ReplyCount > 0 {
			replies, _ := s.GetReplies(ctx, comment.ID, viewerID, 2, 0)
			comment.Replies = replies
		}
	}
	return comments, nil
}

func (s *Service) GetReplies(ctx context.Context, commentID, viewerID string, limit, offset int) ([]*CommentNode, error) {
	rows, err := s.db.Query(ctx, `
		SELECT c.id, c.post_id, c.parent_id, c.user_id, u.display_name, u.avatar_url,
		       c.content, COALESCE(c.media_urls, '{}'), c.like_count,
		       COALESCE(c.reply_count, 0),
		       EXISTS(SELECT 1 FROM comment_likes WHERE comment_id = c.id AND user_id = $2),
		       COALESCE(c.is_deleted, false), c.created_at
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.parent_id = $1 AND c.moderation_status = 'approved'
		ORDER BY c.created_at ASC
		LIMIT $3 OFFSET $4
	`, commentID, viewerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var replies []*CommentNode
	for rows.Next() {
		c := &CommentNode{}
		if err := rows.Scan(&c.ID, &c.PostID, &c.ParentID, &c.UserID, &c.DisplayName, &c.AvatarURL,
			&c.Content, &c.MediaURLs, &c.LikeCount, &c.ReplyCount, &c.ViewerLiked,
			&c.IsDeleted, &c.CreatedAt); err == nil {
			if c.IsDeleted {
				c.Content = "[deleted]"
				c.MediaURLs = nil
			}
			replies = append(replies, c)
		}
	}
	return replies, nil
}

func (s *Service) AddComment(ctx context.Context, postID, userID, content string, parentID *string, mediaURLs []string) (*CommentNode, error) {
	if mediaURLs == nil {
		mediaURLs = []string{}
	}
	c := &CommentNode{}
	var err error
	if parentID != nil {
		err = s.db.QueryRow(ctx, `
			INSERT INTO comments (post_id, user_id, content, parent_id, media_urls, moderation_status)
			VALUES ($1, $2, $3, $4, $5, 'approved')
			RETURNING id, post_id, parent_id, user_id, content, media_urls, like_count, reply_count, is_deleted, created_at
		`, postID, userID, content, parentID, mediaURLs).Scan(
			&c.ID, &c.PostID, &c.ParentID, &c.UserID, &c.Content, &c.MediaURLs,
			&c.LikeCount, &c.ReplyCount, &c.IsDeleted, &c.CreatedAt,
		)
		if err == nil {
			s.db.Exec(ctx, `UPDATE comments SET reply_count = reply_count + 1 WHERE id = $1`, *parentID)
		}
	} else {
		err = s.db.QueryRow(ctx, `
			INSERT INTO comments (post_id, user_id, content, media_urls, moderation_status)
			VALUES ($1, $2, $3, $4, 'approved')
			RETURNING id, post_id, parent_id, user_id, content, media_urls, like_count, reply_count, is_deleted, created_at
		`, postID, userID, content, mediaURLs).Scan(
			&c.ID, &c.PostID, &c.ParentID, &c.UserID, &c.Content, &c.MediaURLs,
			&c.LikeCount, &c.ReplyCount, &c.IsDeleted, &c.CreatedAt,
		)
	}
	if err != nil {
		return nil, err
	}
	s.db.Exec(ctx, `UPDATE posts SET comment_count = comment_count + 1 WHERE id = $1`, postID)
	s.db.QueryRow(ctx, `SELECT display_name, avatar_url FROM users WHERE id = $1`, userID).
		Scan(&c.DisplayName, &c.AvatarURL)
	return c, nil
}

func (s *Service) LikeComment(ctx context.Context, commentID, userID string) (int, bool, error) {
	var exists bool
	s.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM comment_likes WHERE comment_id=$1 AND user_id=$2)`,
		commentID, userID).Scan(&exists)
	var liked bool
	if exists {
		s.db.Exec(ctx, `DELETE FROM comment_likes WHERE comment_id=$1 AND user_id=$2`, commentID, userID)
		s.db.Exec(ctx, `UPDATE comments SET like_count = GREATEST(like_count-1, 0) WHERE id=$1`, commentID)
		liked = false
	} else {
		s.db.Exec(ctx, `INSERT INTO comment_likes (comment_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, commentID, userID)
		s.db.Exec(ctx, `UPDATE comments SET like_count = like_count+1 WHERE id=$1`, commentID)
		liked = true
	}
	var count int
	s.db.QueryRow(ctx, `SELECT like_count FROM comments WHERE id=$1`, commentID).Scan(&count)
	return count, liked, nil
}

func (s *Service) DeleteComment(ctx context.Context, commentID, userID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE comments SET is_deleted = TRUE, content = ''
		WHERE id = $1 AND user_id = $2
	`, commentID, userID)
	return err
}

func (s *Service) LikePost(ctx context.Context, postID, userID string) (int, bool, error) {
	var exists bool
	s.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM post_likes WHERE post_id=$1 AND user_id=$2)`,
		postID, userID).Scan(&exists)
	var liked bool
	if exists {
		s.db.Exec(ctx, `DELETE FROM post_likes WHERE post_id=$1 AND user_id=$2`, postID, userID)
		s.db.Exec(ctx, `UPDATE posts SET like_count = GREATEST(like_count-1, 0) WHERE id=$1`, postID)
		liked = false
	} else {
		s.db.Exec(ctx, `INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, postID, userID)
		s.db.Exec(ctx, `UPDATE posts SET like_count = like_count+1 WHERE id=$1`, postID)
		liked = true
	}
	var count int
	s.db.QueryRow(ctx, `SELECT like_count FROM posts WHERE id=$1`, postID).Scan(&count)
	return count, liked, nil
}

func (s *Service) ToggleSave(ctx context.Context, postID, userID string) (bool, error) {
	var exists bool
	s.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM post_saves WHERE post_id=$1 AND user_id=$2)`,
		postID, userID).Scan(&exists)
	if exists {
		s.db.Exec(ctx, `DELETE FROM post_saves WHERE post_id=$1 AND user_id=$2`, postID, userID)
		return false, nil
	}
	_, err := s.db.Exec(ctx, `INSERT INTO post_saves (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, postID, userID)
	return err == nil, err
}

func (s *Service) SavedPosts(ctx context.Context, userID string, limit, offset int) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT p.id, p.user_id, p.post_type::text, p.content, p.media_urls,
		       ST_Y(p.location::geometry) AS lat, ST_X(p.location::geometry) AS lng,
		       p.city, p.neighbourhood, p.been_here_count, p.like_count, p.comment_count,
		       p.pulse_count, p.expires_at, p.created_at,
		       u.display_name, u.avatar_url
		FROM post_saves ps
		JOIN posts p ON p.id = ps.post_id
		JOIN users u ON u.id = p.user_id
		WHERE ps.user_id = $1 AND p.moderation_status = 'approved'
		ORDER BY ps.created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []map[string]any
	for rows.Next() {
		var id, uid, postType, content, city, neighbourhood, authorName string
		var mediaURLs []string
		var plat, plng float64
		var beenHere, likes, comments, pulses int
		var expiresAt *time.Time
		var createdAt time.Time
		var avatarURL *string

		if err := rows.Scan(&id, &uid, &postType, &content, &mediaURLs,
			&plat, &plng, &city, &neighbourhood,
			&beenHere, &likes, &comments, &pulses,
			&expiresAt, &createdAt, &authorName, &avatarURL); err == nil {
			posts = append(posts, map[string]any{
				"id": id, "user_id": uid, "post_type": postType, "body": content,
				"media_urls": mediaURLs, "lat": plat, "lng": plng,
				"city": city, "neighbourhood": neighbourhood,
				"been_here_count": beenHere, "like_count": likes,
				"comment_count": comments, "pulse_count": pulses,
				"expires_at": expiresAt, "created_at": createdAt,
				"author":  map[string]any{"display_name": authorName, "avatar_url": avatarURL},
				"viewer":  map[string]any{"saved": true},
			})
		}
	}
	return posts, nil
}

func (s *Service) GetRelatedPosts(ctx context.Context, postID string, lat, lng float64, limit int) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT p.id, p.post_type::text, p.content, p.media_urls,
		       ST_Y(p.location::geometry) AS lat, ST_X(p.location::geometry) AS lng,
		       p.city, p.neighbourhood, p.been_here_count, p.like_count, p.created_at,
		       u.display_name, u.avatar_url
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.id != $1
		  AND p.moderation_status = 'approved'
		  AND (p.expires_at IS NULL OR p.expires_at > NOW())
		  AND p.created_at > NOW() - INTERVAL '48 hours'
		  AND ST_DWithin(p.location, ST_Point($3, $2)::geography, 3000)
		ORDER BY ST_Distance(p.location, ST_Point($3, $2)::geography), p.been_here_count DESC
		LIMIT $4
	`, postID, lat, lng, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []map[string]any
	for rows.Next() {
		var id, postType, content, city, neighbourhood, authorName string
		var mediaURLs []string
		var plat, plng float64
		var beenHere, likes int
		var createdAt time.Time
		var avatarURL *string

		if err := rows.Scan(&id, &postType, &content, &mediaURLs, &plat, &plng,
			&city, &neighbourhood, &beenHere, &likes, &createdAt, &authorName, &avatarURL); err == nil {
			posts = append(posts, map[string]any{
				"id": id, "post_type": postType, "body": content,
				"media_urls": mediaURLs, "lat": plat, "lng": plng,
				"city": city, "neighbourhood": neighbourhood,
				"been_here_count": beenHere, "like_count": likes,
				"created_at":       createdAt,
				"user_display_name": authorName, "user_avatar_url": avatarURL,
			})
		}
	}
	return posts, nil
}

func (s *Service) GetUserPosts(ctx context.Context, userID, viewerID string, limit, offset int) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT
			p.id, p.user_id, p.post_type::text, p.content, p.media_urls,
			ST_Y(p.location::geometry), ST_X(p.location::geometry),
			p.city, p.neighbourhood, p.interest_tags,
			p.been_here_count, p.like_count, p.comment_count, p.pulse_count,
			p.created_at, p.expires_at,
			u.display_name, u.avatar_url, u.trust_score, u.is_verified,
			EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $2) AS viewer_liked
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id = $1 AND p.moderation_status = 'approved'
		ORDER BY p.created_at DESC
		LIMIT $3 OFFSET $4
	`, userID, viewerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []map[string]any
	for rows.Next() {
		var id, uid, postType, content, city, neighbourhood, authorName string
		var mediaURLs, tags []string
		var lat, lng float64
		var beenHere, likes, comments, pulses int
		var trustScore int
		var isVerified bool
		var viewerLiked bool
		var createdAt time.Time
		var avatarURL *string
		var expiresAt *time.Time

		if err := rows.Scan(
			&id, &uid, &postType, &content, &mediaURLs,
			&lat, &lng, &city, &neighbourhood, &tags,
			&beenHere, &likes, &comments, &pulses,
			&createdAt, &expiresAt,
			&authorName, &avatarURL, &trustScore, &isVerified, &viewerLiked,
		); err != nil {
			continue
		}
		posts = append(posts, map[string]any{
			"id": id, "user_id": uid, "post_type": postType, "body": content,
			"media_urls": mediaURLs, "lat": lat, "lng": lng,
			"city": city, "neighbourhood": neighbourhood, "interest_tags": tags,
			"been_here_count": beenHere, "like_count": likes,
			"comment_count": comments, "pulse_count": pulses,
			"created_at": createdAt, "expires_at": expiresAt,
			"author": map[string]any{
				"id": uid, "display_name": authorName, "avatar_url": avatarURL,
				"trust_score": trustScore, "is_verified": isVerified,
			},
			"viewer": map[string]any{"liked": viewerLiked},
		})
	}
	return posts, nil
}

// ── HTTP Handlers ─────────────────────────────────────────────────────────────

func Routes(svc *Service, mod *moderation.Service) http.Handler {
	r := chi.NewRouter()
	r.Post("/", handleCreatePost(svc))
	r.Get("/by-user/{userID}", handleGetUserPosts(svc))
	r.Get("/saved", handleSavedPosts(svc))
	// Comment sub-routes must precede /{id} to avoid ambiguity
	r.Get("/comments/{commentID}/replies", handleGetReplies(svc))
	r.Post("/comments/{commentID}/like", handleLikeComment(svc))
	r.Delete("/comments/{commentID}", handleDeleteComment(svc))
	r.Get("/{id}", handleGetPost(svc))
	r.Post("/{id}/been-here", handleBeenHere(svc))
	r.Post("/{id}/pulse", handlePulse(svc))
	r.Post("/{id}/like", handleLike(svc))
	r.Post("/{id}/save", handleSave(svc))
	r.Get("/{id}/comments", handleGetComments(svc))
	r.Post("/{id}/comments", handleAddComment(svc))
	r.Get("/{id}/related", handleRelated(svc))
	r.Post("/{id}/report", handleReport(mod))
	return r
}

func handleSave(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		postID := chi.URLParam(r, "id")
		userID := middleware.UserIDFromCtx(r.Context())
		saved, err := svc.ToggleSave(r.Context(), postID, userID)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "save failed"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"saved": saved})
	}
}

func handleSavedPosts(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		page := 1
		if p := r.URL.Query().Get("page"); p != "" {
			if v, err := strconv.Atoi(p); err == nil && v > 0 {
				page = v
			}
		}
		limit := 20
		offset := (page - 1) * limit
		posts, err := svc.SavedPosts(r.Context(), userID, limit, offset)
		if err != nil || posts == nil {
			posts = []map[string]any{}
		}
		writeJSON(w, http.StatusOK, map[string]any{"posts": posts, "has_more": len(posts) >= limit})
	}
}

// AIProvider is the minimal interface the content package needs from the AI service.
type AIProvider interface {
	Enabled() bool
	GenerateCityGuide(ctx context.Context, city string) ([]ai.GuideTip, error)
	SummarizePost(ctx context.Context, content string) (string, error)
	SuggestHashtags(ctx context.Context, content, city string) ([]string, error)
	GenerateFeedDigest(ctx context.Context, city string, snippets []string) (string, error)
	Chat(ctx context.Context, city string, history []ai.ChatMessage) (string, error)
	GenerateBoostCopy(ctx context.Context, businessName, category, city, hint string) (*ai.BoostCopy, error)
	GenerateFlashCopy(ctx context.Context, businessName, category, city, prompt string) (*ai.FlashCopy, error)
}

func GuideHandler(svc *Service, aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		city := chi.URLParam(r, "city")
		w.Header().Set("Content-Type", "application/json")

		notes, err := svc.GetCulturalGuide(r.Context(), city)
		if err != nil {
			http.Error(w, `{"error":"failed to load guide"}`, http.StatusInternalServerError)
			return
		}

		// If no content and AI is enabled, generate on the fly
		if len(notes) == 0 && aiSvc.Enabled() {
			tips, genErr := aiSvc.GenerateCityGuide(r.Context(), city)
			if genErr == nil && len(tips) > 0 {
				var toSave []ai.GuideTip
				for _, t := range tips {
					notes = append(notes, map[string]any{
						"id":           fmt.Sprintf("ai-%s-%s", city, t.Title[:min(8, len(t.Title))]),
						"title":        t.Title, "body": t.Body, "category": t.Category,
						"upvote_count": 0, "is_ai_generated": true, "author": "Hapa AI",
					})
					toSave = append(toSave, t)
				}
				// Persist asynchronously so the response isn't delayed
				go svc.SaveAIGuide(context.Background(), city, toSave)
			}
		}

		json.NewEncoder(w).Encode(map[string]any{"city": city, "notes": notes, "count": len(notes), "ai_powered": len(notes) > 0 && aiSvc.Enabled()})
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// AIRoutes mounts the AI endpoints under /v1/ai.
func AIRoutes(svc *Service, aiSvc AIProvider) http.Handler {
	r := chi.NewRouter()
	r.Post("/summarize", handleAISummarize(svc, aiSvc))
	r.Post("/hashtags", handleAIHashtags(aiSvc))
	r.Post("/digest", handleAIDigest(svc, aiSvc))
	r.Post("/chat", handleAIChat(aiSvc))
	r.Post("/boost-copy", handleAIBoostCopy(aiSvc))
	r.Post("/flash-copy", handleAIFlashCopy(aiSvc))
	return r
}

func handleAIFlashCopy(aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			BusinessName string `json:"business_name"`
			Category     string `json:"category"`
			City         string `json:"city"`
			Prompt       string `json:"prompt"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.BusinessName == "" {
			http.Error(w, `{"error":"business_name required"}`, http.StatusBadRequest)
			return
		}
		copy, err := aiSvc.GenerateFlashCopy(r.Context(), req.BusinessName, req.Category, req.City, req.Prompt)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"AI unavailable"}`, http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(copy)
	}
}

func handleAIBoostCopy(aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			BusinessName string `json:"business_name"`
			Category     string `json:"category"`
			City         string `json:"city"`
			Hint         string `json:"hint"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.BusinessName == "" {
			http.Error(w, `{"error":"business_name required"}`, http.StatusBadRequest)
			return
		}
		copy, err := aiSvc.GenerateBoostCopy(r.Context(), req.BusinessName, req.Category, req.City, req.Hint)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"AI unavailable"}`, http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(copy)
	}
}

func handleAISummarize(_ *Service, aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Content string `json:"content"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
			http.Error(w, `{"error":"content required"}`, http.StatusBadRequest)
			return
		}
		summary, err := aiSvc.SummarizePost(r.Context(), req.Content)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"AI unavailable"}`, http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"summary": summary})
	}
}

func handleAIHashtags(aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Content string `json:"content"`
			City    string `json:"city"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
			http.Error(w, `{"error":"content required"}`, http.StatusBadRequest)
			return
		}
		tags, err := aiSvc.SuggestHashtags(r.Context(), req.Content, req.City)
		w.Header().Set("Content-Type", "application/json")
		if err != nil || tags == nil {
			tags = []string{}
		}
		json.NewEncoder(w).Encode(map[string]any{"hashtags": tags})
	}
}

func handleAIDigest(svc *Service, aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			City     string   `json:"city"`
			Snippets []string `json:"snippets"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.City == "" {
			http.Error(w, `{"error":"city and snippets required"}`, http.StatusBadRequest)
			return
		}
		digest, err := aiSvc.GenerateFeedDigest(r.Context(), req.City, req.Snippets)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"AI unavailable"}`, http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"digest": digest})
	}
}

func handleAIChat(aiSvc AIProvider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			City     string           `json:"city"`
			Messages []ai.ChatMessage `json:"messages"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.City == "" || len(req.Messages) == 0 {
			http.Error(w, `{"error":"city and messages required"}`, http.StatusBadRequest)
			return
		}
		reply, err := aiSvc.Chat(r.Context(), req.City, req.Messages)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"AI unavailable"}`, http.StatusServiceUnavailable)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"reply": reply})
	}
}

func handleGetUserPosts(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		targetUserID := chi.URLParam(r, "userID")
		viewerID := middleware.UserIDFromCtx(r.Context())
		limit := 20
		offset := 0
		if p := r.URL.Query().Get("page"); p != "" {
			if n, err := strconv.Atoi(p); err == nil && n > 1 {
				offset = (n - 1) * limit
			}
		}
		posts, err := svc.GetUserPosts(r.Context(), targetUserID, viewerID, limit, offset)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"failed to load posts"}`, http.StatusInternalServerError)
			return
		}
		if posts == nil {
			posts = []map[string]any{}
		}
		json.NewEncoder(w).Encode(map[string]any{"posts": posts, "total": len(posts)})
	}
}

func handleCreatePost(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req CreatePostReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
			return
		}
		post, err := svc.CreatePost(r.Context(), userID, req)
		if err != nil {
			http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(post)
	}
}

func handleBeenHere(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		postID := chi.URLParam(r, "id")
		svc.BeenHere(r.Context(), postID, userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "been here recorded"})
	}
}

func handlePulse(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		postID := chi.URLParam(r, "id")
		count, _ := svc.PulseFlash(r.Context(), postID, userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]int{"pulse_count": count})
	}
}

func handleGetPost(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		postID := chi.URLParam(r, "id")
		viewerID := middleware.UserIDFromCtx(r.Context())
		post, err := svc.GetPost(r.Context(), postID, viewerID)
		if err != nil {
			http.Error(w, `{"error":"post not found"}`, http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(post)
	}
}

func handleLike(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		postID := chi.URLParam(r, "id")
		count, liked, err := svc.LikePost(r.Context(), postID, userID)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"failed to update like"}`, http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"like_count": count, "liked": liked})
	}
}

func handleGetComments(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		postID := chi.URLParam(r, "id")
		viewerID := middleware.UserIDFromCtx(r.Context())
		q := r.URL.Query()
		sort := q.Get("sort")
		if sort == "" {
			sort = "new"
		}
		page, _ := strconv.Atoi(q.Get("page"))
		if page < 1 {
			page = 1
		}
		limit := 20
		offset := (page - 1) * limit
		comments, err := svc.GetComments(r.Context(), postID, viewerID, sort, limit, offset)
		if err != nil || comments == nil {
			comments = []*CommentNode{}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"comments": comments, "count": len(comments)})
	}
}

func handleAddComment(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		postID := chi.URLParam(r, "id")
		var req struct {
			Content   string   `json:"content"`
			ParentID  *string  `json:"parent_id,omitempty"`
			MediaURLs []string `json:"media_urls,omitempty"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
			http.Error(w, `{"error":"content required"}`, http.StatusBadRequest)
			return
		}
		comment, err := svc.AddComment(r.Context(), postID, userID, req.Content, req.ParentID, req.MediaURLs)
		if err != nil {
			http.Error(w, `{"error":"failed to add comment"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(comment)
	}
}

func handleGetReplies(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		commentID := chi.URLParam(r, "commentID")
		viewerID := middleware.UserIDFromCtx(r.Context())
		page, _ := strconv.Atoi(r.URL.Query().Get("page"))
		if page < 1 {
			page = 1
		}
		limit := 20
		offset := (page - 1) * limit
		replies, err := svc.GetReplies(r.Context(), commentID, viewerID, limit, offset)
		if err != nil || replies == nil {
			replies = []*CommentNode{}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"replies": replies, "count": len(replies)})
	}
}

func handleLikeComment(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		commentID := chi.URLParam(r, "commentID")
		userID := middleware.UserIDFromCtx(r.Context())
		count, liked, err := svc.LikeComment(r.Context(), commentID, userID)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			http.Error(w, `{"error":"failed to update like"}`, http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"like_count": count, "liked": liked})
	}
}

func handleDeleteComment(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		commentID := chi.URLParam(r, "commentID")
		userID := middleware.UserIDFromCtx(r.Context())
		if err := svc.DeleteComment(r.Context(), commentID, userID); err != nil {
			http.Error(w, `{"error":"failed to delete comment"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "deleted"})
	}
}

func handleRelated(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		postID := chi.URLParam(r, "id")
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		posts, err := svc.GetRelatedPosts(r.Context(), postID, lat, lng, 8)
		if err != nil || posts == nil {
			posts = []map[string]any{}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"posts": posts, "count": len(posts)})
	}
}

func handleReport(mod *moderation.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		postID := chi.URLParam(r, "id")
		userID := middleware.UserIDFromCtx(r.Context())
		var req struct {
			Reason string `json:"reason"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		mod.ReportPost(r.Context(), postID, userID, req.Reason)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "reported"})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
