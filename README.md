# LangWatch PR Review Bot

Automated PR review focused on **violations, not preferences**.

The reviewer can challenge the problem, proposed solution, implementation, architecture, tests, security, and comments. It rejects only when it can identify a concrete violation supported by the PR context.

## Problem

PR review in this repository should be an enforceable engineering gate, not a suggestion engine. The bot needs to reject concrete violations of the repository's review rules while treating PR-controlled content as untrusted input.

## Acceptance criteria

- Review rules live in the repository and are applied consistently.
- The review skill, agent, and rules ship with the action's own repository (fetched by the runner into `${{ github.action_path }}`) and, in an installed/consumer repository, cannot be replaced by a PR. The caller workflow itself (including the pinned action ref) is PR-controlled like any GitHub Actions workflow, and changes to it must be reviewed by a human. This repository's own dogfood workflow deliberately runs the action from the PR under review (`uses: ./`), so self-review here is not a trust boundary.
- PR title, description, and diff are treated as untrusted evidence and prompt-injection attempts do not become reviewer instructions.
- Claude Code runs headlessly through `claude -p` with the dedicated `pr-reviewer` agent and schema-validated review output.
- Reviewer is read-only and cannot edit the repository.
- PRs targeting the configured base branch (default `main`, via `base_branch`) are reviewed only when there are no unresolved **human** review comments (the bot's own review threads do not block the next run).
- The bot installs as a composite GitHub Action; a target repo adds a thin caller workflow (checkout + `uses:`) and customizes through inputs, with no `REVIEW_RULES.md` or `.claude/` files of its own.
- An optional label gate (`review_label`) restricts the review to PRs carrying that label when set; empty means always on.
- Fork PRs are skipped, because secrets are unavailable there.
- Slack notification is opt-out: `slack_notify: false` suppresses it, and only an explicit false disables it.
- `extra_instructions` appends caller-workflow guidance to the review prompt; it is reviewed by humans as a workflow change.
- The action ref on the `uses:` line (`@main`, or a pinned `@v1` tag) selects the version of the rules, agent, and skills that ships with the run.
- Inline review comments are posted only for findings inside the PR diff; findings outside the diff (new and still-open) are listed in the review body under "Outside the diff".
- Every finding carries a `priority` (`P0`/`P1`/`P2`) and a `blocking` flag. P0/P1 are blocking; P2 is non-blocking.
- A review with no blocking finding posts `APPROVE`; a review with any blocking finding (new or still-open) posts `REQUEST_CHANGES`, notifies Slack, and fails the review job.
- Every finding is anchored to `file:line` and states the problem and the fix.
- Each run posts a NEW delta-aware review: findings carry a stable `id` and `status` (`new`/`open`), the reviewer returns a top-level `resolved` array, and the body shows the `Since <sha7>` delta. Only `new` findings get inline comments.
- Findings persist across runs to `last-review.json` in the cached session directory, so the next run knows what it reported before.
- After the automated review completes, the workflow continues the same Claude session with the `pr-brief` skill, generates the human review brief from its template, upserts it as a single marker-identified PR comment (updated in place across runs), and uploads it as an artifact.

## Install in your repository

The bot is a composite GitHub Action. Your repository does **not** need `REVIEW_RULES.md` or any `.claude/` files — the action's own repo ships the rules, agent, and skills. You customize only through inputs.

Add `.github/workflows/review.yml` to your repo (copy from [`install/review.yml`](install/review.yml)):

```yaml
name: PR Review Bot
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
permissions:
  contents: read
  pull-requests: write
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - uses: langwatch/langwatch-pr-review-bot@main
        with:
          slack_notify: "false"
          claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          langwatch_ingest_key: ${{ secrets.LANGWATCH_INGEST_KEY }}
```

Pin the action at `@main` for now; once a `v1` tag is cut, pin `@v1` instead. If you set `review_label`, also add `labeled` to the trigger `types`.

### Secrets

Secrets reach the action through inputs (a composite action has no `secrets:` block). Pass them from your repo secrets on the `with:` line, as the snippet above does.

| Secret | Passed as input | Required | Purpose |
| --- | --- | --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude_oauth_token` | yes | Claude Code auth. Generate with `claude setup-token` (starts with `sk-ant-oat01-…`). |
| `LANGWATCH_INGEST_KEY` | `langwatch_ingest_key` | no | Enables LangWatch telemetry export. See [Telemetry](#telemetry-langwatch). |
| `SLACK_WEBHOOK_URL` | `slack_webhook_url` | no | Slack notification target for blocking findings. |

### Inputs

| Input | Default | Effect |
| --- | --- | --- |
| `review_label` | `""` | When set, the review runs only on PRs carrying this label. Empty = always on. |
| `slack_notify` | `"true"` | Post a Slack notification on blocking findings (needs `slack_webhook_url`). Only `"false"` disables it. |
| `extra_instructions` | `""` | Extra guidance appended to the review prompt, subordinate to the action's rules file. On same-repo pull_request events this text is PR-controlled; do not treat it as trusted. |
| `base_branch` | `"main"` | Only review PRs whose base branch is this branch. |
| `claude_oauth_token` | — (required) | Claude Code OAuth token. |
| `langwatch_ingest_key` | `""` | LangWatch ingest key; enables telemetry when set. |
| `slack_webhook_url` | `""` | Slack webhook for blocking-finding notifications. |
| `github_token` | `${{ github.token }}` | Token for GitHub API calls (thread checks, posting the review). |
| `claude_code_version` | `"2.1.270"` | Version of `@anthropic-ai/claude-code` to install. |

Fork PRs are skipped automatically (secrets are unavailable there). The reviewer runs only on PRs targeting `base_branch` (default `main`).

## How it works

```text
PR opened / updated
        |
        v
context checks
        |
        +--> skip unless base branch matches base_branch (default main)
        |
        +--> block if HUMAN review threads are unresolved
        |
        v
action's own repo (trusted rules/agent/skills)
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
APPROVE   REQUEST_CHANGES   APPROVE
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

The trusted Claude-specific instructions ship with the action's repository, loaded via the user setting source:

- `.claude/skills/pr-review/SKILL.md` — violation-focused review methodology
- `.claude/skills/pr-brief/SKILL.md` — human review brief workflow
- `.claude/skills/pr-brief/TEMPLATE.md` — source of truth for brief structure
- `.claude/agents/pr-reviewer.md` — dedicated read-only subagent profile with access to both skills

The runner fetches the action's own repository into `${{ github.action_path }}` and the action loads its agent and skills from there through the Claude Code **user** setting source, then runs with `--setting-sources user`. That excludes the target repository's own project/local `.claude` settings and hooks, so in an installed/consumer repository a PR cannot swap the reviewer's rules, agent, or skills, or inject hooks. The reviewer reads the rules only from the trusted `REVIEW_RULES.md` supplied by the action (an absolute path outside the working tree). The caller checks out the PR head as the code under review, treated as untrusted evidence. The caller workflow itself (including the pinned action ref) is PR-controlled like any GitHub Actions workflow, so changes to it must be reviewed by a human. This repository's own dogfood workflow deliberately runs the action from the PR under review (`uses: ./`), so self-review here is not a trust boundary.

The action itself owns the gate and orchestration. It embeds a small Python diff-parsing helper but no application layer: its steps run the context checks, gather the diff, invoke Claude, validate the review output against the review JSON schema with `ajv`, post the GitHub review, send Slack notifications, generate the brief, and fail the job when violations are found.

The automated review runs through `claude -p` with a JSON Schema. The brief then uses `claude --continue` in the same job session, so the second stage can use the completed review context without becoming a second code review.

### What it posts

Each run posts three things, delta-aware against the bot's previous review on the same PR:

1. **A review with the delta.** The body is for humans: it opens with `**@LangWatchReviewBot**`, gives a `**N blocking · M non-blocking**` count (or `**No blocking findings.**` when clean), and — when a previous review exists — a `Since <sha7>: X resolved · Y new · Z still open` line. Still-open findings that carry a stored inline url get a `Still open:` line linking each id straight to its thread. The body never explains the PR and never repeats the inline findings. It lists outside-diff findings — both `new` and still-`open` (open findings with no stored url) — under `Outside the diff:`, so a still-open blocker never disappears. The review is `REQUEST_CHANGES` when any finding is blocking (new or still-open), otherwise `APPROVE`.
2. **Inline comments for the new findings.** One per finding with `status: new` anchored to a diff line, formatted as `**[P0 · blocking]** <what is wrong>` followed by `Fix: <the concrete change>` — no history narration, no rule citations, no praise. Still-open findings get no new inline comment; a run whose only blocking findings are still-open posts the short body with no inline comments — the "still blocked" signal.
3. **The human review brief as a PR comment.** Upserted into one issue comment per PR: the bot finds its prior brief by the `<!-- langwatch-review-brief -->` marker and updates it in place, or posts a new one when none exists. The comment is headed `**@LangWatchReviewBot** · Review brief · \`<head sha7>\``. The brief is standalone and is also uploaded as a workflow artifact.

Findings are delta-aware: each carries a stable `id` and a `status` of `new` or `open`, and the reviewer returns a top-level `resolved` array of the ids fixed since the last run. That state is persisted to `last-review.json` inside the cached session directory so the next run knows what it reported before.

### Session memory across runs

Claude Code stores each session transcript under `~/.claude/projects`. The workflow caches that directory with `actions/cache`, keyed by PR (`claude-session-<repo_id>-pr-<N>-<run_id>`, with a `-pr-<N>-` restore prefix). The review step also writes the run's `session_id` to a small file inside the cached directory. On the next run for the same PR, if that id and its transcript are present, the review resumes with `claude -p --resume "$SESSION_ID"`; otherwise it starts fresh. The save step runs `if: always()`, so the conversation persists even when blocking findings fail the job.

Resuming gives the reviewer a memory of its earlier findings. The next review re-checks each previous finding against the current diff — resolved, still open, or superseded — instead of re-deriving from scratch and silently reversing itself.

### Priorities and blocking

Every finding carries a `priority` and a `blocking` flag, defined in [`REVIEW_RULES.md`](REVIEW_RULES.md#priorities). P0 (correctness/security/data-loss/AC-not-met) and P1 (must-fix, no runtime risk) are blocking; P2 (quality/style/opinion, judged with per-rule methodology) is non-blocking. The review posts `REQUEST_CHANGES` when at least one finding is blocking (new or still-open) and `APPROVE` otherwise. The "Fail when violations were found" step fails the job only on blocking findings.

The generated brief is written to `pr-review-brief.md`, added to the GitHub Actions job summary, and uploaded as a workflow artifact.

## Configuration

The workflow expects these repository secrets:

- `CLAUDE_CODE_OAUTH_TOKEN` — OAuth token for Claude Code authentication. Generate locally with `claude setup-token`, which prints a token starting with `sk-ant-oat01-…`. Paste this token value as the secret.
- `SLACK_WEBHOOK_URL` — used to post violation notifications to Slack.
- `LANGWATCH_INGEST_KEY` — optional; when set, enables telemetry export, see [Telemetry (LangWatch)](#telemetry-langwatch) below.

The GitHub token used for reviews and prerequisite thread checks comes from the `github_token` input, which defaults to the job's built-in `${{ github.token }}`.

Claude Code is installed from the official `@anthropic-ai/claude-code` package at a pinned version. The reviewer uses the `opus` model alias from the dedicated agent profile.

## Telemetry (LangWatch)

When `LANGWATCH_INGEST_KEY` is set, every review run exports full Claude Code OpenTelemetry data (traces, logs, metrics, prompt and tool content) to LangWatch. Without it, telemetry is disabled and the review runs unchanged.

Secret (optional):

- `LANGWATCH_INGEST_KEY` — a LangWatch **ingest key** (`ik-lw-...`, trace-write only) created in the project settings, e.g. https://app.langwatch.ai/langwatch-pr-review-bot-jSBhhR/settings. A project API key (`sk-lw-...`) also works but grants more than needed; prefer the ingest key. The workflow sends it as `Authorization: Bearer`.

The export is configured inside the action's steps (`action.yml`): the non-secret OTEL variables are written once to `$GITHUB_ENV`, and the secret-bearing `OTEL_EXPORTER_OTLP_HEADERS` is set per `claude -p` step so no secret is echoed. Self-hosted LangWatch: change `OTEL_EXPORTER_OTLP_ENDPOINT` to `<your-instance>/api/otel`.

Docs:

- https://langwatch.ai/docs/coding-agents/claude-code
- https://code.claude.com/docs/en/monitoring-usage

## Review philosophy

This bot is intentionally not a suggestion engine. It does not report cosmetic preferences or weak hypotheticals. Within that bar it is exhaustive, not sparse: in one pass it reports every violation it can substantiate, with every finding anchored to `file:line` and stating the problem and the fix, and marks which are non-blocking rather than dropping them. Priority (P0/P1/P2) separates what must gate the merge from what is worth seeing but not blocking. When it catches a recurring real problem, add one concise rule to `REVIEW_RULES.md` with its default priority and, for subjective rules, a short "How to judge"; update the skill only when the workflow/instructions themselves need to change.
