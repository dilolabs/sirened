---
title: "ImportStockJob fails with 'Download failed' after INSEE Sirene publishing migration on data.gouv.fr"
category: integration-issues
component: app/models/unite_legale/importable.rb (UniteLegale.download_stock)
symptoms:
  - Solid Queue job ImportStockJob raises RuntimeError "Download failed"
  - Failure occurs ~2 days after the job was enqueued
  - Direct URL https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip returns HTTP 404
  - Old files.data.gouv.fr directory listing contains only a migration notice file
  - Stable dataset URLs (https://www.data.gouv.fr/api/1/datasets/r/<uuid>) answer HTTP 302 to static.data.gouv.fr
date: 2026-08-26
severity: high
tags:
  - solid-queue
  - background-jobs
  - external-api
  - data-gouv-fr
  - insee-sirene
  - net-http
  - http-redirects
---

## Problem

The monthly INSEE Sirene stock import (`ImportStockJob`) failed at runtime with `RuntimeError "Download failed"` raised from `UniteLegale.download_stock`, two days after being enqueued, leaving the ~34M-row Sirene stock unimported and the application serving stale legal-unit data. INSEE took over Sirene publishing on data.gouv.fr at end of May 2026, so the hardcoded direct URL `https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip` began returning HTTP 404. The replacement stable URLs respond with an HTTP 302 redirect to `static.data.gouv.fr`, which `Net::HTTP.get_response` does not follow, causing the download to keep failing until the fix.

## Root Cause

**1. Dead source URL.** `ZIP_SOURCE` pointed at `https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip`, which has returned 404 since INSEE began publishing directly on data.gouv (end May 2026). data.gouv requires automations to use *stable URLs* of the form `https://www.data.gouv.fr/api/1/datasets/r/<uuid>`, which 302-redirect to the current monthly file on static.data.gouv.fr.

**2. No redirect following + full-body buffering.** The previous `download_stock` used `Net::HTTP.get_response`, which does not follow redirects — so even a correct stable URL would fail with "Download failed". Additionally, it buffered the entire response body in RAM before writing, a problem for these multi-GB (2–3 GB) stock files.

## Solution

Point `ZIP_SOURCE` at stable dataset-resource UUID URLs (one per model):

```ruby
# UniteLegale::Importable
ZIP_SOURCE = "https://www.data.gouv.fr/api/1/datasets/r/825f4199-cadd-486c-ac46-a65a8ea1a047"
# Etablissement::Importable
ZIP_SOURCE = "https://www.data.gouv.fr/api/1/datasets/r/0651fb76-bcf3-4f6a-a38d-bc04fa708576"
```

Rewrote `download_stock` to resolve redirects first, then stream the final GET body to disk in chunks via `response.read_body` — replacing full-body buffering, which previously loaded the entire 2–3 GB file into RAM:

```ruby
def self.download_stock(source: ZIP_SOURCE, destination: ZIP_DESTINATION)
  uri = resolve_final_uri(URI.parse(source))
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS), read_timeout: 300) do |http|
    http.request_get(uri.request_uri) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise "Download failed"
      end
      File.open(destination, "wb") do |file|
        response.read_body { |chunk| file.write(chunk) }
      end
    end
  end
end

def self.resolve_final_uri(uri, remaining_redirects: 5)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
    http.head(uri.request_uri)
  end
  if response.is_a?(Net::HTTPRedirection)
    raise "Too many redirects while downloading #{uri}" if remaining_redirects.zero?
    resolve_final_uri(URI.join(uri, response["location"]), remaining_redirects: remaining_redirects - 1)
  else
    uri
  end
end
```

Notes:
- `resolve_final_uri` follows up to 5 HEAD-request redirects; `URI.join(uri, ...)` handles relative `Location` headers.
- HTTP errors raise `"Download failed"` before opening the destination file, so no partial/empty file is left behind.
- The new zip still contains CSVs named `StockUniteLegale_utf8.csv` / `StockEtablissement_utf8.csv`, so `unzip_stock` entry filters are unchanged.
- Verified live: both resolvers land on real August 2026 files; tests cover redirect-following, HTTP-error → `"Download failed"` without creating the destination file, and the too-many-redirects guard (via a stdlib `TCPServer`-based fake HTTP server in `test/support/fake_http_server.rb`).

## Prevention

1. **Add `retry_on` with backoff to the import jobs — cheap.** Enable `retry_on StandardError, wait: :polynomially_longer, attempts: 3` on `ImportStockJob`, so transient DNS/timeout/reset blips don't kill the monthly run. Pipeline is effectively idempotent (`delete_stock` first, `upsert_all` imports), though a retry restarts the full multi-hour download+import — acceptable monthly.

2. **Alert on failed executions via Mission Control Jobs — cheap to moderate.** mission_control-jobs is already installed; wire `SolidQueue::FailedExecution.count` into alerting (scheduled Slack/email check). Converts silent breakage into a same-day signal, though you're still up to a month stale until re-run.

3. **Keep and extend the stable-URL regression tests — cheap.** Existing guards assert `ZIP_SOURCE` matches the documented data.gouv stable-API shape and excludes `files.data.gouv.fr`. Fully offline and fast, but cannot detect data.gouv retiring a dataset UUID — only stops reintroducing a volatile mirror.

4. **Pre-flight HEAD check inside the job before the big download — cheap.** Fail fast with logging when status/Content-Type look wrong (HTML error page instead of ZIP). Pairs well with retries; TOCTOU means final GET can still fail after a passing HEAD — negligible for a monthly job.

5. **Scheduled real-network smoke test of the stable URLs — expensive, network-dependent.** A recurring task that hits both live `ZIP_SOURCE` URLs and alerts if unreachable catches upstream changes weeks before import day. Do NOT put this in Minitest (flaky/slow CI, egress often blocked). Another moving part plus outage-noise risk.

6. **Track upstream datasets as a human process — cheap but unreliable.** Document the data.gouv.fr dataset pages next to `ZIP_SOURCE` and subscribe to their changelog/RSS plus INSEE Sirene announcements. Zero code, catches republishing changes early, but depends on someone reading it — complement, never primary defense.

### Incident context worth remembering

- `ImportStockJob` is scheduled **monthly in production only** via `config/recurring.yml` (`monthly_import_stock`) and has **no retry configuration** — a failed run stays failed until the next month or manual `bin/rails sirene:import_stock`. This is why the failure surfaced ~2 days after enqueue.
- Manual re-run path: `bin/rails sirene:import_stock`.
