# Session — Jira MCP authorize + re-platform kickoff (Cline)

**Date:** 2026-09-01 ~06:05 UTC
**Agent:** Cline (VS Code extension)
**Spec:** docs/superpowers/specs/2026-08-31-onprem-k8s-replatform-design.md

## TL;DR
Authorize + verify 2 Jira MCP servers trong Cline (OAuth 2.1, scopes `read:jira-work` +
`write:jira-work`) → đọc được đầy đủ project **PI** trên site `anmatesstudio.atlassian.net`
(cloudId `9b284e38-8718-4dc9-b91a-0d55873bd1d8`). Backlog PI khớp current-task.md:
**14 epic PI-1→PI-14** (PI-1 = In Progress, còn lại To Do) + task con tới PI-89.
Cập nhật shared-memory để Cline và Claude Code làm chung trên cùng một trạng thái.

## Root cause / bối cảnh
- Trước session: Cline chưa có MCP server nào (`mcpServers: {}`), không thao tác được Jira.
- User tự add 2 plugin Jira MCP server (2 prefix tool: `atlassian__*` và `jira__*` —
  cả hai cùng auth một account, kết quả giống nhau).

## Solution / những gì đã xác minh
- **Auth OK**: user Thanh Nguyen (`5f670044e4ac20006a9231ae`), account active, email verified.
- **Site**: `anmatesstudio.atlassian.net`, 3 project nhìn thấy: **PI** (Platform &
  Infrastructure — project chính của re-platform), **Tech** (backlog cũ, 54 issue chờ user
  bulk-delete vì MCP không có tool delete), + 1 project khác.
- **PI backlog**: 14 epic PI-1→PI-14 theo phase 0→8 (PI-1 `[P0] Network Assessment &
  DNS/PKI Bootstrap` đang In Progress; PI-2 `[P0] Bare-Metal & Hypervisor Provisioning`;
  PI-3 `[P1] Cluster Platform Bootstrap`; ... PI-14 `[P8] Backup/DR`).
- **Gotcha 1 (JQL)**: server từ chối JQL unbounded — phải có điều kiện ràng buộc
  (`created >= -Nd`, `project = PI`, ...). Lỗi: "Unbounded JQL queries are not allowed here".
- **Gotcha 2 (Confluence)**: API Confluence 404 — site chưa bật Confluence hoặc MCP chỉ có
  scope Jira. Nếu cần wiki thì kiểm tra lại scope của MCP server.
- **Gotcha 3 (rate limit)**: 200 req/limit window trên search API.

## Files changed
- `.claude/shared-memory/sessions/2026-09-01-jira-mcp-authorize-replatform-kickoff.md` (new)
- `.claude/shared-memory/current-task.md` (prepend status 2026-09-01)
- `.claude/shared-memory/changelog.md` (append row)

## Verification
- getAccessibleAtlassianResources + getVisibleJiraProjects + searchJQL: PASS (200).
- Không tạo/sửa issue nào trong session này (chỉ đọc + ghi shared-memory).

## Open follow-ups
1. **PI-1 (In Progress)** — chờ user chạy lệnh khám phá trên PC host thật (`lsblk`, `df -h`,
   `virsh vol-list`, kiểm tra CGNAT/domain) — Cline/Claude Code chỉ tổng hợp kết quả.
2. Xoá 54 issue cũ trong project **Tech** (user bulk-delete tay trên web Jira).
3. 5 câu hỏi mở §16 của spec (NVMe trống · CGNAT · row users không email · IP tĩnh · tên miền).
4. Khi user confirm một session đã giải quyết xong → migrate Path A thành R-NNN.

## Key facts (grep-able)
- cloudId PI/anmatesstudio: `9b284e38-8718-4dc9-b91a-0d55873bd1d8`
- account_id: `5f670044e4ac20006a9231ae` (Thanh Nguyen, classic.nct@gmail.com)
- Jira epic keys: PI-1 … PI-14; task range: PI-16 … PI-89 (PI-15 để trống — xem changelog 2026-08-31)
- JQL error string: `Unbounded JQL queries are not allowed here. Please add a search restriction to your query.`
- Confluence v2 spaces endpoint trên server này trả HTTP 404
