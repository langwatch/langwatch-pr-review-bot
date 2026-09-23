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
- PRs targeting the configured base branch (default `main`, via `base_branch`) are reviewed only when there are no unresolved **human** review comments. Threads from bots (CodeRabbit, Dependabot, this bot, etc.) never block the review; only comments a human OPENED do — a human reply inside one of the bot's own finding threads does not block.
- When a finding the bot raised is fixed, the bot resolves that finding's own review thread so the PR shows only open work; a finding with no thread of its own is left alone, and nothing is ever deleted.
- When a later review approves the PR, the bot's own earlier "changes requested" reviews are superseded so the merge status reflects the current verdict; a human's or another bot's review is never touched.
- A finding the bot raised is closed as accepted, rather than raised again, when a human with write access replies to its thread refuting it or deferring it to a linked issue; a bare acknowledgement or a reply from someone without write access does not close it.
- When a human dismisses the bot's "changes requested" review, its still-unresolved findings are treated as accepted (counted under "accepted", their threads resolved) so a dismissal with no new problems turns the check green; a review the bot dismissed itself does not, and new findings on new code still block.
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
- The PR diff is **not capped**. The whole elided diff is handed to the reviewer, which reads it agentically across as many turns as the PR needs (per-file `Read` with offset/limit, `Grep`), so a large PR gets full coverage. The review body carries no truncation notice.
- Files marked `linguist-generated=true` in the `.gitattributes` **on the base branch** are elided from the review diff, so large generated blobs (prisma manifests, big fixtures) do not crowd out human-authored files. Attributes are read from the base ref, not the PR head, so a pull request cannot hide its own files by marking them generated. The review body and reviewer prompt report the elided file count. To opt a file in, add a line such as `path/to/file.generated.json linguist-generated=true` to the base branch's `.gitattributes`; the literal value `true` is required (`set` or any other value keeps the file in the diff). Resolving attributes on the base ref needs git ≥ 2.40 (for `git check-attr --source`); on an older runner the action logs a warning and reviews the full diff without eliding.
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
  # contents: write lets the default GITHUB_TOKEN resolve fixed findings' threads
  # (resolveReviewThread). Drop it to contents: read if you do not want thread resolution.
  contents: write
  pull-requests: write
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - uses: langwatch/langwatch-pr-review-bot@main
        with:
          slack_notify: "false"
          claude_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          langwatch_ingest_key: ${{ secrets.LANGWATCH_INGEST_KEY }}
```

Pin to a commit SHA; repositories that require SHA-pinned actions reject tag and branch refs, including the actions nested inside this one. Repositories without this policy can use `@main` or `@v1` tags. If you set `review_label`, also add `labeled` to the trigger `types`.

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
        +--> block only when a HUMAN opened an unresolved thread
        |     (replies on the bot's own findings never block)
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

1. **A review with the delta.** The body is for humans: it opens with `**@LangWatchReviewBot**`. There is no truncation notice — the diff is never capped. When any files were elided as generated it adds a `Generated files elided (N): <basenames>` line (a bare `Generated files elided (N).` above five files). It gives a `**N blocking · M non-blocking**` count (or `**No blocking findings.**` when clean), and — when a previous review exists — a `Since <sha7>: X resolved · Y new · Z still open` line. Still-open findings that carry a stored inline url get a `Still open:` line linking each id straight to its thread. The body never explains the PR and never repeats the inline findings. It lists outside-diff findings — both `new` and still-`open` (open findings with no stored url) — under `Outside the diff:`, so a still-open blocker never disappears. The review is `REQUEST_CHANGES` when any finding is blocking (new or still-open), otherwise `APPROVE`.
2. **Inline comments for the new findings.** One per finding with `status: new` anchored to a diff line, formatted as `**[P0 · blocking]** <what is wrong>` followed by `Fix: <the concrete change>` — no history narration, no rule citations, no praise. Still-open findings get no new inline comment; a run whose only blocking findings are still-open posts the short body with no inline comments — the "still blocked" signal.
3. **The human review brief as a PR comment.** Upserted into one issue comment per PR: the bot finds its prior brief by the `<!-- langwatch-review-brief -->` marker and updates it in place, or posts a new one when none exists. The comment is headed `**@LangWatchReviewBot** · Review brief · \`<head sha7>\``. The brief is standalone and is also uploaded as a workflow artifact.

