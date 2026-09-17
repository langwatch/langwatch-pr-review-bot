Feature: PR human review brief

  As a human reviewer
  I want a review brief generated for a ready pull request
  So that I can quickly understand the risk and decisions involved in reviewing it

  Scenario: A ready pull request gets a review brief
    Given the pull request targets "main"
    And the automated PR review has completed
    When the PR brief workflow runs
    Then it generates a human review brief following the repository template

  Scenario: The brief workflow fails to complete
    Given the pull request targets "main"
    And the automated PR review has completed
    When the PR brief workflow fails to complete
    Then the run fails with a clear error
