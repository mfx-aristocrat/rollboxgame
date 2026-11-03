# Game creation roadmap

Statuses: TODO, IN_PROGRESS, BLOCKED, AWAITING_VALIDATION, DONE. Stable IDs remain unchanged when scope is refined. Required Studio gates apply to runtime milestones, not research/tool-only milestones.

Repository update 2026-11-03: user merged PR #1 into main (260d22c), bringing the earlier implementation and pickup repairs into main. Historical “not merged” notes below describe their original checkpoints; this user merge does not establish pending runtime gates as passed. New M03-R2 expansion stays on develop pending its remaining validation.

## M01 — Repository, research and release design
- Objective/scope: preserve the brief; establish durable instructions; compare original concepts against current evidence; select a modest initial release and architecture before gameplay.
- Dependencies: none.
- Status: DONE.
- Deliverables: AGENTS.md, PROJECT_STATE.md, this roadmap, docs/market_research.md, docs/game_design.md; preserve original README guide.
- Acceptance: 3–5 weighted concepts, dated URLs and metric periods, separated evidence/hypotheses, justified recommendation, first-minute and ten-minute loop, measurable release/slice gates, explicit exclusions and tool/account limits.
- Automated checks: review all required documents and source links; `git diff --check`; verify owner/visibility/auth/remote. Studio: not required.
- Git evidence: 801769d committed/pushed develop and fast-forward merged/pushed main; both remote heads verified 801769d0b67f70feaf0cf6d697010605b8733b54.

## M02 — Reproducible source/build foundation
- Objective/scope: pinned tools, Rojo project mapping, reproducible place artifact, CI and setup/build/check documentation.
- Dependencies: M01.
- Status: DONE.
- Deliverables: tool lock/setup scripts, Rojo mapping, source folders, smoke check, CI, README setup and source-of-truth rules.
- Acceptance: clean setup, explicit tool versions, successful repeated build with matching hash, generated place contains server/client/shared scripts, CI runs same checks.
- Automated checks: tool version checks, build twice/hash, generated-place structural smoke test, diff check. Studio: opening the generated place is deferred to M03 runtime gate and must remain explicit.
- Git evidence: foundation e77a0b7; completion fd712fa. Windows and Ubuntu CI passed (41548927180; final develop 41549094589, main 41549127631). Both remote heads verified fd712fa7db106e282680d94b49925cb35dff691e. Roblox opening deferred to M03.

## M03 — Playable vertical slice
- Objective/scope: one environment, central mechanic, onboarding, essential responsive UI and a complete session progression cycle, according to the selected design.
- Dependencies: M01, M02.
- Status: AWAITING_VALIDATION.
- Deliverables: source-generated world, server gameplay, client controls/UI, core-rule tests, exact Studio validation script.
- Acceptance: design's slice criteria demonstrated; server validates actions; free retry/recovery; two-player isolation; touch/desktop controls. Evaluate fun/clarity before adding substantial content.
- Automated checks: core gameplay unit tests, invalid remote/rate-limit tests, place build/smoke. Studio: new player full loop, two clients, touch emulator, death/respawn; record observations and revise design.
- Evidence: Training world/server/client source implemented, 20 pure gameplay cases pass; all Luau compiles and repeated builds match. Commit **e4794e8** pushed to develop; Windows/Ubuntu CI **41550690715 SUCCESS**. Studio/MCP access now works; real startup and near-box E pickup pass after the protected-property repair documented under M03-R1. Required full Studio S01–S09 remain pending. No merge to main until required gates pass. No substantial content expansion before slice evaluation.

## M04 — Persistent progression and lifecycle reliability
- Objective/scope: versioned saves, test/production separation, bounded retries, session ownership, shutdown/disconnect safety and failure UI.
- Dependencies: M03 design interfaces; implementation/tests may proceed independently while M03 runtime remains pending. Completion requires M03.
- Status: AWAITING_VALIDATION.
- Deliverables: persistence adapter/service, progression integration, failure-recovery tests and configuration instructions.
- Acceptance: new/returning player retains progression, failed load cannot overwrite saves, stale servers cannot write, concurrent sessions handled, failed writes recover visibly.
- Automated checks: fake-store load/save/retry/conflict/migration cases. Studio: private published test experience with API access, reconnect and simultaneous clients. Pending account access blocks runtime completion.
- Evidence: 37 persistence and 13 lifecycle fake-store cases pass; versioned codec, lease/retry/operation deduplication, guarded server adapter and lifecycle integration implemented. Astra/xhigh review's lease-renewal race fixed and regression-tested; late load/save cleanup also tested. Commit **e4794e8** pushed to develop; Windows/Ubuntu CI **41550690715 SUCCESS**. Disabled by default. Required private-service Studio P01–P05 pending; M03 also pending. Not merged to main.

