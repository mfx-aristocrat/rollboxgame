# Real Studio pickup regression — 2026-11-03

The repeated E-key failure was reproduced in a real Studio server/client test. The previous fake-adapter tests missed a startup error because they replaced `World.build` with a stub. No keyboard or economy rewrite was required.

## Reproduction and cause

A temporary server fixture placed the character six studs from the box. A client LocalScript used Roblox's supported `UserInputService:CreateVirtualInput():SendKey` API to press and release E. It recorded actual input/prompt events, HUD/snapshot state, server parcel existence immediately and later, and real client/server error history. Results returned through `StudioTestService:EndTest` as JSON; no HTTP permission change or external upload was needed.

Before the fix, E reached the client and the native prompt fired, but no parcel appeared. The server reported:

```text
The current thread cannot write 'FallenPartsDestroyHeight' (lacking capability PluginOrOpenCloud)
```

`World.build` assigned `workspace.FallenPartsDestroyHeight = -100` from an ordinary server Script. That assignment throws before Main creates Remotes and registers pickup. The rendered world/prompt existed, but the pickup handler and client HUD never initialized.

Ranked checks after the red trace: (1) startup failure before Remotes, confirmed by the permission error and zero folders; (2) duplicate bootstrap/remote mismatch, unsupported by zero folders; (3) missing E/focus, ruled out by one actual E event, one native client prompt event and no focused textbox. The earlier distance fix remains relevant, but could not compensate for the startup crash.

Roblox restricts this property's setter to Studio/plugin tooling; it supports serialization. The setting now lives in the Rojo Workspace `$properties`, and `World.build` no longer writes it at runtime. [Official Workspace reference](https://create.roblox.com/docs/reference/engine/classes/Workspace#FallenPartsDestroyHeight).

## Before and after evidence

| Observation | Original engine run | Fixed engine run |
| --- | --- | --- |
| Real E key event / native client prompt | 1 / 1 | 1 / 0 (direct E handler won) |
| Remotes folders | 0 | 1 |
| HUD initialized | false | true |
| Parcel immediately / after further delay | false / false | true / true |
| Snapshot / HUD | unavailable | Running / CARRYING PARCEL |
| Server errors | protected-property exception | none |
| Client errors captured | none | none |

The open World source was compared with repository HEAD before editing and matched. Its previous Workspace threshold was -500. The fixed source and -100 Edit property were applied through plugin-backed Studio APIs and read back. The real runtime fixture also verifies -100, preventing a script-only sync from silently retaining the old threshold.

The artifact regression first failed with `Workspace must serialize FallenPartsDestroyHeight`, then passed after the project configuration change. Local build checks compile 20 Luau files and pass 94 standalone cases plus XML/source/config checks. The Studio regression is a separate result: **14/14 runtime assertions PASS**, including real E input, initialized HUD, Running snapshot, sustained parcel, no errors and threshold -100. It also verifies temporary fixture cleanup.

After cleanup, a fresh ordinary playtest was started. The agent focused the Studio viewport and pressed E through Windows computer-use input. The screenshot showed **CARRYING PARCEL • 0 coins** and the next-gate instruction. This clean test was left running for the user with the parcel picked up. No diagnostic Script/LocalScript remained in Edit.

## Repeat the engine test

With one connected, idle Studio Edit session containing the current source and Workspace property:

```powershell
python scripts/studio-pickup-check.py
```

The Python standard-library driver uses the existing loopback-only MCP bridge. It refuses an active user playtest and unknown fixture collisions, creates only its tagged temporary Script/LocalScript, starts Play, collects the fixture's JSON result, and removes its own exact-source fixtures after the test ends. The Studio test itself uses real VirtualInput, not a direct reward/Start remote or a mocked input callback. Full local evidence is saved under ignored `.tools/pickup-engine-result.json`; sanitized results are in `validation/pickup-startup-before.json` and `validation/pickup-startup-after.json`.

This validates startup and near-box keyboard pickup for one player. Boundary distances, touch/gamepad, two clients, the delivery/reward loop, terrain traversal, real hardware performance and persistence remain separate pending gates. No public publishing, paid purchase or save-data change occurred.
