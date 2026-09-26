package services

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/anmates/api/models"
	wsx "github.com/anmates/api/ws"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// BotPersona is one demo chat bot (users rows seeded in migration 016). Replies
// are scripted, not generated: the demo must work with no model configured,
// and chat text never reaches an LLM (same rule as the concierge).
type BotPersona struct {
	ID       uuid.UUID
	Greeting string
	Food     string // what this bot always wants to eat, in words
	Place    string // the kind of spot it suggests
	Smalltalk []string
}

// BotPersonas is keyed by the fixed user ids in 016_chat_bots_reads.sql.
var BotPersonas = map[uuid.UUID]BotPersona{
	uuid.MustParse("00000000-0000-0000-0000-0000000000b1"): {
		Greeting: "Hí, mình là Minh Anh (bot demo) 👋 Thấy bạn cũng mê lẩu nè, tối nay đi ăn khuya không?",
		Food:     "lẩu", Place: "một quán lẩu Thái mở tới khuya",
		Smalltalk: []string{
			"Mình thì ăn lẩu quanh năm, trời nóng cũng ăn 😆",
			"Bạn thích lẩu cay hay lẩu nấm?",
			"Ăn lẩu xong làm dĩa ốc nữa là hết sẩy.",
		},
	},
	uuid.MustParse("00000000-0000-0000-0000-0000000000b2"): {
		Greeting: "Yo! Hoàng Nam đây (bot demo) 🔥 Cuối tuần này làm một buổi BBQ Hàn không?",
		Food:     "đồ nướng", Place: "một quán nướng than hoa kiểu Hàn",
		Smalltalk: []string{
			"Ba chỉ bò nướng chấm tương là chân ái.",
			"Bạn uống được bia không, hay mình gọi nước ngọt?",
			"Mình hay đi nhóm 3–4 người, đông mới vui.",
		},
	},
	uuid.MustParse("00000000-0000-0000-0000-0000000000b3"): {
		Greeting: "Chào bạn, Thu Trang nè (bot demo) ☕ Sáng mai cà phê không?",
		Food:     "cà phê với bánh ngọt", Place: "một quán cà phê yên tĩnh có sân vườn",
		Smalltalk: []string{
			"Mình uống bạc xỉu, còn bạn?",
			"Có quán bánh flan gần đó ngon lắm, ăn xong ghé luôn.",
			"Cuối tuần quán đông, mình đi sớm tí nha.",
		},
	},
	uuid.MustParse("00000000-0000-0000-0000-0000000000b4"): {
		Greeting: "Hello, Quốc Bảo đây (bot demo) 🍜 Sáng nay ăn phở chưa?",
		Food:     "phở", Place: "một tiệm phở bò gia truyền",
		Smalltalk: []string{
			"Phở tái nạm là số một, bạn ăn gì?",
			"Bún bò Huế cũng ngon, hôm nào đổi gió.",
			"Mình ăn sáng sớm lắm, 7h là có mặt.",
		},
	},
}

func init() {
	for id, p := range BotPersonas {
		p.ID = id
		BotPersonas[id] = p
	}
}

// BotReply picks the persona's answer to text. turn counts the bot's earlier
// messages in the chat, so smalltalk moves on instead of repeating.
func BotReply(p BotPersona, text string, turn int) string {
	t := strings.ToLower(strings.TrimSpace(text))
	words := map[string]bool{}
	for _, w := range strings.FieldsFunc(t, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }) {
		words[w] = true
	}
	// Phrases match anywhere; single words only as whole words ("hi" ≠ "thích").
	has := func(keys ...string) bool {
		for _, k := range keys {
			if strings.Contains(k, " ") && strings.Contains(t, k) || words[k] {
				return true
			}
		}
		return false
	}
	switch {
	case has("đặt bàn", "dat ban", "book", "booking"):
		return "Ok bạn bấm \"Đặt bàn cho bữa ăn này\" ngay dưới khung chat nha, mình xác nhận liền 👌"
	case has("mấy giờ", "khi nào", "lúc nào", "hôm nào", "tối nay", "cuối tuần", "mai", "when", "tonight"):
		return "Tối nay mình hơi kẹt, 7h tối thứ Sáu được không? 🙏"
	case has("ở đâu", "quán nào", "chỗ nào", "đâu", "where"):
		return "Mình biết " + p.Place + ", chốt giờ xong mình gửi địa chỉ nha."
	case has("không được", "ko được", "bận", "thôi", "no", "sorry", "hông được"):
		return "Không sao, hôm khác mình rủ lại nha 😊"
	case has("ok", "oke", "okay", "được", "đồng ý", "chốt", "yes", "deal", "nhất trí"):
		return "Chốt kèo! 🎉 Bạn đặt bàn giúp mình nhé, tới giờ mình nhắn."
	case has("bot", "ai vậy", "là ai", "who"):
		return "Mình là bot demo của AnMates — để bạn thử nhắn tin như thật đó 😄"
	case has("chào", "chao", "hello", "hi", "hí", "alo", "hey", "xin chào"):
		return "Chào bạn nha! Hôm nay thèm " + p.Food + " quá trời 😋"
	case strings.HasSuffix(t, "?"):
		return "Câu hay đó! Đi ăn " + p.Food + " rồi mình kể tiếp cho vui 😄"
	}
	if len(p.Smalltalk) == 0 {
		return "😄"
	}
	return p.Smalltalk[turn%len(p.Smalltalk)]
}

