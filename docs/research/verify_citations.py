"""Checks the competitor research files against their own sources.

For each docs/research/competitors/*.md:
  - the template's sections are present;
  - at least 4 sources, and each source URL can be fetched (self-hosted Firecrawl, FIRECRAWL_URL);
  - every quoted phrase ("...", 12+ chars) appears in at least one of the sources cited in the same sentence.
Quotes are the claims we can check mechanically; numbers and paraphrases still need a human spot check.

Usage: python docs/research/verify_citations.py [slug ...]
"""
import json
import os
import re
import sys
import unicodedata
import urllib.request

FIRECRAWL = os.environ.get("FIRECRAWL_URL", "http://127.0.0.1:3002")
HERE = os.path.dirname(os.path.abspath(__file__))
SECTIONS = ["## Tóm tắt", "## Vòng lặp chính", "## Cách ghép người", "## Tổ chức buổi gặp", "## An toàn",
            "## Giữ chân", "## Kiếm tiền", "## Điểm đặc biệt", "## ĂnMates nên học", "## Nguồn"]
_cache = {}


def fetch(url):
    if url not in _cache:
        req = urllib.request.Request(FIRECRAWL + "/v1/scrape", data=json.dumps({"url": url, "formats": ["markdown"]}).encode(),
                                     headers={"Content-Type": "application/json"})
        try:
            _cache[url] = (json.load(urllib.request.urlopen(req, timeout=120)).get("data") or {}).get("markdown") or ""
        except Exception as e:  # noqa: BLE001 — report, don't crash the run
            _cache[url] = ""
            print(f"    fetch failed {url}: {e}")
    return _cache[url]


def norm(s):
    s = unicodedata.normalize("NFKC", s).lower()
    s = s.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"').replace("—", "-").replace("–", "-")
    return re.sub(r"\s+", " ", s)


def check(path):
    text = open(path, encoding="utf-8").read()
    name = os.path.basename(path)
    missing = [s for s in SECTIONS if s not in text]
    sources = dict(re.findall(r"^\[(\d+)\]\s+(https?://\S+)", text, re.M))
    # Only the sections describing the competitor: "ĂnMates nên học" quotes our own snapshot, not the sources.
    body = text.split("## ĂnMates nên học")[0]
    reachable = {n: len(fetch(u)) > 300 for n, u in sources.items()}
    quotes_ok, quotes_bad = 0, []
    for sentence in re.split(r"(?<=[.!?])\s+|\n", body):
        refs = re.findall(r"\[(\d+)\]", sentence)
        if not refs:
            continue
        # A quote opens after a space/bracket/start and closes before punctuation/space/end — avoids pairing the
        # closing mark of one quote with the opening mark of the next.
        for q in re.findall(r"(?:^|[\s(\[:])[\"“]([^\"”\n]{12,}?)[\"”](?=[\s.,;:)\]!?]|$)", sentence):
            cands = [sources[r] for r in refs if r in sources]
            if any(norm(q) in norm(fetch(u)) for u in cands):
                quotes_ok += 1
            else:
                quotes_bad.append((q[:70], refs))
    print(f"{name}: sources {len(sources)} (reachable {sum(reachable.values())}), "
          f"quotes {quotes_ok}/{quotes_ok + len(quotes_bad)} verified, missing sections {missing or 'none'}")
    for q, refs in quotes_bad:
        print(f"    UNVERIFIED quote {q!r} cited {refs}")
    for n, ok in reachable.items():
        if not ok:
            print(f"    UNREACHABLE [{n}] {sources[n]}")
    return {"file": name, "sources": len(sources), "reachable": sum(reachable.values()), "quotes_ok": quotes_ok,
            "quotes_bad": len(quotes_bad), "missing": missing}


if __name__ == "__main__":
    d = os.path.join(HERE, "competitors")
    wanted = sys.argv[1:]
    files = sorted(f for f in os.listdir(d) if f.endswith(".md") and (not wanted or f[:-3] in wanted))
    rows = [check(os.path.join(d, f)) for f in files]
    tot_ok = sum(r["quotes_ok"] for r in rows)
    tot = tot_ok + sum(r["quotes_bad"] for r in rows)
    print(f"\nTOTAL files {len(rows)} | quotes verified {tot_ok}/{tot} | "
          f"sources reachable {sum(r['reachable'] for r in rows)}/{sum(r['sources'] for r in rows)}")
