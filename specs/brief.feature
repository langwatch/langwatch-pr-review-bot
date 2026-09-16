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

  Scenario: Brief generation fails when claude -p exits non-zero
    Given the pull request targets "main"
    And the automated PR review has completed
    When the "Generate human review brief" step runs claude -p
    And claude -p exits with a non-zero code
    Then the exit code, stderr, and any partial brief are printed to the log
    And the step fails with that exit code
