package handlers

import "testing"

func TestValidAvatarChoice(t *testing.T) {
	const me = "7f7c1d1e-0000-4000-8000-000000000001"
	const other = "7f7c1d1e-0000-4000-8000-000000000002"

	ok := []string{
		"", // back to the app's default
		"asset:assets/v2/avatar-chibi.png",
		"asset:assets/v2/avatars/sample-1.png",
		"asset:assets/v2/avatars/sample-10.png",
		"/api/v1/users/" + me + "/avatar?v=0123456789ab", // my own upload
	}
	bad := []string{
		"asset:assets/v2/avatars/sample-11.png",
		"asset:assets/v2/avatars/sample-0.png",
		"asset:assets/v2/hotpot.png",
		"asset:../../secrets.png",
		"asset:assets/v2/avatars/sample-1.png?x",
		"https://evil.example/pixel.png", // would leak viewers' IPs to any host
		"http://example.com/a.jpg",
		"/api/v1/users/" + other + "/avatar?v=0123456789ab",
		"/api/v1/users/" + me + "/avatar",
		"javascript:alert(1)",
	}
	for _, s := range ok {
		if !validAvatarChoice(me, s) {
			t.Errorf("validAvatarChoice(%q) = false, want true", s)
		}
	}
	for _, s := range bad {
		if validAvatarChoice(me, s) {
			t.Errorf("validAvatarChoice(%q) = true, want false", s)
		}
	}
}

func TestDecodeImageBase64(t *testing.T) {
	for _, in := range []string{"aGVsbG8=", "data:image/png;base64,aGVsbG8=", "  aGVs\nbG8=  "} {
		got, err := decodeImageBase64(in)
		if err != nil || string(got) != "hello" {
			t.Errorf("decodeImageBase64(%q) = %q, %v; want \"hello\"", in, got, err)
		}
	}
	if _, err := decodeImageBase64("%%% not base64"); err == nil {
		t.Error("decodeImageBase64 accepted garbage")
	}
}
