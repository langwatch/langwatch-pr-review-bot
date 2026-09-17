# LangWatch PR Review Bot

Automated PR review focused on **violations, not preferences**.

The reviewer can challenge the problem, proposed solution, implementation, architecture, tests, security, and comments. It rejects only when it can identify a concrete violation supported by the PR context.

## Problem

PR review in this repository should be an enforceable engineering gate, not a suggestion engine. The bot needs to reject concrete violations of the repository's review rules while treating PR-controlled content as untrusted input.

## Acceptance criteria

- Review rules live in the repository and are applied consistently.
- The review skill, agent, and rules are read from the base branch and cannot be replaced by a PR. The workflow file itself (including the prompt and output contract) is PR-controlled like any GitHub Actions workflow, and changes to it must be reviewed by a human.
- PR title, description, and diff are treated as untrusted evidence and prompt-injection attempts do not become reviewer instructions.
- Claude Code runs headlessly through `claude -p` with the dedicated `pr-reviewer` agent and schema-validated review output.
- Reviewer is read-only and cannot edit the repository.
- PRs targeting `main` are reviewed only after repository prerequisites pass and there are no unresolved **human** review comments (the bot's own review threads do not block the next run).
- Every finding carries a `priority` (`P0`/`P1`/`P2`) and a `blocking` flag. P0/P1 are blocking; P2 is non-blocking.
- A clean review posts `APPROVE`.
- Blocking violations post `REQUEST_CHANGES` with inline comments, notify Slack, and fail the review job.
- Only non-blocking findings post as a `COMMENT` review (still visible, inline) without failing the job.
- Reviews are exhaustive in one pass: every substantiated violation is reported, each citing `file:line` and the rule.
- The reviewer's session is remembered across runs on the same PR, so a follow-up review re-checks its earlier findings instead of re-deriving and reversing them.
- After the automated review completes, the workflow continues the same Claude session with the `pr-brief` skill and generates the human review brief from its template.

## How it works

```text
PR opened / updated
        |
        v
repository prerequisites
        |
        +--> skip unless base branch is main
        |
        +--> block if HUMAN review threads are unresolved
        |
        v
trusted base checkout
        |
        +--> restore cached Claude session for this PR
        |
        +--> Claude Code: pr-reviewer agent
        |       |
        |       +--> resume prior session when present (memory of past findings)
        |       +--> pr-review skill
        |       +--> read-only repo inspection
        |
        +--> PR diff supplied as untrusted evidence
        |
        v
structured review result (each finding: priority + blocking)
  |             |              |
  v             v              v
PASS      BLOCKING        NON-BLOCKING ONLY
  |             |              |
APPROVE   REQUEST_CHANGES   COMMENT
  |             |              |
  +------ slack notification on blocking violations
  |
  v
Claude --continue
  |
  +--> save session to cache (if: always)
  |
  +--> pr-brief skill
  +--> TEMPLATE.md
  |
  v
human review brief
```

The review rules live in [`REVIEW_RULES.md`](REVIEW_RULES.md).

The trusted Claude-specific instructions live on the trusted base in:

- `.claude/skills/pr-review/SKILL.md` — violation-focused review methodology
- `.claude/skills/pr-brief/SKILL.md` — human review brief workflow
- `.claude/skills/pr-brief/TEMPLATE.md` — source of truth for brief structure
- `.claude/agents/pr-reviewer.md` — dedicated read-only subagent profile with access to both skills

The review job checks out the PR's base SHA, never the PR-controlled tree, so the review skill, agent, and `REVIEW_RULES.md` cannot be replaced by a PR. It fetches the PR ref only to compute a diff. The workflow file itself (including the prompt and output contract) is PR-controlled like any GitHub Actions workflow, so changes to it must be reviewed by a human.

The workflow itself owns the gate and orchestration. There is no Python application layer: GitHub Actions performs prerequisite checks, gathers the diff, invokes Claude, validates the review output against the review JSON schema with `ajv`, posts the GitHub review, sends Slack notifications, generates the brief, and fails the job when violations are found.

The automated review runs through `claude -p` with a JSON Schema. The brief then uses `claude --continue` in the same job session, so the second stage can use the completed review context without becoming a second code review.

### Session memory across runs

Claude Code stores each session transcript under `~/.claude/projects`. The workflow caches that directory with `actions/cache`, keyed by PR (`claude-session-<repo_id>-pr-<N>-<run_id>`, with a `-pr-<N>-` restore prefix). The review step also writes the run's `session_id` to a small file inside the cached directory. On the next run for the same PR, if that id and its transcript are present, the review resumes with `claude -p --resume "$SESSION_ID"`; otherwise it starts fresh. The save step runs `if: always()`, so the conversation persists even when blocking findings fail the job.

Resuming gives the reviewer a memory of its earlier findings. A follow-up review re-checks each previous finding against the current diff — resolved, still open, or superseded — instead of re-deriving from scratch and silently reversing itself.

### Priorities and blocking

Every finding carries a `priority` and a `blocking` flag, defined in [`REVIEW_RULES.md`](REVIEW_RULES.md#priorities). P0 (correctness/security/data-loss/AC-not-met) and P1 (must-fix, no runtime risk) are blocking; P2 (quality/style/opinion, judged with per-rule methodology) is non-blocking. The review posts `REQUEST_CHANGES` only when at least one finding is blocking, `COMMENT` when there are only non-blocking findings, and `APPROVE` when clean. The "Fail when violations were found" step fails the job only on blocking findings.

The generated brief is written to `pr-review-brief.md`, added to the GitHub Actions job summary, and uploaded as a workflow artifact.

## Configuration

The workflow expects these repository secrets:

- `CLAUDE_CODE_OAUTH_TOKEN` — OAuth token for Claude Code authentication. Generate locally with `claude setup-token`, which prints a token starting with `sk-ant-oat01-…`. Paste this token value as the secret.
- `SLACK_WEBHOOK_URL` — used to post violation notifications to Slack.
- `LANGWATCH_INGEST_KEY` — optional; when set, enables telemetry export, see [Telemetry (LangWatch)](#telemetry-langwatch) below.

The GitHub token used for reviews and prerequisite thread checks comes from the built-in `GITHUB_TOKEN` secret.

Claude Code is installed from the official `@anthropic-ai/claude-code` package at a pinned version. The reviewer uses the `opus` model alias from the dedicated agent profile.

## Telemetry (LangWatch)

When `LANGWATCH_INGEST_KEY` is set, every review run exports full Claude Code OpenTelemetry data (traces, logs, metrics, prompt and tool content) to LangWatch. Without it, telemetry is disabled and the review runs unchanged.

Secret (optional):

- `LANGWATCH_INGEST_KEY` — a LangWatch **ingest key** (`ik-lw-...`, trace-write only) created in the project settings, e.g. https://app.langwatch.ai/langwatch-pr-review-bot-jSBhhR/settings. A project API key (`sk-lw-...`) also works but grants more than needed; prefer the ingest key. The workflow sends it as `Authorization: Bearer`.

The export is configured as job-level `env` in `.github/workflows/review.yml`. Self-hosted LangWatch: change `OTEL_EXPORTER_OTLP_ENDPOINT` to `<your-instance>/api/otel`.

Docs:

- https://langwatch.ai/docs/coding-agents/claude-code
- https://code.claude.com/docs/en/monitoring-usage

## Review philosophy

This bot is intentionally not a suggestion engine. It does not report cosmetic preferences or weak hypotheticals. Within that bar it is exhaustive, not sparse: in one pass it reports every violation it can substantiate, each citing `file:line` and the rule, and marks which are non-blocking rather than dropping them. Priority (P0/P1/P2) separates what must gate the merge from what is worth seeing but not blocking. When it catches a recurring real problem, add one concise rule to `REVIEW_RULES.md` with its default priority and, for subjective rules, a short "How to judge"; update the skill only when the workflow/instructions themselves need to change.
