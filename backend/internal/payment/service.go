package payment

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/hapa-world/hapa/pkg/config"
)

type InitPaymentReq struct {
	UserID      string  `json:"user_id"`
	Email       string  `json:"email"`
	AmountUSD   float64 `json:"amount_usd"`
	Currency    string  `json:"currency"`
	BookingID   string  `json:"booking_id,omitempty"`
	Description string  `json:"description"`
	Provider    string  `json:"provider"` // flutterwave|paystack|mpesa
}

type InitPaymentResp struct {
	PaymentLink string `json:"payment_link"`
	Reference   string `json:"reference"`
}

type Service struct {
	cfg *config.Config
}

func NewService(cfg *config.Config) *Service {
	return &Service{cfg: cfg}
}

// InitPayment generates a payment link via Flutterwave or Paystack
func (s *Service) InitPayment(ctx context.Context, req InitPaymentReq) (*InitPaymentResp, error) {
	switch req.Provider {
	case "flutterwave":
		return s.initFlutterwave(ctx, req)
	case "paystack":
		return s.initPaystack(ctx, req)
	default:
		return nil, fmt.Errorf("unsupported payment provider: %s", req.Provider)
	}
}

func (s *Service) initFlutterwave(ctx context.Context, req InitPaymentReq) (*InitPaymentResp, error) {
	if s.cfg.FlutterwaveKey == "" {
		return nil, fmt.Errorf("flutterwave key not configured")
	}

	// TODO: call Flutterwave API
	// POST https://api.flutterwave.com/v3/payments
	ref := fmt.Sprintf("hapa_%s_%d", req.UserID[:8], len(req.Description))
	return &InitPaymentResp{
		PaymentLink: fmt.Sprintf("https://checkout.flutterwave.com/v3/hosted/pay/%s", ref),
		Reference:   ref,
	}, nil
}

func (s *Service) initPaystack(ctx context.Context, req InitPaymentReq) (*InitPaymentResp, error) {
	if s.cfg.PaystackKey == "" {
		return nil, fmt.Errorf("paystack key not configured")
	}

	// TODO: call Paystack API
	// POST https://api.paystack.co/transaction/initialize
	ref := fmt.Sprintf("hapa_ps_%s", req.UserID[:8])
	return &InitPaymentResp{
		PaymentLink: fmt.Sprintf("https://paystack.com/pay/%s", ref),
		Reference:   ref,
	}, nil
}

// VerifyPayment confirms a payment webhook or callback
func (s *Service) VerifyPayment(ctx context.Context, provider, reference string) (bool, error) {
	// TODO: verify with provider API
	return true, nil
}

// WebhookHandler processes payment webhooks from Flutterwave/Paystack
func WebhookHandler(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var event map[string]any
		if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
			http.Error(w, "invalid webhook", http.StatusBadRequest)
			return
		}

		// TODO: verify webhook signature, update booking/payment status
		w.WriteHeader(http.StatusOK)
	}
}
