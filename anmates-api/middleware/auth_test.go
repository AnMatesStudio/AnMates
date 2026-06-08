package middleware

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

var testSecret = []byte("test-secret-key")

func newTestApp(handlerRan *bool) *fiber.App {
	app := fiber.New()
	app.Get("/probe", JWT(testSecret), func(c *fiber.Ctx) error {
		*handlerRan = true
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"user_id": UserID(c).String()})
	})
	return app
}

func TestJWT_NoToken_Returns401_HandlerNotRun(t *testing.T) {
	ran := false
	app := newTestApp(&ran)

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != fiber.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
	if ran {
		t.Error("handler must not run when no token provided")
	}
}

func TestJWT_GarbageToken_Returns401_HandlerNotRun(t *testing.T) {
	ran := false
	app := newTestApp(&ran)

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("Authorization", "Bearer this.is.garbage")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != fiber.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
	if ran {
		t.Error("handler must not run for garbage token")
	}
}

func TestJWT_ValidToken_Returns200_HandlerRan_UserIDCorrect(t *testing.T) {
	ran := false
	app := newTestApp(&ran)

	uid := uuid.New()
	tok, _, err := SignAccessToken(testSecret, uid, time.Hour)
	if err != nil {
		t.Fatalf("SignAccessToken: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != fiber.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("want 200, got %d: %s", resp.StatusCode, body)
	}
	if !ran {
		t.Error("handler must run for a valid token")
	}
}
