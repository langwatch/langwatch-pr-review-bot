Feature: Review bot observability

  As a maintainer of the review bot
  I want to see the agent's traces and details in the LangWatch project
  So that I can inspect, debug and measure every automated review

  Background:
    Given the repository secret "LANGWATCH_INGEST_KEY" is set
    And the workflow ".github/workflows/review.yml" sets job-level OpenTelemetry env pointing at "https://app.langwatch.ai/api/otel"

  Scenario: A review run exports a trace
    Given the "Run automated review" step runs "claude -p"
    When the step completes
    Then a trace appears in the LangWatch project with service name "pr-review-bot"
    And the trace input contains the review prompt

  Scenario: The trace carries full detail
    Given a review run has exported a trace
    Then the trace includes log records for the user prompt
    And the trace includes log records for assistant responses
    And the trace includes log records for tool calls with tool content
    And the trace includes log records for raw API bodies
    And the trace includes metrics for tokens and cost

  Scenario: The brief step is also traced
    Given the "Generate human review brief" step runs
    When the step completes
    Then it exports its own trace to the same LangWatch project

  Scenario: Missing key does not break the review
    Given the repository secret "LANGWATCH_INGEST_KEY" is empty
    When the pipeline runs
    Then telemetry is disabled
    And the review still completes
    And no trace is exported

  Scenario: Self-hosted endpoint
    Given "OTEL_EXPORTER_OTLP_ENDPOINT" is changed to a self-hosted LangWatch instance
    When a review run exports a trace
    Then the trace is exported to the self-hosted endpoint
    And no other configuration changes
