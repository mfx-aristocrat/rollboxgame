# Platformer adventure expansion

Decision: 2026-11-03. The user explicitly requested more items, gameplay and terrain, with a Mario-inspired player/world. This authorizes M03-R2 alongside the earlier pending slice gates; it does not pass those gates or authorize public release.

## Player experience and scope

Keep Switchback Couriers and its four polarity gates. Surround it with a bright toy-like platforming landscape: grassy layered cliffs, rounded hills, oversized flowers, colorful cottage roofs, archways, flagpoles, stepping ledges and cloud formations. Dress the player as a cheerful red-capped courier with blue overalls, yellow buttons, gloves, brown boots and a moustache. All geometry is authored from engine primitives; the cap carries the game's own courier identity. No imported Nintendo models, logos, audio or textures are needed.

The expansion adds two connected southern regions, Sunpetal Gardens and Cloudstep Mesa, increasing the current world footprint beyond 920×920 studs. A safe walking route reaches every region; springs and short stepping ledges provide optional platforming. New geometry must not catch falling Training runners or obstruct pickup/spawn.

Collect golden trail tokens, find landmark pennants, open fixed-reward bonus crates and use spring pads. These are shared visible landmarks with **per-player, once-per-session collection**. Show a compact exploration counter and clear collection feedback. Crates are deterministic and free. Exploration rewards are separate session score, not saved coins, purchases or delivery completion. Death preserves exploration collection; leaving resets it. Other players retain their own opportunities. Spring pads do not apply during a scored parcel run, preserving movement validation and best times.

## Ownership and integration contract

- `WorldLayout`/`TerrainWorld`: existing and new terrain, safe connected walking paths, region signs and scenery. Pure layout stays testable outside Studio.
- `AdventureLayout.create(config)`: immutable-by-convention numeric item/spring positions, unique IDs, kind and fixed score; no Roblox services.
- `AdventureWorld.build(parent, layout)`: named `PlatformerAdventure` root; returns `{items = {{spec, part, prompt?}}, springs = {{spec, part}}}`. All objects anchored; decorative pieces noncolliding. Interactables need no embedded scripts.
- `AdventureRules`: per-player collected IDs, fixed score, duplicate/range/alive/cooldown checks. Never modifies Profile or delivery economy.
- `Adventure.new(world, config)`: server owns state, spatial collection sampling and crate prompts. Public `add(player)`, `remove(player)`, `step(player, root, alive, running, now)`, `snapshot(player)`, `destroy()`. No new client-authorized reward remote. Snapshot has score/collected/total/landmarks/message; client presents it.
- `CourierAppearance`: source-built outfit attached to ordinary R6/R15 character limbs; no movement/health changes. Handle appearance loading and respawn without duplicate outfit parts. Owned parts are massless/noncolliding; default avatar assets are only changed in the live game character, never the user's account.
- Main agent owns bootstrap integration, HUD, roadmap/state, Studio synchronization, evidence and Git. Independent delegates own disjoint source/test files.

## Acceptance and checks defined before implementation

1. Expanded map has six named reachable regions, connected safe paths, distinctive landmarks and visible detail at the depot. Original Training geometry, pickup and fall clearance remain intact.
2. One coherent red-cap/overalls courier outfit appears after appearance loads and on respawn; attachments never anchor/block the avatar or hide the parcel.
3. At least 24 trail tokens, four fixed bonus crates, six landmark collectibles and four springs. Each item gives only its configured session score once per player; far/dead/malformed/duplicate collection cannot award. Two players can collect independently.
4. Springs launch a nearby idle player with bounded vertical speed/cooldown. They do not boost a scored delivery or create a delivery reward. Ordinary walking remains possible.
5. HUD communicates collection progress and session-only status while preserving delivery, safe-area controls and shop behavior. Collected objects visually distinguish personal completion.
6. Automated: pure adventure rules/boundaries, independent-player state, deterministic bounded layout/reachability/clearance; existing 94 cases; all source compiles; artifact mapping/static Workspace setting; byte-identical builds; Windows/Linux CI.
7. Studio: real E pickup regression; outfit/respawn readback and screenshot; real movement over a token; crate prompt once/duplicate/far rejection; idle spring motion and running-run exclusion; terrain traversal samples; no captured server/client errors; desktop and small landscape/portrait HUD review. Record uncompleted checks explicitly. Existing multiplayer/hardware/five-tester/persistence gates remain separate.

## API references

Verified official documentation: [Character appearance](https://create.roblox.com/docs/characters/appearance), [HumanoidDescription](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription), [Player lifecycle](https://create.roblox.com/docs/reference/engine/classes/Player), [BasePart physics](https://create.roblox.com/docs/reference/engine/classes/BasePart). Cosmetic composition and exact jump tuning require real Studio validation, not just compilation.
