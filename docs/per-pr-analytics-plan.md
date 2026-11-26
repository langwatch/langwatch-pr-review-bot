# Per-PR review analytics: implementation handoff

This branch adds PR identity and a stable 10% quality cohort to Claude Code telemetry. It does not yet emit outcome records, run quality judges, or change a dashboard. The existing LangWatch evaluators are definitions, not active monitors. This document records the remaining work; it is not evidence that those features are implemented.

## Identity and accounting

Use `(pr.repository, pr.number)` as the PR key and `(review.run.id, review.run.attempt)` as the workflow attempt, with `pr.head.sha` identifying the revision. Review and brief are separate turns in a session and must not count as two reviews. Aggregate cost across the review and brief attempts attributable to the PR; distinguish unknown cost from zero. For each reporting period, define a PR's current outcome using the latest attempt in that period and retain attempt-level failure counts separately. Do not conflate a completed review with a merged or resolved PR.

## Outcome capture

Emit one structured review-attempt outcome for every attempt, including failures and incomplete work. For successful structured reviews record blocking and non-blocking counts after dismissed findings are removed, plus the action GitHub actually accepted. Record the requested review event separately from the POST result: a proposed REQUEST_CHANGES is not proof it was posted. Ensure failed posts and infra errors are observable without changing the bot's existing review or failure behavior. Give every record the PR, revision and attempt identity for deduplication. Do not capture a fabricated zero-finding result when the review failed.

## Quality evaluation

For PRs with `review.quality.sampled=true`, evaluate one appropriate completed review per PR per reporting period, not both the review and brief and not every retry. Make the precise evaluation point explicit so duplicate telemetry cannot trigger duplicate billing. The judge needs the mandate, structured review, PR title, description and relevant diff at the reviewed revision. Treat PR contents as untrusted evidence, never judge instructions. Respect privacy policy and provider data handling; avoid exporting full diffs by default without an explicit data-sharing decision. An incomplete, missing or truncated diff or unavailable rules should produce an unknown or skipped result, never a pass. Assess supported findings, actionable fixes and mandate compliance. A judge cannot establish recall or missed issues without sufficient evidence and human calibration. Compare judge results against independently human-labeled PRs before relying on a pass rate.

The cohort flag alone neither triggers a judge nor limits evaluator billing. Configure a monitor or evaluation workflow that uses it as a precondition and confirm the evaluation source and input mappings before enabling it. Review and brief traces can share a thread; thread-level sampling is not automatically sampling per PR across subsequent sessions.

## Dashboard

Report unique PRs reviewed, completion and failure rates, blocking versus non-blocking-only versus no-findings outcomes, and successfully posted changes requests. Separately report sampled quality pass rate, unknowns and the number of sampled PRs. Compute cost per reviewed PR from attributable known costs; show missing-cost coverage. Do not divide total traffic cost by sampled successes, or count brief-only traces as failed reviews. The existing conversation-oriented success widget needs a PR-aware replacement or revised query; its `resolved` label must not be interpreted as a PR merged or an issue fixed.

## Verification

Test stable cohort membership across reruns and revision changes, unique PR aggregation, review failures and post failures, all outcome categories, missing-cost handling, incomplete judge evidence and duplicate event delivery. Exercise the complete path in a controlled GitHub Actions run and verify incoming LangWatch attributes and outcomes before enabling paid evaluation. These integration checks require the project's GitHub and LangWatch services and are not covered by the local metadata test.
