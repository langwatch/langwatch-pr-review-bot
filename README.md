# LangWatch PR Review Bot

Automated PR review focused on **violations, not preferences**.

The reviewer can challenge the problem, proposed solution, implementation, architecture, tests, security, and comments. It rejects only when it can identify a concrete violation supported by the PR context.

## Problem

PR review in this repository should be an enforceable engineering gate, not a suggestion engine. The bot needs to reject concrete violations of the repository's review rules while treating PR-controlled content as untrusted input.

## Acceptance criteria

- Review rules live in the repository and are applied consistently.
- Reviewer instructions are trusted and cannot be replaced by a PR.
- PR title, description, and diff are treated as untrusted evidence and prompt-injection attempts do not become reviewer instructions.
- Claude Code runs headlessly through `claude -p` with the dedicated `pr-reviewer` agent and schema-validated review output.
- Reviewer is read-only and cannot edit the repository.
- PRs targeting `main` are reviewed only after repository prerequisites pass and there are no unresolved review comments.
- A clean review posts `APPROVE`.
- Concrete violations post `REQUEST_CHANGES` with inline comments, notify Slack, and fail the review job.
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
        +--> block if review threads are unresolved
        |
        v
trusted base checkout
        |
        +--> Claude Code: pr-reviewer agent
        |       |
        |       +--> pr-review skill
        |       +--> read-only repo inspection
        |
        +--> PR diff supplied as untrusted evidence
        |
        v
structured review result
  |             |
  v             v
PASS          VIOLATIONS
  |             |
APPROVE     REQUEST_CHANGES
  |             |
  +------ slack notification on violations
  |
  v
Claude --continue
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

The review job checks out the PR's base SHA, never the PR-controlled tree. It fetches the PR ref only to compute a diff, so PR changes cannot replace the reviewer configuration before evaluation.

The workflow itself owns the gate and orchestration. There is no Python application layer: GitHub Actions performs prerequisite checks, gathers the diff, invokes Claude, validates the schema output with `jq`, posts the GitHub review, sends Slack notifications, generates the brief, and fails the job when violations are found.

The automated review runs through `claude -p` with a JSON Schema. The brief then uses `claude --continue` in the same job session, so the second stage can use the completed review context without becoming a second code review.

The generated brief is written to `pr-review-brief.md`, added to the GitHub Actions job summary, and uploaded as a workflow artifact.

## Configuration

The workflow expects these repository secrets:

- `ANTHROPIC_API_KEY` — used by Claude Code.
- `SLACK_WEBHOOK_URL` — used to post violation notifications to Slack.

The GitHub token used for reviews and prerequisite thread checks comes from the built-in `GITHUB_TOKEN` secret.

Claude Code is installed from the official `@anthropic-ai/claude-code` package at a pinned version. The reviewer uses the `opus` model alias from the dedicated agent profile.

## Review philosophy

This bot is intentionally not a suggestion engine. It should not report cosmetic preferences or weak hypotheticals. When it catches a recurring real problem, add one concise rule to `REVIEW_RULES.md` and update the skill only when the workflow/instructions themselves need to change.
