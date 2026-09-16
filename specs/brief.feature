Feature: PR human review brief

  As a human reviewer
  I want a review brief generated for a ready pull request
  So that I can quickly understand the risk and decisions involved in reviewing it

  Scenario: A ready pull request gets a review brief
    Given the pull request targets "main"
    And the automated PR review has completed
    When the PR brief workflow runs
    Then it generates a human review brief using the PR Hound brief skill
    And the brief follows the repository human review brief template

  Scenario: The PR reviewer fails to complete the brief
    Given the pull request targets "main"
    And the automated PR review has completed
    When the PR reviewer fails to complete the brief
    Then the run fails
    And the failure details are shown in the log
