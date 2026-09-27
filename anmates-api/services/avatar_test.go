package services

import (
	"bytes"
	"errors"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"testing"
)

func encodePNG(t *testing.T, w, h int, fill color.Color) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, fill)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestNormalizeAvatar_PNGBecomesJPEGOnWhite(t *testing.T) {
	// Fully transparent: a JPEG has no alpha, and a naive re-encode paints it black.
	in := encodePNG(t, 512, 512, color.NRGBA{0, 0, 0, 0})

	out, err := NormalizeAvatar(in)
	if err != nil {
		t.Fatalf("NormalizeAvatar: %v", err)
	}
	img, format, err := image.Decode(bytes.NewReader(out))
	if err != nil || format != "jpeg" {
		t.Fatalf("output is %q (err %v), want a jpeg", format, err)
	}
	if b := img.Bounds(); b.Dx() != 512 || b.Dy() != 512 {
		t.Fatalf("output is %v, want 512x512", b)
	}
	r, g, bl, _ := img.At(256, 256).RGBA()
	if r>>8 < 240 || g>>8 < 240 || bl>>8 < 240 {
		t.Fatalf("transparent pixel came out rgb(%d,%d,%d), want white", r>>8, g>>8, bl>>8)
	}
}

func TestNormalizeAvatar_JPEGIsReencoded(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 300, 200))
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, src, nil); err != nil {
		t.Fatal(err)
	}
	out, err := NormalizeAvatar(buf.Bytes())
	if err != nil {
		t.Fatalf("NormalizeAvatar: %v", err)
	}
	cfg, format, err := image.DecodeConfig(bytes.NewReader(out))
	if err != nil || format != "jpeg" || cfg.Width != 300 || cfg.Height != 200 {
		t.Fatalf("got %s %dx%d (err %v), want jpeg 300x200", format, cfg.Width, cfg.Height, err)
	}
}

func TestNormalizeAvatar_Rejects(t *testing.T) {
	var gifBuf bytes.Buffer
	_ = gif.Encode(&gifBuf, image.NewPaletted(image.Rect(0, 0, 100, 100), []color.Color{color.Black}), nil)

	cases := []struct {
		name string
		in   []byte
		want error
	}{
		{"empty", nil, ErrUnsupportedImageType},
		{"text", []byte("definitely not an image, just some text bytes"), ErrUnsupportedImageType},
		{"gif", gifBuf.Bytes(), ErrUnsupportedImageType},
		{"too wide", encodePNG(t, MaxAvatarSide+1, 100, color.White), ErrAvatarDimensions},
		{"too small", encodePNG(t, MinAvatarSide-1, MinAvatarSide-1, color.White), ErrAvatarDimensions},
		{"too many bytes", append(encodePNG(t, 100, 100, color.White), make([]byte, MaxAvatarUploadBytes)...), ErrAvatarTooLarge},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := NormalizeAvatar(tc.in); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestAvatarPath(t *testing.T) {
	got := AvatarPath("7f7c1d1e-0000-4000-8000-000000000001", "0123456789abcdef0123")
	want := "/api/v1/users/7f7c1d1e-0000-4000-8000-000000000001/avatar?v=0123456789ab"
	if got != want {
		t.Fatalf("AvatarPath = %q, want %q", got, want)
	}
}
