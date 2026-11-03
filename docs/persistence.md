# Persistence foundation (M04)

Status: source implementation and automated foundation validated; M04 AWAITING_VALIDATION for Studio/private-service tests. Persistence remains disabled in the build. Automated fake-store evidence is separate from Roblox runtime evidence.

## Acceptance and checks

- Only a successful, schema-valid atomic load grants a session permission to save. A failed load never supplies a writable default profile.
- Atomic `UpdateAsync` acquisition excludes concurrent owners. A fresh unique token and an expiring lease fence every save and release; expired or replaced owners cannot write.
- Transient failures receive bounded ordered retries. Repeated callbacks have no gameplay side effects; an uncertain write outcome cannot make a release retry overwrite a newer session.
- Schema v1 preserves the selected design's coins, completed runs, tutorial state, cosmetic ownership/equipment and route best times. Malformed, unrecognized and future data is refused without replacement.
- Test and production use explicit, distinct store names and key prefixes. No implicit production environment or local writable fallback exists.
- Lune tests must cover existing progress, failed load, concurrent lock, expiry takeover, stale save, write/release failure, callback re-entry, invalid data, environment separation and retry deadlines.
- Required runtime gate remains pending: private published test experience, API access, reconnect, two server ownership contention, service failures, autosave renewal, leave and shutdown. No build or fake-store test proves that gate.

## Verified platform references

Observed 2026-11-03. Implementation decisions follow current official documentation, with a small dependency-injected module rather than copying Roblox's reference implementation.

- [Data stores](https://create.roblox.com/docs/cloud-services/data-stores): server access, cancelling a write by returning nil, non-yielding transforms, and a separate test experience for Studio API access.
- [Player data and purchasing systems](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing): atomic session locks, regular renewal, crash expiry and explicit load/save failure state.
- [Best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices): bounded backoff with jitter, requests ordered per key, uncertain outcomes, staggered autosaves.
- [UpdateAsync reference source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GlobalDataStore.yaml): transforms can run repeatedly; existing metadata and user IDs must be explicitly returned to preserve them.
- [BindToClose reference source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/DataModel.yaml): the platform allows 30 seconds for shutdown handlers; a blocked network operation cannot be promised a successful save.

## Implementation and configuration

- `src/server/Persistence.luau` is dependency-injected: `new({environment, profile, update, now, sleep, makeToken})`. `update(key, transform)` wraps `DataStore:UpdateAsync`. Non-yielding callbacks preserve existing metadata/user IDs, recheck schema/lease on every retry, and persist an operation ID with each snapshot.
- Dot-method API: `load(userId, deadline?)`, `save(userId, profile, deadline?)`, `release(userId, profile, deadline?)`, `status(userId)`, `forget(userId)`. Returns `{ok, reason, ...}`. Successful load returns a detached `profile`; failure gives no writable default. Positive real user IDs are required for real stores.
- `src/shared/Profile.luau` validates schema v1. There is no older live schema to migrate. Future/unversioned/malformed records fail closed; add a tested explicit migration before changing this policy.
- `src/server/PlayerData.luau` injects the store/clock/scheduler to manage async loading, gated mutations, dirty/saved revision feedback, staggered first save at 45–59 seconds and subsequent saves every 60 seconds (including lease renewal for unchanged profiles). Lease defaults to 180 seconds; three bounded store attempts use exponential backoff with jitter. A failed save retries at the next scheduled interval while ownership remains valid; lease loss freezes progression.
- Main wires Roblox services, freezes player state before final release, and joins in-flight load/save work. Clean leave uses a 20-second scheduling deadline; shutdown starts concurrent releases with a shared 25-second deadline. Roblox network calls already in flight cannot be interrupted or guaranteed to finish within that deadline. Late load/save responses attempt safe cleanup.
- A failed release keeps the immutable pending snapshot/operation ID. Final release cannot be replayed over a newer owner's write. Expired terminal bookkeeping is retired after a 185-second grace period; underlying stored locks also expire. No promise of zero crash loss: up to an autosave interval of unsaved play may be lost, and service outages can extend that window.

### Exact enablement steps (pending user/account configuration)

1. Keep the current default for local slice testing: `src/server/ServerSettings.luau` has `persistenceEnabled=false`. The HUD says Practice; no load/save request is made.
2. Create/publish a **private test** experience in Studio, confirm its universe ID in Creator Hub, and keep it separate from any production experience. A place ID is not a universe ID.
3. In `ServerSettings.luau`, set `testUniverseId` to that actual universe ID, keep `dataEnvironment="test"`, and set `persistenceEnabled=true` only in the test build. Production ID may stay 0 while testing; it must later be a different real universe ID before production enablement. Wrong/unconfigured IDs block progression rather than falling back to writable defaults.
4. The owner must enable Studio API access in the **private test experience** for Studio datastore tests. The agent cannot change that security setting through computer-use. Follow Roblox's warning to avoid production data access from Studio.
5. Open the freshly rebuilt place under that test experience. Check load/save HUD state; complete docs/studio_validation.md P01–P05 and record universe/build IDs and evidence. Test new/returning players, real save failures and ownership contention. Local two-client synthetic users may have non-positive IDs; use real accounts/private published tests for persisted user data.
6. Stores are `SwitchbackCouriers_test_v1` and `SwitchbackCouriers_production_v1`; keys additionally start `test:User_` or `production:User_`. Do not reuse live data for failure injection. Do not turn production on before runtime gates pass.

## Automated evidence

2026-11-03: Lune 0.11.1 passes **37 persistence cases** and **13 lifecycle cases**, plus the separate gameplay suite. Cases cover failed/uncertain load, no writable defaults, malformed/future data, lock contention/takeover, stale writes, commit-then-error outcomes, callback re-entry, metadata, deadlines, expired bookkeeping, disconnect while loading, autosaves, visible failure/recovery and shutdown. Review found and fixed a cached-lease-expiry race during in-flight renewal; its regression test verifies subsequent progression and final release. Late load/save completion after close's deadline also has deterministic fake-scheduler coverage. These use fakes; Roblox integration remains unverified. Run `./scripts/check.ps1` for all suites and build checks.
