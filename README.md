# LangWatch PR Review Bot

Automated PR review focused on **violations, not preferences**.

The reviewer may challenge the problem, the proposed solution, the implementation, architecture, tests, and project conventions — not merely the code style.

## Review philosophy

A PR should be rejected only for a concrete violation of the review rules. The checklist is intentionally short and should evolve as the bot catches recurring classes of mistakes.

## Initial review areas

- PR intent, problem, solution, decisions, and acceptance criteria
- Correctness and breaking changes
- Code quality and unnecessary complexity
- Architecture and dependency boundaries
- Tests and behavior coverage
- Security and observability
- Comments, dead code, and cruft

See [`REVIEW_RULES.md`](REVIEW_RULES.md) for the current checklist.

## Status

Initial repository scaffold. The GitHub Action and reviewer implementation are added in the first development PR.
