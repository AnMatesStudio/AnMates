#!/usr/bin/env bash
# Verify E2E: OTel SDK của anmates-api có thật sự chạy và dữ liệu có chảy hết
# pipeline Alloy → gateway → Tempo/Mimir/Loki hay không.
#
# Gộp các bước tự động hoá được của:
#   - anmates-infra/docs/runbooks/otlp-lgtm-deploy.md  §4.5 §4.6 §4.7 §6
#   - docs/superpowers/plans/2026-09-08-otel-go-instrumentation.md  Task 6 + 7
# Phần còn lại (5 correlation jump trong Grafana UI) in ra checklist ở cuối.
#
# Dùng:
#   deploy/scripts/verify-otel.sh
#
# Mỗi check in PASS / FAIL / WARN / SKIP kèm gợi ý. Exit code = số FAIL.
#
# Override (chủ yếu để chạy thử với rig local deploy/otel-e2e-local/):
#   API_URL GATEWAY_METRICS_URL ALLOY_METRICS_URL TEMPO_URL MIMIR_URL LOKI_URL
#     đặt biến nào thì KHÔNG port-forward service tương ứng
#   SKIP_K8S=1        bỏ các check cần kubectl (image, env, log, HPA)
#   SKIP_LOKI=1       bỏ check Loki
#   REQUESTS=30       số request sinh ra (tail sampling giữ ~20% baseline)
set -uo pipefail

NS_APP=${NS_APP:-anmates}
NS_MON=${NS_MON:-monitoring}
API_DEPLOY=${API_DEPLOY:-anmates-api}
REQUESTS=${REQUESTS:-30}
ROUTE=${ROUTE:-/api/v1/venues}
SPANMETRICS=${SPANMETRICS:-traces_spanmetrics}

PASS=0 FAIL=0 WARN=0
PF_PIDS=()
TMP=$(mktemp -d)
cleanup() {
	for p in "${PF_PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
	rm -rf "$TMP"
}
trap cleanup EXIT

