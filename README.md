# agent-ops-starter

Three sub-agents, one hook, and a cost cheatsheet for agentic coding tools. MIT.

Every new repo, you rebuild the same boring layer: a review agent, a hook that
checks for secrets, some idea of what your context budget is. This is that
layer, ready to copy.

Works with Claude Code and other agentic coding tools.

## What's here

| File | What it does |
|---|---|
| `agents/code-review.md` | Reviews a diff for correctness and obvious security holes. Reports, doesn't edit. |
| `agents/test-backfill.md` | Writes tests for untested paths in a file you point it at. |
| `agents/incident-triage.md` | Takes a stack trace or failing log, finds the likely cause, stops before fixing. |
| `hooks/secret-scan.sh` | Pre-commit gate. Blocks the commit when a staged file matches a known key format (AWS, GitHub, Slack, Anthropic, Google, PEM private keys). |
| `cheatsheet.md` | One page on context budgeting and what actually costs you tokens. |

## Install

```bash
git clone https://github.com/agent-ops-kit/agent-ops-starter
cd your-repo
mkdir -p .claude/agents .claude/hooks
cp ../agent-ops-starter/agents/*.md .claude/agents/
cp ../agent-ops-starter/hooks/secret-scan.sh .claude/hooks/
chmod +x .claude/hooks/secret-scan.sh
```

The agents are picked up from `.claude/agents/` automatically. The hook works
two ways — pick either (or both):

```bash
# 1) as a plain git pre-commit hook (works with any tool, or no tool):
cp .claude/hooks/secret-scan.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 2) as a Claude Code PreToolUse hook that blocks the agent's own
#    `git commit` calls — the exact settings.json block to paste is in
#    the header comment of secret-scan.sh.
```

Read the files before you run them. They're short on purpose.

## The hook

`secret-scan.sh` scans the **staged** content of a commit and exits non-zero
on a match, which blocks the commit. Test it before you trust it:

```bash
echo 'AWS_SECRET_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"' > canary.env
git add canary.env
git commit -m test   # must be REFUSED with a SECRET-SCAN message
git reset canary.env && rm canary.env
```

If it doesn't block, it isn't protecting you. Same is true of any hook you
didn't test. False positive on a test fixture? Add the path pattern to
`.secretscanignore` at your repo root.

One dependency note: `secret-scan.sh` prefers `jq` for parsing hook JSON in
Claude Code mode but falls back to a grep parser and still blocks without
it. The full kit's other hooks require `jq` outright — without it they warn
on stderr and enforce nothing, so install jq before trusting any of them.

## Contributing

Issues and PRs welcome, especially "this agent did the wrong thing on my repo."
That's the useful bug report.

## The full kit

These three are the ones I use most. The full **Agent Ops Kit** has 8
sub-agents, 6 hooks, 10 slash commands, 5 `CLAUDE.md` starters for different
stacks, and a playbook on context budgeting — $19, 14-day refund, at
[agent-ops-kit.com](https://agent-ops-kit.com/?utm_source=github&utm_medium=readme&utm_campaign=aok-launch48&utm_content=starter-repo)..

Eight sub-agents, not forty. Each one has a job it does and a job it refuses.
It's the same work as what's in this repo, so if these three aren't useful to
you, the other five probably aren't either. Judge it on these.

## License

MIT. Use it in commercial work, no attribution required.

---

Not affiliated with, endorsed by, or sponsored by Anthropic. "Claude Code" is
referenced only to describe compatibility.
