# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment.

1. ## Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

State your assumptions explicitly. If uncertain, ask.
If multiple interpretations exist, present them - don't pick silently.
If a simpler approach exists, say so. Push back when warranted.
If something is unclear, stop. Name what's confusing. Ask.

2. ## Simplicity First

Minimum code that solves the problem. Nothing speculative.

No features beyond what was asked.
No abstractions for single-use code.
No "flexibility" or "configurability" that wasn't requested.
No error handling for impossible scenarios.
If you write 200 lines and it could be 50, rewrite it.
Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

3. ## Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

Don't "improve" adjacent code, comments, or formatting.
Don't refactor things that aren't broken.
Match existing style, even if you'd do it differently.
If you notice unrelated dead code, mention it - don't delete it.
When your changes create orphans:

Remove imports/variables/functions that YOUR changes made unused.
Don't remove pre-existing dead code unless asked.
The test: Every changed line should trace directly to the user's request.

File-granularity exception (split on sight): when your work touches a type or view that lives in an oversized bucket file (~500+ lines), extract the piece you're working on into its own file as part of the change. Extraction is move-only — no behavior changes, no restyling of the moved code. Don't split files your change doesn't touch.

4. ## Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

"Add validation" → "Write tests for invalid inputs, then make them pass"
"Fix the bug" → "Write a test that reproduces it, then make it pass"
"Refactor X" → "Ensure tests pass before and after"
For multi-step tasks, state a brief plan:

> 1. [Step] → verify: [check]
> 2. [Step] → verify: [check]
> 3. [Step] → verify: [check]

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

5. ## Branching & Commits

Work happens on branches. main stays clean.

No feature work or bug fixes on main.
Branch names should relate to the work being done.
Don't merge until changes are device/simulator verified.
Claude handles the commit (summary & description). I handle the push.
Small cosmetic or trivial hotfixes are permissible on main with approval — case-by-case.

# Release & Authorial Docs

- DECISIONS.md — Append new entries when in-session decisions are
  made. Use the existing format (`## YYYY-MM-DD (title)`, then
  **Decision** / **Why** / **Alternative considered**). Do not
  rewrite or reorganize existing entries.
- TODO.md — Mark off existing items as work completes. Add new items
  for future sessions when prompted or when work is deferred to a
  separate session. When you complete an item, check it off and move
  it to Done with a date (YYYY-MM-DD). Don't leave shipped work
  sitting in Next or Backlog.
- CHANGELOG.md — in-flight changes to the project as a result of
  coding sessions.

This project doesn't use a separate brainstorm/planning agent
alongside Claude Code (no Cowork split), so Claude Code owns these
docs end to end during sessions — no handoff notes needed. Revisit
this if that changes.

### Release Docs

ASC_LISTING.md and RELEASE_NOTES.md don't exist yet — the project
hasn't reached a release pass. Add them when the app gets close to
shipping, not before. Once they exist: ASC_LISTING.md is App Store
Connect listing copy (surface anything release-worthy in your session
summary so the release-pass skill can pick it up); RELEASE_NOTES.md
is only relevant during a release pass and handled by that skill — do
not read or reference it during normal dev sessions.
