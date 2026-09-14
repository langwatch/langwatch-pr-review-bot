from dataclasses import dataclass


@dataclass(frozen=True)
class Rule:
    id: str
    text: str
    category: str


RULES = (
    Rule("intent.description", "PR description clearly explains why the PR exists", "Intent & Decisions"),
    Rule("intent.problem", "The stated problem is valid and sufficiently justified", "Intent & Decisions"),
    Rule("intent.solution", "The proposed solution addresses the stated problem", "Intent & Decisions"),
    Rule("intent.ac", "Acceptance criteria are explicit and satisfied", "Intent & Decisions"),
    Rule("correctness.bugs", "No bugs", "Correctness"),
    Rule("correctness.errors", "All errors are handled appropriately", "Correctness"),
    Rule("correctness.edges", "Real edge cases are handled", "Correctness"),
    Rule("quality.cruft", "No dead code or cruft", "Code Quality"),
    Rule("quality.redundancy", "No redundant code", "Code Quality"),
    Rule("quality.complexity", "No unnecessary complexity", "Code Quality"),
    Rule("quality.yagni", "No YAGNI violations", "Code Quality"),
    Rule("quality.defensive", "No speculative defensive coding", "Code Quality"),
    Rule("quality.explicit", "Prefer explicit over implicit behavior", "Code Quality"),
    Rule("quality.defaults", "No hidden defaults", "Code Quality"),
    Rule("quality.reuse", "Existing tools and services are reused", "Code Quality"),
    Rule("quality.clean-code", "No Clean Code violations", "Code Quality"),
    Rule("architecture.srp", "No SRP violations", "Architecture"),
    Rule("architecture.solid", "No SOLID violations", "Architecture"),
    Rule("architecture.boundaries", "Controller / Service / Repository boundaries are respected", "Architecture"),
    Rule("architecture.dependencies", "Dependencies flow in the intended direction", "Architecture"),
    Rule("testing.logic", "All logic is tested", "Testing"),
    Rule("testing.behavior", "Tests test behavior, not implementation", "Testing"),
    Rule("testing.no-mocks", "No mocks", "Testing"),
    Rule("testing.feature", "Matching .feature file", "Testing"),
    Rule("security.concerns", "Security concerns are addressed", "Security & Operations"),
    Rule("operations.observability", "Logging / observability is appropriate", "Security & Operations"),
    Rule("comments.noise", "No LLM-generated comment noise", "Comments"),
    Rule("comments.history", "No historical narration of removed or changed code", "Comments"),
    Rule("comments.commented-code", "No commented-out code or temporary notes left behind", "Comments"),
)
