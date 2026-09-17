Feature: Automated PR review

  As a developer who has opened a pull request
  I want the PR reviewer to evaluate my PR only after all prerequisites are satisfied
  So that concrete engineering violations are caught before human review

  Scenario: Prerequisites are not satisfied
    Given the pull request targets "main"
    And one or more prerequisite checks have not passed
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: Prerequisites are satisfied and blocking violations are found
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    And all tests are green
    And there are no unresolved review comments
    When the PR reviewer evaluates the pull request using the repository review skill and review rules
    And one or more findings are blocking
    Then concrete violations are reported as inline review comments
    And the pull request is marked "changes requested"
    And the PR reviewer status check fails
    And a notification is posted to the Slack dev channel

  Scenario: Only non-blocking findings are found
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    And there are no unresolved review comments
    When the PR reviewer evaluates the pull request using the repository review skill and review rules
    And every finding is non-blocking
    Then the findings are reported as review comments
    And the pull request is not marked "changes requested"
    And the PR reviewer status check passes

  Scenario: Each finding carries a priority
    Given the pull request targets "main"
    When the PR reviewer reports a finding
    Then the finding carries a priority
    And the finding states whether it is blocking

  Scenario: A thread opened by the automated reviewer does not block the next review
    Given the pull request targets "main"
    And a review thread was opened by the automated reviewer and has no human reply
    And the thread is unresolved
    When the pipeline runs
    Then the PR reviewer runs

  Scenario: A human reply in a reviewer-opened thread still blocks the next review
    Given the pull request targets "main"
    And a review thread was opened by the automated reviewer
    And a human has replied in the thread
    And the thread is unresolved
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: A follow-up review remembers earlier findings
    Given a pull request that was already reviewed once
    And the pull request has been updated
    When the PR reviewer evaluates the updated pull request
    Then the reviewer re-checks each earlier finding against the current change
    And each earlier finding is marked resolved, still open, or superseded
    And the reviewer does not reverse earlier guidance without stating why
    And any new findings are reported

  Scenario: Prerequisites are satisfied and no violations are found
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    And all tests are green
    And there are no unresolved review comments
    When the PR reviewer evaluates the pull request using the repository review skill and review rules
    And no review violations are found
    Then the PR reviewer status check passes
    And the bot does not add violation comments

  Scenario: Missing reviewer credentials fail before any review
    Given the reviewer credentials are missing
    When the pipeline runs
    Then the run fails before any review with a clear error

  Scenario: Findings are accepted as a JSON document
    Given the PR reviewer returns its findings as a JSON document
    And the findings match the review schema
    When the pipeline extracts the findings
    Then the findings are accepted

  Scenario: Findings are accepted from a JSON block within prose
    Given the PR reviewer returns its findings as text containing a JSON block
    And the findings match the review schema
    When the pipeline extracts the findings
    Then the findings are accepted

  Scenario: Findings that do not match the schema fail the run
    Given the PR reviewer returns findings that do not match the review schema
    When the pipeline extracts the findings
    Then the run fails
    And the raw reviewer output is shown in the log

  Scenario: The PR reviewer fails to complete
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    When the PR reviewer fails to complete
    Then the run fails
    And the failure details are shown in the log
