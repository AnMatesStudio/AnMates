package services

import "testing"

const bingReviewFixture = `
<html><body>
<ol id="b_results">
  <li class="b_algo">
    <h2><a href="https://www.foody.vn/ho-chi-minh/quan-abc">Quán ABC - Foody.vn</a></h2>
    <div class="b_caption">
      <div class="b_attribution">Xếp hạng: 4,5/5 &middot; 1.234 đánh giá</div>
      <p>Quán ABC nổi tiếng với lẩu bò ngon, không gian rộng rãi, phục vụ nhiệt tình, giá cả hợp lý.</p>
    </div>
  </li>
  <li class="b_algo">
    <h2><a href="https://tripadvisor.com.vn/abc">Quán ABC</a></h2>
    <div class="b_caption"><p>Mình ghé Quán ABC cuối tuần, món ăn ngon, view đẹp, sẽ quay lại lần sau nhé mọi người.</p></div>
  </li>
  <li class="b_algo">
    <h2><a href="https://example.com/admin">Cổng thông tin</a></h2>
    <div class="b_caption"><p>Trang thông tin hành chính của thành phố và các thủ tục liên quan tới cư dân.</p></div>
  </li>
</ol>
</body></html>`

func TestParseBingReviews(t *testing.T) {
	info := parseBingReviews(bingReviewFixture, significantTokens("Quán ABC"))

	if info.Rating != 4.5 {
		t.Errorf("rating = %v, want 4.5", info.Rating)
	}
	if info.ReviewCount != 1234 {
		t.Errorf("review count = %d, want 1234", info.ReviewCount)
	}
	// Two relevant snippets; the generic admin page is filtered out.
	if len(info.Highlights) != 2 {
		t.Fatalf("highlights = %d, want 2: %+v", len(info.Highlights), info.Highlights)
	}
	if info.Highlights[0].Source != "foody.vn" {
		t.Errorf("first source = %q, want foody.vn", info.Highlights[0].Source)
	}
	for _, h := range info.Highlights {
		if h.Text == "" {
			t.Error("empty highlight text")
		}
	}
}

func TestParseBingReviews_Empty(t *testing.T) {
	info := parseBingReviews("<html><body>no results</body></html>", []string{"abc"})
	if info.Rating != 0 || info.ReviewCount != 0 || len(info.Highlights) != 0 {
		t.Errorf("expected zero ReviewInfo, got %+v", info)
	}
}

func TestPrepareReviewSearchQuery(t *testing.T) {
	got := prepareReviewSearchQuery("Lẩu Bò Giáo Toàn Phường 5")
	want := "Lẩu Bò Giáo Toàn đánh giá review"
	if got != want {
		t.Errorf("prepareReviewSearchQuery = %q, want %q", got, want)
	}
}
