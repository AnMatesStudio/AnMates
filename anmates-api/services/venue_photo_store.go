package services

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MaxVenuePhotoBytes caps a single stored image. Base64 inflates by ~4/3, so a
// 3 MiB photo costs ~4 MiB of text in the row.
const MaxVenuePhotoBytes = 3 << 20

// ErrPhotoNotFound is returned when a venue has no photo in the requested slot.
var ErrPhotoNotFound = errors.New("venue photo not found")

// ErrUnsupportedImageType is returned for bytes that aren't a supported image.
var ErrUnsupportedImageType = errors.New("unsupported image type")

// VenuePhoto is one stored image. Data holds the DECODED bytes; the base64 text
// only exists at rest in the DB, so callers never deal with the encoding.
type VenuePhoto struct {
	RestaurantID uuid.UUID
	Position     int
	MIMEType     string
	Data         []byte
	SHA256       string
}

// VenuePhotoStore persists venue images as base64 text in the venue_photos table.
//
// Storing bytes rather than a URL is deliberate: the previous approach kept links
// to the data pipeline's own ngrok tunnel, and every photo broke when the tunnel
// went away. See db/migrations/014_venue_photo_blobs.sql.
type VenuePhotoStore struct {
	pool *pgxpool.Pool
}

func NewVenuePhotoStore(pool *pgxpool.Pool) *VenuePhotoStore {
	return &VenuePhotoStore{pool: pool}
}

// supportedImageMIME sniffs the bytes rather than trusting a caller-supplied
// content type — the ingest endpoint accepts base64 from the pipeline, and a
// mislabelled blob would be served back with the wrong Content-Type.
func supportedImageMIME(data []byte) (string, bool) {
	switch http.DetectContentType(data) {
	case "image/jpeg":
		return "image/jpeg", true
	case "image/png":
		return "image/png", true
	case "image/webp":
		return "image/webp", true
	case "image/gif":
		return "image/gif", true
	default:
		return "", false
	}
}

// Put stores one decoded image in a venue's gallery slot, replacing whatever
// occupied that slot. Re-storing identical bytes for the same venue is a no-op,
// so the pipeline can re-run without churning rows.
func (s *VenuePhotoStore) Put(ctx context.Context, restaurantID uuid.UUID, position int, data []byte, sourceURL string) (VenuePhoto, error) {
	if len(data) == 0 {
		return VenuePhoto{}, fmt.Errorf("%w: empty body", ErrUnsupportedImageType)
	}
	if len(data) > MaxVenuePhotoBytes {
		return VenuePhoto{}, fmt.Errorf("image too large: %d bytes (max %d)", len(data), MaxVenuePhotoBytes)
	}
	mime, ok := supportedImageMIME(data)
	if !ok {
		return VenuePhoto{}, ErrUnsupportedImageType
	}

	sum := sha256.Sum256(data)
	digest := hex.EncodeToString(sum[:])
	encoded := base64.StdEncoding.EncodeToString(data)

	// Two unique constraints guard this table: one per (venue, slot) and one per
	// (venue, image). Clear any *other* slot already holding these exact bytes so
	// the slot upsert below can't collide with the dedup index.
	if _, err := s.pool.Exec(ctx,
		`DELETE FROM venue_photos WHERE restaurant_id = $1 AND sha256 = $2 AND position <> $3`,
		restaurantID, digest, position); err != nil {
		return VenuePhoto{}, err
	}

	_, err := s.pool.Exec(ctx, `
		INSERT INTO venue_photos (restaurant_id, position, data_base64, mime_type, byte_size, sha256, source_url)
		VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, ''))
		ON CONFLICT (restaurant_id, position) DO UPDATE SET
			data_base64 = EXCLUDED.data_base64,
			mime_type   = EXCLUDED.mime_type,
			byte_size   = EXCLUDED.byte_size,
			sha256      = EXCLUDED.sha256,
			source_url  = EXCLUDED.source_url,
			created_at  = now()
	`, restaurantID, position, encoded, mime, len(data), digest, sourceURL)
	if err != nil {
		return VenuePhoto{}, err
	}

	return VenuePhoto{
		RestaurantID: restaurantID,
		Position:     position,
		MIMEType:     mime,
		Data:         data,
		SHA256:       digest,
	}, nil
}

// Get returns the decoded image in a venue's slot. The base64 text is decoded
// here so no caller above this layer has to know the storage encoding.
func (s *VenuePhotoStore) Get(ctx context.Context, restaurantID uuid.UUID, position int) (VenuePhoto, error) {
	var (
		encoded string
		mime    string
		digest  string
	)
	err := s.pool.QueryRow(ctx, `
		SELECT data_base64, mime_type, sha256
		FROM venue_photos
		WHERE restaurant_id = $1 AND position = $2
	`, restaurantID, position).Scan(&encoded, &mime, &digest)
	if errors.Is(err, pgx.ErrNoRows) {
		return VenuePhoto{}, ErrPhotoNotFound
	}
	if err != nil {
		return VenuePhoto{}, err
	}

	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return VenuePhoto{}, fmt.Errorf("decode stored photo: %w", err)
	}

	return VenuePhoto{
		RestaurantID: restaurantID,
		Position:     position,
		MIMEType:     mime,
		Data:         data,
		SHA256:       digest,
	}, nil
}

// CountsFor returns how many stored photos each of the given venues has. Used by
// the catalogue listing to emit only photo URLs that will actually resolve.
func (s *VenuePhotoStore) CountsFor(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]int, error) {
	out := make(map[uuid.UUID]int, len(ids))
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT restaurant_id, count(*)
		FROM venue_photos
		WHERE restaurant_id = ANY($1)
		GROUP BY restaurant_id
	`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var id uuid.UUID
		var n int
		if err := rows.Scan(&id, &n); err != nil {
			return nil, err
		}
		out[id] = n
	}
	return out, rows.Err()
}
