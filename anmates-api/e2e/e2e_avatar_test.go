package e2e

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"strings"
	"testing"
	"time"
)

// cropPNG is what the app uploads: its circle crop rendered as a 512×512 PNG.
func cropPNG(t *testing.T) string {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, 512, 512))
	for y := 0; y < 512; y++ {
		for x := 0; x < 512; x++ {
			img.Set(x, y, color.NRGBA{uint8(x / 2), uint8(y / 2), 180, 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes())
}

// get fetches a public path without the JSON envelope, as an <img src> would.
func get(t *testing.T, path string, header map[string]string) *http.Response {
	t.Helper()
	req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, baseURL()+path, nil)
	for k, v := range header {
		req.Header.Set(k, v)
	}
	res, err := client.Do(req)
	if err != nil {
		t.Fatalf("GET %s: %v", path, err)
	}
	return res
}

type profileOut struct {
	ID        string  `json:"id"`
	AvatarURL *string `json:"avatar_url"`
}

func myAvatar(t *testing.T, u user) *string {
	t.Helper()
	var p profileOut
	decode(t, must(t, http.MethodGet, "/api/v1/profile", u.token, nil, 200), &p)
	return p.AvatarURL
}

// E2E-27: upload a cropped photo → it is served from our own DB at a versioned
// URL a partner's deck shows; a bundled sample and "back to default" also work;
// anything else is refused.
func TestE2E27_Avatar(t *testing.T) {
	a, b := newUser(t, "E2E Avatar A"), newUser(t, "E2E Avatar B")
	tag := fmt.Sprintf("e2e-avatar-%d", time.Now().UnixNano())
	onboard(t, a, tag)
	onboard(t, b, tag)

	// Signed out: no upload.
	if st, _ := do(t, http.MethodPut, "/api/v1/profile/avatar", "", map[string]any{"image_base64": cropPNG(t)}); st != 401 {
		t.Fatalf("upload without a token → %d, want 401", st)
	}
	// Not an image.
	must(t, http.MethodPut, "/api/v1/profile/avatar", a.token,
		map[string]any{"image_base64": base64.StdEncoding.EncodeToString([]byte("hello, not a picture"))}, 400)

	// Upload.
	var up profileOut
	decode(t, must(t, http.MethodPut, "/api/v1/profile/avatar", a.token,
		map[string]any{"image_base64": "data:image/png;base64," + cropPNG(t)}, 200), &up)
	if up.AvatarURL == nil || !strings.HasPrefix(*up.AvatarURL, "/api/v1/users/"+a.id+"/avatar?v=") {
		t.Fatalf("avatar_url after upload = %v, want /api/v1/users/%s/avatar?v=…", up.AvatarURL, a.id)
	}
	if got := myAvatar(t, a); got == nil || *got != *up.AvatarURL {
		t.Fatalf("GET /profile avatar_url = %v, want %s", got, *up.AvatarURL)
	}

	// Served as a JPEG, cacheable forever at the versioned URL, 304 on revalidation.
	res := get(t, *up.AvatarURL, nil)
	res.Body.Close()
	if res.StatusCode != 200 || res.Header.Get("Content-Type") != "image/jpeg" {
		t.Fatalf("GET avatar → %d %s, want 200 image/jpeg", res.StatusCode, res.Header.Get("Content-Type"))
	}
	if !strings.Contains(res.Header.Get("Cache-Control"), "immutable") {
		t.Fatalf("versioned avatar Cache-Control = %q, want immutable", res.Header.Get("Cache-Control"))
	}
	etag := res.Header.Get("ETag")
	res = get(t, *up.AvatarURL, map[string]string{"If-None-Match": etag})
	res.Body.Close()
	if res.StatusCode != 304 {
		t.Fatalf("GET avatar with its ETag → %d, want 304", res.StatusCode)
	}
	// Without the version it must be revalidated, or a new photo would hide behind the old one.
	res = get(t, "/api/v1/users/"+a.id+"/avatar", nil)
	res.Body.Close()
	if res.StatusCode != 200 || strings.Contains(res.Header.Get("Cache-Control"), "immutable") {
		t.Fatalf("unversioned avatar → %d %q, want 200 without immutable", res.StatusCode, res.Header.Get("Cache-Control"))
	}

	// B's deck shows A with that photo.
	var cs []struct {
		UserID    string  `json:"user_id"`
		AvatarURL *string `json:"avatar_url"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/matches", b.token, nil, 200), &cs)
	found := false
	for _, c := range cs {
		if c.UserID == a.id {
			found = true
			if c.AvatarURL == nil || *c.AvatarURL != *up.AvatarURL {
				t.Fatalf("A in B's deck has avatar_url %v, want %s", c.AvatarURL, *up.AvatarURL)
			}
		}
	}
	if !found {
		t.Fatal("A (same unique tastes) missing from B's deck")
	}

	// A bundled sample instead.
	sample := "asset:assets/v2/avatars/sample-3.png"
	must(t, http.MethodPut, "/api/v1/profile", a.token, map[string]any{"avatar_url": sample}, 200)
	if got := myAvatar(t, a); got == nil || *got != sample {
		t.Fatalf("avatar_url after picking a sample = %v, want %s", got, sample)
	}
	// Not one of ours, or someone else's host.
	for _, bad := range []string{"asset:assets/v2/avatars/sample-99.png", "https://evil.example/p.png", "/api/v1/users/" + b.id + "/avatar?v=abc"} {
		must(t, http.MethodPut, "/api/v1/profile", a.token, map[string]any{"avatar_url": bad}, 400)
	}
	// Back to the default.
	must(t, http.MethodPut, "/api/v1/profile", a.token, map[string]any{"avatar_url": ""}, 200)
	if got := myAvatar(t, a); got != nil {
		t.Fatalf("avatar_url after clearing = %q, want null", *got)
	}

	// Nobody uploaded for B.
	res = get(t, "/api/v1/users/"+b.id+"/avatar", nil)
	res.Body.Close()
	if res.StatusCode != 404 {
		t.Fatalf("avatar of a user who never uploaded → %d, want 404", res.StatusCode)
	}
}
