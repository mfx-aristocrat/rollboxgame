# Parcel pickup diagnosis — 2026-11-03

Status: source defects reproduced and corrected; Roblox runtime confirmation **PENDING**. This does not complete M03.

User observation: the game starts, but pressing the instructed E does not appear to pick up the visible parcel. No runtime trace or controlled before/after Studio playtest is available to this investigation. The exact cause of that user's observation remains unconfirmed.

## Acceptance and feedback loop

- Press E near the visible box, tap Take parcel, or activate the native prompt: one server-owned run begins and one personal parcel appears in front of the avatar. The station remains for other players.
- HUD confirms CARRYING PARCEL and the next gate. Prompt, HUD eligibility and server validation use the same station point/radius.
- Outside range, unavailable data or a dead/missing character prevents pickup with visible feedback. Duplicate pickup requests preserve the active run, timer, parcel and coins. Malformed requests and floods remain bounded.
- Automated: actual entrypoint adapter tests, existing rule/data tests, source compilation and reproducible place checks. Required engine checks: keyboard/native prompt, touch/gamepad, avatar welding/camera, two clients and the full delivery loop; these remain pending.

Fast loop: `.tools/bin/lune.exe run tests/run.luau`. `tests/pickup.luau` loads the actual client and server entrypoints through `@lune/luau`, supplies fake engine/service boundaries and real Config/RunRules/Progression/Profile modules, invokes actual registered callbacks, and checks outgoing intents, actual server snapshots and generated parcel objects. It does not duplicate the pickup decision in a test-only rule or claim to simulate the Roblox prompt renderer/network/physics.

## Red evidence before the fix

The first registered test fired the production `world.prompt.Triggered` callback at avatar position `{18,12,0}`, which is approximately 11.05 studs from the visible box `{7,11,0}` and inside its 12-stud prompt range. The original server instead checked 18 studs from depot `{0,12,0}` against a 15-stud depot radius.

Command: `.tools/bin/lune.exe run tests/run.luau`; exit 1:

```text
actual prompt near visible station starts pickup:
native prompt fired 11 studs from box but server rejected pickup
```

Minimal coordinate probe, changing only root X from 18 to 7, made that production prompt/handler test pass. The next actual-client test then failed; same command, exit 1:

```text
actual client E sends pickup request:
pressing advertised E sent no Start intent
```

The original native ProximityPrompt already owned an E binding. Therefore the second failure establishes absence of a direct HUD keyboard fallback, **not** proof that native E was globally broken. The first failure proves a station/server geometry mismatch under a concrete near-box condition. Neither establishes the user's exact avatar position or prompt state.

## Ranked hypotheses and predictions

These were sent to the coordinating agent before probing:

1. Inconsistent station/server geometry: changing root X from 18 to 7 should make the original handler accept. **Reproduced and confirmed.**
2. HUD/prompt eligibility disagreement: a depot-valid position at X=-14 should be outside the actual box's native range. **Confirmed by source geometry; corrected and regression-covered.**
3. Missing direct E fallback: isolated actual-client InputBegan E should emit no Start request. **Reproduced.** Native prompt remains a separate legitimate path.
4. A rear-mounted parcel masks successful pickup: an accepted run should create a parcel at positive local Z. **Confirmed by original source inspection**, which used `CFrame.new(0,0,1.5)`; visual interpretation still requires Studio. Roblox avatar forward is local negative Z.

## Changes and automated evidence

`Config.pickup.position/radius` now define server eligibility and HUD `nearPickup`; the world prompt consumes that same configuration. Existing snapshot fields including `nearDepot` remain; `nearPickup` and `carryingParcel` are additive. Both native prompt and direct E/touch UI call the same existing server handler. Input ignores processed events, focused text fields and the shop modal. A duplicate Start/Retry cannot replace an active run or grant rewards.

The personal welded parcel is positioned at local `{0,-0.25,-2}` and stays non-colliding, non-touching and massless. Success text and persistent CARRYING PARCEL status identify the state independently of its appearance. Station objects are not consumed. Range, character and data rejection messages are visible; existing remote validation/rate limits remain active. No persistence or economy changes.

The final 17 pickup adapter cases exercise native prompt→handler, actual E→remote→handler→snapshot→HUD, touch button, duplicate native/remote requests, front parcel, valid boundary/outside geometry, dead character, unavailable profile, malformed/flooded remotes, shared station for two players, UI eligibility and completed-run retry. Existing gameplay/persistence/lifecycle tests run alongside them. All 87 behavioral cases pass locally; syntax compilation passes. Coordinating agent records full build/hash checks separately.

## Required Studio confirmation

1. Rebuild and open the current place artifact; Stop any older playtest first. Start F5, inspect Output and approach the visible box. Test native E plus the HUD button; observe a front-held parcel and CARRYING PARCEL.
2. Approach from both sides of the configured 12-stud boundary. Compare native prompt availability with HUD eligibility. Outside-range attempts must show Move closer with no run/parcel.
3. Repeatedly press E/tap while holding a parcel. Timer/checkpoint/polarity must continue; no extra parcel or coins. Complete a delivery, retry free, reset/death and repeat.
4. Run two clients: both can collect independent parcels from the same unchanged station. Check portrait/landscape touch and native gamepad prompt; verify carried parcel visibility/animation/camera on actual rigs.
5. Record source commit/build hash, positions, screenshots/Output and actual outcomes in the Studio validation record. Required S01–S09 gates remain pending until that evidence exists.
