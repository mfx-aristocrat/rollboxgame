# Project state

Updated: 2026-11-03 (Europe/Warsaw). Source implemented through Training slice and persistence foundations. Runtime gates remain unverified; game is not release-ready.

## Repository and current work
- Repository: https://github.com/mfx-aristocrat/rollboxgame (public; preserved).
- Working branch: develop.
- Last verified stable local main and origin/main: fd712fa7db106e282680d94b49925cb35dff691e. M01 (801769d) and M02 (e77a0b7 + fd712fa) are committed, pushed and merged. Remote develop also fd712fa at the last pre-implementation push check; implementation push pending below.
- Current milestones: M03 and M04 AWAITING_VALIDATION; source and automated tests implemented, mandatory runtime gates pending. M05 expansion blocked on observed slice feedback. M06 not complete.
- User brief preserved in Git. Original README content preserved as docs/original_obby_guide.md; current uppercase README.md documents the actual project.

## Verified environment and checks
- Git and gh available; active GitHub account mfx-aristocrat with ADMIN repository permission; fetch succeeded. Main initially clean except untracked user brief.
- PowerShell 7.6.5, Python 3.15.1 and Git/gh available. Pinned local Rojo 7.7.1 and Lune 0.11.1 installed with archive hashes verified; setup/CI also support Linux x86_64. No Luau type analysis or engine simulation claimed.
- User installed and signed into Studio. Executable verified present at LOCALAPPDATA/Roblox/Versions/version-7062aec9dbe74b14/RobloxStudioBeta.exe. Studio runtime checks not yet performed. No credentials stored in source/state.
- M02 Windows/Linux CI passed on develop (41549094589) and main (41549127631); original foundation CI 41548927180 also passed.
- Latest local scripts/check.ps1: 14 Luau files compile; **70 behavioral cases pass** (20 gameplay, 37 persistence, 13 lifecycle); place mapping/source checks pass; two byte-identical builds. build/RollboxGame.rbxlx SHA256: 2b559a2d396f64222d641a89f80a3453dbfdf42e4444bc5151a9a187499a4043 (regenerate after any source change).
- This validates pure rules/fake stores and serialized place structure, not Roblox engine behavior, real saving, performance or player comprehension.
- No Studio playtests run.
- Studio launch and subsequent capture retry after the user opened it were refused by the computer-use permission layer: "Computer Use was not approved to use Roblox Studio". Window was listed, but no screenshot or interaction was allowed. App permission must be enabled before agent-driven testing. Do not bypass the restriction through another launch method.

## Delegation
- research_design: requested `gpt-6-astra`, `xhigh` (override accepted by spawn tool; internal model not independently exposed); market research, concept comparison, design/architecture/slice plan.
- build_foundation: requested `gpt-6.1-sol`, `high` (override accepted; internal model not independently exposed); pinned tools/scripts/Rojo/CI, no gameplay.
- persistence: requested `gpt-6-astra`, `xhigh` (override accepted; internal model not independently exposed); injectable session-safe persistence and failure tests, no content expansion.
- Main session settings are client-controlled; no model/effort change claimed.
- vertical_slice assigned Sol/high; it and persistence stopped at an account usage limit. Partial files preserved, main continuing directly as fallback; no successful delegated completion claimed. No main-session model change claimed.
- security_review requested Astra/xhigh; completed bounded review. Fixed its confirmed lease-renewal/readiness race and added regression coverage plus late load/save-after-close-deadline cases. No remaining concrete exploit/data-loss finding in that review; fake-scheduler tests still do not prove Roblox runtime behavior.
- ui_text_review requested Terra/medium; source-only review identified landscape shop overlap and portrait Switch/jump-control proximity. Fixed with a centered modal that hides underlying HUD/actions and a centered single action raised above the portrait control row. Actual touch layout/screenshots still pending. Both review overrides were accepted; internal model identity not independently inspected.

## Decisions and blockers
- Selected Switchback Couriers, weighted 80/100 against three alternatives; current-source research and bounded design recorded in docs. Recommendation remains provisional pending five-tester slice gate. Training-only slice before content expansion.
- Modest solo-developer scope, original source-generated assets, no paid assets or public publishing authorized.
- Main stays stable; completed validated milestones only. Pending-runtime work may be pushed to develop with explicit status.
- Built source: depot, generated rooftop course/safe detour/shortcut, four polarity gates, per-player timing/checkpoint recovery, server-validated rewards, Mint purchase/equip, responsive keyboard/touch HUD and parcel visual. No additional release routes built.
- Persistence is **disabled by default** via src/server/ServerSettings.luau. Practice progress resets on leave. Enabled mode requires explicit matching private-test universe ID and owner-enabled API access; wrong config/failed load blocks progression. 60-second autosave target, 180-second lease; crash/outage loss window disclosed. No IDs invented, no private upload performed yet.
- No purchase button, no developer products; optional cosmetic pass remains ID 0/disabled. No paid assets, spending or public release.
- Five unfamiliar testers (two touch), real baseline mobile hardware, private experience/API access and Studio permission remain external gates. M05 content must wait for S01–S09 evidence.

## Exact next actions
1. Commit/push reviewed pending-runtime work to develop only, inspect both CI jobs, then record actual implementation SHA and remote verification. Automated checks currently pass; reviews addressed.
2. Enable Studio in computer-use app permissions (user action). Open the generated build/RollboxGame.rbxlx in Studio and run docs/studio_validation.md S01–S08: first loop twice→Mint, wrong gate/fall/reset, two clients and touch layouts. Record actual Output/screenshots/failures; revise and retest as needed.
3. Arrange S09 with five unfamiliar testers, two touch; require 4/5 first delivery <3 min and correct explanation, 3/5 voluntary retry. If the gate fails, revise the mechanic; do not add routes to compensate.
4. Create/publish a private test experience only; owner configures API access. Follow docs/persistence.md to set the actual test universe ID, enable test persistence and run P01–P05/reconnect/failure/ownership cases. Keep production disabled.
5. Mark M03/M04 DONE only with required runtime evidence, then complete their develop→main Git workflow. Resume M05 content/pass tests and M06 release/hardware/account checks. Public release or paid expenditure still requires explicit approval.
