---
name: implement
description: Implement an issue or a described change with the repository's agents. They plan, challenge, build, review in rounds and verify with make check.
disable-model-invocation: true
---

# Implement

Call `EnterWorktree` before you start, unless the session already works under `.claude/worktrees/`. The workflow's agents write to the session's checkout.

Run the workflow with `$ARGUMENTS`, an issue number or a description of the change:

```
Workflow({ name: 'implement', args: '<issue number or description>' })
```

It returns the settled `plan`, `clean`, `blocked`, the findings still `open`, and four lists for the user to decide: `disputed` (findings the coder argued against), `beyond` (problems outside the request), `deviations` (where the build left the plan) and `challenges` (the devil's advocate's arguments). Return all four to the user. Do not decide them yourself.

Then:

1. Run `git fetch origin` and `git log --oneline HEAD..origin/main`. If those commits touch the same files, rebase and run `make check` again.
2. Commit following `docs/agents/commits.md`, push the branch and open a pull request with `gh pr create`. The body says what the change does and lists the four lists.
3. Open it as a draft when one of the four lists holds something to decide, when `clean` or `blocked` says the work is unfinished, or when `capture` is true. A change to capture needs a person to try a recording before it merges, so say that in the body.
