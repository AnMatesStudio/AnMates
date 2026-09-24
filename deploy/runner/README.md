# Self-hosted deploy runner (container) trên devops-pc

Runner cho [`.github/workflows/cd.yml`](../../.github/workflows/cd.yml). CI
([`ci.yml`](../../.github/workflows/ci.yml)) test + build + push image lên GHCR trên
GitHub-hosted. Khi CI trên `main` **xanh**, CD chạy trên runner này và `helm upgrade`
với tag = SHA của commit CI vừa build.

```
push main ─► CI (ubuntu-latest): api + web → ghcr.io/anmatesstudio/anmates-{api,web}:<sha>
                 │ workflow_run: completed + success
                 ▼
             CD (devops-pc): helm upgrade --set image.{api,web}.tag=<sha> → smoke /health
```

| File | Vai trò |
|---|---|
| [`Dockerfile`](Dockerfile) | `ghcr.io/actions/actions-runner` + Helm v4 + kubectl |
| [`docker-compose.yml`](docker-compose.yml) | 1 runner, `restart: unless-stopped`, `network_mode: host`, 1 CPU / 1g |
| [`entrypoint.sh`](entrypoint.sh) | Chỉ đăng ký `devops-pc` (label `pc-runner`) ở lần chạy đầu. Credential lưu trong volume `state` nên reboot không cần token |
| [`rbac-deployer.yaml`](rbac-deployer.yaml) + [`scripts/make-deployer-kubeconfig.sh`](scripts/make-deployer-kubeconfig.sh) | ServiceAccount `ci-deployer` nằm ở ns `ci-cd`, chỉ có quyền deploy vào ns `anmates` (Role/RoleBinding đặt trong `anmates`) |

## 0. Tiền đề

```bash
sudo systemctl enable --now docker containerd   # daemon tự lên khi boot → runner tự lên
kubectl config current-context                 # context ADMIN của cụm on-prem
kubectl -n anmates get secret ghcr-pull anmates-api
```

## 1. Bảo mật (repo PUBLIC)

Vào **Settings → Actions → General → "Require approval for all external contributors"**.
`cd.yml` luôn chạy theo bản trên `main` nên PR không sửa được bước deploy. Nhưng PR từ fork
vẫn có thể sửa `ci.yml` để một job nhắm vào `runs-on: pc-runner`, nên cần maintainer
approve thì PR fork mới được chạy.

## 2. Tắt runner native cũ

Trên devops-pc, trong thư mục cài cũ (thường là `~/actions-runner`):
`sudo ./svc.sh stop && sudo ./svc.sh uninstall`. Container đăng ký cùng tên `devops-pc`
với `--replace` nên chiếm luôn slot cũ.

## 3. Kubeconfig

Chạy bằng user thường của bạn, **không `sudo`**, với context admin của cluster:

```bash
cd deploy/runner
cp .env.example .env && chmod 600 .env
./scripts/make-deployer-kubeconfig.sh
```

Script làm các việc sau:
1. Tạo ns `ci-cd` + SA/token ở đó, và Role/RoleBinding ở `anmates`.
2. Tự kiểm tra: **được** patch deployment trong `anmates`, **không được** list nodes/secrets toàn cluster.
3. Ghi `./kubeconfig` (gitignored). File thuộc về chính bạn, mode 640.
4. Ghi `KUBECONFIG_GID=$(id -g)` vào `.env`.

Container (user `runner`, uid 1001) đọc file qua primary group của bạn nhờ `group_add`.
Trên Ubuntu primary group chỉ có mình bạn, nên các user khác trên host không đọc được.
Compose sẽ không start nếu thiếu file hoặc thiếu `KUBECONFIG_GID`.

`ps` trên host có thể hiện process runner dưới tên của user nào đang có uid 1001 trên host.
Đó chỉ là tên hiển thị, process vẫn nằm trong container.

## 4. Chạy

Điền `RUNNER_TOKEN` vào `.env` (Settings → Actions → Runners → New self-hosted runner), rồi:

```bash
docker compose up -d --build
docker compose logs -f          # chờ "Listening for Jobs"
```

Khi `devops-pc` hiện **Idle** trên GitHub thì xoá `RUNNER_TOKEN` khỏi `.env`.

## 5. Nghiệm thu

1. `sudo reboot` → `docker compose ps` thấy `Up`, trên GitHub `devops-pc` hiện Idle.
2. Actions → CI → Run workflow (main) → CI xanh → CD tự chạy → `kubectl -n anmates get deploy -o wide` thấy tag = SHA.

---

## Vận hành

| Việc | Cách làm |
|---|---|
| Deploy lại một commit | Mở CD run của commit đó → **Re-run jobs** |
| Rollback | `helm -n anmates history anmates` → `helm -n anmates rollback anmates <REV>` |
| Nâng Helm/kubectl | sửa `ARG` trong `Dockerfile` → `docker compose build --pull && docker compose up -d` |
| Pin kubectl theo cụm | `KUBECTL_VERSION=v1.xx.y` cùng minor với server (lệch tối đa ±1) |
| Đăng ký lại runner | `docker compose down && docker volume rm anmates-runner_state` → điền `RUNNER_TOKEN` → `docker compose up -d` |
| Xoay token deployer | `kubectl -n ci-cd delete secret ci-deployer-token && ./scripts/make-deployer-kubeconfig.sh` |

## Troubleshooting

- **CD không chạy sau khi CI xanh:** `workflow_run` chỉ kích hoạt khi `cd.yml` **đã có trên `main`**. CD cũng bỏ qua các run của PR.
- **CD "Queued" mãi:** runner offline. Kiểm tra `docker compose ps` / `docker compose logs`.
- **Runner restart liên tục, log 404 / "registration deleted":** runner đã bị Remove trên GitHub. Làm bước "Đăng ký lại runner".
- **`dial tcp 10.10.10.11:6443` refused/timeout:** thử `curl -k https://10.10.10.11:6443/version` từ host. Host gọi được mà container không thì container đang không chạy `network_mode: host`. Host network là bắt buộc vì libvirt NAT `virbr1` REJECT traffic đi từ `docker0`.
- **`helm upgrade` fail và tự rollback:** xem step `Diagnostics`. Thường gặp `ImagePullBackOff` (secret `ghcr-pull`) hoặc `CrashLoopBackOff` (thiếu key trong secret `anmates-api`).
