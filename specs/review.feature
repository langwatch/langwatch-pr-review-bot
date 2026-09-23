Feature: Automated PR review

  As a developer who has opened a pull request
  I want the PR reviewer to evaluate my PR only after all prerequisites are satisfied
  So that concrete engineering violations are caught before human review

  Background:
    Given the pull request targets "main"

  Scenario: Prerequisites are not satisfied
    Given one or more prerequisite checks have not passed
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: Reviewer credentials are missing
    Given the reviewer credentials are missing
    When the pipeline runs
    Then the run fails with a clear error before any review

  Scenario: Blocking findings request changes and notify Slack
    Given all prerequisite checks are green
    When the PR reviewer finds one or more blocking violations
    Then new blocking violations are reported as inline review comments
    And the pull request is marked "changes requested"
    And the PR reviewer status check fails
    And a notification is posted to the Slack dev channel

  Scenario: Non-blocking or no findings pass the review
    Given all prerequisite checks are green
    When the PR reviewer finds only non-blocking findings, or none at all
    Then any new findings are reported as inline review comments
    And the pull request is not marked "changes requested"
    And the PR reviewer status check passes
    And each finding carries a priority and states whether it is blocking

  Scenario: Reviewer output is accepted in either supported shape
    Given the PR reviewer returns valid findings, either as plain JSON or inside prose
    When the pipeline extracts the findings
    Then the findings are accepted

  Scenario: Reviewer output cannot be used
    Given all prerequisite checks are green
    When the PR reviewer fails to complete or returns findings in an unusable shape
    Then the run fails with a clear error

  Scenario: A reviewer-opened thread with no human reply does not block the next review
    Given an unresolved review thread opened by the automated reviewer with no human reply
    When the pipeline runs
    Then the PR reviewer runs

  Scenario: A human reply on the bot's own finding thread does not block the next review
    Given an unresolved review thread whose first comment is this bot's finding
    And a human has replied in that thread
    When the pipeline runs
    Then the PR reviewer runs

  Scenario: A human-opened unresolved thread still blocks the next review
    Given an unresolved review thread whose first comment is human-authored
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: A bot-only reply in a thread does not block the next review
    Given an unresolved review thread with replies only from bots (CodeRabbit, Dependabot, etc.)
    When the pipeline runs
    Then the PR reviewer runs

  Scenario: A follow-up review tracks resolved and still-open findings
    Given an earlier review with findings
    When a new push resolves some of them
    Then the follow-up review lists the resolved findings' ids in the top-level "resolved" array
    And re-emits each still-unresolved finding with its previous id and status "open"
    And no finding's summary or fix text narrates history

  Scenario: Fixed findings resolve their review threads
    Given a previous review opened inline threads for findings
    And the new review reports some of those findings fixed
    When the review has been posted and the previous findings recorded
    Then each fixed finding's thread is resolved first
    And only after the resolve succeeds is a reply "Fixed as of <sha7>" posted to it

  Scenario: A failed thread resolution posts no reply
    Given a fixed finding whose thread cannot be resolved by the current github_token
    When self-cleaning runs
    Then no reply is posted to that thread
    And a warning names the finding id and the token requirement

  Scenario: A finding with no inline thread is not resolved
    Given a fixed finding that was only reported in the review body, with no inline thread
    When self-cleaning runs
    Then a warning names the finding id
    And no thread is resolved for it

  Scenario: A dropped finding id is treated as resolved
    Given a previous finding id that is absent from both the new "findings" and "resolved" arrays
    When self-cleaning runs
    Then its thread is treated as fixed and resolved

  Scenario: Re-running on an unchanged diff posts no duplicate resolution reply
    Given a finding whose thread was already resolved on a previous run
    When self-cleaning runs again on an unchanged diff
    Then no reply is posted to that thread
    And the thread is not mutated again

  Scenario: A human thread quoting a finding marker is never resolved by the bot
    Given an unresolved thread a human opened whose body quotes a finding's "<!-- id: -->" marker
    When self-cleaning runs
    Then the bot neither resolves nor replies to that thread

  Scenario: A human review starting with the bot signature is never dismissed
    Given a human-authored changes-requested review whose body begins with the bot signature
    When the new review approves the pull request
    Then that human review is not dismissed

  Scenario: A clean re-review dismisses the bot's prior changes-requested reviews
    Given the bot posted an earlier "changes requested" review on this pull request
    When the new review approves the pull request
    Then each earlier changes-requested review by the bot is dismissed as superseded
    And the review just posted is not dismissed
    And no human or other-bot review is dismissed

  Scenario: A still-blocking re-review keeps the bot's prior changes-requested review
    Given the bot posted an earlier "changes requested" review on this pull request
    When the new review still requests changes
    Then no review is dismissed

  Scenario: A human explanation on a bot thread closes the finding as accepted
    Given an unresolved bot-opened thread with a human reply that explains why the finding does not apply
    When the bot reviews the next push
    Then the finding is reported as accepted, not open and not new
    And the thread is resolved with a one-line "Accepted" reply
    And the review body counts it under "accepted" in the delta line

  Scenario: A follow-on issue reference on a bot thread closes the finding as accepted
    Given an unresolved bot-opened thread on a blocking finding with a human reply that references a follow-on issue
    When the bot reviews the next push
    Then the finding is reported as accepted
    And the thread is resolved with a one-line "Accepted" reply
    And the review body lists the finding under "Deferred with a linked issue:"

  Scenario: A bare acknowledgement on a bot thread keeps the finding open
    Given an unresolved bot-opened thread with a human reply that only acknowledges the finding without explanation or reference
    When the bot reviews the next push
    Then the finding stays open
    And the thread stays unresolved

  Scenario: A bot-authored reply never counts as acceptance
    Given an unresolved bot-opened thread whose only replies are authored by a bot
    When the bot reviews the next push
    Then the finding is not accepted on the basis of that reply

  Scenario: A non-member reply cannot accept a finding
    Given an unresolved bot-opened thread whose only reply is from an author who is not an owner, member, or collaborator
    When the bot reviews the next push
    Then that reply is dropped before the reviewer sees it
    And the finding is not accepted on the basis of that reply

  Scenario: A human-dismissed bot review marks its findings accepted
    Given the bot's previous changes-requested review was dismissed by a human
    And that review's findings are still unresolved
    When the bot reviews the next push
    Then each of those findings is reported as accepted, not open and not new
    And each such thread is resolved with an "Accepted: dismissed by <actor>" reply
    And the review body counts them under "accepted" in the delta line

  Scenario: A dismissed review with no new findings yields an approving review
    Given the bot's previous changes-requested review was dismissed by a human
    And the fresh review finds no new blocking problems
    When the bot reviews the next push
    Then the review is an approval
    And the review job exits zero

  Scenario: New findings after a dismissal still block
    Given the bot's previous changes-requested review was dismissed by a human
    And the fresh review finds a new blocking problem on new code
    When the bot reviews the next push
    Then the review requests changes for the new finding
    And the dismissed findings are still reported as accepted

  Scenario: A dismissal is honored once and does not auto-accept later findings
    Given a human dismissed the bot's changes-requested review and the bot then approved
    When a later push introduces a new blocking problem
    Then the new finding blocks the review
    And it is not auto-accepted on the basis of the earlier dismissal

  Scenario: Dismissing the bot's approving review does not accept its findings
    Given the bot's most recent review is an approval that a human then dismissed
    When the bot reviews the next push
    Then its findings are not marked accepted on the basis of that dismissal
    And any still-open finding stays open

  Scenario: A review the bot dismissed itself is not treated as accepted
    Given the bot dismissed its own earlier changes-requested review as superseded
    When the bot reviews the next push
    Then its findings are not marked accepted on the basis of that dismissal

  Scenario: Cleanup failure does not fail the review job
    Given a thread resolution or review dismissal call fails
    When self-cleaning runs
    Then the failure is reported as a warning naming the item id
    And the review job exit code is unchanged

  Scenario: A fork pull request is skipped
    Given a pull request opened from a fork
    When the pipeline runs
    Then the PR reviewer does not run

  Scenario: A configured label gates the review
    Given the reviewer is configured with a review label
    When a pull request does not carry that label
    Then the PR reviewer does not run

  Scenario: Slack notification is suppressed when disabled
    Given the reviewer is configured with slack_notify false
    When the PR reviewer finds one or more blocking violations
    Then no notification is posted to Slack

  Scenario: Findings outside the diff are reported in the body, not inline
    Given the PR reviewer reports a finding on a line outside the pull request diff
    When the review is posted
    Then the finding appears in the review body under "Outside the diff"
    And the finding is not posted as an inline comment

  Scenario: Still-open findings outside the diff stay listed in the review body
    Given a still-open finding that is outside the current pull request diff
    When the review is posted
    Then the finding appears in the review body under "Outside the diff" alongside any new outside-diff findings
    And the still-open finding gets no new inline comment

  Scenario: Inline comments carry a hidden finding id
    Given the PR reviewer reports a finding anchored to a diff line
    When the review is posted
    Then the inline comment contains a hidden HTML comment with the finding id
    And the id marker format is "<!-- id:<slug> -->"

  Scenario: Still-open findings link to their original inline comment
    Given a previous review posted an inline comment for a finding
    When the finding is still open
    Then the review body links to that inline comment under "Still open"

  Scenario: Inline comment states problem and fix only
    Given the PR reviewer reports a blocking finding anchored to a diff line
    When the review is posted
    Then the inline comment states the priority, the problem in one sentence, and the fix in one sentence
    And the inline comment contains no history narration, rule citation, or praise

  Scenario: Review body reports counts and the delta since the previous review
    Given a previous review of this pull request exists
    And the current review has new, still-open, and resolved findings
    When the review is posted
    Then the review body reports the blocking and non-blocking count
    And the review body reports the resolved, new, and still-open counts since the previous head sha
    And the review body does not explain what the pull request does
    And the review body does not repeat the inline findings

  Scenario: The first review omits the delta line
    Given no previous review of this pull request exists
    When the review is posted
    Then the review body reports the blocking and non-blocking count
    And the review body has no "Since" delta line

  Scenario: Only new findings get inline comments
    Given the current review has a new finding and a still-open finding, both anchored to diff lines
    When the review is posted
    Then only the new finding is posted as an inline comment
    And the still-open finding gets no new inline comment

  Scenario: Still-open blocking findings keep the review blocking
    Given the current review has a still-open blocking finding and no new findings
    When the review is posted
    Then the pull request is marked "changes requested"
    And the review posts no inline comments

  Scenario: Brief is one comment updated in place
    Given the automated review has completed
    When the human review brief is generated
    Then the brief is upserted as a single issue comment identified by its marker
    And an existing brief comment is updated in place instead of posting a new one
    And the comment begins with the signature "@LangWatchReviewBot" and the head sha
    And the brief is also uploaded as a workflow artifact

  Scenario: Brief comment is located by bot author and marker
    Given a previous brief comment exists
    When the pipeline searches for the brief comment to update
    Then it locates the comment by both the bot author (user.type == "Bot") and the marker text
    And a comment with the marker posted by a human is not updated

  Scenario: Review is signed @LangWatchReviewBot
    Given the PR reviewer posts any review
    When the review is posted
    Then the review body begins with the signature "@LangWatchReviewBot"

  Scenario: Installed in another repository as a GitHub Action
    Given a repository that installs the reviewer with only a thin caller workflow
    And the caller repository has no REVIEW_RULES.md and no .claude files
    When the PR reviewer runs through the installed GitHub Action
    Then the rules, agent, and skills come from the action's own repository
    And the target repository customizes behavior only through workflow inputs

  Scenario: Installed action reads its own rules and template
    Given the action is installed in another repository
    When the review runs
    Then the reviewer reads the rules and brief template from the action's own directory
    And a brief that does not follow the template fails the run

  Scenario: Review prompt stays small regardless of PR size
    Given a pull request whose diff exceeds the reviewer's stdin input limit
    When the PR reviewer runs
    Then the PR title, description, and diff are written to a file referenced in the prompt
    And the file is kept in the workspace alongside the other scratch files
    And no PR body or diff is piped to the reviewer on standard input
    And the review runs without exceeding the input size limit

  Scenario: The diff is never capped and is reviewed whole at any size
    Given a pull request whose elided diff is arbitrarily large
    When the PR reviewer runs
    Then the whole elided diff is written into the review bundle with no truncation trailer
    And the bundle records the total file count and the shown file count
    And the prompt tells the reviewer the diff may be large and to read it in full
    And the prompt tells the reviewer never to claim coverage of any part it did not read
    And the review body begins with the signature "@LangWatchReviewBot"
    And the review body carries no truncation notice

  Scenario: Generated files are elided from the review diff and reported
    Given a pull request that changes files marked "linguist-generated=true" in the base branch .gitattributes
    When the PR reviewer runs
    Then those files are excluded from the diff
    And the review bundle names the elided generated files and their count
    And the prompt tells the reviewer the count of elided files and not to review their contents line-by-line
    And the prompt does not contain the elided file names
    And the review body states how many generated files were elided
    And the total file count still includes the elided generated files

  Scenario: Generated attributes are read from the base branch, not the pull request head
    Given a pull request that marks one of its own changed files "linguist-generated=true" only in the head .gitattributes
    And that file is not marked generated on the base branch
    When the PR reviewer runs
    Then that file is NOT elided from the review diff

  Scenario: Five or fewer generated files are listed by basename in the body
    Given a pull request with five or fewer elided generated files
    When the review is posted
    Then the review body lists the elided files by basename after the count

  Scenario: More than five generated files collapse to a count in the body
    Given a pull request with more than five elided generated files
    When the review is posted
    Then the review body states only the count of elided files with no file list

  Scenario: A runner whose git lacks check-attr --source reviews the full diff
    Given a runner whose git does not support "git check-attr --source" (git older than 2.40)
    When the PR reviewer runs
    Then the run logs a warning that generated files are not elided
    And the full diff is reviewed with no files elided
    And the generated-elided output is zero
    And the run does not fail because of the git version

  Scenario: A pull request with no generated files leaves the diff untouched
    Given a pull request whose changed files are not marked "linguist-generated=true" on the base branch
    When the PR reviewer runs
    Then the review diff is the same as the unelided diff
    And the review body carries no generated-files notice
    And the generated-elided output is zero

  Scenario: Eliding generated files never adds a truncation notice
    Given a pull request whose diff is large because of generated files
    When the generated files are elided and the remaining diff is reviewed
    Then the remaining diff is reviewed whole with no truncation trailer
    And the review body carries no truncation notice
    And the review body reports the generated files that were elided

  # --- Licensing design decisions against the linked issue (issue #13) ---

  @ac-1
  Scenario: Every design decision traces to a linked-issue acceptance criterion
    Given the pull request is linked to an issue that has acceptance criteria
    And every design decision in the diff traces to one of those acceptance criteria
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then no unlicensed-decision finding is reported

  @ac-2
  Scenario: An unlicensed decision has no acceptance criterion and no license line
    Given the pull request is linked to an issue that has acceptance criteria
    And the diff introduces a design decision that no acceptance criterion requested
    And the pull request body has no "license:" line for that decision
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then a blocking finding "unlicensed-decision-<slug>" is reported citing the specific decision
    And the finding states that no acceptance criterion in the linked issue covers it

  @ac-3
  Scenario: A decision is licensed by a line in the pull request body
    Given the pull request introduces a design decision with no matching acceptance criterion
    And the pull request body contains a "Decision: <X> — license: AC-<n>" or "license: owner ratified <url>" line for that decision
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then the unlicensed-decision finding is suppressed for that decision

  @ac-4
  Scenario: The pull request has no linked issue
    Given the pull request has no linked issue
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then a single non-blocking "no-linked-issue" finding reports that licenses cannot be checked
    And no per-decision finding is fabricated

  @ac-5
  Scenario: The linked issue has no acceptance criteria
    Given the pull request is linked to an issue that has no acceptance criteria
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then a single non-blocking "no-linked-issue" finding reports that licenses cannot be checked
    And no per-decision finding is fabricated

  @ac-6
  Scenario: A benign untraced choice is not flagged as unlicensed
    Given the diff contains a routine implementation choice that no acceptance criterion names
    And that choice is not invented scope
    When the PR reviewer evaluates the "every design decision is licensed" rule
    Then no unlicensed-decision finding is reported for that choice

  @ac-7
  Scenario: Owner acceptance resolves a flagged decision
    Given the bot has posted an unlicensed-decision finding on a pull request thread
    When the owner replies "Accepted:" on that thread
    Then the finding is resolved through the existing owner-acceptance mechanism
    And the finding is not re-raised on the next review

  @ac-8
  Scenario: The existing scope rule still catches unrelated unrequested changes
    Given the diff contains a change unrelated to any design-decision framing that serves no stated requirement
    When the PR reviewer evaluates the scope rules
    Then a finding is still reported for that change