Findings are delta-aware: each carries a stable `id` and a `status` of `new` or `open`, and the reviewer returns a top-level `resolved` array of the ids fixed since the last run. That state is persisted to `last-review.json` inside the cached session directory so the next run knows what it reported before.

### Session memory across runs

Claude Code stores each session transcript under `~/.claude/projects`. The workflow caches that directory with `actions/cache`, keyed by PR (`claude-session-<repo_id>-pr-<N>-<run_id>`, with a `-pr-<N>-` restore prefix). The review step also writes the run's `session_id` to a small file inside the cached directory. On the next run for the same PR, if that id and its transcript are present, the review resumes with `claude -p --resume "$SESSION_ID"`; otherwise it starts fresh. The save step runs `if: always()`, so the conversation persists even when blocking findings fail the job.

Resuming gives the reviewer a memory of its earlier findings. The next review re-checks each previous finding against the current diff — resolved, still open, or superseded — instead of re-deriving from scratch and silently reversing itself.

### Self-cleaning threads and reviews

After the review is posted and the run's findings are recorded, a separate best-effort step cleans up the action's own past output so the PR shows only open work. It never deletes anything, and every operation is best-effort: a failure is a workflow warning naming the item and never fails the job. Thread reconciliation runs only when a previous review exists (the first review has nothing to reconcile); review dismissal runs on every approving review, including the first.

- **Resolved-finding threads.** For each finding the new review reports fixed — an id in the top-level `resolved` array, or a prior id that has vanished from `findings`, `resolved`, and the accepted ids (gone means fixed) — the action finds the review thread whose root comment carries that finding's `<!-- id:<id> -->` marker. A thread is the bot's own only when its root author is the login the bot posts as (resolved once via GraphQL `viewer { login }` — which returns `github-actions` under the default token — and falling back to `github-actions[bot]` only if that query fails) **and** the root body carries the marker — never login alone, never marker alone — so a human quoting a finding is not mistaken for the bot's own thread, and a user or GitHub-App `github_token` is recognised the same as the default one. It **resolves the thread first**, and only when the resolve succeeds posts one reply `` **@LangWatchReviewBot** Fixed as of `<sha7>`. `` — so a token that cannot resolve never leaves a dangling "done" reply on a still-open thread. A fixed finding with no inline thread is reported as a warning instead. Already-resolved threads are left untouched, so re-running on an unchanged diff posts no duplicate reply. Threads not rooted in this bot's own comment are never touched.
- **Stale changes-requested reviews.** When the new review approves the PR, the action dismisses each earlier review still in `CHANGES_REQUESTED` that is the bot's own — its author is the login the bot posts as **and** its body begins with the `**@LangWatchReviewBot**` signature (both required, so neither a human review under a shared login nor a human quoting the signature is dismissed) — with the message `` Superseded by `<sha7>` review. ``, so the merge status reflects the current verdict. It never dismisses the review just posted, a human review, or another bot's review, and it dismisses nothing while the new review still requests changes.
- **Findings explained away or deferred in a reply.** Before each review the action collects the replies on its own unresolved finding threads and passes them to the reviewer inside the untrusted evidence fence. Only replies from an `OWNER`, `MEMBER`, or `COLLABORATOR` are shown to the reviewer; a reply from an outside account cannot accept a finding and is dropped (the count is logged). When a shown reply substantively refutes a finding, or defers it to a concrete follow-on (an issue/PR number, a GitHub issue URL, or wording like "tracked in"/"deferred to"), the reviewer marks the finding **accepted** instead of re-raising it: the delta line then reads `Since <sha7>: X resolved · A accepted · Y new · Z still open`, the thread is resolved (again, resolve first) with a `` **@LangWatchReviewBot** Accepted: <reason> `` reply, and a deferred blocking finding is also listed under `Deferred with a linked issue:` so the deferral is visible. A bare acknowledgement ("acknowledged", "will fix") does not accept, and a bot-authored reply never counts.

