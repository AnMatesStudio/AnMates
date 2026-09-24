# 2026-09-24 — Self-hosted runner container trên devops-pc + auto CD helm

## TL;DR
CI (`.github/workflows/ci.yml`) chuyển từ `ubuntu-latest` sang **self-hosted runner chạy
dạng container** trên devops-pc (`deploy/runner/`), và job cuối đổi từ "in lệnh helm để chạy
tay" thành **tự `helm upgrade`** vào k8s on-prem khi push `main` xanh. Runner tự lên lại sau
reboot (`restart: unless-stopped` + docker enabled), credential đăng ký giữ trong volume nên
không cần token lại.

## Quyết định
- **2 runner** (`devops-pc-1/2`) để lane api + web chạy song song. Label giữ `pc-runner,
  ubuntu-runner` như runner native cũ `devops-pc` (đang Offline, cần gỡ).
- **Docker-outside-of-Docker** (mount `/var/run/docker.sock`), buildx `driver: docker` →
  layer cache nằm sẵn ở daemon host; bỏ `type=gha` cache trên self-hosted.
- **`network_mode: host` BẮT BUỘC**: cụm là VM KVM trên libvirt NAT `virbr1` (10.10.10.0/24);
  libvirt chỉ ACCEPT traffic vào virbr1 nếu ESTABLISHED → từ `docker0` tới 10.10.10.11:6443
  bị REJECT, từ host netns thì đi được.
- **Toolchain bake vào image**: Go 1.25.x (resolve patch mới nhất lúc build), gcc (race),
  golangci-lint v2.12.2, Flutter 3.44.0 (Dart 3.12.0, khớp máy dev), Helm **v4.0.0**
  (→ `--rollback-on-failure`, tên mới của `--atomic`), kubectl stable.
- **Kubeconfig không nằm trên GitHub**: SA `ci-deployer` chỉ quyền ns `anmates`
  (`rbac-deployer.yaml`), file `deploy/runner/kubeconfig` mount read-only, uid 1001.
- **Repo PUBLIC** → PR từ fork tự route sang `ubuntu-latest` (steps setup-go/flutter-action/
  golangci-lint-action chỉ chạy khi `runner.environment == 'github-hosted'`). Đây chỉ là lớp 2;
  lớp chính là setting "Require approval for all external contributors".
- Thêm `deploy/charts/anmates/**` vào path filter (đổi chart cũng deploy).
- Job deploy: `environment: production`, `concurrency: deploy-production` (không cancel),
  pre-flight secret `ghcr-pull`+`anmates-api`, smoke `kubectl exec deploy/anmates-web -- wget
  http://127.0.0.1/health` (đi qua nginx → Service anmates-api).

## Files
- `deploy/runner/{Dockerfile,entrypoint.sh,docker-compose.yml,.env.example,.gitignore,rbac-deployer.yaml,README.md,scripts/make-deployer-kubeconfig.sh}` (mới)
- `.github/workflows/ci.yml` (viết lại), `.github/actionlint.yaml` (mới, khai báo label)
- banner `.github/{CI-CD,WORKFLOW-ARCHITECTURE}.md`, comment `values-prod.yaml`, plan 2026-09-01 §1 + H4

## Verification (trên Mac, OrbStack, `--platform linux/amd64`)
- `docker build` image OK; step verify in ra go1.25.14, golangci-lint 2.12.2, helm v4.0.0, kubectl v1.37.1, docker 29.7.2, buildx 0.36.1.
- Trong image, trên code HEAD: `go vet` OK, `go test` all ok, `go test -race ./middleware ./ws` OK,
  `golangci-lint run` 0 issues, `flutter pub get/analyze` (2 info), `flutter test` 57 pass, `flutter build web` OK.
- entrypoint: thiếu token → dừng với message rõ (đã sửa bug: `$(fn)` inline trong args không kích hoạt `set -e`,
  và `log` ra stdout bị nuốt vào token); socket sai gid → dừng với hướng dẫn DOCKER_GID.
