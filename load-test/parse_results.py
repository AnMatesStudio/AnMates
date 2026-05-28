#!/usr/bin/env python3
"""Parse a k6 JSONL output file and print a structured load-test report.

Usage:
    python3 parse_results.py <raw.json> [peak_vus] [user_pool]

Exit codes:
    0  all SLOs passed
    1  one or more SLOs failed or raw.json unreadable
"""
import sys
import json
import math
import time

raw_file  = sys.argv[1] if len(sys.argv) > 1 else "results/raw.json"
peak_vus  = int(sys.argv[2]) if len(sys.argv) > 2 else None
user_pool = int(sys.argv[3]) if len(sys.argv) > 3 else None

durations      = []
status_codes   = {}
data_sent      = 0.0
data_recv      = 0.0
main_reqs      = 0
vu_samples     = []
first_time     = None
last_time      = None
err_samples    = []

try:
    with open(raw_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") != "Point":
                continue

            t = obj["data"].get("time")
            if t:
                if first_time is None:
                    first_time = t
                last_time = t

            metric = obj.get("metric")
            val    = obj["data"].get("value", 0)
            tags   = obj["data"].get("tags", {})

            if metric == "http_req_duration":
                durations.append(val)
            elif metric == "http_reqs":
                grp = tags.get("group", "")
                if "setup" not in grp:
                    main_reqs += 1
                s = tags.get("status")
                if s:
                    status_codes[s] = status_codes.get(s, 0) + 1
            elif metric == "error_rate":
                err_samples.append(val)
            elif metric == "vus":
                vu_samples.append(int(val))
            elif metric == "data_sent":
                data_sent += val
            elif metric == "data_received":
                data_recv += val
except FileNotFoundError:
    print(f"[ERROR] {raw_file} not found — test may have failed before k6 wrote output")
    sys.exit(1)


def pct(arr, p):
    if not arr:
        return 0.0
    s = sorted(arr)
    idx = max(0, math.ceil(p / 100.0 * len(s)) - 1)
    return round(s[idx], 2)


total_sec = 0
if first_time and last_time:
    from datetime import datetime, timezone
    fmt = "%Y-%m-%dT%H:%M:%S.%fZ"
    t0 = datetime.strptime(first_time[:26] + "Z", fmt).replace(tzinfo=timezone.utc)
    t1 = datetime.strptime(last_time[:26]  + "Z", fmt).replace(tzinfo=timezone.utc)
    total_sec = round((t1 - t0).total_seconds())

rps    = round(main_reqs / total_sec, 1) if total_sec > 0 else 0
max_vu = max(vu_samples) if vu_samples else 0
s2xx   = sum(v for k, v in status_codes.items() if k.startswith("2"))
s4xx   = sum(v for k, v in status_codes.items() if k.startswith("4"))
s5xx   = sum(v for k, v in status_codes.items() if k.startswith("5"))
s409   = status_codes.get("409", 0)

err_rate = round(sum(err_samples) / len(err_samples) * 100, 2) if err_samples else \
           round((s4xx - s409 + s5xx) / main_reqs * 100, 2) if main_reqs > 0 else 0.0

p95 = pct(durations, 95)
p99 = pct(durations, 99)

slo_p95  = p95 < 500
slo_p99  = p99 < 1000
slo_err  = err_rate < 1.0
all_pass = slo_p95 and slo_p99 and slo_err

CYAN  = "\033[0;36m"
GREEN = "\033[0;32m"
RED   = "\033[0;31m"
WHITE = "\033[1;37m"
GRAY  = "\033[0;90m"
RST   = "\033[0m"


def badge(ok):
    return f"{GREEN}PASS{RST}" if ok else f"{RED}FAIL{RST}"


sep = WHITE + ("=" * 59) + RST
now = time.strftime("%Y-%m-%d %H:%M")

print(f"\n{sep}")
print(f"  {WHITE}ANMATES API LOAD TEST REPORT  --  {now}{RST}")
print(sep)

print(f"\n  {CYAN}SETUP{RST}")
if user_pool is not None:
    print(f"  User pool  : {user_pool} tokens")
print(f"  Peak VUs   : {max_vu}")
print(f"  Test time  : {total_sec}s")

print(f"\n  {CYAN}THROUGHPUT{RST}")
print(f"  Total reqs : {main_reqs}")
print(f"  Avg req/s  : {rps}")
print(f"  Data sent  : {round(data_sent/1024/1024, 2)} MB")
print(f"  Data recv  : {round(data_recv/1024/1024, 2)} MB")

print(f"\n  {CYAN}LATENCY (ms){RST}")
print(f"  p50  :  {pct(durations, 50)}")
print(f"  p75  :  {pct(durations, 75)}")
print(f"  p90  :  {pct(durations, 90)}")
print(f"  p95  :  {p95}  (SLO: p95<500ms)   [{badge(slo_p95)}]")
print(f"  p99  :  {p99}  (SLO: p99<1000ms)  [{badge(slo_p99)}]")
print(f"  max  :  {pct(durations, 100)}")

print(f"\n  {CYAN}ERRORS{RST}")
print(f"  2xx        :  {s2xx}")
print(f"  4xx real   :  {s4xx - s409}")
print(f"  5xx        :  {s5xx}")
print(f"  409 (dup)  :  {s409}  (expected — duplicate wishlist entries)")
print(f"  Rate       :  {err_rate}%  (SLO: rate<1%)  [{badge(slo_err)}]")

print(f"\n  {CYAN}STATUS BREAKDOWN{RST}")
for k in sorted(status_codes):
    note = "  (expected)" if k == "409" else ""
    print(f"  {k}  :  {status_codes[k]}{note}")

print()
if all_pass:
    print(f"  {GREEN}RESULT: ALL SLOs PASSED{RST}")
else:
    print(f"  {RED}RESULT: ONE OR MORE SLOs FAILED{RST}")
print(sep)
print(f"  {GRAY}HTML report: load-test/results/report.html{RST}")
print(f"  {GRAY}Raw data:    load-test/results/raw.json{RST}\n")

sys.exit(0 if all_pass else 1)
