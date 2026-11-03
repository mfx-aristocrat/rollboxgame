# Project state

Updated: 2026-11-03 (Europe/Warsaw). Larger exploration world and parcel pickup revision implemented after user feedback. Agent runtime gates remain unverified; game is not release-ready.

## Repository and current work
- Repository: https://github.com/mfx-aristocrat/rollboxgame (public; preserved).
- Working branch: develop.
- Last verified stable local main and origin/main: fd712fa7db106e282680d94b49925cb35dff691e. M01 (801769d) and M02 (e77a0b7 + fd712fa) are committed, pushed and merged.
- Last verified revision code local develop and origin/develop: **db4cb69cd581fc350430235d70afb392b45d100a**, committed/pushed and checked via ls-remote; tree clean after push. This handoff-only documentation update follows; inspect Git for the latest documentation HEAD. Previous checkpoint: 049c8ca.
- Current milestones: M03-R1 AWAITING_VALIDATION (terrain/pickup feedback revision); M03 and M04 also AWAITING_VALIDATION. M05 new scored routes/purchases remain blocked on slice feedback; user explicitly authorized the surrounding terrain expansion. M06 not complete.
- User brief preserved in Git. Original README content preserved as docs/original_obby_guide.md; current uppercase README.md documents the actual project.

## Verified environment and checks
- Git and gh available; active GitHub account mfx-aristocrat with ADMIN repository permission; fetch succeeded. Main initially clean except untracked user brief.
- PowerShell 7.6.5, Python 3.15.1 and Git/gh available. Pinned local Rojo 7.7.1 and Lune 0.11.1 installed with archive hashes verified; setup/CI also support Linux x86_64. No Luau type analysis or engine simulation claimed.
- User installed and signed into Studio. Executable verified present at LOCALAPPDATA/Roblox/Versions/version-7062aec9dbe74b14/RobloxStudioBeta.exe. Studio runtime checks not yet performed. No credentials stored in source/state.
- M02 Windows/Linux CI passed on develop (41549094589) and main (41549127631); original foundation CI 41548927180 also passed.
- Implementation CI [41550690715](https://github.com/mfx-aristocrat/rollboxgame/actions/runs/41550690715) for e4794e8: **both Windows and Ubuntu jobs SUCCESS**, head SHA verified. Built place artifact available from that run. Runtime gates still pending.
- Current terrain/pickup revision CI [41554997023](https://github.com/mfx-aristocrat/rollboxgame/actions/runs/41554997023), code db4cb69: **Windows and Ubuntu SUCCESS**. Current artifact is available from this run. Main remains at fd712fa because revised runtime gates are pending.
- Latest local scripts/check.ps1: **18 Luau files compile; 94 behavioral cases pass** (20 gameplay, 37 persistence, 13 lifecycle, 17 pickup entrypoint adapters, 7 world geometry/connectivity); place mapping/source checks pass; two byte-identical builds. build/RollboxGame.rbxlx SHA256: **f7d00c35df3a1687e01e2642ac21098fce54ebff00cf004269ff06ce9b9d9eb9** (regenerate after source changes).
- This validates pure rules/fake stores and serialized place structure, not Roblox engine behavior, real saving, performance or player comprehension.
- User reports starting the previous game successfully but could not pick up the visible box with E. This is launch/interaction feedback, not a passed full-loop test. No agent Studio playtests run.
- Studio launch and subsequent capture retry after the user opened it were refused by the computer-use permission layer: "Computer Use was not approved to use Roblox Studio". Window was listed, but no screenshot or interaction was allowed. App permission must be enabled before agent-driven testing. Do not bypass the restriction through another launch method.
- New user-authorized integration: globally installed exact `robloxstudio-mcp@latest` (resolved 2.6.0), release-hash-verified matching Studio plugin, and enabled Codex STDIO entry `robloxstudio` with localhost-only host. SDK startup/tool discovery passed (**69 tools**); `get_connected_instances` returned **0**. Studio plugin/session connection and runtime tests remain pending. Save/restart Studio, owner enables HTTP/plugin access, then reload Codex MCP and connect plugin. Exact steps and package provenance: docs/studio_mcp_setup.md. This does not change computer-use app permissions or establish a playtest pass.

## Delegation
- research_design: requested `gpt-6-astra`, `xhigh` (override accepted by spawn tool; internal model not independently exposed); market research, concept comparison, design/architecture/slice plan.
- build_foundation: requested `gpt-6.1-sol`, `high` (override accepted; internal model not independently exposed); pinned tools/scripts/Rojo/CI, no gameplay.
- persistence: requested `gpt-6-astra`, `xhigh` (override accepted; internal model not independently exposed); injectable session-safe persistence and failure tests, no content expansion.
- Main session settings are client-controlled; no model/effort change claimed.
- vertical_slice assigned Sol/high; it and persistence stopped at an account usage limit. Partial files preserved, main continuing directly as fallback; no successful delegated completion claimed. No main-session model change claimed.
- security_review requested Astra/xhigh; completed bounded review. Fixed its confirmed lease-renewal/readiness race and added regression coverage plus late load/save-after-close-deadline cases. No remaining concrete exploit/data-loss finding in that review; fake-scheduler tests still do not prove Roblox runtime behavior.
- ui_text_review requested Terra/medium; source-only review identified landscape shop overlap and portrait Switch/jump-control proximity. Fixed with a centered modal that hides underlying HUD/actions and a centered single action raised above the portrait control row. Actual touch layout/screenshots still pending. Both review overrides were accepted; internal model identity not independently inspected.
- This revision: pickup_fix and world_expansion requested `gpt-6.1-sol` / `high`, overrides accepted. Completed bounded work with disjoint owned files; main reviewed and reran checks. No unavailable-setting fallback was needed this turn; internal model identity not independently inspected.

## Decisions and blockers
- Selected Switchback Couriers, weighted 80/100 against three alternatives; research/design recorded in docs. Recommendation remains provisional pending five-tester slice gate. No new scored routes before that gate; environment expansion separately authorized by the user's latest feedback.
- Modest solo-developer scope, original source-generated assets, no paid assets or public publishing authorized.
- Main stays stable; completed validated milestones only. Pending-runtime work may be pushed to develop with explicit status.
- Built source: depot, generated rooftop course/safe detour/shortcut, four polarity gates, per-player timing/checkpoint recovery, server-validated rewards, Mint purchase/equip, responsive keyboard/touch HUD and parcel visual. No additional release routes built.
- Revision: approximately 920×920-stud exploration footprint with Meadow/forest, Coast/lagoon/dock, Redstone Heights and Frostpeak; 25 connected path links, 49 rendered walking segments, ramps and bridges. Original course/recovery corridor remains protected by geometry tests. Only generated SwitchbackWorld is replaced; no global Terrain edits or unrelated workspace deletion. Real device performance remains pending.
- Pickup: reproduced native prompt→production handler rejection at a valid near-box position (server used a different depot center/radius). Unified station/prompt/server/HUD geometry through Config.pickup. Added direct E shortcut, out-of-range feedback, front-held parcel and CARRYING PARCEL HUD. Native E rendering and user's exact original position/cause remain unverified; full diagnosis/red→green evidence in docs/pickup_diagnosis.md.
- Persistence is **disabled by default** via src/server/ServerSettings.luau. Practice progress resets on leave. Enabled mode requires explicit matching private-test universe ID and owner-enabled API access; wrong config/failed load blocks progression. 60-second autosave target, 180-second lease; crash/outage loss window disclosed. No IDs invented, no private upload performed yet.
- No purchase button, no developer products; optional cosmetic pass remains ID 0/disabled. No paid assets, spending or public release.
- Five unfamiliar testers (two touch), real baseline mobile hardware, private experience/API access and Studio permission remain external gates. M05 content must wait for S01–S09 evidence.

## Exact next actions
0. Finish the new MCP connection using docs/studio_mcp_setup.md: save/restart Studio, enable HTTP/plugin access as owner, reload Codex MCP, then connect the MCP Server plugin. Verify a real instance read-only before runtime testing. Server/package/plugin installation is complete; no Studio instance was connected during the installation check.
1. Stop the old playtest and **reopen** `C:\Users\micha\OneDrive\Dokumenty\ChatGPT\RollboxGame\build\RollboxGame.rbxlx` (File > Open from File), or sync stopped Studio via Rojo. An already-open old place does not update from rebuilding. Start F5; run docs/studio_validation.md R01–R06 (box range/E/touch/carrying, duplicate requests, two clients, full terrain loop, course/fall, touch/performance). Enable Studio computer-use permission for agent-driven tests, or record the manual results. Latest capture attempt was still refused; no screenshot/engine run claimed. Current code, tests and docs are committed/pushed with successful CI; no implementation files intentionally left unfinished.
2. Arrange S09 with five unfamiliar testers, two touch; require 4/5 first delivery <3 min and correct explanation, 3/5 voluntary retry. If the gate fails, revise the mechanic; do not add routes to compensate.
3. Create/publish a private test experience only; owner configures API access. Follow docs/persistence.md to set the actual test universe ID, enable test persistence and run P01–P05/reconnect/failure/ownership cases. Keep production disabled.
4. Mark M03/M04 DONE only with required runtime evidence, then complete their develop→main Git workflow. Resume M05 content/pass tests and M06 release/hardware/account checks. Public release or paid expenditure still requires explicit approval.