- actionlint sạch, `helm lint` với values-prod sạch.
- **CHƯA** verify: đăng ký runner thật, reboot, job deploy trên cụm (Claude không có access devops-pc/cụm).

## Open follow-ups (user chạy trên devops-pc theo README §0–§5)
- Bật "Require approval for all external contributors" (repo public).
- Gỡ runner native cũ `devops-pc`.
- `make-deployer-kubeconfig.sh` → `.env` (DOCKER_GID, RUNNER_TOKEN) → `docker compose up -d --build` → reboot test.
- Pin `KUBECTL_VERSION` theo minor của cụm (chưa biết version cụm).
- Flutter trong image ghim 3.44.0; lane fork-PR (GitHub-hosted) vẫn dùng `channel: stable` mới nhất — có thể lệch.

---

## Rev 2 (cùng ngày), theo yêu cầu user: CI về GitHub-hosted, PC chỉ chạy CD
Lý do: giảm tải cho devops-pc (host đồng thời chạy các VM KVM của cụm). Khớp lại thiết kế ban đầu ở
`docs/superpowers/specs/2026-08-31-onprem-k8s-replatform-full-reference.md` (cloud runner test, host deploy).
- `ci.yml`: lane `api`/`web` quay về `ubuntu-latest`, giữ nguyên như HEAD (setup-go, flutter-action,
  golangci-lint-action, gha cache). Bỏ phần route fork PR + các step `runner.environment`.
  Job `deploy` vẫn chạy `[self-hosted, pc-runner]`, `needs: [api, web]` → tag `<sha>` chắc chắn đã có
  trên GHCR; checkout sparse `deploy/charts/anmates`; `permissions: contents: read`.
- Runner image chỉ còn helm v4 + kubectl (bỏ Go/Flutter/golangci/gcc). **Bỏ mount docker socket**
  (không còn quyền tương đương root trên host), bỏ `DOCKER_GID`, bỏ volume cache.
- Compose còn **1 runner** tên `devops-pc` (trùng tên runner native cũ, `--replace` chiếm slot đó), giới hạn 1 CPU / 1g.
- Verify: actionlint sạch, `docker compose config` OK, build image amd64 OK (helm v4.0.0, kubectl v1.37.1),
  entrypoint thiếu token → dừng rõ ràng. Toàn bộ các bước CI của rev 1 không cần verify lại (lane giữ như HEAD).
- Vẫn cần approval cho fork PR (repo public, fork có thể sửa `runs-on` để nhắm vào `pc-runner`).

---

## Rev 3 (cùng ngày): tách CD ra `cd.yml` + dọn phần thừa
- `.github/workflows/cd.yml` mới: `on: workflow_run [CI] completed, branches [main]`, job chạy khi
  `conclusion == success`, `event != pull_request`, `head_repository == github.repository`.
  **Gotcha**: với `workflow_run`, `github.sha` = HEAD của main, KHÔNG phải commit CI đã build → image tag +
  checkout chart dùng `github.event.workflow_run.head_sha`. `workflow_run` luôn chạy file từ default
  branch → PR không sửa được bước deploy. Muốn deploy lại một commit: "Re-run jobs" trên CD run của nó.
- `ci.yml` = HEAD + thêm path `deploy/charts/anmates/**`, bỏ job `deploy-command` (in lệnh helm), sửa header.
- Dọn: xoá `.github/actionlint.yaml`; entrypoint chỉ còn đường RUNNER_TOKEN (bỏ ACCESS_TOKEN/PAT,
  URL/tên/label hardcode: repo AnMatesStudio/AnMates, `devops-pc`, label `pc-runner`); compose bỏ các
  biến override; Dockerfile bỏ jq; `.env.example` chỉ còn RUNNER_TOKEN; README viết gọn lại.