The bot acts through the workflow's `github_token`. Posting thread replies and the [dismiss-a-review](https://docs.github.com/en/rest/pulls/reviews#dismiss-a-review-for-a-pull-request) REST call work under `pull-requests: write`. Resolving a thread with [`resolveReviewThread`](https://docs.github.com/en/graphql/reference/mutations#resolvereviewthread) needs one more grant: add `contents: write` to the workflow's `permissions:` alongside `pull-requests: write`. With both, the default `GITHUB_TOKEN` (`github-actions[bot]`) resolves threads — no PAT or GitHub-App token is required (verified on proof PR #11: with only `contents: read` the mutation returns `Resource not accessible by integration`; adding `contents: write` resolves the thread). Because the action resolves before replying, a token that still cannot resolve posts no reply at all and emits a warning naming the finding and this requirement, rather than leaving a "done" reply on a thread that stays open. Either way the resolve failure is only a `::warning::` and never fails the job.

### Priorities and blocking

Every finding carries a `priority` and a `blocking` flag, defined in [`REVIEW_RULES.md`](REVIEW_RULES.md#priorities). P0 (correctness/security/data-loss/AC-not-met) and P1 (must-fix, no runtime risk) are blocking; P2 (quality/style/opinion, judged with per-rule methodology) is non-blocking. The review posts `REQUEST_CHANGES` when at least one finding is blocking (new or still-open) and `APPROVE` otherwise. The "Fail when violations were found" step fails the job only on blocking findings.

The generated brief is written to `pr-review-brief.md`, added to the GitHub Actions job summary, and uploaded as a workflow artifact.

### Licensing design decisions

The reviewer checks that every design decision in a PR was actually asked for. Before the review, the action reads the PR body for closing keywords (`Closes|Fixes|Resolves #N`, case-insensitive) and full issue URLs, fetches each linked issue's body and comments, and passes its Gherkin scenarios and `## Acceptance Criteria` list to the reviewer as `<linked-issue number="N">` sections inside the untrusted evidence fence. It also collects any `license:` lines from the PR body into a `<licenses>` section.

Two trust boundaries apply to this fetch:

- **Comment author trust.** An `## Acceptance Criteria` / Gherkin section is only extracted from the linked issue's body and from comments posted by an `OWNER`, `MEMBER`, or `COLLABORATOR` (the same allow-list used for finding-acceptance replies). A comment from any other account is fetched but never scanned for AC/Gherkin text, so an outside commenter cannot forge scope for the license check.
- **Same-repo only.** A full issue URL naming a different `owner/repo` than the PR's own is never fetched — the fetch runs with the workflow's own token, so following an arbitrary cross-repo URL would let a PR body make that token read from a repo it has no business touching. A cross-repo ref is dropped and recorded in the bundle as `<linked-issue-skipped repo="owner/name" number="N" reason="cross-repo"/>` instead of being fetched.

A **design decision** is a diff choice that introduces a constraint or capability nobody requested: a new limit/cap/threshold, a config knob, an abstraction, a fallback path, a new dependency, a retry/timeout policy, or a schema change. Each one must trace to a linked-issue acceptance criterion/scenario or to a `license:` line. A decision that traces to neither gets a **blocking** finding, `unlicensed-decision-<slug>`, that quotes the decision and states no acceptance criterion covers it. Benign choices — naming, formatting, test structure, a private helper extraction, an early return — are not design decisions and are never flagged.

**Escape hatch.** An author licenses a decision up front by adding a line to the PR body:

- `Decision: <what> — license: AC-<n>` — the decision is covered by acceptance criterion _n_.
- `license: owner ratified <url>` — the owner ratified it out of band; link the ratification.

Either line suppresses the `unlicensed-decision` finding for that decision. After the fact, the owner can also clear a posted finding by replying on its thread with a reason the finding does not apply, or a concrete follow-on (an issue/PR number, a URL, "tracked in ...") — the same owner-acceptance mechanism used for every other finding. A bare acknowledgement with no explanation or reference does not accept the finding.

When a PR links **no** issue (or the linked issue has no acceptance criteria), the reviewer cannot check licenses. It then posts a single **non-blocking** `no-linked-issue` note saying so, and flags no individual decisions.

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
