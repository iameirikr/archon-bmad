# Archon BMAD

**A collection of [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) workflows for the
[Archon](https://archon.diy) workflow engine.**

This repository is a home for native Archon workflows that automate parts of the BMAD method. Each
workflow is a self-contained `*.yaml` file in [`workflows/`](./workflows) that runs locally, in chat,
on the web UI, or in an isolated git worktree — no tmux, no Python helper, no separate orchestrator
process. Install them all at once and run whichever one you need.

The collection grows over time. The first workflow,
[`archon-bmad-story-automator`](#archon-bmad-story-automator), automates the BMAD *implementation*
loop; future workflows will cover other parts of the method (planning, review, release, and so on).

---

## Install

`./install.sh` copies **every** workflow in [`workflows/`](./workflows) into your Archon workflows
directory — so a single install gives you the whole collection, and re-running it picks up any
workflows added later.

**Global (every project on your machine):**

```bash
./install.sh
# copies workflows/*.yaml -> ~/.archon/workflows/
```

**A specific repo:**

```bash
./install.sh /path/to/your-bmad-project/.archon/workflows
```

**Manual:**

```bash
mkdir -p ~/.archon/workflows
cp workflows/*.yaml ~/.archon/workflows/
```

Respects `ARCHON_HOME`. Verify the collection is discoverable (every workflow here is named
`archon-bmad-*`):

```bash
archon workflow list | grep archon-bmad
```

---

## Workflows

| Workflow                                                | Automates                                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------------------- |
| [`archon-bmad-story-automator`](#archon-bmad-story-automator) | The BMAD implementation loop — create → dev → review → commit per story, with per-epic retrospectives. |

_More workflows will be added here over time._

---

### archon-bmad-story-automator

A port of the [`bmad-story-automator`](https://github.com/bmad-code-org/bmad-automator) onto the
Archon workflow engine. After you've finished BMAD planning (PRD, architecture, sprint plan) and
`sprint-status.yaml` exists, this workflow drives the whole implementation cycle — story by story,
with an adversarial review gate and per-epic retrospectives — using **your existing BMAD skills**.

#### What it does

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

#### Requirements

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

#### Usage

Run from the **root of your BMAD project** (no isolation flags needed — see
[Isolation](#isolation) for why):

```bash
# Implement a whole epic
archon workflow run archon-bmad-story-automator "epic 2"

# Implement specific stories
archon workflow run archon-bmad-story-automator "stories 2-1 through 2-4"

# Implement everything still pending in sprint-status
archon workflow run archon-bmad-story-automator "all pending stories"

# Kick it off detached and watch it
archon workflow run archon-bmad-story-automator "epic 2" --detach
archon workflow runs
```

You can also launch it from Archon chat ("run archon-bmad-story-automator for epic 2") or the web UI.
The free-text argument is interpreted by the loop's `select` phase against `sprint-status.yaml`, so
natural phrasing ("epic 2", "the auth stories", "everything left") works.

#### Isolation

This workflow **always runs in your live checkout** — it declares `worktree.enabled: false`, so
Archon never creates a worktree and you never need a `--no-worktree` flag (passing `--branch` or
`--from` is rejected with a clear error).

Why it has to: Archon's default worktree is a fresh checkout of *tracked* files only, but BMAD
gitignores everything this workflow depends on — `_bmad/` (its config and the Python scripts the
skills execute), `.claude/` (the BMAD skills themselves), and usually the output folder holding
`sprint-status.yaml` and the story files. In a worktree all of that is absent, so both the `init`
guard and the BMAD skills fail. The live checkout is the only place they all exist together.

The per-story commits land on **your current branch**. To get isolation, make your own throwaway
branch before running and review it afterward:

```bash
git checkout -b bmad/epic-2
archon workflow run archon-bmad-story-automator "epic 2"
# review the commits, then merge — or `git branch -D bmad/epic-2` to discard
```

#### Configuration knobs

Edit `workflows/archon-bmad-story-automator.yaml` to taste:

- `model:` — uses real Claude aliases so it works without extra setup: default `sonnet`, the heavy
  `build-loop` node `opus` (dev + adversarial review — under-powering this is the main reason naive
  automation produces slop), and the `report` node `haiku`. `opus` over a long multi-story run is the
  expensive part; drop `build-loop` to `sonnet` to trade quality for cost. If you'd rather use Archon
  tier presets (`small`/`medium`/`large`), configure them first with `archon ai tier set <tier>
  claude <model>` — unconfigured tier names fail to resolve.
- `build-loop.loop.max_iterations` (default `150`) — raise for very large multi-epic runs.
- `build-loop.idle_timeout` (default `1800000` ms = 30 min) — raise if `dev-story` sessions run long.
- `build-loop.loop.until` / retry counts (`maxReviewRetries`, `maxCreateRetries`) — tune the gates.

#### How it differs from the upstream automator

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

---

## Adding a workflow

1. Drop a new `*.yaml` Archon workflow into [`workflows/`](./workflows) with a descriptive `name:`.
   Keep it prefixed `archon-bmad-` so it's easy to find with `archon workflow list | grep archon-bmad`.
2. Add a row to the [Workflows](#workflows) table and a `###` section documenting it.
3. `./install.sh` picks it up automatically — no installer changes needed.

## Credits & license

`archon-bmad-story-automator` is ported from
[`bmad-code-org/bmad-automator`](https://github.com/bmad-code-org/bmad-automator) and built for the
[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD). Both are MIT-licensed; see
[`NOTICE`](./NOTICE) for attribution. This repository is MIT-licensed — see [`LICENSE`](./LICENSE).
