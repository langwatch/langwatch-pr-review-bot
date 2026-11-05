Feature: Review bot observability

  As a maintainer of the review bot
  I want to see the agent's traces and details in the LangWatch project
  So that I can inspect, debug and measure every automated review

  Scenario: Review and brief runs appear as traces attributed to their pull request
    Given telemetry export to LangWatch is configured
    And GitHub is connected to the same LangWatch project
    When the PR reviewer and PR brief workflow run
    Then a trace appears in the LangWatch project for each run
    And each trace includes the prompts, responses, tool calls, and cost
    And each coding-agent session reports its checkout repository and branch
    And LangWatch links each session to the matching pull request

  Scenario: Telemetry export is not configured
    Given telemetry export to LangWatch is not configured
    When the pipeline runs
    Then the review runs unchanged and nothing is exported
