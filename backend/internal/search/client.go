package search

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	ms "github.com/meilisearch/meilisearch-go"
)

type Client struct {
	ms *ms.Client
}

func NewClient(url, masterKey string) *Client {
	return &Client{
		ms: ms.NewClient(ms.ClientConfig{
			Host:   url,
			APIKey: masterKey,
		}),
	}
}

func (c *Client) IndexBusiness(ctx context.Context, b any) error {
	idx := c.ms.Index("businesses")
	_, err := idx.AddDocuments([]any{b}, "id")
	return err
}

func (c *Client) IndexPost(ctx context.Context, p any) error {
	idx := c.ms.Index("posts")
	_, err := idx.AddDocuments([]any{p}, "id")
	return err
}

func (c *Client) Search(ctx context.Context, query, city, indexName string, limit int) ([]map[string]any, error) {
	idx := c.ms.Index(indexName)
	req := &ms.SearchRequest{Limit: int64(limit)}
	if city != "" {
		req.Filter = fmt.Sprintf("city = '%s'", city)
	}
	res, err := idx.Search(query, req)
	if err != nil {
		return nil, err
	}

	var results []map[string]any
	for _, hit := range res.Hits {
		if m, ok := hit.(map[string]any); ok {
			results = append(results, m)
		}
	}
	return results, nil
}

func (c *Client) SetupIndices() error {
	bizIdx := c.ms.Index("businesses")
	bizIdx.UpdateSettings(&ms.Settings{
		SearchableAttributes: []string{"name", "description", "category", "city", "neighbourhood"},
		FilterableAttributes: []string{"city", "category", "tier", "is_verified", "price_range"},
		SortableAttributes:   []string{"rating_avg", "review_count"},
		TypoTolerance:        &ms.TypoTolerance{Enabled: true},
	})

	postIdx := c.ms.Index("posts")
	postIdx.UpdateSettings(&ms.Settings{
		SearchableAttributes: []string{"content", "city", "neighbourhood"},
		FilterableAttributes: []string{"city", "post_type", "moderation_status"},
		SortableAttributes:   []string{"created_at"},
	})

	return nil
}

func Routes(c *Client) http.Handler {
	r := chi.NewRouter()
	r.Get("/", handleSearch(c))
	return r
}

type searchReq struct {
	Query string `json:"q"`
	City  string `json:"city"`
	Type  string `json:"type"`
	Limit int    `json:"limit"`
}

func handleSearch(c *Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		query := q.Get("q")
		city := q.Get("city")
		searchType := q.Get("type")
		if searchType == "" {
			searchType = "businesses"
		}

		results, err := c.Search(r.Context(), query, city, searchType, 20)
		if err != nil {
			http.Error(w, `{"error":"search failed"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"results": results,
			"count":   len(results),
			"query":   query,
		})
	}
}
