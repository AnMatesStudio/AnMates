# Đã chuyển sang repo `AnMates-Data-Bridge`

Thiết kế và runbook cho tuyến sync Data-Pipeline → catalog on-prem nay nằm ở
**https://github.com/AnMatesStudio/AnMates-Data-Bridge**:

| Nội dung cũ ở đây | Vị trí mới |
|---|---|
| Kiến trúc + quyết định | `docs/architecture.md` |
| Diagram | `docs/architecture.html` |
| Runbook setup 2 máy | `docs/RUNBOOK.md` |
| compose + systemd unit | `docker-compose.yml`, `deploy/data-bridge.service` |

**Vẫn ở lại repo này** (không chuyển được): `anmates-api/db/migrations/014_pipeline_source.sql`
và `015_sync_ledger.sql`. Chúng đi vào binary `api` qua `//go:embed migrations/*.sql` trong
`anmates-api/db/migrate.go` — tách ra khỏi repo là migration runner không thấy nữa.
