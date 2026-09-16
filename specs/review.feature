Feature: Automated PR review

  As a developer who has opened a pull request
  I want the PR reviewer to evaluate my PR only after all prerequisites are satisfied
  So that concrete engineering violations are caught before human review

  Scenario: Prerequisites are not satisfied
    Given the pull request targets "main"
    And one or more prerequisite checks have not passed
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: Prerequisites are satisfied and violations are found
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    And all tests are green
    And there are no unresolved review comments
    When the PR reviewer evaluates the pull request using the repository review skill and review rules
    Then concrete violations are reported as inline review comments
    And the pull request is marked "changes requested"
    And the PR reviewer status check fails
    And a notification is posted to the Slack dev channel

  Scenario: Prerequisites are satisfied and no violations are found
    Given the pull request targets "main"
    And all prerequisite pipeline checks are green
    And all tests are green
    And there are no unresolved review comments
    When the PR reviewer evaluates the pull request using the repository review skill and review rules
    And no review violations are found
    Then the PR reviewer status check passes
    And the bot does not add violation comments

  Scenario: Auth token resolves from the primary secret
    Given the repository secret "CLAUDE_CODE_OAUTH_TOKEN" is set
    When the pipeline checks the Claude auth token
    Then the token is accepted
    And the PR reviewer proceeds

  Scenario: Auth token falls back to the legacy secret
    Given the repository secret "CLAUDE_CODE_OAUTH_TOKEN" is empty
    And the repository secret "ANTHROPIC_API_KEY" is set
    When the pipeline checks the Claude auth token
    Then the token is accepted
    And the PR reviewer proceeds

  Scenario: Empty auth token fails before any review
    Given the repository secret "CLAUDE_CODE_OAUTH_TOKEN" is empty
    And the repository secret "ANTHROPIC_API_KEY" is empty
    When the pipeline checks the Claude auth token
    Then the check fails with a clear error
    And no review is attempted

  Scenario: Violations are accepted from a JSON-string result
    Given the "Run automated review" step returns violations as a JSON-encoded string in "result"
    And every violation item matches the schema
    When the pipeline extracts violations
    Then the violations are accepted

  Scenario: Violations are accepted from a fenced JSON block in prose
    Given the "Run automated review" step returns violations inside a fenced ```json``` block within prose in "result"
    And every violation item matches the schema
    When the pipeline extracts violations
    Then the violations are accepted

  Scenario: Malformed violations fail extraction
    Given the "Run automated review" step returns an output whose extracted items do not match the schema
    When the pipeline extracts violations
    Then the extraction step fails
    And the raw output is dumped to the log
