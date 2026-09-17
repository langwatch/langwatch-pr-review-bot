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

  Scenario: A follow-up review remembers earlier findings
    Given a pull request that was already reviewed once and has since been updated
    When the PR reviewer evaluates the updated pull request
    Then each earlier finding is marked resolved, still open, or superseded
    And any new findings are reported
