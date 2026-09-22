# PR Review Rules

The reviewer rejects **violations**, not preferences. A rule is enforced only when there is enough evidence to identify a real violation.

## Priorities

Every violation carries a priority and a blocking flag. Assign the priority from the rule's **default priority** below; raise it only when the concrete evidence warrants (for example, a "Code Quality" smell that actually causes a bug is P0, not P2).

- **P0 — blocking.** Correctness, security, data loss, or an acceptance criterion not met. A runtime or trust risk.
- **P1 — blocking.** Must fix before merge per these rules, but no runtime risk (for example, missing required tests, a missing `.feature` file, a mandated convention broken).
- **P2 — non-blocking.** Quality, style, or opinion. Reported so the author sees it, but does not gate the merge. Judge P2 findings with the "How to judge" methodology on the rule; without substantiating evidence, do not report them.

Only blocking findings (P0/P1) request changes and fail the review job. Non-blocking findings (P2) are still reported.

Each rule below is tagged with its default priority. Subjective rules also carry a short **How to judge** (what to compare against, what evidence to cite, what does NOT count).

## Intent & Decisions
- PR description clearly explains why the PR exists — **P1**
- The stated problem is valid and sufficiently justified — **P1**
- The proposed solution addresses the stated problem — **P0**
- Key implementation decisions are reasonable — **P2**
  - How to judge: compare the decision against the PR's own stated goal and existing repository conventions. Cite the specific decision and a concrete cost it imposes (a broken invariant, a cheaper path already in the repo). A decision you would merely have made differently does NOT count.
- Alternatives were considered where appropriate — **P2**
  - How to judge: only when the chosen approach carries a real, cited downside AND a standard alternative avoids it. Cite both. "An alternative exists" alone does NOT count.
- No unnecessary scope or invented requirements — **P1**
  - How to judge: compare the diff against the stated problem/AC. Cite the changed lines that serve no stated requirement. Refactors the author declared in the description do NOT count.
- Acceptance criteria (AC) are explicit — **P1**
- PR satisfies all acceptance criteria — **P0**
- If intent, solution, or AC cannot be justified, reject the PR — **P0**

## Correctness
- No bugs — **P0**
- All errors are handled appropriately — **P0**
- Real edge cases are handled — **P0**
  - How to judge: cite a concrete input or state that reaches the code and misbehaves. A hypothetical that cannot occur given the callers does NOT count.
- No unintended breaking changes — **P0**

## Code Quality
- No dead code or cruft — **P2**
- No redundant code — **P2**
- No unnecessary complexity — **P2**
  - How to judge: cite the simpler form that produces identical behavior. Compare against existing code in the same area. "I find it complex" without a simpler equivalent does NOT count.
- No YAGNI violations — **P2**
  - How to judge: cite the added capability that no current caller or AC uses. Extension points the AC explicitly asks for do NOT count.
- No speculative defensive coding — **P2**
  - How to judge: cite the guard for a condition that cannot occur given the code's callers/types. Guards on genuinely external/untrusted input do NOT count.
- Avoid branching logic where possible — **P2**
  - How to judge: cite a flatter form (early return, table, polymorphism) that removes the branch without changing behavior. Branches reflecting real distinct cases do NOT count.
- Prefer explicit over implicit behavior — **P2**
  - How to judge: cite the hidden behavior and where it surprises a reader. An established repo idiom does NOT count.
- No hidden defaults — **P2**
  - How to judge: cite the default value applied silently where the caller would reasonably expect to set it.
- Existing tools/services are reused — **P1**
  - How to judge: name the existing tool/service/abstraction in the trusted repository the change should have used, with its path. If none exists, this does NOT apply.
- Nothing reinvented that already has an off-the-shelf solution — **P1**
  - How to judge: name the specific off-the-shelf solution already available in the repo or its dependencies. A solution that is not present does NOT count.
- Naming and structure are clear and consistent — **P2**
  - How to judge: cite the inconsistency against a neighboring convention in the same module. Personal naming taste does NOT count.
- One primary export per file — **P1**
- No Clean Code violations — **P2**
  - How to judge: cite the specific principle and the line. A vague "not clean" does NOT count.

## Architecture
- Composition over inheritance — **P2**
  - How to judge: cite the inheritance used where composition is the repo norm and the inheritance creates real coupling.
- No SRP violations — **P2**
  - How to judge: name the two+ distinct responsibilities in one unit and why they change for different reasons.
- No SOLID violations — **P2**
  - How to judge: name the specific principle (S/O/L/I/D) and cite the code that breaks it.
- Controller / Service / Repository boundaries respected — **P1**
- Feature-based module structure respected — **P1**
- Dependencies flow in the intended direction — **P1**
  - How to judge: cite the import/call that points against the intended layer direction.
- Business logic does not leak into controllers or repositories — **P1**
  - How to judge: cite the domain logic located in a controller/repository that belongs in a service.
- No inappropriate coupling between features — **P1**
  - How to judge: cite the cross-feature import that couples two features that should be independent.
- One primary export per file — **P1**

## Testing
- All logic is tested — **P1**
  - How to judge: cite the added/changed behavior with no covering test. Trivial pass-throughs do NOT count.
- Tests test behavior, not implementation — **P2**
  - How to judge: cite the test asserting on internal calls/structure rather than observable behavior.
- No mocks — **P1**
  - How to judge: cite the mock/stub of a type the repo owns. A double at a genuine external boundary (network, clock, paid API) does NOT count.
- Matching `.feature` file — **P1**

## Security & Operations
- Security concerns addressed — **P0**
- Logging / observability appropriate — **P2**
  - How to judge: cite missing observability on a critical path, or a log that leaks secrets/PII (the latter is P0).

## Comments
- Comments are useful and necessary — **P2**
- No LLM-generated comment noise — **P2**
  - How to judge: cite the comment that restates what the code plainly does. Comments explaining WHY do NOT count.
- No historical narration of removed or changed code — **P2**
  - How to judge: cite the comment describing what the code used to do.
- No commented-out code or temporary notes left behind — **P2**
