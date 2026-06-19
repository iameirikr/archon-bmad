# archon-bmad

**Automate the BMAD implementation loop as a native [Archon](https://archon.diy) workflow.**

This is a port of the [`bmad-story-automator`](https://github.com/bmad-code-org/bmad-automator)
onto the Archon workflow engine. After you've finished BMAD planning (PRD, architecture, sprint
plan) and `sprint-status.yaml` exists, drop this workflow into your Archon install and let Archon
drive the whole implementation cycle — story by story, with an adversarial review gate and per-epic
retrospectives — using **your existing BMAD skills**.

No tmux. No Python helper. No separate orchestrator process. Just one Archon workflow that runs
locally, in chat, on the web UI, or in an isolated git worktree.

---

## What it does

For each selected story it plays one role per loop iteration, verifying against the real
`sprint-status.yaml` after every step (never trusting a session that merely "looks done"):

| Phase    | BMAD skill invoked              | What happens                                                        |
| -------- | ------------------------------- | ------------------------------------------------------------------ |
| `create` | `bmad-create-story`             | Write the next story file (YOLO, autonomous)                       |
| `dev`    | `bmad-dev-story`                | Implement all `[ ]` tasks, run tests, tick checkboxes              |
| `auto`   | `bmad-qa-generate-e2e-tests`    | Optional — test-gen; **auto-skipped** if the skill isn't installed |
| `review` | _inlined adversarial reviewer_  | Attack impl vs story claims + git reality; auto-fix; **gate = 0 CRITICAL**; loops ≤ 5 |
| `commit` | —                               | `git commit` only after review verifies                            |
| `retro`  | `bmad-retrospective`            | Fires per epic when every story in it is `done`; YOLO; non-blocking |

When everything in your selection is `done` and each completed epic has had its retrospective, the
run finishes and emits a report.

## Requirements

- **Archon** installed (`archon` CLI or the web UI). See https://archon.diy.
- A **BMAD-METHOD project** with planning complete — i.e. `_bmad/bmm/config.yaml` and
  `<output_folder>/implementation-artifacts/sprint-status.yaml` both exist.
- The BMAD implementation skills installed in the project under one of `.claude/skills`,
  `.agents/skills`, or `.codex/skills`:
  - `bmad-create-story` *(required)*
  - `bmad-dev-story` *(required)*
  - `bmad-retrospective` *(required)*
  - `bmad-qa-generate-e2e-tests` *(optional — the `auto` phase is skipped if absent)*

The workflow defaults to the `claude` provider so the BMAD skills are auto-discovered. It works with
any project BMAD targets (the workflow itself is project-agnostic).

## Install

Pick one:

**Global (every project on your machine):**

```bash
./install.sh
# copies workflows/bmad-implement.yaml -> ~/.archon/workflows/
```

**A specific repo:**

```bash
./install.sh /path/to/your-bmad-project/.archon/workflows
```

**Manual:**

```bash
mkdir -p ~/.archon/workflows
cp workflows/bmad-implement.yaml ~/.archon/workflows/
```

Respects `ARCHON_HOME`. Verify it's discoverable:

```bash
archon workflow list | grep bmad-implement
```

## Usage

Run from the **root of your BMAD project**:

```bash
# Implement a whole epic
archon workflow run bmad-implement "epic 2"

# Implement specific stories
archon workflow run bmad-implement "stories 2-1 through 2-4"

# Implement everything still pending in sprint-status
archon workflow run bmad-implement "all pending stories"

# Run in the live checkout instead of an isolated worktree
archon workflow run bmad-implement --no-worktree "epic 2"

# Kick it off detached and watch it
archon workflow run bmad-implement "epic 2" --detach
archon workflow runs
```

You can also launch it from Archon chat ("run bmad-implement for epic 2") or the web UI. The free-text
argument is interpreted by the loop's `select` phase against `sprint-status.yaml`, so natural phrasing
("epic 2", "the auth stories", "everything left") works.

### Isolation

By default Archon runs the workflow in a **git worktree** on a fresh branch, so BMAD's mutations to
`sprint-status.yaml`, story files, and source stay isolated until you review and merge. Pass
`--no-worktree` to run in the live checkout. The final report tells you which branch to review.

## Configuration knobs

Edit `workflows/bmad-implement.yaml` to taste:

- `model:` — workflow default is `medium`; the heavy `build-loop` node is pinned to `large` because
  under-powering the dev/review work is the main reason naive automation produces slop. Lower it (or
  point it at a [tier/alias](https://archon.diy)) if you want to trade quality for cost.
- `build-loop.loop.max_iterations` (default `150`) — raise for very large multi-epic runs.
- `build-loop.idle_timeout` (default `1800000` ms = 30 min) — raise if `dev-story` sessions run long.
- `build-loop.loop.until` / retry counts (`maxReviewRetries`, `maxCreateRetries`) — tune the gates.

## How it differs from the upstream automator

This is a faithful port of the *pipeline*, deliberately simplified for the Archon runtime:

- **One Archon `loop:` node** driven by a `state.json` state machine + `sprint-status.yaml`, instead
  of a Python orchestrator spawning tmux child sessions. `fresh_context: true` gives each role a clean
  session, mirroring the automator's isolated sessions.
- **The adversarial reviewer is inlined** into the workflow (derived from the automator's bundled
  `bmad-story-automator-review` skill), so you don't need to install that review skill separately.
- **No programmatic complexity scoring / per-story agent selection.** Archon handles provider/model
  selection via config tiers; set the loop `model` (or tiers) once.
- **Commit-only, like the upstream** — it does not open PRs. Add a final node if you want one.

Everything else — the `create → dev → auto → review(≤5) → commit` per-story sequence, the
"0 CRITICAL issues" completion gate, sprint-status as source of truth, and per-epic retrospectives
fired inside the loop — matches the automator.

## Credits & license

Ported from [`bmad-code-org/bmad-automator`](https://github.com/bmad-code-org/bmad-automator)
and built for the [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD). Both are MIT-licensed;
see [`NOTICE`](./NOTICE) for attribution. This repository is MIT-licensed — see [`LICENSE`](./LICENSE).