- Verify: actionlint (ci+cd) sạch, compose config OK, build image amd64 OK, entrypoint thiếu token → exit 1 kèm thông báo rõ.
- Rev 3b: SA `ci-deployer` + token Secret chuyển sang ns **`ci-cd`** (user muốn đặt tên rõ ràng hơn; `rbac-deployer.yaml` tạo luôn Namespace).
  Role + RoleBinding **vẫn ở `anmates`** (Role chỉ cấp quyền trong namespace chứa nó; RoleBinding trỏ tới SA ở ns khác được).
  Script dùng `SA_NS=ci-cd` / `APP_NS=anmates`; muốn xoay token thì `kubectl -n ci-cd delete secret ci-deployer-token`.
- Bug (user gặp trên devops-pc): script không ghi `./kubeconfig`. Nguyên nhân: bước tự kiểm tra
  `kubectl auth can-i list nodes` chạy với context `namespace: anmates` → hỏi TRONG ns anmates, Role
  `resources: ["*"]` (core group) trả `yes` cho cả resource cluster-scoped → báo sai "RBAC quá rộng" → `exit 1`
  ngay trước `install`. Thực tế `get nodes` bị Forbidden. Sửa: `auth can-i ... -A` (cluster scope), kiểm tra
  thêm `list secrets -A`; prompt nhận `y`/`yes`, trả lời khác thì in "aborted" thay vì thoát im lặng.
  Verify trên OrbStack k8s v1.35: chạy lần đầu trên cluster sạch → ghi file; chạy lần 2 idempotent; trả lời `n` → aborted;
  kubeconfig ghi ra: get secret trong anmates OK, get nodes / secrets trong ci-cd → Forbidden.
- Quyền file kubeconfig: user `runner` của image có uid 1001 cố định, nhưng trên devops-pc uid 1001 = tài khoản `huy`
  → `huy` từng sở hữu + đọc được credential deploy. Đổi sang cấp quyền qua GROUP: file `root:10001` mode 640,
  compose `group_add: ["10001"]`, script `KUBECONFIG_GID=10001` + dừng nếu gid đó đã có group trên host
  (`getent group`). Không build lại image với UID khác (phải `chown -R /home/runner` → image phình thêm một layer).
  Verify bằng container alpine: uid 1001 có group 10001 → đọc được; uid 1001 không có group → Permission denied.
- (thay dòng trên) User không muốn tạo gid 10001. Bản cuối: chạy script bằng user thường (từ chối root/sudo), file
  `kubeconfig` thuộc user đó, mode 640; script ghi `KUBECONFIG_GID=$(id -g)` vào `.env`; compose
  `group_add: ["${KUBECONFIG_GID:?...}"]`. Primary group trên Ubuntu chỉ có user đó → user khác (vd `huy` uid 1001 trên host)
  không đọc được. `rm -f` trước `install` vì file cũ có thể thuộc user khác. Verify trong ubuntu:24.04: ghi file + .env
  (chạy 2 lần vẫn 1 dòng), uid 1001 + group → đọc được, uid 1002 → denied; compose thiếu biến → báo lỗi chỉ tới script.
- Bug: user tạo lại runner trên GitHub + dán RUNNER_TOKEN mới → vẫn lỗi `Registration was not found` /
  `runner registration has been deleted from the server`. Nguyên nhân: entrypoint thấy volume `state` có `.runner` là
  khôi phục luôn, bỏ qua token mới. Sửa: có RUNNER_TOKEN thì đăng ký trước (`rm` state local rồi `config.sh --replace`),
  config.sh fail (token quá 1h) mà volume có state → dùng state; không token + không state → exit 1 kèm hướng dẫn.
  Verify 6 nhánh bằng image thật + stub config.sh/run.sh. Cũng xác nhận log `TaskCanceledException` ở BrokerServer
  sau mỗi job là bình thường (runner tự huỷ long-poll status=Busy khi job xong, poll lại với Online); job deploy đầu
  tiên trên devops-pc đã Succeeded (Code 100). Block `logging` (rotation) mình thêm vào compose đã bị gỡ trên đĩa.
