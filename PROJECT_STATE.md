# Project state

Updated: 2026-11-03 (Europe/Warsaw). Implementation/research in progress; no runtime/release claims.

## Repository and current work
- Repository: https://github.com/mfx-aristocrat/rollboxgame (public; preserved).
- Working branch: develop (created from main).
- Last verified local/remote main and develop: 801769d0b67f70feaf0cf6d697010605b8733b54 (M01 complete, pushed and merged; both remote heads checked).
- Current milestone: M02 toolchain locally validated, preparing CI commit. M03 design accepted; partial pure rule modules preserved but not part of the stable foundation commit.
- Existing user file `Roblox_Game_Creation_Instructions.md` read in full and preserved unchanged. Original `readme.md` retained pending relocation as a beginner guide.

## Verified environment and checks
- Git and gh available; active GitHub account mfx-aristocrat with ADMIN repository permission; fetch succeeded. Main initially clean except untracked user brief.
- Python 3.15 and Node/npm present. Rojo/Lune/Luau/StyLua/Selene not found on PATH initially. Pinned Rojo/Lune setup in progress.
- User installed and signed into Studio. Executable verified present at LOCALAPPDATA/Roblox/Versions/version-7062aec9dbe74b14/RobloxStudioBeta.exe. Studio runtime checks not yet performed. No credentials stored in source/state.
- M02 foundation verified: Rojo 7.7.1/Lune 0.11.1 archive SHA256, 4-file syntax compilation, mapped place smoke and two byte-identical builds (SHA256 3071cc9d98252422259242b40e1f8f510bcca34563116fdbae67f3ced06a80c2). This was a foundation with 0 behavior tests.
- Independent M04 work: 33 persistence fake-store cases passed; runtime and adapter integration pending.
- No Studio playtests run.

## Delegation
- research_design: requested `gpt-6-astra`, `xhigh` (override accepted by spawn tool; internal model not independently exposed); market research, concept comparison, design/architecture/slice plan.
- build_foundation: requested `gpt-6.1-sol`, `high` (override accepted; internal model not independently exposed); pinned tools/scripts/Rojo/CI, no gameplay.
- persistence: requested `gpt-6-astra`, `xhigh` (override accepted; internal model not independently exposed); injectable session-safe persistence and failure tests, no content expansion.
- Main session settings are client-controlled; no model/effort change claimed.
- vertical_slice assigned Sol/high; it and persistence stopped at an account usage limit. Partial files preserved, main continuing directly as fallback; no successful delegated completion claimed. No main-session model change claimed.

## Decisions and blockers
- Selected Switchback Couriers, weighted 80/100 against three alternatives; current-source research and bounded design recorded in docs. Recommendation remains provisional pending five-tester slice gate. Training-only slice before content expansion.
- Modest solo-developer scope, original source-generated assets, no paid assets or public publishing authorized.
- Main stays stable; completed validated milestones only. Pending-runtime work may be pushed to develop with explicit status.
- Studio newly available; local UI inspection/playtesting is next after source completion. Five first-time testers and real mobile hardware remain external gates.

## Exact next actions
1. Push foundation commit, inspect Windows/Linux CI, resolve failures before completing M02 merge.
2. Finish M03 server/world/client from partial pure rules and run behavioral tests, then open/build/playtest in Studio.
3. Integrate M04 persistence adapter and run failure tests; keep practice mode explicit until private datastore runtime gates pass.
4. Record observed runtime evidence and exact outstanding tester/account/hardware actions. No substantial content expansion before slice gate.
