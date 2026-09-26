package services

import (
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestBotReply(t *testing.T) {
	p := BotPersonas[uuid.MustParse("00000000-0000-0000-0000-0000000000b1")]
	cases := []struct {
		name, in, want string
	}{
		{"booking", "Đặt bàn luôn nha", "Đặt bàn cho bữa ăn này"},
		{"tonight is a time question, not a refusal", "Tối nay đi lẩu không?", "thứ Sáu"},
		{"where", "Quán nào vậy?", p.Place},
		{"refusal", "Mình bận rồi", "hôm khác"},
		{"agree", "Ok luôn", "Chốt kèo"},
		{"greeting", "Hi bạn", "Chào bạn"},
		{"hi inside a word is not a greeting", "mình thích ăn cay", p.Smalltalk[2]},
		{"who", "Bạn là bot hả", "bot demo"},
		{"other question", "Bạn học trường nào?", "Câu hay đó"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := BotReply(p, tc.in, 2); !strings.Contains(got, tc.want) {
				t.Fatalf("BotReply(%q) = %q, want it to contain %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestBotReplySmalltalkMovesOn(t *testing.T) {
	p := BotPersonas[uuid.MustParse("00000000-0000-0000-0000-0000000000b2")]
	if BotReply(p, "hmm", 0) == BotReply(p, "hmm", 1) {
		t.Fatal("smalltalk repeated itself on consecutive turns")
	}
}

func TestBotPersonasHaveIDs(t *testing.T) {
	if len(BotPersonas) != 4 {
		t.Fatalf("want 4 bots (migration 016), got %d", len(BotPersonas))
	}
	for id, p := range BotPersonas {
		if p.ID != id || p.Greeting == "" {
			t.Fatalf("persona %s: id %s, greeting %q", id, p.ID, p.Greeting)
		}
	}
}
