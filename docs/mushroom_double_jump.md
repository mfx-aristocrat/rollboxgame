# Grass and mushroom double jump

User-authorized extension, 2026-11-03. Improve the flat green floor's grass appearance, and let a player discover a mushroom crate that unlocks a higher, two-press jump. This work extends the existing game; pending release gates still apply.

## Behavior and scope defined before implementation

- Use Roblox's built-in Grass material on green course tops, with a more natural green palette and restrained, noncolliding source-built grass detail. Retain the floor-flicker separation, path visibility, course gaps and walking geometry. No uploaded textures or permissions are required.
- Place a distinct source-built mushroom crate on the first west-exit trail, near (-92,11.625,24), reachable by ordinary walking. A red/cream spotted mushroom is visible. Open it with the standard E/touch/gamepad prompt to receive the mushroom and unlock double jump. The shared crate stays available for other players.
- The unlock belongs to each player for this session. Death/respawn retains it; leaving resets it. No saved-profile or coin changes. Existing 40 exploration finds and four bonus crates retain their scoring contract; the mushroom crate is a separate power-up.
- Keep the ordinary first jump. A second distinct Space press while airborne gives one bounded upward boost; holding Space or requesting a third jump cannot keep adding boosts. A genuine landing recharges the air jump. Use the ordinary jump button twice on touch/gamepad; keep typing, menus and shop focus safe.
- Server owns collection/unlock, one-air-jump eligibility, landing/takeoff observations, cooldown and allowed impulse. Client sends only intent and shows feedback; no client-supplied velocity/reward or trusted ownership flag. Remotes are bounded/rate-limited. Character changes clear old air-cycle state and connections while retaining session entitlement.
- The free ability may be used while carrying a parcel. Gate order, polarity, legitimate movement checks and one-time rewards remain enforced. Validate this integration rather than disabling existing checks.

## Ownership seams

Power-up configuration and source crate are separate from the exploration-score catalog. A server Powerups module owns crate prompt, per-player state and physical validation; a pure rule module supports meaningful boundary tests. A client JumpController owns physical input edges, focus gating and per-character cleanup. Main owns bootstrap, snapshot/ack integration, source synchronization, evidence and Git.

Runtime refinement: classic character ownership made server-only velocity writes intermittent. The server validates and consumes the single air jump, then approves a bounded integer request nonce on JumpApproval. The owning client executes one fixed boost for a matching living character, pending request and epoch within 0.4 seconds. Landing, death, cancellation and ordered recovery invalidation discard pending approvals. Physics is applied once. A pending-takeoff window tolerates zero-velocity transition frames; observed upward displacement confirms takeoff when owner velocity is unavailable on the server. Ordinary ledge falls remain ineligible.

## Verified implementation

Green course tops now use Grass; 144 original noncolliding, nontouching, nonquery blades add edge detail. Landscape is 747 Parts within the existing 1100 cap. The 40 exploration finds and their score contract are retained.

The first engine trials exposed sticky takeoff classification and intermittent server-only physics. These were fixed with pending takeoff observation, server-approved owner execution, and stale/duplicate approval rejection. The final single-client test passes **23/23 assertions**: ordinary jump ≈7.27 studs, double ≈14.00, quick ≈12.96, late ≈12.84, third press ≈14.00 and carrying ≈14.00. Holding Space retains ordinary height. Landing recharge, native crate prompt, far/locked/malformed/focus rejection, respawn retention and a complete powered delivery awarding exactly 25 coins pass; no captured server/client errors. These are local Studio measurements, not network performance targets.

Repeat with `python scripts/studio-pickup-check.py --suite powerups --output .tools/powerups-result.json`. Multiplayer uses `python scripts/studio-powerups-multiplayer.py --suite powerups --output .tools/powerups-multiplayer.json`, invoking the documented StudioTestService multiplayer API because the installed MCP start tool does not invoke that API. Both preserve active user tests and clean only owned fixtures. Actual touch/gamepad device testing is separate from the passing input-adapter checks.

Two-client run: both clients connected and native crate prompts independently unlocked each player's ability. `independentLock` and `independentCrate` passed. The aggregate test remains FAIL: background VirtualInput missed some Space presses (including a zero-height baseline), and Roblox's Player2 ChatScript reported an unregistered CoreGuiChatConnections error. This is not a passed multiplayer input or device gate. Full trace: validation/mushroom-two-clients.json. Final single-client pass: validation/mushroom-pass.json. Both tests cleaned fixtures; the multiplayer result marker was removed.

API sources: [input/CAS](https://create.roblox.com/docs/reference/engine/classes/ContextActionService), [owner physics](https://create.roblox.com/docs/physics/network-ownership), [Studio multiplayer](https://create.roblox.com/docs/reference/engine/classes/StudioTestService), [built-in materials](https://create.roblox.com/docs/parts/materials).

## Observable acceptance and required checks

1. Green course floors visibly read as grass; no new conflicting floor faces, path obstructions or mandatory jump changes. Reproducible build, source mapping and existing floor regression pass.
2. Nearby E/standard prompt unlocks the mushroom for that player exactly once; far/dead/duplicate/malformed attempts cannot grant or stack it. Two players retain separate opportunities. Spawn/death/session reset behavior is explicit.
3. Real Studio input before unlock produces the ordinary jump; after unlock two separate jump presses reach a higher peak. A held key/third press cannot produce another boost. Landing permits another double jump. Test walking off a ledge, death midair, rapid input and focus/modal behavior.
4. Default touch/gamepad jump input has equivalent behavior, without an overlapping custom jump button. Record actual emulator/controller evidence separately from unit input-adapter tests.
5. Delivery pickup and a representative powered jump do not cause a false movement reset, skip a gate or alter coin grants. Existing adventure/floor/runtime suites remain green.
6. Run all meaningful automated checks, real engine tests and a visual grass/crate review; update docs and PROJECT_STATE. Keep any unverified device/multiplayer/release gates AWAITING_VALIDATION, push develop and update the draft PR. No public publishing or paid actions.
