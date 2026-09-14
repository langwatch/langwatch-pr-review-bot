from dataclasses import dataclass


@dataclass(frozen=True)
class Violation:
    rule_id: str
    message: str
    path: str | None = None
    line: int | None = None


@dataclass(frozen=True)
class ReviewResult:
    violations: tuple[Violation, ...]

    @property
    def passed(self) -> bool:
        return not self.violations

    def summary(self) -> str:
        if self.passed:
            return "All review criteria satisfied."

        count = len(self.violations)
        lines = [f"{count} violation{'s' if count != 1 else ''} found."]
        for violation in self.violations:
            location = ""
            if violation.path:
                location = violation.path
                if violation.line:
                    location += f":{violation.line}"
                location += " — "
            lines.append(f"- {location}{violation.message}")
        return "\n".join(lines)


def decide(violations: list[Violation] | tuple[Violation, ...]) -> ReviewResult:
    """Turn concrete findings into the single pass/fail decision used by CI.

    The reviewer should supply only evidence-backed violations. Preferences,
    stylistic disagreements, and low-value suggestions do not belong here.
    """
    return ReviewResult(tuple(violations))
