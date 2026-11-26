#!/usr/bin/env bash
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/review-telemetry-attributes.sh"
export GITHUB_REPOSITORY='acme/review-bot' PR_NUMBER=42 PR_HEAD_SHA=abc123 GITHUB_RUN_ID=100 GITHUB_RUN_ATTEMPT=1
first="$(bash "$script")"
[[ "$first" == *'pr.repository=acme%2Freview-bot,pr.number=42,pr.head.sha=abc123,review.run.id=100,review.run.attempt=1,review.quality.sampled='* ]]
sample="${first##*review.quality.sampled=}"
[[ "$sample" == true || "$sample" == false ]]
export PR_HEAD_SHA=def456 GITHUB_RUN_ID=101 GITHUB_RUN_ATTEMPT=2
second="$(bash "$script")"
[[ "${second##*review.quality.sampled=}" == "$sample" ]]
[[ "$second" == *'pr.head.sha=def456,review.run.id=101,review.run.attempt=2'* ]]
export PR_NUMBER=0
if bash "$script" >/dev/null 2>&1; then echo 'invalid PR number accepted' >&2; exit 1; fi
printf 'PR telemetry attribute tests passed\n'