c_pass() { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$*"; }
c_fail() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
c_warn() { WARN=$((WARN + 1)); printf '  \033[33mWARN\033[0m %s\n' "$*"; }
c_skip() { printf '  \033[90mSKIP\033[0m %s\n' "$*"; }
hint() { printf '       ↳ %s\n' "$*"; }
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# pf <ns> <target> <localPort> <remotePort> — port-forward nền, đợi cổng mở.
pf() {
	kubectl -n "$1" port-forward "$2" "$3:$4" >"$TMP/pf-$3.log" 2>&1 &
	PF_PIDS+=($!)
	for _ in $(seq 1 20); do
		curl -s -o /dev/null "localhost:$3" 2>/dev/null && return 0
		sleep 0.5
	done
	echo "port-forward $2 thất bại: $(cat "$TMP/pf-$3.log")" >&2
	return 1
}

# url_for <VARNAME> <ns> <target> <localPort> <remotePort> [pathPrefix]
url_for() {
	local var=$1 ns=$2 target=$3 lp=$4 rp=$5 prefix=${6:-}
	if [ -n "${!var:-}" ]; then return 0; fi
	if pf "$ns" "$target" "$lp" "$rp"; then
		printf -v "$var" 'http://localhost:%s%s' "$lp" "$prefix"
	else
		printf -v "$var" ''
	fi
}

# metric_sum <url> <regex tên metric> — cộng mọi series khớp. Tên counter nội
# bộ của collector có/không hậu tố _total tuỳ version, nên regex chấp nhận cả hai.
metric_sum() {
	curl -s "$1" | awk -v re="^($2)(\\{| )" '$0 ~ re { s += $NF } END { printf "%d", s + 0 }'
}

promql() { # promql <base> <query>
	curl -sG "$1/api/v1/query" --data-urlencode "query=$2"
}

K8S=1
if [ "${SKIP_K8S:-0}" = 1 ]; then
	K8S=0
elif ! kubectl --request-timeout=8s get ns "$NS_APP" >/dev/null 2>&1; then
	echo "Không kết nối được cluster (kubectl get ns $NS_APP). Kiểm tra VPN/kubeconfig," >&2
	echo "hoặc chạy với SKIP_K8S=1 + URL override để test với rig local." >&2
	exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
section "1. Image có OTel SDK không"
if [ $K8S = 1 ]; then
	IMAGE=$(kubectl -n "$NS_APP" get deploy "$API_DEPLOY" -o jsonpath='{.spec.template.spec.containers[?(@.name=="api")].image}')
	echo "  image: $IMAGE"
	# go version -m đọc buildinfo — còn nguyên dù build với -ldflags="-s -w".
	# KHÔNG grep 'opentelemetry' trơn: main cũ đã có go.opentelemetry.io/otel
	# gián tiếp (qua fiberprometheus). otelfiber/otelpgx mới là dấu hiệu SDK.
	if command -v go >/dev/null && command -v docker >/dev/null && docker info >/dev/null 2>&1; then
		CID=$(docker create --platform linux/amd64 "$IMAGE" 2>"$TMP/pull.err")
		if [ -n "$CID" ] && docker cp "$CID:/app/api" "$TMP/api" >/dev/null 2>&1; then
			docker rm "$CID" >/dev/null
			MODS=$(go version -m "$TMP/api" | grep -E 'otelfiber|otelpgx|otlptracegrpc' | awk '{print $2"@"$3}')
			if [ -n "$MODS" ]; then
				c_pass "binary có instrumentation: $(echo "$MODS" | tr '\n' ' ')"
			else
				c_fail "binary KHÔNG có otelfiber/otelpgx — image build từ code trước khi merge"
				hint "merge feat/otel-go-instrumentation → CI push image → helm upgrade --set image.api.tag=<sha>"
			fi
		else
			[ -n "$CID" ] && docker rm "$CID" >/dev/null
			c_warn "không pull được image để soi binary ($(head -c 120 "$TMP/pull.err"))"
			hint "cần 'docker login ghcr.io' — các check runtime bên dưới vẫn đủ để kết luận"
		fi
	else
		c_skip "cần go + docker cục bộ để soi binary"
	fi
else
	c_skip "SKIP_K8S=1"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "2. Pod được cấu hình OTEL_* (chart api.otel.enabled)"
if [ $K8S = 1 ]; then
	ENVJSON=$(kubectl -n "$NS_APP" get deploy "$API_DEPLOY" -o jsonpath='{range .spec.template.spec.containers[?(@.name=="api")].env[*]}{.name}={.value}{"\n"}{end}')
	ep=$(echo "$ENVJSON" | sed -n 's/^OTEL_EXPORTER_OTLP_ENDPOINT=//p')
	sampler=$(echo "$ENVJSON" | sed -n 's/^OTEL_TRACES_SAMPLER=//p')
	if [ -z "$ep" ]; then
		c_fail "không có OTEL_EXPORTER_OTLP_ENDPOINT → telemetry.Setup() trả no-op"
		hint "values-prod.yaml: api.otel.enabled: true, rồi helm upgrade"
	else
		c_pass "OTEL_EXPORTER_OTLP_ENDPOINT=$ep"
		case "$ep" in *observability-alloy*) ;; *) c_warn "endpoint không trỏ vào Alloy (runbook §6: app gửi Alloy, KHÔNG gửi gateway)" ;; esac
	fi
	if [ "$sampler" = parentbased_always_on ]; then
		c_pass "OTEL_TRACES_SAMPLER=parentbased_always_on (head sampling tắt)"
	else
		c_fail "OTEL_TRACES_SAMPLER='$sampler' — phải parentbased_always_on, tail sampling ở gateway"
	fi
else
	c_skip "SKIP_K8S=1"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "3. SDK thật sự khởi động trong pod"
