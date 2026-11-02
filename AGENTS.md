# Project instructions

## Session startup
1. Read the full project brief, [Roblox_Game_Creation_Instructions.md](Roblox_Game_Creation_Instructions.md), then `PROJECT_STATE.md` and `game_creation_steps.md`.
2. Inspect files, Git status/branches/remotes, tool availability, and actual validation evidence. Reconcile stale documentation before resuming the next unfinished milestone.
3. Preserve existing work. Repository: `mfx-aristocrat/rollboxgame`; preserve visibility. Keep test experiences private. Public release and paid spending require explicit user approval.

## Delivery and validation
- `game_creation_steps.md` is the authoritative roadmap. Define observable acceptance and required automated/Studio checks before implementation. Research and document the concept before gameplay.
- Develop on `develop`. For each completed milestone: validate, update documentation, commit and push `develop`, merge into `main`, push and verify both remote SHAs. Respect protections; use PRs if required. No force pushes or unrelated overwrites.
- Pending mandatory runtime tests mean `AWAITING_VALIDATION`, not `DONE`. Incomplete work may be committed/pushed on `develop`; keep it out of stable `main` until its required gates pass.
- Source-controlled Luau and Rojo are authoritative. Generate maps/UI from source; document how Studio-edited assets return to source. Pin tools and verify reproducible builds.
- Server owns rewards, inventory, purchases and progression. Validate/rate-limit remotes. Save versioned data with retries and session ownership; segregate test/production stores. Purchase grants require persisted receipt deduplication if developer products are introduced.
- Run meaningful tests for changed behavior and required checks. Record automated evidence separately from Studio playtests; a build is not a playtest. Follow `docs/game_design.md` for release scope and `docs/studio_validation.md` when runtime testing begins.
- Record asset origins/licenses. Keep credentials outside source control. Disabled/unconfigured purchases must have no active purchase buttons.
- Before handoff update `PROJECT_STATE.md` with verified commits, changes, checks, blockers, assumptions and exact next actions. Never claim unverified uploads, playtests or release readiness.

## Task-based delegation
Main agent coordinates, integrates, validates, maintains state and handles Git. Use bounded tasks with owned files, acceptance criteria and checks; parallelize independent work only.

| Task | Requested subagent model | Effort |
| --- | --- | --- |
| Research synthesis, concept/design/scope, economy, architecture, slice planning | `gpt-6-astra` | `xhigh` |
| Gameplay, Luau, tests, ordinary debugging | `gpt-6.1-sol` | `high` |
| Screenshot/UI review, player-facing text | `gpt-6.1-terra` | `medium` |
| Difficult bugs, multiplayer, persistence, purchases, security review | `gpt-6-astra` | `xhigh` |

If unavailable use Sol at requested effort; if Extra High unavailable use High. Report actual runtime settings/fallbacks in state. Keep tiny tasks local; Medium suits documentation/housekeeping when independently configurable. The main session's model/effort cannot be changed by a prompt: recommend the user switch to High once design/architecture/slice planning are established, and Extra High for difficult tasks. Never claim that recommendation changed settings.
