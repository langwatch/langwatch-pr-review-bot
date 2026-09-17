Feature: Automated PR review

  As a developer who has opened a pull request
  I want the PR reviewer to evaluate my PR only after all prerequisites are satisfied
  So that concrete engineering violations are caught before human review

  Background:
    Given the pull request targets "main"

  Scenario: Prerequisites are not satisfied
    Given one or more prerequisite checks have not passed
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: Reviewer credentials are missing
    Given the reviewer credentials are missing
    When the pipeline runs
    Then the run fails with a clear error before any review

  Scenario: Blocking findings request changes and notify Slack
    Given all prerequisite checks are green
    When the PR reviewer finds one or more blocking violations
    Then concrete violations are reported as inline review comments
    And the pull request is marked "changes requested"
    And the PR reviewer status check fails
    And a notification is posted to the Slack dev channel

  Scenario: Non-blocking or no findings pass the review
    Given all prerequisite checks are green
    When the PR reviewer finds only non-blocking findings, or none at all
    Then any findings are reported as review comments
    And the pull request is not marked "changes requested"
    And the PR reviewer status check passes
    And each finding carries a priority and states whether it is blocking

  Scenario: Reviewer output is accepted in either supported shape
    Given the PR reviewer returns valid findings, either as plain JSON or inside prose
    When the pipeline extracts the findings
    Then the findings are accepted

  Scenario: Reviewer output cannot be used
    Given all prerequisite checks are green
    When the PR reviewer fails to complete or returns findings in an unusable shape
    Then the run fails with a clear error

  Scenario: A reviewer-opened thread with no human reply does not block the next review
    Given an unresolved review thread opened by the automated reviewer with no human reply
    When the pipeline runs
    Then the PR reviewer runs

  Scenario: A human reply in a reviewer-opened thread blocks the next review
    Given an unresolved review thread opened by the automated reviewer where a human has replied
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: A follow-up review omits resolved findings
    Given an earlier review with findings
    When a new push resolves some of them
    Then the follow-up review omits the resolved findings
    And restates the remaining ones as first-time findings
    And no finding carries a resolved, still-open, superseded, or NEW label

  Scenario: A fork pull request is skipped
    Given a pull request opened from a fork
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: A configured label gates the review
    Given the reviewer is configured with a review label
    When a pull request does not carry that label
    Then the PR reviewer does not run

  Scenario: Slack notification is suppressed when disabled
    Given the reviewer is configured with slack_notify false
    When the PR reviewer finds one or more blocking violations
    Then no notification is posted to Slack

  Scenario: Findings outside the diff are reported in the body, not inline
    Given the PR reviewer reports a finding on a line outside the pull request diff
    When the review is posted
    Then the finding appears in the review body under "Outside the diff"
    And the finding is not posted as an inline comment

  Scenario: Inline comment states problem and fix only
    Given the PR reviewer reports a blocking finding anchored to a diff line
    When the review is posted
    Then the inline comment states the priority, the problem in one sentence, and the fix in one sentence
    And the inline comment contains no history narration, rule citation, or praise

  Scenario: Review body summarises for humans and does not repeat inline findings
    Given the PR reviewer reports findings anchored to diff lines
    When the review is posted
    Then the review body gives a plain-English overview and a blocking and non-blocking count
    And the review body does not repeat the inline findings

  Scenario: Review is signed @LangWatchReviewBot
    Given the PR reviewer posts any review
    When the review is posted
    Then the review body begins with the signature "@LangWatchReviewBot"

  Scenario: Installed in another repository as a GitHub Action
    Given a repository that installs the reviewer with only a thin caller workflow
    And the caller repository has no REVIEW_RULES.md and no .claude files
    When the PR reviewer runs through the installed GitHub Action
    Then the rules, agent, and skills come from the action's own repository
    And the target repository customizes behavior only through workflow inputs