if [ $K8S = 1 ]; then
	LOGS=$(kubectl -n "$NS_APP" logs "deploy/$API_DEPLOY" -c api 2>/dev/null | grep -m1 -E '"msg":"OpenTelemetry (bật|tắt)')
	case "$LOGS" in
	*'OpenTelemetry bật'*) c_pass "log khởi động: $(echo "$LOGS" | grep -oE '"endpoint":"[^"]*"')" ;;
	*'OpenTelemetry tắt'*) c_fail "SDK có trong image nhưng TẮT — thiếu OTEL_EXPORTER_OTLP_ENDPOINT (xem mục 2)" ;;
	*) c_fail "không thấy dòng 'OpenTelemetry bật/tắt' — image cũ (chưa có package telemetry) hoặc log đã rotate"
		hint "kubectl -n $NS_APP rollout restart deploy/$API_DEPLOY rồi chạy lại" ;;
	esac
	if kubectl -n "$NS_APP" logs "deploy/$API_DEPLOY" -c api 2>/dev/null | grep -q '"msg":"otel sdk"'; then
		c_warn "có lỗi export từ SDK: $(kubectl -n "$NS_APP" logs "deploy/$API_DEPLOY" -c api | grep -m1 '"msg":"otel sdk"' | cut -c1-200)"
		hint "kubectl -n $NS_APP exec deploy/$API_DEPLOY -- getent hosts observability-alloy.$NS_MON.svc.cluster.local"
	fi
else
	c_skip "SKIP_K8S=1"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4. Sinh traffic — mỗi response phải có X-Trace-Id"
url_for API_URL "$NS_APP" "svc/$API_DEPLOY" 18080 8080
: >"$TMP/ids"
if [ -z "$API_URL" ]; then
	c_fail "không port-forward được svc/$API_DEPLOY"
else
	for _ in $(seq 1 "$REQUESTS"); do
		curl -s -o /dev/null -D - "$API_URL$ROUTE" |
			awk -F': ' 'tolower($1)=="x-trace-id" { gsub(/\r/, "", $2); print $2 }' >>"$TMP/ids"
		sleep 0.1
	done
	n=$(sort -u "$TMP/ids" | grep -cE '^[0-9a-f]{32}$')
	if [ "$n" -eq "$REQUESTS" ]; then
		c_pass "$n/$REQUESTS response có X-Trace-Id 32-hex, tất cả khác nhau"
	elif [ "$n" -eq 0 ]; then
		c_fail "không response nào có X-Trace-Id — middleware.Tracing chưa chạy (mục 1–3)"
	else
		c_warn "$n/$REQUESTS response có X-Trace-Id"
	fi
	[ "$(curl -s -o /dev/null -D - "$API_URL/health" | grep -ci x-trace-id)" = 0 ] &&
		c_pass "/health không bị trace (probe không làm ngập Tempo)" ||
		c_fail "/health đang bị trace"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "5. Alloy nhận span (runbook §4.6)"
url_for ALLOY_METRICS_URL "$NS_MON" svc/observability-alloy 12345 12345 /metrics
if [ -z "$ALLOY_METRICS_URL" ]; then
	c_fail "không port-forward được Alloy"
else
	sleep 6 # BatchSpanProcessor của SDK flush mỗi 5s
	acc=$(metric_sum "$ALLOY_METRICS_URL" 'otelcol_receiver_accepted_spans(_total)?')
	if [ "$acc" -gt 0 ]; then c_pass "accepted_spans=$acc"; else
		c_fail "accepted_spans=0 — app không gửi tới được Alloy"
		hint "Alloy là DaemonSet internalTrafficPolicy:Local — node của pod api phải có pod Alloy Running"
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "6. Gateway export không lỗi (runbook §4.5)"
url_for GATEWAY_METRICS_URL "$NS_MON" deploy/observability-otel-gateway 18888 8888 /metrics
if [ -z "$GATEWAY_METRICS_URL" ]; then
	c_fail "không port-forward được gateway"
else
	sent=$(metric_sum "$GATEWAY_METRICS_URL" 'otelcol_exporter_sent_spans(_total)?')
	failed=$(metric_sum "$GATEWAY_METRICS_URL" 'otelcol_exporter_send_failed_(spans|metric_points|log_records)(_total)?')
	[ "$sent" -gt 0 ] && c_pass "sent_spans=$sent" || c_fail "sent_spans=0"
	[ "$failed" -eq 0 ] && c_pass "send_failed=0" || {
		c_fail "send_failed=$failed"
		hint "kubectl -n $NS_MON logs deploy/observability-otel-gateway --tail=50 (thường là sai tên Service backend)"
	}
