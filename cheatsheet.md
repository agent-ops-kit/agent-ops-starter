# Agent cost-control cheatsheet

One page. The theme: **tokens follow context, context follows discipline.**
Written for Claude Code; the principles port to any agent CLI.

## 1. Context is the bill

- Everything in the conversation is re-sent on every turn. A pasted 2,000-line
  log file costs you on every message after it, not once.
- `/context` shows what is filling the window; `/compact` summarizes and
  frees it. Compact at natural task boundaries, not mid-investigation —
  compaction is lossy.
- Start a fresh session per task. A session that has done three unrelated
  tasks carries all three around forever.

## 2. Keep CLAUDE.md lean

- CLAUDE.md loads into EVERY conversation. Every stale paragraph is a
  recurring charge. Budget it like an API: facts and rules the agent needs
  on most tasks, nothing else.
- Long procedures ("how we do releases") belong in a skill or command file
  that loads only when invoked — not in CLAUDE.md.

## 3. Route heavy lifting to subagents

- A subagent runs in its OWN context window and returns only a summary:
  test runs, log spelunking, wide searches, doc reading. The 400 lines of
  output stay in the subagent; your main session gets 5.
- Give worker subagents `model: haiku` in their frontmatter for
  search/summarize/format jobs — same isolation, cheaper tokens. Keep your
  strongest model for design decisions, not for grepping.
- Do not round-trip: a subagent that returns "here is everything I found"
  in full defeats the point. Its prompt should demand a summary.

## 4. Let hooks replace re-runs

- The expensive failure is the re-run: the agent edits, "finishes", and you
  discover a broken test two turns later — paying for the wander back.
  A PostToolUse hook that runs the touched file's tests feeds the failure
  back immediately, in the same turn.
- Deterministic checks (secrets, protected files, forbidden commands)
  belong in hooks, not in prompts. A hook is free; asking the model to
  remember a rule costs tokens on every turn and still gets forgotten.

## 5. Stop paying the permission-prompt tax

- Every prompt you approve by hand is your time, and every denied-then-
  retried command is tokens. Allowlist the safe, boring commands your
  repo runs constantly (test, lint, build, read-only git) in permission
  settings or an allowlist hook. Keep the destructive stuff prompting.

## 6. Ask smaller questions

- "Fix the failing test in tests/test_billing.py" beats "the build is
  broken, investigate" — scoping the task IS cost control; exploration is
  the most expensive thing an agent does.
- Point at files (`@path/to/file`) instead of describing them; a wrong
  guess about which file you meant costs a full search round-trip.
- Batch related requests in one message rather than three messages the
  agent processes with full context each time.

## 7. Know your escape hatches

- A session going in circles will not un-circle: stop, start clean, restate
  the task with what you learned. Sunk tokens are sunk.
- Long-running autonomous work: cap it with `maxTurns` in the subagent's
  frontmatter so a stuck loop cannot run all night.

---

*From Agent Ops Kit. Works with Claude Code and other agentic coding
tools. Not affiliated with, endorsed by, or sponsored by Anthropic.*
