# Private test and release procedure

Status: preparatory procedure; no Roblox experience, account eligibility, permissions, product ID or runtime test has been verified. This document does not complete M06.

## Private test setup
1. Run `./scripts/check.ps1`; record the Git SHA and `Get-FileHash build/RollboxGame.rbxlx -Algorithm SHA256`.
2. Open the generated place in Roblox Studio, signed into the intended Roblox owner account. GitHub credentials do not authenticate Roblox.
3. Publish it to a **new private test experience**. Confirm access remains private in Creator Hub. Configure the maximum player count to the limit in game_design.md. Record the universe/place IDs in the private test evidence; neither ID is configured yet.
4. Use the test data environment described in docs/persistence.md when available. Enable Studio API access only for the isolated private test experience when persistence validation begins. Never use a production experience for failure-injection tests.
5. Follow docs/studio_validation.md when available. Record hardware, test account roles, build SHA, date, screenshots/Output errors and individual test outcomes. Check real mobile hardware as well as the Device Simulator before claiming mobile performance.

## Publishing prerequisites
Check current eligibility, audience reach, maturity/compliance questionnaire, content and monetization requirements in Creator Hub. Requirements can vary by account and audience; do not infer eligibility from a successful GitHub build. Current official guidance was consulted on 2026-11-03:

- [Create and publish games and places](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- [Roblox publishing requirements](https://en.help.roblox.com/hc/en-us/articles/203313890-How-to-Publish-Games-on-Roblox)
- [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes)
- [Device Simulator](https://create.roblox.com/docs/studio/device-simulator)

All public release and any fees, subscriptions, advertising or paid assets require explicit approval from the user. Prepare the tested build, truthful description/screenshots, configuration and checklist before requesting that approval.

## Optional purchase configuration
Keep all purchase IDs disabled until real items are created under the intended Roblox experience and verified. For an initial permanent cosmetic pass, create it under the experience's Monetization > Passes area in Creator Hub (UI labels can change), supply its art/description/price, and copy its ID into the documented server config. Then validate success, cancellation, ownership rejoin and service-failure cases in a private test experience using Roblox's supported purchase testing workflow. Never invent an ID or charge a real purchase for a test without approval. [Official passes documentation](https://create.roblox.com/docs/production/monetization/passes).

## Release verification and rollback
1. M03–M05 must be DONE with required runtime evidence, CI green and final validated commits merged/pushed to main.
2. Rebuild the exact approved SHA and record artifact checksum and Roblox place version after private publishing. Verify spawn, a full loop, rewards, persistence, touch UI and entitlement behavior in the Roblox app.
3. Before production updates, retain the previously validated Git SHA and Roblox place version. Use the version-management/restore workflow in Creator Hub or rebuild the prior SHA in a separate checkout and republish through Studio if rollback is needed.
4. Keep profile schemas backward compatible. A code rollback is not a datastore rollback; future-schema data must fail closed. Plan and test migrations/backups before changing the stored schema.
5. Record release/rollback results in PROJECT_STATE.md and the validation evidence. Do not expose private test data or publish until authorized.
