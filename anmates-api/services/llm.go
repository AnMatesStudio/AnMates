package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// ConciergeInput is what the model sees: a derived mood, the shared budget band,
// and the pre-fetched candidate venues. Chat text is NEVER passed here (injection-safe);
// only a coarse mood label derived server-side.
type ConciergeInput struct {
	MoodTags   []string
	BudgetMin  int
	BudgetMax  int
	Candidates []Candidate
}

// Pick is the model's choice: a candidate id + a short reason. The model authors
// only the id selection + reason text; all venue facts come from the DB.
type Pick struct {
	RestaurantID string `json:"restaurant_id"`
	Reason       string `json:"reason"`
}

// ConciergeOutput is the strict JSON the model must return.
type ConciergeOutput struct {
	Intro      string `json:"intro"`
	Picks      []Pick `json:"picks"`
	CostTokens int    `json:"-"` // filled by the impl, not the model
}

// LLMClient is the pluggable model backend. The OpenAI-compatible impl works with
// LM Studio (dev), Ollama, vLLM, or a cloud endpoint — selected purely by env.
type LLMClient interface {
	Rank(ctx context.Context, in ConciergeInput) (ConciergeOutput, error)
}

// ---- Fake (tests + offline) -------------------------------------------------

// FakeLLM deterministically picks the first up-to-3 candidates. Used in unit tests
// and as a safe default when no real backend is configured.
type FakeLLM struct{}

func (FakeLLM) Rank(_ context.Context, in ConciergeInput) (ConciergeOutput, error) {
	out := ConciergeOutput{Intro: "2 đứa hợp gu rồi nè! Đây là vài chỗ ngon, vừa túi tiền, nằm giữa 2 đứa:"}
	for i, c := range in.Candidates {
		if i >= 3 {
			break
		}
		out.Picks = append(out.Picks, Pick{RestaurantID: c.ID.String(), Reason: "Gần điểm giữa, hợp gu 2 đứa"})
	}
	return out, nil
}

// ---- OpenAI-compatible backend (LM Studio / Ollama / vLLM / cloud) ----------

type OpenAICompatLLM struct {
	baseURL string
	apiKey  string
	model   string
	hc      *http.Client
}

func NewOpenAICompatLLM(baseURL, apiKey, model string) *OpenAICompatLLM {
	return &OpenAICompatLLM{
		baseURL: strings.TrimRight(baseURL, "/"),
		apiKey:  apiKey,
		model:   model,
		hc:      &http.Client{Timeout: 60 * time.Second},
	}
}

type oaiMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type oaiReq struct {
	Model          string       `json:"model"`
	Messages       []oaiMessage `json:"messages"`
	Temperature    float64      `json:"temperature"`
	MaxTokens      int          `json:"max_tokens,omitempty"`
	ResponseFormat interface{}  `json:"response_format,omitempty"`
}

type oaiResp struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
			// Reasoning models (e.g. Qwen3 via LM Studio) place the answer in
			// reasoning_content and leave content empty — we fall back to it.
			ReasoningContent string `json:"reasoning_content"`
		} `json:"message"`
	} `json:"choices"`
	Usage struct {
		TotalTokens int `json:"total_tokens"`
	} `json:"usage"`
}

func (l *OpenAICompatLLM) Rank(ctx context.Context, in ConciergeInput) (ConciergeOutput, error) {
	userPayload, _ := json.Marshal(map[string]interface{}{
		"mood_tags":  in.MoodTags,
		"budget_vnd": map[string]int{"min": in.BudgetMin, "max": in.BudgetMax},
		"candidates": slimCandidates(in.Candidates),
	})

	reqBody := oaiReq{
		Model:       l.model,
		Temperature: 0.4,
		// Headroom for reasoning models that "think" before emitting the JSON.
		MaxTokens: 2000,
		Messages: []oaiMessage{
			{Role: "system", Content: conciergeSystemPrompt},
			{Role: "user", Content: string(userPayload)},
		},
		ResponseFormat: venuePicksSchema,
	}
	raw, _ := json.Marshal(reqBody)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, l.baseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return ConciergeOutput{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if l.apiKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+l.apiKey)
	}

	resp, err := l.hc.Do(httpReq)
	if err != nil {
		return ConciergeOutput{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ConciergeOutput{}, fmt.Errorf("llm http %d", resp.StatusCode)
	}

	var parsed oaiResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return ConciergeOutput{}, err
	}
	if len(parsed.Choices) == 0 {
		return ConciergeOutput{}, fmt.Errorf("llm: empty choices")
	}

	// Reasoning models (Qwen3 in LM Studio) route the JSON into reasoning_content
	// and leave content empty — fall back to it. parseConciergeJSON extracts the
	// {...} object regardless of surrounding prose / think text.
	msg := parsed.Choices[0].Message
	answer := msg.Content
	if strings.TrimSpace(answer) == "" {
		answer = msg.ReasoningContent
	}

	out, err := parseConciergeJSON(answer)
	if err != nil {
		return ConciergeOutput{}, err
	}
	out.CostTokens = parsed.Usage.TotalTokens
	return out, nil
}