// BotTiming spaces the bot's reaction like a person's: seen, then typing, then
// the reply. Zero in tests.
type BotTiming struct {
	Seen, Typing, Reply time.Duration
}

var DefaultBotTiming = BotTiming{Seen: 700 * time.Millisecond, Typing: 500 * time.Millisecond, Reply: 1600 * time.Millisecond}

// BotService makes the demo bots behave like chat partners: matched on
// request, a greeting on the first match, then read receipt → typing → reply
// to every message, over the same hub a real partner's socket uses.
type BotService struct {
	pool   *pgxpool.Pool
	hub    wsx.HubI
	chat   *ChatService
	match  *MatchingService
	timing BotTiming
	log    *slog.Logger

	mu  sync.Mutex
	gen map[uuid.UUID]uint64 // per match: newest message wins, earlier replies are dropped
}

func NewBotService(pool *pgxpool.Pool, hub wsx.HubI, chat *ChatService, match *MatchingService, timing BotTiming, log *slog.Logger) *BotService {
	return &BotService{pool: pool, hub: hub, chat: chat, match: match, timing: timing, log: log, gen: map[uuid.UUID]uint64{}}
}

// Start matches userID with every demo bot (idempotent) and has each bot that
// hasn't spoken yet open with its greeting.
func (b *BotService) Start(ctx context.Context, userID uuid.UUID) error {
	for id, p := range BotPersonas {
		if id == userID {
			continue
		}
		m, err := b.match.MatchWith(ctx, userID, id)
		if err != nil {
			return err
		}
		var spoken bool
		if err := b.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM messages WHERE match_id = $1 AND sender_id = $2)`,
			m.ID, id).Scan(&spoken); err != nil {
			return err
		}
		if !spoken {
			if _, err := b.chat.SaveMessage(ctx, m.ID, id, p.Greeting, "text"); err != nil {
				return err
			}
		}
	}
	return nil
}

// BotIn returns the bot in the match other than senderID, if there is one.
func (b *BotService) BotIn(ctx context.Context, matchID, senderID uuid.UUID) (BotPersona, bool) {
	var partner uuid.UUID
	err := b.pool.QueryRow(ctx, `
		SELECT CASE WHEN user_a_id = $2 THEN user_b_id ELSE user_a_id END
		FROM matches WHERE id = $1`, matchID, senderID).Scan(&partner)
	if err != nil {
		return BotPersona{}, false
	}
	p, ok := BotPersonas[partner]
	return p, ok
}

// OnMessage reacts to a user's message in a bot chat, asynchronously. Only the
// newest message of a burst gets an answer.
func (b *BotService) OnMessage(matchID, senderID uuid.UUID, text string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	p, ok := b.BotIn(ctx, matchID, senderID)
	cancel()
	if !ok {
		return
	}
	b.mu.Lock()
	b.gen[matchID]++
	g := b.gen[matchID]
	b.mu.Unlock()
	go b.react(matchID, p, text, g)
}

func (b *BotService) current(matchID uuid.UUID, g uint64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.gen[matchID] == g
}

func (b *BotService) react(matchID uuid.UUID, p BotPersona, text string, g uint64) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	time.Sleep(b.timing.Seen)
	if at, err := b.chat.MarkRead(ctx, matchID, p.ID); err == nil {
		b.BroadcastRead(matchID, p.ID, at)
	}

	time.Sleep(b.timing.Typing)
	if !b.current(matchID, g) {
		return
	}
	typing, _ := json.Marshal(map[string]string{"user_id": p.ID.String()})
	b.hub.Broadcast(matchID, p.ID, wsx.Envelope{Type: "typing", Payload: typing})

	time.Sleep(b.timing.Reply)
	if !b.current(matchID, g) {
		return
	}
	var turn int
	_ = b.pool.QueryRow(ctx,
		`SELECT count(*) FROM messages WHERE match_id = $1 AND sender_id = $2`,
		matchID, p.ID).Scan(&turn)
	saved, err := b.chat.SaveMessage(ctx, matchID, p.ID, BotReply(p, text, turn), "text")
	if err != nil {
		b.log.Warn("bot reply save failed", "match_id", matchID, "err", err)
		return
	}
	b.broadcastMessage(matchID, p.ID, saved)
}

func (b *BotService) broadcastMessage(matchID, senderID uuid.UUID, m *models.Message) {
	payload, _ := json.Marshal(m)
	b.hub.Broadcast(matchID, senderID, wsx.Envelope{Type: "message", Payload: payload})
}

// BroadcastRead tells the rest of the room that userID has read up to at.
func (b *BotService) BroadcastRead(matchID, userID uuid.UUID, at time.Time) {
	BroadcastRead(b.hub, matchID, userID, at)
}

// BroadcastRead is the read-receipt envelope: {"user_id", "read_at"}.
func BroadcastRead(hub wsx.HubI, matchID, userID uuid.UUID, at time.Time) {
	payload, _ := json.Marshal(map[string]string{
		"user_id": userID.String(),
		"read_at": at.UTC().Format(time.RFC3339Nano),
	})
	hub.Broadcast(matchID, userID, wsx.Envelope{Type: "read", Payload: payload})
}
