package services

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	_ "image/png" // registers the PNG decoder the app's crop is sent in
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	// MaxAvatarUploadBytes caps the decoded upload. The app sends a 512×512 PNG,
	// well under this; a 2 MiB photo is ~2.7 MiB of base64 JSON, inside the 4 MiB body limit.
	MaxAvatarUploadBytes = 2 << 20
	// MaxAvatarSide / MinAvatarSide bound each dimension: the app crops to 512.
	MaxAvatarSide     = 1024
	MinAvatarSide     = 64
	avatarJPEGQuality = 88
)

var (
	ErrAvatarTooLarge   = errors.New("avatar too large")
	ErrAvatarDimensions = errors.New("avatar dimensions out of range")
	ErrAvatarNotFound   = errors.New("avatar not found")
)

// NormalizeAvatar checks an uploaded photo and re-encodes it as a JPEG on white:
// the stored bytes are always one type, carry no EXIF (location!) or other
// metadata, and a PNG's transparent pixels don't turn black.
func NormalizeAvatar(data []byte) ([]byte, error) {
	if len(data) > MaxAvatarUploadBytes {
		return nil, fmt.Errorf("%w: %d bytes (max %d)", ErrAvatarTooLarge, len(data), MaxAvatarUploadBytes)
	}
	switch http.DetectContentType(data) {
	case "image/jpeg", "image/png":
	default:
		return nil, ErrUnsupportedImageType
	}
	// Dimensions before decoding, so a tiny file claiming a huge canvas is
	// refused without allocating it.
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupportedImageType, err)
	}
	if cfg.Width > MaxAvatarSide || cfg.Height > MaxAvatarSide ||
		cfg.Width < MinAvatarSide || cfg.Height < MinAvatarSide {
		return nil, fmt.Errorf("%w: %dx%d (each side %d–%d)", ErrAvatarDimensions,
			cfg.Width, cfg.Height, MinAvatarSide, MaxAvatarSide)
	}
	src, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupportedImageType, err)
	}

	b := src.Bounds()
	flat := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(flat, flat.Bounds(), image.NewUniform(color.White), image.Point{}, draw.Src)
	draw.Draw(flat, flat.Bounds(), src, b.Min, draw.Over)

	var out bytes.Buffer
	if err := jpeg.Encode(&out, flat, &jpeg.Options{Quality: avatarJPEGQuality}); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

// AvatarPath is the serving route of a user's uploaded photo, versioned by the
// first 12 hex digits of its sha256 so every new photo is a new URL.
func AvatarPath(userID, sha string) string {
	v := sha
	if len(v) > 12 {
		v = v[:12]
	}
	return "/api/v1/users/" + userID + "/avatar?v=" + v
}

// Avatar is a user's stored photo, decoded.
type Avatar struct {
	Data   []byte
	SHA256 string
}

// AvatarStore keeps each user's uploaded photo in user_avatars (migration 021).
type AvatarStore struct {
	pool *pgxpool.Pool
}

func NewAvatarStore(pool *pgxpool.Pool) *AvatarStore { return &AvatarStore{pool: pool} }

// Put normalizes and stores [data] as the user's photo and points avatar_url at
// it, in one transaction. Returns the new avatar_url.
func (s *AvatarStore) Put(ctx context.Context, userID uuid.UUID, data []byte) (string, error) {
	jpg, err := NormalizeAvatar(data)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(jpg)
	digest := hex.EncodeToString(sum[:])
	path := AvatarPath(userID.String(), digest)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op after Commit

	if _, err := tx.Exec(ctx, `
		INSERT INTO user_avatars (user_id, data_base64, mime_type, byte_size, sha256)
		VALUES ($1, $2, 'image/jpeg', $3, $4)
		ON CONFLICT (user_id) DO UPDATE SET
			data_base64 = EXCLUDED.data_base64,
			byte_size   = EXCLUDED.byte_size,
			sha256      = EXCLUDED.sha256,
			updated_at  = now()
	`, userID, base64.StdEncoding.EncodeToString(jpg), len(jpg), digest); err != nil {
		return "", err
	}
	if _, err := tx.Exec(ctx, `UPDATE users SET avatar_url = $2 WHERE id = $1`, userID, path); err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return path, nil
}

// Get returns the user's stored photo, or ErrAvatarNotFound.
func (s *AvatarStore) Get(ctx context.Context, userID uuid.UUID) (Avatar, error) {
	var encoded, digest string
	err := s.pool.QueryRow(ctx,
		`SELECT data_base64, sha256 FROM user_avatars WHERE user_id = $1`, userID,
	).Scan(&encoded, &digest)
	if errors.Is(err, pgx.ErrNoRows) {
		return Avatar{}, ErrAvatarNotFound
	}
	if err != nil {
		return Avatar{}, err
	}
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return Avatar{}, fmt.Errorf("decode stored avatar: %w", err)
	}
	return Avatar{Data: data, SHA256: digest}, nil
}
