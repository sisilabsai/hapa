package circles

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Circle struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	City        string    `json:"city"`
	Category    string    `json:"category"`
	CoverURL    string    `json:"cover_url,omitempty"`
	MemberCount int       `json:"member_count"`
	IsPublic    bool      `json:"is_public"`
	IsMember    bool      `json:"is_member"`
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateCircleReq struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	City        string `json:"city"`
	Category    string `json:"category"`
}

type CirclePost struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url,omitempty"`
	Content     string    `json:"content"`
	MediaURLs   []string  `json:"media_urls"`
	PostType    string    `json:"post_type"`
	LikeCount   int       `json:"like_count"`
	CommentCount int      `json:"comment_count"`
	IsLiked     bool      `json:"is_liked"`
	CreatedAt   time.Time `json:"created_at"`
}

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func (s *Service) DiscoverCircles(ctx context.Context, city, userID string, limit, offset int) ([]Circle, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	rows, err := s.db.Query(ctx, `
		SELECT c.id, c.name, COALESCE(c.description,''), c.city, COALESCE(c.category,''),
		       COALESCE(c.cover_url,''), c.member_count, c.is_public, c.created_by, c.created_at,
		       EXISTS(SELECT 1 FROM circle_members cm WHERE cm.circle_id = c.id AND cm.user_id = $2) AS is_member
		FROM circles c
		WHERE c.city = $1 AND c.is_public = TRUE
		ORDER BY c.member_count DESC, c.created_at DESC
		LIMIT $3 OFFSET $4
	`, city, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("query circles: %w", err)
	}
	defer rows.Close()

	var out []Circle
	for rows.Next() {
		var c Circle
		if err := rows.Scan(
			&c.ID, &c.Name, &c.Description, &c.City, &c.Category,
			&c.CoverURL, &c.MemberCount, &c.IsPublic, &c.CreatedBy, &c.CreatedAt, &c.IsMember,
		); err != nil {
			continue
		}
		out = append(out, c)
	}
	if out == nil {
		out = []Circle{}
	}
	return out, nil
}

func (s *Service) MyCircles(ctx context.Context, userID string) ([]Circle, error) {
	rows, err := s.db.Query(ctx, `
		SELECT c.id, c.name, COALESCE(c.description,''), c.city, COALESCE(c.category,''),
		       COALESCE(c.cover_url,''), c.member_count, c.is_public, c.created_by, c.created_at,
		       TRUE AS is_member
		FROM circles c
		JOIN circle_members cm ON cm.circle_id = c.id
		WHERE cm.user_id = $1
		ORDER BY cm.joined_at DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query my circles: %w", err)
	}
	defer rows.Close()

	var out []Circle
	for rows.Next() {
		var c Circle
		if err := rows.Scan(
			&c.ID, &c.Name, &c.Description, &c.City, &c.Category,
			&c.CoverURL, &c.MemberCount, &c.IsPublic, &c.CreatedBy, &c.CreatedAt, &c.IsMember,
		); err != nil {
			continue
		}
		out = append(out, c)
	}
	if out == nil {
		out = []Circle{}
	}
	return out, nil
}

func (s *Service) GetCircle(ctx context.Context, id, userID string) (*Circle, error) {
	var c Circle
	err := s.db.QueryRow(ctx, `
		SELECT c.id, c.name, COALESCE(c.description,''), c.city, COALESCE(c.category,''),
		       COALESCE(c.cover_url,''), c.member_count, c.is_public, c.created_by, c.created_at,
		       EXISTS(SELECT 1 FROM circle_members cm WHERE cm.circle_id = c.id AND cm.user_id = $2)
		FROM circles c
		WHERE c.id = $1
	`, id, userID).Scan(
		&c.ID, &c.Name, &c.Description, &c.City, &c.Category,
		&c.CoverURL, &c.MemberCount, &c.IsPublic, &c.CreatedBy, &c.CreatedAt, &c.IsMember,
	)
	if err != nil {
		return nil, fmt.Errorf("circle not found")
	}
	return &c, nil
}

func (s *Service) CreateCircle(ctx context.Context, req CreateCircleReq, userID string) (*Circle, error) {
	var c Circle
	err := s.db.QueryRow(ctx, `
		INSERT INTO circles (name, description, city, category, created_by)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, name, COALESCE(description,''), city, COALESCE(category,''),
		          COALESCE(cover_url,''), member_count, is_public, created_by, created_at
	`, req.Name, req.Description, req.City, req.Category, userID).Scan(
		&c.ID, &c.Name, &c.Description, &c.City, &c.Category,
		&c.CoverURL, &c.MemberCount, &c.IsPublic, &c.CreatedBy, &c.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create circle: %w", err)
	}
	// Auto-join creator
	_, _ = s.db.Exec(ctx, `
		INSERT INTO circle_members (circle_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, c.ID, userID)
	c.IsMember = true
	c.MemberCount = 1
	return &c, nil
}

func (s *Service) JoinCircle(ctx context.Context, circleID, userID string) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO circle_members (circle_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, circleID, userID)
	if err != nil {
		return fmt.Errorf("join circle: %w", err)
	}
	_, _ = s.db.Exec(ctx, `
		UPDATE circles SET member_count = member_count + 1 WHERE id = $1
	`, circleID)
	return nil
}

func (s *Service) LeaveCircle(ctx context.Context, circleID, userID string) error {
	res, err := s.db.Exec(ctx, `
		DELETE FROM circle_members WHERE circle_id = $1 AND user_id = $2
	`, circleID, userID)
	if err != nil {
		return fmt.Errorf("leave circle: %w", err)
	}
	if res.RowsAffected() > 0 {
		_, _ = s.db.Exec(ctx, `
			UPDATE circles SET member_count = GREATEST(member_count - 1, 0) WHERE id = $1
		`, circleID)
	}
	return nil
}

// CirclePosts returns posts from the circle's city filtered by category tag.
func (s *Service) CirclePosts(ctx context.Context, circleID, userID string, limit, offset int) ([]CirclePost, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	circle, err := s.GetCircle(ctx, circleID, userID)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.Query(ctx, `
		SELECT p.id, p.user_id, u.display_name, COALESCE(u.avatar_url,''),
		       COALESCE(p.content,''), p.media_urls, p.post_type::text,
		       p.like_count, p.comment_count,
		       EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = $3) AS is_liked,
		       p.created_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.city = $1
		  AND ($2 = '' OR $2 = ANY(p.interest_tags))
		  AND p.moderation_status = 'approved'
		  AND (p.expires_at IS NULL OR p.expires_at > NOW())
		ORDER BY p.created_at DESC
		LIMIT $4 OFFSET $5
	`, circle.City, circle.Category, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("query circle posts: %w", err)
	}
	defer rows.Close()

	var out []CirclePost
	for rows.Next() {
		var p CirclePost
		var mediaURLs []string
		if err := rows.Scan(
			&p.ID, &p.UserID, &p.DisplayName, &p.AvatarURL,
			&p.Content, &mediaURLs, &p.PostType,
			&p.LikeCount, &p.CommentCount, &p.IsLiked, &p.CreatedAt,
		); err != nil {
			continue
		}
		if mediaURLs == nil {
			mediaURLs = []string{}
		}
		p.MediaURLs = mediaURLs
		out = append(out, p)
	}
	if out == nil {
		out = []CirclePost{}
	}
	return out, nil
}