## M03-R1 — Player feedback: terrain expansion and reliable parcel pickup
- Objective/scope: implement the user's 2026-11-03 requests: a larger explorable world with varied terrain and repair the visible box/E interaction. This explicit environment expansion is authorized while other M03 observation gates remain pending; it adds no new scored delivery routes.
- Dependencies: existing M03 implementation; user reports the game starts but parcel pickup does not work as expected.
- Status: AWAITING_VALIDATION.
- Deliverables: connected terrain regions around the preserved Training course; shared pickup geometry and clear carry feedback; actual entrypoint pickup regression harness; world layout checks; updated design/test/handoff documentation.
- Acceptance: at least four distinctive walkable regions with connected paths from the depot; Training gates/checkpoints/fall clearance unchanged; pickup prompt, server and HUD agree on box position/range; E, prompt and touch action share validated pickup behavior; successful pickup is clearly visible; repeated requests cannot restart/grant duplicate rewards.
- Automated checks: red→green production-call-chain pickup tests, bounds/path connectivity/grade/clearance world checks, all existing suites and reproducible build, Windows/Linux CI.
- Studio checks: approach the box from both sides and boundary distances, press E/tap prompt, confirm visible carried box and Running HUD; two clients independently pick up; walk all terrain paths; fall/respawn and complete original route. User report is not evidence these revised tests passed.
- Evidence: 17 production-entrypoint pickup adapters and 7 world checks pass, total 94 standalone cases; 20 Luau compile including two optional Studio fixtures; repeated builds match. Source pickup range mismatch and geometry obstructions were reproduced/fixed. A subsequent real Studio red trace found startup crashing on the runtime `FallenPartsDestroyHeight` setter before pickup registered. The setting now serializes in Rojo Workspace properties; XML regression failed before/passes after. Real Studio regression: **14/14 assertions PASS**, fixtures cleaned. A clean viewport E press also produced CARRYING PARCEL. R01 is partial; range/touch/native-only and R02–R06 remain pending. See docs/runtime_pickup_startup_fix.md; no main merge before required runtime validation.
- Git evidence: **db4cb69** committed/pushed to develop; Windows and Ubuntu CI **41554997023 SUCCESS**, remote code SHA verified. Handoff documentation follows in a separate commit. No main merge while R01–R06/runtime gates are pending.
- Startup repair Git evidence: **77caa6579702672dede2d1c3411d9d421acb3f0c** committed/pushed to develop; Windows and Ubuntu CI **41633735629 SUCCESS**, both remote heads verified. Real pickup regression and clean viewport E pass recorded in docs; broader gates still pending, so no main merge.

## M03-R2 — Platformer adventure, courier outfit and world expansion
- Objective/scope: user's explicit expansion request after merging PR #1; bright classic-platformer scenery and red-cap/overalls courier, exploration items and spring pads around the preserved delivery loop. Detailed pre-implementation brief: docs/platformer_expansion.md.
- Dependencies: merged main 260d22c with startup repair. Earlier slice/release gates remain pending; this new scope is explicitly authorized.
- Status: AWAITING_VALIDATION.
- Deliverables: two connected new regions, original character styling, token trails/landmarks/free bonus crates/springs, session exploration HUD, meaningful automated and Studio checks.
- Acceptance: six reachable regions; at least 24 tokens/four crates/six landmarks/four springs; per-player once-only session score; range/alive/cooldown checks; springs disabled during scored delivery; respawn-safe noncolliding outfit; original course/pickup preserved.
- Required checks: existing suites plus adventure rules/layout; reproducible build and CI; real Studio pickup, collection/crate/spring/outfit/respawn and viewport evidence. Record pending device/multiplayer checks without claiming completion.
- Evidence: six regions across 1120×1360 studs; 30 tokens, four crates, six landmarks, four springs and a 24-part courier outfit. 29 Luau compile; 121 standalone cases pass; repeated build SHA256 48f48739bc345d2dc4a7285881065c014a6ba0575b92aae861f66aa53719a3a5. Real Studio pickup 14/14 and expansion 21/21 assertions PASS; fixtures cleaned; normal desktop preview visible. Full traversal, touch/gamepad, two-client and scored-spring end-to-end gates remain pending. See docs/studio_validation.md A01–A07.
- Git evidence: base main 260d22c (user-merged PR #1), fast-forwarded into develop preserving clean source. Expansion commit/CI recorded in PROJECT_STATE.md after push. Do not merge as a completed milestone while mandatory runtime checks remain pending.
- Expansion pushed as **800d793ef72e442e6b881229e7ce0dbba350c028**; Windows/Ubuntu CI **41679099759 SUCCESS**, remote SHAs verified. [Draft PR #2](https://github.com/mfx-aristocrat/rollboxgame/pull/2) open against main; no merge while the remaining gates are pending.

## M05 — Initial release content, optional purchases and polish
- Objective/scope: finish bounded release content only after slice feedback; optional cosmetics; performance/security/accessibility review.
- Dependencies: validated M03; M04 for persistent unlocks.
- Status: BLOCKED.
- Deliverables: initial release content and cosmetic configuration, purchase flow/tests as applicable, asset register and UI review.
- Acceptance: design's release scope and quality budgets met; satisfying free loop; unconfigured purchases hidden; server verifies entitlements. Developer products, if later added, require durable receipt deduplication and failure tests.
- Automated checks: economy/inventory/purchase tests, security review, build/check. Studio: successful/cancelled purchases via supported testing, desktop/touch UX, multi-client and performance gates.
- Git evidence: none; intentionally blocked on observed M03 slice gate. Three-route scope and pass configuration documented; only Training/Mint implemented. No invented IDs or paid actions.

## M06 — Private release candidate and deployment handoff
- Objective/scope: reproducible release candidate, private publishing/configuration, release verification and rollback instructions.
- Dependencies: M03–M05 DONE.
- Status: TODO.
- Deliverables: release checklist, exact account configuration, validation evidence, build checksum and rollback procedure.
- Acceptance: mandatory tests pass, account settings/IDs verified, no unresolved material bugs, final validated code merged/pushed. Public release remains separate explicit approval.
- Automated checks: all CI + clean build; verified remote SHAs. Studio: first-time/returning/mobile/multiplayer/reconnect/performance and private published smoke tests.
- Git evidence: none; docs/deployment.md is preparatory only, runtime/account prerequisites not verified.

## Expansion backlog
Additional environments, social events, leaderboards, developer products and user-generated content require separate scope/evidence after the initial release is validated.