fi

# ─────────────────────────────────────────────────────────────────────────────
section "7. Trace trong Tempo đúng hình dạng (plan Task 6 Step 4)"
url_for TEMPO_URL "$NS_MON" svc/observability-tempo 13200 3200
if [ -z "$TEMPO_URL" ] || [ ! -s "$TMP/ids" ]; then
	c_skip "không có Tempo hoặc không có trace id"
else
	# Tail sampling giữ ~20% trace bình thường → thử lần lượt mọi id đã sinh.
	found=""
	for _ in $(seq 1 12); do
		while read -r id; do
			if curl -sf -H 'Accept: application/json' "$TEMPO_URL/api/traces/$id" -o "$TMP/trace.json"; then
				found=$id
				break
			fi
		done <"$TMP/ids"
		[ -n "$found" ] && break
		sleep 5
	done
	if [ -z "$found" ]; then
		c_fail "không trace nào trong $REQUESTS trace có trong Tempo sau 60s"
		hint "gateway sent_spans > 0 mà Tempo rỗng → kiểm tra pipeline traces/sampled"
	else
		python3 - "$TMP/trace.json" "$found" <<'PY' && c_pass "trace $found: 1 root SERVER, DB span là con" || c_fail "trace $found sai hình dạng (xem trên)"
import sys, json
d = json.load(open(sys.argv[1]))
spans = [s for b in d.get("batches", []) for ss in b.get("scopeSpans", []) for s in ss["spans"]]
kind = lambda s: str(s.get("kind"))
roots = [s for s in spans if not s.get("parentSpanId")]
client = [s for s in spans if kind(s) in ("3", "SPAN_KIND_CLIENT")]
print("       spans:", ", ".join(f'{s["name"]}' for s in spans))
ok = True
if len(roots) != 1:
    print("       >1 root → DB span mồ côi: handler dùng context.Background() thay c.UserContext()"); ok = False
if not client:
    print("       không có CLIENT span → otelpgx chưa gắn (Task 3)"); ok = False
res = {a["key"] for b in d["batches"] for a in b["resource"]["attributes"]}
miss = [k for k in ("service.name", "service.version", "service.namespace",
                    "deployment.environment", "k8s.pod.name", "k8s.namespace.name") if k not in res]
if miss:
    print("       thiếu resource attribute:", miss); ok = False
raw = open(sys.argv[1]).read()
if "url.query" in raw or "lat=" in raw:
    print("       query string lọt vào span (redactingExporter không chạy)"); ok = False
sys.exit(0 if ok else 1)
PY
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "8. spanmetrics trong Mimir (plan Task 6 Step 5–6, Task 7 Step 2)"
url_for MIMIR_URL "$NS_MON" svc/observability-mimir 19009 9009 /prometheus
if [ -z "$MIMIR_URL" ]; then
	c_fail "không port-forward được Mimir"
else
	q="${SPANMETRICS}_calls_total{service_name=\"anmates-api\",span_kind=\"SPAN_KIND_SERVER\"}"
	res=""
	for _ in $(seq 1 12); do # connector flush + remote_write: tới ~60s
		res=$(promql "$MIMIR_URL" "$q")
		echo "$res" | grep -q '"span_name"' && break
		sleep 5
	done
	python3 - "$res" "$ROUTE" >"$TMP/sm.out" <<'PY'
import sys, json
r = json.loads(sys.argv[1] or "{}").get("data", {}).get("result", [])
if not r:
    print("FAIL|không có series spanmetrics cho service_name=anmates-api"); sys.exit()
