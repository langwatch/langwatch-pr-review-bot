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
