# Project state

Updated: 2026-11-03 (Europe/Warsaw). Implementation/research in progress; no runtime/release claims.

## Repository and current work
- Repository: https://github.com/mfx-aristocrat/rollboxgame (public; preserved).
- Working branch: develop (created from main).
- Last verified local main and remote origin/main: 98d8135 (initial README). develop not yet pushed.
- Current milestone: M01 research/design accepted; completing Git workflow. M02 toolchain checks passed locally. M03 implementation starts only after the documented concept/design decision.
- Existing user file `Roblox_Game_Creation_Instructions.md` read in full and preserved unchanged. Original `readme.md` retained pending relocation as a beginner guide.

## Verified environment and checks
- Git and gh available; active GitHub account mfx-aristocrat with ADMIN repository permission; fetch succeeded. Main initially clean except untracked user brief.
- Python 3.15 and Node/npm present. Rojo/Lune/Luau/StyLua/Selene not found on PATH initially. Pinned Rojo/Lune setup in progress.
- Roblox Studio process/install not found in checked LOCALAPPDATA Roblox Versions path. No connected Roblox account or Studio runtime verified. Required playtests remain pending.
- M02 foundation verified: Rojo 7.7.1/Lune 0.11.1 archive SHA256, 4-file syntax compilation, mapped place smoke and two byte-identical builds (SHA256 3071cc9d98252422259242b40e1f8f510bcca34563116fdbae67f3ced06a80c2). This was a foundation with 0 behavior tests.
- Independent M04 work: 33 persistence fake-store cases passed; runtime and adapter integration pending.
- No Studio playtests run.

## Delegation
- research_design: requested `gpt-6-astra`, `xhigh` (override accepted by spawn tool; internal model not independently exposed); market research, concept comparison, design/architecture/slice plan.
- build_foundation: requested `gpt-6.1-sol`, `high` (override accepted; internal model not independently exposed); pinned tools/scripts/Rojo/CI, no gameplay.
- persistence: requested `gpt-6-astra`, `xhigh` (override accepted; internal model not independently exposed); injectable session-safe persistence and failure tests, no content expansion.
- Main session settings are client-controlled; no model/effort change claimed.

## Decisions and blockers
- Selected Switchback Couriers, weighted 80/100 against three alternatives; current-source research and bounded design recorded in docs. Recommendation remains provisional pending five-tester slice gate. Training-only slice before content expansion.
- Modest solo-developer scope, original source-generated assets, no paid assets or public publishing authorized.
- Main stays stable; completed validated milestones only. Pending-runtime work may be pushed to develop with explicit status.
- Studio absence blocks runtime proof, not research/build/pure-rule tests or independent persistence work.

## Exact next actions
1. Finish current-source research and weighted concept comparison, inspect research/design, finalize release criteria before gameplay.
2. Validate and commit M01 on develop; push/merge main and verify remote heads.
3. Validate pinned setup and repeatable Rojo build; document setup; finish M02 Git workflow.
4. Build/test M03 slice and document exact Studio gates. Continue independent foundations while runtime gates remain blocked; update this handoff with actual evidence before stopping.
