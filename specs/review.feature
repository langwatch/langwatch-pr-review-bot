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
    Then new blocking violations are reported as inline review comments
    And the pull request is marked "changes requested"
    And the PR reviewer status check fails
    And a notification is posted to the Slack dev channel

  Scenario: Non-blocking or no findings pass the review
    Given all prerequisite checks are green
    When the PR reviewer finds only non-blocking findings, or none at all
    Then any new findings are reported as inline review comments
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

  Scenario: A follow-up review tracks resolved and still-open findings
    Given an earlier review with findings
    When a new push resolves some of them
    Then the follow-up review lists the resolved findings' ids in the top-level "resolved" array
    And re-emits each still-unresolved finding with its previous id and status "open"
    And no finding's summary or fix text narrates history

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

  Scenario: Still-open findings outside the diff stay listed in the review body
    Given a still-open finding that is outside the current pull request diff
    When the review is posted
    Then the finding appears in the review body under "Outside the diff" alongside any new outside-diff findings
    And the still-open finding gets no new inline comment

  Scenario: Inline comments carry a hidden finding id
    Given the PR reviewer reports a finding anchored to a diff line
    When the review is posted
    Then the inline comment contains a hidden HTML comment with the finding id
    And the id marker format is "<!-- id:<slug> -->"

  Scenario: Still-open findings link to their original inline comment
    Given a previous review posted an inline comment for a finding
    When the finding is still open
    Then the review body links to that inline comment under "Still open"

  Scenario: Inline comment states problem and fix only
    Given the PR reviewer reports a blocking finding anchored to a diff line
    When the review is posted
    Then the inline comment states the priority, the problem in one sentence, and the fix in one sentence
    And the inline comment contains no history narration, rule citation, or praise

  Scenario: Review body reports counts and the delta since the previous review
    Given a previous review of this pull request exists
    And the current review has new, still-open, and resolved findings
    When the review is posted
    Then the review body reports the blocking and non-blocking count
    And the review body reports the resolved, new, and still-open counts since the previous head sha
    And the review body does not explain what the pull request does
    And the review body does not repeat the inline findings

  Scenario: The first review omits the delta line
    Given no previous review of this pull request exists
    When the review is posted
    Then the review body reports the blocking and non-blocking count
    And the review body has no "Since" delta line

  Scenario: Only new findings get inline comments
    Given the current review has a new finding and a still-open finding, both anchored to diff lines
    When the review is posted
    Then only the new finding is posted as an inline comment
    And the still-open finding gets no new inline comment

  Scenario: Still-open blocking findings keep the review blocking
    Given the current review has a still-open blocking finding and no new findings
    When the review is posted
    Then the pull request is marked "changes requested"
    And the review posts no inline comments

  Scenario: Brief is one comment updated in place
    Given the automated review has completed
    When the human review brief is generated
    Then the brief is upserted as a single issue comment identified by its marker
    And an existing brief comment is updated in place instead of posting a new one
    And the comment begins with the signature "@LangWatchReviewBot" and the head sha
    And the brief is also uploaded as a workflow artifact

  Scenario: Brief comment is located by bot author and marker
    Given a previous brief comment exists
    When the pipeline searches for the brief comment to update
    Then it locates the comment by both the bot author (user.type == "Bot") and the marker text
    And a comment with the marker posted by a human is not updated

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

  Scenario: Installed action reads its own rules and template
    Given the action is installed in another repository
    When the review runs
    Then the reviewer reads the rules and brief template from the action's own directory
    And a brief that does not follow the template fails the run
