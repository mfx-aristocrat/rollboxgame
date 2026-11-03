# Game creation roadmap

Statuses: TODO, IN_PROGRESS, BLOCKED, AWAITING_VALIDATION, DONE. Stable IDs remain unchanged when scope is refined. Required Studio gates apply to runtime milestones, not research/tool-only milestones.

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
- Evidence: Training world/server/client source implemented, 20 pure gameplay cases pass; all Luau compiles and repeated builds match. Required Studio S01–S09 remain pending because computer-use cannot capture the Studio window; user has installed/opened it. Commit/push recorded in state; no merge to main until required gates pass. No substantial content expansion before slice evaluation.

## M04 — Persistent progression and lifecycle reliability
- Objective/scope: versioned saves, test/production separation, bounded retries, session ownership, shutdown/disconnect safety and failure UI.
- Dependencies: M03 design interfaces; implementation/tests may proceed independently while M03 runtime remains pending. Completion requires M03.
- Status: AWAITING_VALIDATION.
- Deliverables: persistence adapter/service, progression integration, failure-recovery tests and configuration instructions.
- Acceptance: new/returning player retains progression, failed load cannot overwrite saves, stale servers cannot write, concurrent sessions handled, failed writes recover visibly.
- Automated checks: fake-store load/save/retry/conflict/migration cases. Studio: private published test experience with API access, reconnect and simultaneous clients. Pending account access blocks runtime completion.
- Evidence: 37 persistence and 13 lifecycle fake-store cases pass; versioned codec, lease/retry/operation deduplication, guarded server adapter and lifecycle integration implemented. Astra/xhigh review's lease-renewal race fixed and regression-tested; late load/save cleanup also tested. Disabled by default. Required private-service Studio P01–P05 pending; M03 also pending. Commit/push recorded in state; not merged to main.

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
