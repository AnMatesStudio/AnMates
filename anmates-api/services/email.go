package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"
	"time"
)

// EmailSender delivers a transactional email. Implementations must be safe for
// concurrent use. textBody is the plain-text fallback; htmlBody is the rich
// version (pass "" to send text only).
type EmailSender interface {
	Send(ctx context.Context, to, subject, textBody, htmlBody string) error
}

// SMTPSender sends mail over SMTP with STARTTLS + PLAIN auth. It is tuned for
// Gmail (smtp.gmail.com:587 + a Google App Password) but works with any
// STARTTLS-capable provider. net/smtp's SendMail upgrades the connection to TLS
// automatically when the server advertises STARTTLS, then authenticates.
type SMTPSender struct {
	addr     string // "host:port", e.g. "smtp.gmail.com:587"
	host     string // bare host, used for the PLAIN auth realm
	auth     smtp.Auth
	from     string // envelope + From header address
	fromName string // optional display name in the From header
}

// NewSMTPSender builds an SMTPSender. username/password are the SMTP credentials
// (for Gmail: the account address + a 16-char App Password). from defaults to the
// username when empty.
func NewSMTPSender(host string, port int, username, password, from, fromName string) *SMTPSender {
	if from == "" {
		from = username
	}
	return &SMTPSender{
		addr:     fmt.Sprintf("%s:%d", host, port),
		host:     host,
		auth:     smtp.PlainAuth("", username, password, host),
		from:     from,
		fromName: fromName,
	}
}

func (s *SMTPSender) Send(ctx context.Context, to, subject, textBody, htmlBody string) error {
	msg := buildMessage(s.from, s.fromName, to, subject, textBody, htmlBody)
	// net/smtp has no context support; run it on a goroutine so a cancelled
	// request context can stop us waiting on a slow/hung SMTP server.
	done := make(chan error, 1)
	go func() {
		done <- smtp.SendMail(s.addr, s.auth, s.from, []string{to}, msg)
	}()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case err := <-done:
		if err != nil {
			return fmt.Errorf("smtp send: %w", err)
		}
		return nil
	}
}

// buildMessage assembles an RFC 5322 message. With an htmlBody it emits a
// multipart/alternative body so clients render the HTML while text-only clients
// fall back to textBody; without one it sends plain text.
func buildMessage(from, fromName, to, subject, textBody, htmlBody string) []byte {
	fromHeader := from
	if fromName != "" {
		// RFC 2047 encode the display name so UTF-8 (e.g. "ĂnMates") survives.
		fromHeader = fmt.Sprintf("%s <%s>", encodeHeaderWord(fromName), from)
	}
	var b strings.Builder
	b.WriteString("From: " + fromHeader + "\r\n")
	b.WriteString("To: " + to + "\r\n")
	b.WriteString("Subject: " + encodeHeaderWord(subject) + "\r\n")
	b.WriteString("Date: " + time.Now().Format(time.RFC1123Z) + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")

	if htmlBody == "" {
		b.WriteString("Content-Type: text/plain; charset=\"UTF-8\"\r\n")
		b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
		b.WriteString(textBody)
		return []byte(b.String())
	}

	boundary := randomBoundary()
	b.WriteString("Content-Type: multipart/alternative; boundary=\"" + boundary + "\"\r\n\r\n")
	b.WriteString("--" + boundary + "\r\n")
	b.WriteString("Content-Type: text/plain; charset=\"UTF-8\"\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
	b.WriteString(textBody + "\r\n\r\n")
	b.WriteString("--" + boundary + "\r\n")
	b.WriteString("Content-Type: text/html; charset=\"UTF-8\"\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
	b.WriteString(htmlBody + "\r\n\r\n")
	b.WriteString("--" + boundary + "--\r\n")
	return []byte(b.String())
}

// encodeHeaderWord RFC 2047 base64-encodes a header value when it has non-ASCII
// bytes (so Vietnamese diacritics in Subject/From render correctly everywhere).
func encodeHeaderWord(s string) string {
	ascii := true
	for i := 0; i < len(s); i++ {
		if s[i] > 127 {
			ascii = false
			break
		}
	}
	if ascii {
		return s
	}
	return "=?UTF-8?B?" + base64.StdEncoding.EncodeToString([]byte(s)) + "?="
}

func randomBoundary() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return "anmates_" + hex.EncodeToString(b)
}

// LogSender is a dev fallback used when SMTP is not configured: it logs the email
// (including the OTP) instead of delivering it, so local/dev flows still work
// without credentials. NEVER selected in production paths — main.go only wires it
// when SMTP env vars are absent and warns loudly.
type LogSender struct{ log *slog.Logger }

func NewLogSender(log *slog.Logger) *LogSender { return &LogSender{log: log} }

func (l *LogSender) Send(_ context.Context, to, subject, textBody, _ string) error {
	l.log.Warn("email NOT sent (SMTP unconfigured) — logging instead",
		"to", to, "subject", subject, "body", textBody)
	return nil
}
