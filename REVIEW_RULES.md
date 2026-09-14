# PR Review Rules

The reviewer rejects **violations**, not preferences. A rule should be enforced only when there is enough evidence to identify a real violation.

## Intent & Decisions

- PR description clearly explains why the PR exists
- The stated problem is valid and sufficiently justified
- The proposed solution addresses the stated problem
- Key implementation decisions are reasonable
- Alternatives were considered where appropriate
- No unnecessary scope or invented requirements
- Acceptance criteria (AC) are explicit
- PR satisfies all acceptance criteria
- If intent, solution, or AC cannot be justified, reject the PR

## Correctness

- No bugs
- All errors are handled appropriately
- Real edge cases are handled
- No unintended breaking changes

## Code Quality

- No dead code or cruft
- No redundant code
- No unnecessary complexity
- No YAGNI violations
- No speculative defensive coding
- Avoid branching logic where possible
- Prefer explicit over implicit behavior
- No hidden defaults
- Existing tools/services are reused
- Nothing reinvented that already has an off-the-shelf solution
- Naming and structure are clear and consistent
- One primary export per file
- No Clean Code violations

## Architecture

- Composition over inheritance
- No SRP violations
- No SOLID violations
- Controller / Service / Repository boundaries respected
- Feature-based module structure respected
- Dependencies flow in the intended direction
- Business logic does not leak into controllers or repositories
- No inappropriate coupling between features
- One primary export per file

## Testing

- All logic is tested
- Tests test behavior, not implementation
- No mocks
- Matching `.feature` file

## Security & Operations

- Security concerns addressed
- Logging / observability appropriate

## Comments

- Comments are useful and necessary
- No LLM-generated comment noise
- No historical narration of removed or changed code
- No commented-out code or temporary notes left behind