names = sorted({x["metric"].get("span_name", "") for x in r})
print("INFO|span_name:", ", ".join(names))
want = "GET " + sys.argv[2]
print(("PASS|" if want in names else "FAIL|") + f"span_name '{want}' (route pattern, không URL thô)")
import re
raw = [n for n in names if re.search(r"[0-9a-f]{8}-[0-9a-f]{4}|/\d+(/|$)", n)]
print(("FAIL|span_name chứa id thô: " + ", ".join(raw)) if raw else "PASS|không span_name nào chứa UUID/id")
lab = r[0]["metric"]
miss = [k for k in ("http_request_method", "http_response_status_code") if k not in lab]
print(("FAIL|dimension RỖNG " + str(miss) + " — semconv SDK lệch với gateway spanmetrics.dimensions") if miss
      else "PASS|dimension http_request_method + http_response_status_code có giá trị")
print(("PASS|" if len(names) < 100 else "FAIL|") + f"{len(names)} span_name (< 100)")
PY
	while IFS='|' read -r st msg; do
		case $st in PASS) c_pass "$msg" ;; FAIL) c_fail "$msg" ;; INFO) echo "       $msg" ;; esac
	done <"$TMP/sm.out"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "9. Log vào Loki kèm trace_id (plan Task 6 Step 8)"
if [ "${SKIP_LOKI:-0}" = 1 ]; then
	c_skip "SKIP_LOKI=1"
else
	url_for LOKI_URL "$NS_MON" svc/observability-loki-gateway 13100 80
	if [ -z "$LOKI_URL" ]; then
		c_fail "không port-forward được Loki gateway"
	else
		n=$(curl -sG "$LOKI_URL/loki/api/v1/query_range" \
			--data-urlencode 'query={service_name="anmates-api"} |= "trace_id"' \
			--data-urlencode "start=$(($(date +%s) - 900))000000000" \
			--data-urlencode 'limit=20' |
			python3 -c 'import sys,json; print(sum(len(s["values"]) for s in json.load(sys.stdin)["data"]["result"]))' 2>/dev/null || echo 0)
		if [ "$n" -gt 0 ]; then c_pass "$n dòng log có trace_id trong 15 phút qua"; else
			c_fail "Loki không có log nào của service_name=anmates-api kèm trace_id"
			hint "runbook §5: kiểm tra otelcol.processor.transform \"pod_logs\" trong Alloy"
		fi
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "10. ⚠️  Hợp đồng HPA còn nguyên (runbook §4.7)"
if [ $K8S = 1 ]; then
	if kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" 2>/dev/null | grep -q 'pods/http_requests_per_second'; then
		c_pass "custom.metrics có pods/http_requests_per_second"
	else
		c_fail "custom.metrics KHÔNG có http_requests_per_second"
	fi
	cur=$(kubectl -n "$NS_APP" get hpa "$API_DEPLOY" -o jsonpath='{.status.currentMetrics[*].pods.current.averageValue}' 2>/dev/null)
	if [ -n "$cur" ]; then c_pass "HPA đọc được http_requests_per_second = $cur"; else
		c_fail "HPA không có current value (TARGETS <unknown>) — runbook §4.7, rollback nếu không sửa được trong 5 phút"
	fi
else
	c_skip "SKIP_K8S=1"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "11. Làm tay trong Grafana (runbook §4.9)"
TID=$(head -1 "$TMP/ids" 2>/dev/null)
cat <<EOF
  kubectl -n $NS_MON port-forward svc/observability-grafana 3000:80  →  http://localhost:3000
  [ ] metric → trace   Explore → Mimir → histogram_quantile(0.95, sum by (le) (rate(${SPANMETRICS}_duration_milliseconds_bucket{service_name="anmates-api"}[5m]))) → bật Exemplars → click diamond
  [ ] trace → log      Explore → Tempo → ${found:-$TID} → chọn span → Logs for this span
  [ ] log → trace      Explore → Loki → {service_name="anmates-api"} → mở dòng có trace_id → View trace
  [ ] trace → metric   trong trace view → Request rate / Error rate / p95
  [ ] service graph    Explore → Tempo → Service Graph (rỗng là bình thường khi api chưa gọi HTTP service nào có instrument)
EOF

printf '\n\033[1mKết quả: %d PASS, %d FAIL, %d WARN\033[0m\n' "$PASS" "$FAIL" "$WARN"
exit "$FAIL"
