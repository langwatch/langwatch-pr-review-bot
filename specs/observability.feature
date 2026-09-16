Feature: Review bot observability

  As a maintainer of the review bot
  I want to see the agent's traces and details in the LangWatch project
  So that I can inspect, debug and measure every automated review

  Background:
    Given telemetry export to LangWatch is configured

  Scenario: A review run is recorded as a trace
    When the PR reviewer evaluates the pull request
    Then a trace for the review run appears in the LangWatch project
    And the trace includes the review prompt

  Scenario: The trace carries full conversation detail
    When the PR reviewer evaluates the pull request
    Then the trace includes the prompts and responses exchanged
    And the trace includes the tool calls made and their content
    And the trace includes token and cost metrics

  Scenario: The human brief generation is recorded too
    Given the automated PR review has completed
    When the PR brief workflow runs
    Then a trace for the brief generation appears in the LangWatch project

  Scenario: Telemetry export is not configured
    Given telemetry export to LangWatch is not configured
    When the pipeline runs
    Then the review runs unchanged
    And nothing is exported
