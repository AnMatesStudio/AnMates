package services

import "context"

// DBLLMVenueProvider is the legacy concierge data source: it searches the local
// `restaurants` table for candidates near the midpoint, asks the LLM to rank them,
// and enforces the anti-hallucination rule (only ids that exist in the DB survive,
// venue facts copied from the DB row). Kept as a fallback for deployments that have
// a seeded restaurants table and no ai-venue-search service.
type DBLLMVenueProvider struct {
	venues *VenueEngine
	llm    LLMClient
}

func NewDBLLMVenueProvider(venues *VenueEngine, llm LLMClient) *DBLLMVenueProvider {
	return &DBLLMVenueProvider{venues: venues, llm: llm}
}

func (p *DBLLMVenueProvider) Suggest(ctx context.Context, mid LatLng, mood []string, budgetMin, budgetMax, radiusM, limit int) (intro string, picks []CardPick, costTokens int, err error) {
	candidates, err := p.venues.SearchCandidates(ctx, mid, budgetMin, budgetMax, radiusM, limit)
	if err != nil {
		return "", nil, 0, err
	}
	if len(candidates) == 0 {
		return "", nil, 0, nil // no candidates → caller records skipped_preconds
	}

	out, err := p.llm.Rank(ctx, ConciergeInput{
		MoodTags: mood, BudgetMin: budgetMin, BudgetMax: budgetMax, Candidates: candidates,
	})
	if err != nil {
		return "", nil, 0, err
	}

	picks = validatePicks(out.Picks, candidates, 3)
	return out.Intro, picks, out.CostTokens, nil
}
