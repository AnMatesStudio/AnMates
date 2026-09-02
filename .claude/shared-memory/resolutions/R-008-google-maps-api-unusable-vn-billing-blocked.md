---
id: R-008
title: Google Maps Platform APIs unusable for AnMates — blocked for VN billing despite correct config (Cloud Storage works in same project)
tags: [gcp, google-maps, places-api, billing, vietnam, geo-policy, api-key, web-search, venue-image]
platforms: [backend]
severity: major
status: confirmed
date_resolved: 2026-06-14
confirmed_by: user
related_sessions: [sessions/2026-06-14-google-maps-api-blocked-vn-and-photo-scrape-decision.md]
related_blockers: []
---

# R-008: Google Maps Platform APIs unusable for AnMates (VN-gated billing)

## TL;DR
We tried to adopt **Google Places API (New)** as the venue-photo source. After fixing and
verifying every config gate (billing Active + linked + card Primary, API key Application
restrictions = None, Places API (New) enabled and in the key's allowlist, project number
matching everywhere), **all Google Maps Platform APIs still return billing/permission
errors** — while **non-Maps Google Cloud APIs (Cloud Storage) work in the exact same
project + billing account**. Root cause (user-agreed): **Google Maps Platform is gated for
Vietnam** (mapping/surveying regulations), independent of any setting we control. **Do not
re-attempt Google Maps/Places/Geocoding APIs for this project.** Use Goong for data; source
photos elsewhere.

## Symptoms
Google Places API (New), `POST https://places.googleapis.com/v1/places:searchText`, with a
fully-configured key:
```
{"error":{"code":403,"message":"The caller does not have permission","status":"PERMISSION_DENIED"}}
```
Legacy Maps APIs (same key, same project) say it plainly:
```
You must enable Billing on the Google Cloud Project ...   (status REQUEST_DENIED)
```
…even though billing IS enabled, Active, linked, with a Primary Visa.

Distinct earlier gates seen while configuring (separate causes, all fixed, NOT the final one):
```
API_KEY_SERVICE_BLOCKED                      → key's API-restriction allowlist missing the API (e.g. restricted to Solar API only)
API_KEY_HTTP_REFERRER_BLOCKED                → key Application-restriction = HTTP referrers (can't work for server-side / no-Referer calls)
"Requests from referer <empty> are blocked." → same as above
```

## Root Cause
The blocker is **Maps-Platform-specific and country-level**, not a config/IAM/billing
mistake:
- **Isolation test proves it:** in the SAME project (`anmates`, number `748505933219`) with
  the SAME billing ("My Maps Billing Account", Active, Visa ••5073 Primary), the Cloud
  Storage JSON API **succeeds** reading a public object (`200 storage#objects`). A billed,
  non-Maps GCP API works fine. Only **Maps Platform** APIs refuse.
- API keys are **not IAM principals**, so missing user IAM roles cannot be the cause of an
  API-key call failing this way (and the anonymous key read Cloud Storage public data fine).
- Billing was verified end-to-end: project number `748505933219` == Project ID `anmates`
  (Welcome page + Gemini `consumer: projects/748505933219`), linked to an Active billing
  account whose Primary payment method is a valid Visa.
- The remaining variable is **the billing account's country (Vietnam)**. Google Maps
  Platform availability is gated by country (VN regulates geographic/mapping data — the same
  reason VN products use licensed providers like Goong). A VN billing account → Maps
  Platform blocked; general GCP unaffected. "You must enable Billing" is Maps Platform's
  generic phrasing for "Maps Platform not available for this billing account".

This **confirms the project's pre-existing LOCKED decision**: *"Google Maps PROHIBITED in
VN → data/routing = Goong."*

## Solution

### Steps (the decision, not a config fix)
1. **Stop using Google Maps Platform APIs** (Places New/old, Geocoding, Time Zone, Static,
   etc.) for this project. They cannot be unblocked from the GCP console while billing is a
   VN account.
2. Keep **Goong** as the venue-data provider (name/address/coords) — VN-legal, already wired.
3. Source venue **photos** from a non-Google-Maps-API path. Chosen direction: **headless
   browser scrape of Google Maps web, run from a residential IP**, downloaded → Firebase
   Storage → cached permanently in Postgres keyed by Goong id (see related session for the
   full plan + the residential-IP / CAPTCHA caveat). Foursquare Photos is a paid fallback
   (Premium $18.75 CPM, no free tier; viable only with permanent per-venue caching).

### Code changes (if any)
None — this is a platform/billing constraint + a direction decision. No code changed.

## Verification
Live `curl` probes on 2026-06-14 (residential IP):
- Places New / Geocoding / Time Zone / Static Map → billing/permission denied (verbatim above).
- Cloud Storage public-object read in the **same project + billing** → `200 OK` with real data.
- Billing console screenshots: account Active, Visa ••5073 Primary, linked to `anmates`.
- User reviewed the evidence and agreed the cause is Google's VN country policy.

## Why this fix works (for future-Claude)
The decisive test is **same-project isolation**: if a *non-Maps* GCP API works but *every*
Maps Platform API returns "enable billing", the problem is NOT billing/config/IAM — it is a
**Maps-Platform country gate**. Don't burn hours re-checking billing links, key
restrictions, or API enablement (we already did — all correct). For VN, the answer is
structural: Maps Platform is unavailable; use Goong + a non-Maps photo source.

## Gotchas / Related issues
- The New Places API returns an **opaque** `PERMISSION_DENIED` "The caller does not have
  permission" for MANY distinct causes (billing, API not enabled, key restriction). When it
  does, cross-check with a **legacy** Maps endpoint (`maps.googleapis.com/...`) which returns
  a **specific** error string — that's how we learned the real cause was "billing"
  (= Maps-Platform unavailable), not key restriction.
- `API_KEY_SERVICE_BLOCKED` vs `API_KEY_HTTP_REFERRER_BLOCKED` vs generic billing are three
  independent gates — fixing one reveals the next. Creating a NEW key/project each time
  resets progress (each new project lacks the prior config). Use ONE key in ONE project.
- This does NOT mean GCP is unusable for AnMates — Cloud Run, Cloud Storage, Firebase, etc.
  all work. Only **Maps Platform** is gated.
- Photo direction is **decided but not built** (see session). Has a hard residential-IP
  requirement (datacenter IPs → CAPTCHA) and a ToS/copyright caveat the user accepted.

## References
- Related session: [sessions/2026-06-14-google-maps-api-blocked-vn-and-photo-scrape-decision.md](../sessions/2026-06-14-google-maps-api-blocked-vn-and-photo-scrape-decision.md)
- Pre-existing decision: "Google Maps PROHIBITED in VN → Goong" (docs/specs/ai-concierge-chat-spec.md; current-task.md history)
- Goong (VN-legal maps/data provider): https://goong.io
