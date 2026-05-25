package moderation

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/hapa-world/hapa/pkg/config"
)

type Service struct {
	db  *pgxpool.Pool
	cfg *config.Config
}

func NewService(db *pgxpool.Pool, cfg *config.Config) *Service {
	return &Service{db: db, cfg: cfg}
}

func (s *Service) ReportPost(ctx context.Context, postID, reporterID, reason string) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO moderation_reports (reporter_id, post_id, reason)
		VALUES ($1, $2, $3)
	`, reporterID, postID, reason)
	return err
}

func (s *Service) AutoModerateText(ctx context.Context, text string) bool {
	// TODO: integrate Google Vision + multilingual BERT model
	// For now, returns true (approved)
	return true
}

func (s *Service) ReviewReport(ctx context.Context, reportID, reviewerID, action string) error {
	status := "resolved"
	if action == "remove" {
		status = "action_taken"
		// TODO: remove content
	}
	_, err := s.db.Exec(ctx, `
		UPDATE moderation_reports
		SET status = $2, reviewed_by = $3, resolved_at = NOW()
		WHERE id = $1
	`, reportID, status, reviewerID)
	return err
}

// ModerationQueue returns pending reports for admin review
func (s *Service) ModerationQueue(ctx context.Context, limit int) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT mr.id, mr.reason, mr.created_at,
		       u.display_name AS reporter_name,
		       p.content AS post_content, p.post_type::text
		FROM moderation_reports mr
		JOIN users u ON u.id = mr.reporter_id
		LEFT JOIN posts p ON p.id = mr.post_id
		WHERE mr.status = 'pending'
		ORDER BY mr.created_at ASC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var queue []map[string]any
	for rows.Next() {
		var id, reason, reporterName string
		var postContent, postType *string
		var createdAt any
		if err := rows.Scan(&id, &reason, &createdAt, &reporterName, &postContent, &postType); err == nil {
			queue = append(queue, map[string]any{
				"id": id, "reason": reason, "created_at": createdAt,
				"reporter": reporterName, "post_content": postContent, "post_type": postType,
			})
		}
	}
	return queue, nil
}

// HTTP handler for admin moderation dashboard
func AdminHandler(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		queue, err := svc.ModerationQueue(r.Context(), 50)
		if err != nil {
			http.Error(w, `{"error":"failed to load queue"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"queue": queue, "count": len(queue)})
	}
}
