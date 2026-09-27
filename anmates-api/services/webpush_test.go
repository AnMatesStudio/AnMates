package services

import "testing"

func TestAllowedPushEndpoint(t *testing.T) {
	cases := []struct {
		name         string
		endpoint     string
		allowAnyHost bool
		want         bool
	}{
		{"fcm https", "https://fcm.googleapis.com/fcm/send/x", false, true},
		{"firefox wpush", "https://updates.push.services.mozilla.com/wpush/v2/x", false, true},
		{"apple web push", "https://web.push.apple.com/x", false, true},
		{"windows wns", "https://wns2-par02p.notify.windows.com/w/?token=x", false, true},
		{"chromium jmt17 https", "https://jmt17.google.com/fcm/send/x", false, true},
		{"jmt17 suffix after allowed host", "https://jmt17.google.com.evil.com/x", false, false},
		{"jmt17 superstring without dot", "https://xjmt17.google.com/x", false, false},
		{"jmt17 plain http refused", "http://jmt17.google.com/x", false, false},
		{"plain http refused", "http://fcm.googleapis.com/x", false, false},
		{"suffix after allowed host", "https://fcm.googleapis.com.evil.com/x", false, false},
		{"superstring without dot", "https://evilfcm.googleapis.com/x", false, false},
		{"aws metadata ip", "https://169.254.169.254/latest", false, false},
		{"localhost", "https://localhost/x", false, false},
		{"not a url", "not a url", false, false},
		{"dev endpoint with allowAnyHost", "http://e2e:9099/push/1", true, true},
		{"dev endpoint refused in prod", "http://e2e:9099/push/1", false, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := AllowedPushEndpoint(tc.endpoint, tc.allowAnyHost); got != tc.want {
				t.Fatalf("AllowedPushEndpoint(%q, %v) = %v, want %v", tc.endpoint, tc.allowAnyHost, got, tc.want)
			}
		})
	}
}
