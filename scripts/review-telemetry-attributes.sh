#!/usr/bin/env bash
# Build non-secret OpenTelemetry resource attributes for the review and brief.
# A repository/PR pair always lands in the same 10% cohort, including retries.
set -euo pipefail

repo="${GITHUB_REPOSITORY:-}"
pr="${PR_NUMBER:-}"
sha="${PR_HEAD_SHA:-}"
run="${GITHUB_RUN_ID:-}"
attempt="${GITHUB_RUN_ATTEMPT:-}"
if [[ -z "$repo" || ! "$pr" =~ ^[1-9][0-9]*$ || -z "$sha" || -z "$run" || -z "$attempt" ]]; then
  echo 'Missing PR identity or workflow run metadata' >&2
  exit 1
fi

# Hash only the PR identity, not the revision or workflow run. Use the first
# 32 bits to avoid shell integer overflow. The cohort is a stable approximation
# to 10%, not a guarantee that exactly 10% of a finite set will be selected.
hash="$(printf '%s#%s' "$repo" "$pr" | sha256sum)"
bucket=$((16#${hash:0:8} % 10))
if [[ "$bucket" -eq 0 ]]; then sampled=true; else sampled=false; fi
encode() { jq -rn --arg value "$1" '$value | @uri'; }
printf 'service.name=pr-review-bot,pr.repository=%s,pr.number=%s,pr.head.sha=%s,review.run.id=%s,review.run.attempt=%s,review.quality.sampled=%s\n' \
  "$(encode "$repo")" "$pr" "$(encode "$sha")" "$(encode "$run")" "$(encode "$attempt")" "$sampled"
