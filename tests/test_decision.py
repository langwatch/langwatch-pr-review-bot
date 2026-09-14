from review_bot.decision import Violation, decide


def test_clean_review_passes():
    result = decide([])

    assert result.passed
    assert result.summary() == "All review criteria satisfied."


def test_violation_fails_and_reports_location():
    result = decide([
        Violation(
            rule_id="quality.redundancy",
            message="redundant implementation; existing service already provides this behavior",
            path="src/foo.ts",
            line=42,
        )
    ])

    assert not result.passed
    assert result.summary() == (
        "1 violation found.\n"
        "- src/foo.ts:42 — redundant implementation; existing service already provides this behavior"
    )


def test_multiple_violations_are_all_reported():
    result = decide([
        Violation("intent.description", "PR description does not establish why this behavior is required"),
        Violation("quality.redundancy", "new branch duplicates existing error handling"),
    ])

    assert not result.passed
    assert result.summary().startswith("2 violations found.\n")
    assert "why this behavior is required" in result.summary()
    assert "duplicates existing error handling" in result.summary()
