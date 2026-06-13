package services

import "strings"

// maxOnboardingKeywords bounds how many Goong AutoComplete keywords a user's
// onboarding tags expand to. Each keyword costs 1 autocomplete + up to N Detail
// calls, so the personalized fan-out must stay sane.
const maxOnboardingKeywords = 8

// onboardingKeywordMap decodes the playful onboarding tag keys (food/vibe/culture
// — see the Flutter onboarding screens) into REAL Vietnamese food-search keywords
// that actually appear in venue names (Goong AutoComplete matches on the name).
// Keys are unique across the three dimensions, so one combined map suffices.
// Dietary/generic tags map to nil (no useful search term).
var onboardingKeywordMap = map[string][]string{
	// ── Gú Ẩm Thực (food) ──
	"fwb":      {"quán nhậu", "bia"},     // Food with beer
	"ons":      {"trà sữa"},              // Olong nướng sữa (trà sữa)
	"419":      {"bún"},                  // Bún mọc chín
	"sgbb":     {"chè", "sầu riêng"},     // Sầu riêng bỡ béo
	"sgdd":     {"lẩu dê", "cháo"},       // Súp gà đùi dê
	"ck":       {"cà phê", "kem"},        // Cafe kem
	"vk":       {"quán chay", "cơm chay"}, // Vegetarian Kho Chay
	"ex":       {"ốc", "ếch"},            // Ếch xiên
	"bx":       {"bò nướng", "lẩu bò"},   // Bò Xào (beef lover)
	"ox":       {"ốc", "hải sản"},        // Ốc xào (seafood lover)
	"spicy":    {"lẩu thái", "mì cay"},   // Ăn cay
	"sweetie":  {"chè", "bánh ngọt"},     // Sweetie
	"no_onion": nil,                      // dietary restriction → no keyword

	// ── Nền văn minh (culture / cuisine nationality) ──
	"vn": {"cơm tấm", "phở"},
	"kr": {"quán hàn", "gà hàn quốc"},
	"jp": {"sushi", "ramen"},
	"th": {"lẩu thái", "món thái"},
	"tw": {"trà sữa"},
	"cn": {"dimsum", "mì hoa"},
	"us": {"burger", "gà rán"},

	// ── Vibe buổi ăn (ambiance) ──
	"party":   {"quán nhậu", "bia"},
	"quiet":   {"cà phê"},
	"street":  {"ăn vặt", "quán vỉa hè"},
	"explore": nil, // generic — let the default keywords cover it
	"fancy":   {"nhà hàng", "buffet"},
	"yolo":    nil,
	"chill":   nil,
}

// FoodKeywordsFromOnboarding maps a user's onboarding selections to Goong search
// keywords (deduped, order-preserving, capped at maxOnboardingKeywords). Returns
// nil when no tag yields a keyword, so the caller falls back to the default set.
func FoodKeywordsFromOnboarding(food, vibe, culture []string) []string {
	out := make([]string, 0, maxOnboardingKeywords)
	seen := make(map[string]bool)
	add := func(tags []string) {
		for _, tag := range tags {
			key := strings.ToLower(strings.TrimSpace(tag))
			for _, kw := range onboardingKeywordMap[key] {
				if len(out) >= maxOnboardingKeywords {
					return // cap checked BEFORE appending so we never overshoot
				}
				if seen[kw] {
					continue
				}
				seen[kw] = true
				out = append(out, kw)
			}
		}
	}
	// food first (most specific to taste), then culture (cuisine), then vibe.
	add(food)
	add(culture)
	add(vibe)
	if len(out) == 0 {
		return nil
	}
	return out
}
