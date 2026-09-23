Feature: Review PRs of any size
  As a PR author or reviewer
  I want the bot to review the full diff regardless of size
  So that large PRs get complete coverage instead of a partial review

  # The elided diff is handed to a single agentic `claude -p` review pass, uncapped.
  # The reviewer reads it across as many turns as it needs (per-file Read with
  # offset/limit, Grep), so there is no byte budget and no truncation. One pass runs
  # per run, producing exactly one posted review.

  @integration
  Scenario: PR far above the old 512 KiB cap gets full-coverage findings
    Given a pull request whose elided diff exceeds 512 KiB
    When the PR reviewer runs
    Then the whole elided diff is written into the review bundle with no truncation trailer
    And the review covers the entire diff
    And the review body carries no "truncated" or partial-coverage notice

  @integration
  Scenario: Multi-MB hand-written diff gets full coverage
    Given a pull request whose elided, hand-written diff is several megabytes in size
    When the PR reviewer runs
    Then the review covers the entire diff
    And the review body carries no truncation notice

  @integration
  Scenario: One review is posted per run
    Given a pull request of any size
    When the PR reviewer completes its single review pass
    Then exactly one review is posted with one verdict and one Since-delta line
    And no finding appears more than once

  @integration
  Scenario: A review-pass error fails the run and posts no review
    Given a pull request under review
    When the review pass exits non-zero or times out
    Then the workflow run fails visibly
    And no review is posted at all
    And the bot never posts an approval or a partial review as if it succeeded

# --- AC Coverage Map ---
# AC 1: "PR far above 512 KiB gets full-coverage findings, no truncated notice" → Scenario: PR far above the old 512 KiB cap gets full-coverage findings
# AC 2: "Multi-MB hand-written diff gets full coverage with zero truncation notice" → Scenario: Multi-MB hand-written diff gets full coverage
# AC 3: "Exactly one review, one verdict, one Since-delta line per run" → Scenario: One review is posted per run
# AC 4: "A review-pass non-zero exit or timeout fails the run visibly and posts NO review — no silent partial approve, no posted-but-incomplete review" → Scenario: A review-pass error fails the run and posts no review