// parseConciergeJSON tolerates models that wrap JSON in prose / code fences.
func parseConciergeJSON(s string) (ConciergeOutput, error) {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '{'); i >= 0 {
		if j := strings.LastIndexByte(s, '}'); j >= i {
			s = s[i : j+1]
		}
	}
	var out ConciergeOutput
	if err := json.Unmarshal([]byte(s), &out); err != nil {
		return ConciergeOutput{}, fmt.Errorf("llm: bad json: %w", err)
	}
	return out, nil
}

type slimCandidate struct {
	RestaurantID string   `json:"restaurant_id"`
	Name         string   `json:"name"`
	Cuisine      []string `json:"cuisine_tags"`
	PriceMin     *int     `json:"price_min,omitempty"`
	PriceMax     *int     `json:"price_max,omitempty"`
	Rating       *float64 `json:"rating,omitempty"`
	DistanceM    int      `json:"distance_m"`
}

func slimCandidates(cs []Candidate) []slimCandidate {
	out := make([]slimCandidate, len(cs))
	for i, c := range cs {
		out[i] = slimCandidate{
			RestaurantID: c.ID.String(), Name: c.Name, Cuisine: c.Cuisine,
			PriceMin: c.PriceMin, PriceMax: c.PriceMax, Rating: c.Rating, DistanceM: c.DistanceM,
		}
	}
	return out
}

const conciergeSystemPrompt = `Bạn là "Trợ lý ĂnMates" — trợ lý gợi ý quán ăn cho 2 người vừa hợp gu trên app hẹn hò ẩm thực.
Nhiệm vụ: từ DANH SÁCH QUÁN cho sẵn, chọn TỐI ĐA 3 quán hợp nhất cho buổi ăn đầu tiên của 2 người,
ưu tiên: gần điểm giữa, hợp mood/gu, vừa ngân sách.
QUY TẮC BẮT BUỘC:
- CHỈ được chọn quán có trong danh sách (dùng đúng "restaurant_id"). Tuyệt đối KHÔNG bịa quán.
- Trả lời DUY NHẤT bằng JSON đúng schema: {"intro": string, "picks": [{"restaurant_id": string, "reason": string}]}.
- "intro" ấm áp, ngắn gọn, tiếng Việt. "reason" mỗi quán ngắn (<60 ký tự), nói vì sao hợp.
- CHỈ DÙNG TIẾNG VIỆT. TUYỆT ĐỐI KHÔNG dùng chữ Hán / tiếng Trung / tiếng Anh trong "intro" và "reason".
- Tối đa 3 picks.`

// venuePicksSchema forces structured output where the server supports it (LM Studio,
// OpenAI). Servers that ignore it still get the JSON instruction in the prompt.
var venuePicksSchema = map[string]interface{}{
	"type": "json_schema",
	"json_schema": map[string]interface{}{
		"name":   "venue_picks",
		"strict": true,
		"schema": map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"intro": map[string]interface{}{"type": "string"},
				"picks": map[string]interface{}{
					"type": "array",
					"items": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"restaurant_id": map[string]interface{}{"type": "string"},
							"reason":        map[string]interface{}{"type": "string"},
						},
						"required":             []string{"restaurant_id", "reason"},
						"additionalProperties": false,
					},
				},
			},
			"required":             []string{"intro", "picks"},
			"additionalProperties": false,
		},
	},
}
