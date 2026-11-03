# Roblox Studio MCP installation

Installed 2026-11-03 on this Windows host at the user's request: the exact unscoped npm package **robloxstudio-mcp@latest**, resolved to **2.6.0**. This package belongs to [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp), whose repository is archived and recommends a maintained fork. No different package was substituted.

## Verified installation

- `npm install --global robloxstudio-mcp@2.6.0` succeeded.
- Copied the package's `studio-plugin/MCPPlugin.rbxmx` to `%LOCALAPPDATA%/Roblox/Plugins/MCPPlugin.rbxmx`. SHA256 matches the v2.6.0 GitHub release: `946996ddfcf553ff26f8122b2ff39a4c165d4317f1084d9ea7631dba356d87b0`.
- Registered enabled global Codex MCP entry `robloxstudio`, STDIO transport, using the installed Node executable and installed package entrypoint. Set `ROBLOX_STUDIO_HOST=127.0.0.1` to keep the bridge local. Existing Codex MCP entries were preserved; prior config backed up under the user's private `.codex/backups` folder.
- SDK smoke check initialized server version 2.6.0, discovered **69 tools**, and called `get_connected_instances`: **0 instances**. Server startup/tool discovery passed; Studio connection and runtime tests have **not** passed. The temporary check process was closed after verification.
- No game, place, scripts, account permissions, publishing settings or saved data were modified by the installation.

### Connection verified — 2026-11-03

Native Codex MCP tools are now available. `get_connected_instances` returned one Edit session; `get_place_info` read **Place1**, place ID **101188910650353**, universe ID **10774439666**. `execute_luau` explicitly targeted Edit and returned JSON confirming `IsStudio=true`, `IsRunning=false`. This proves connection, metadata read and read-only plugin-context Luau execution. No place was changed and no playtest was started. Source/build identity and place visibility remain unverified; inspect them before gameplay testing. Rediscover the instance each session. The installed tool set does not expose `get_studio_state`; use its actual supported schemas rather than assuming another fork's API.

## Finish connecting (user actions)

This host is already connected and has completed a real startup/E regression. The steps below describe a new host or recovery; do not repeat them or change settings for the current working connection.

1. Save current Studio work. Fully close and reopen Roblox Studio to load the local plugin. Do not discard unsaved work or publish publicly for this setup.
2. Follow Studio's plugin network access prompts. The package's [installation guide](https://github.com/boshyxd/robloxstudio-mcp/blob/main/studio-plugin/INSTALLATION.md) discusses **Allow HTTP Requests**, but this host connected and completed the EndTest-based pickup regression while game `HttpService.HttpEnabled` was **false**. Enabling game HTTP is not a prerequisite established by our test; leave a working configuration alone.
3. Reload MCP servers in the Codex desktop app (Settings > MCP servers > Restart), or restart the app. Confirm `robloxstudio` is enabled. [Official OpenAI MCP configuration instructions](https://learn.chatgpt.com/docs/extend/mcp).
4. In Studio's **Plugins** toolbar, open **MCP Server** and connect it to `http://127.0.0.1:58741` (the package's default local port). Approve any Studio plugin access prompt yourself. The plugin should show **Connected** when Codex's server is running.
5. Ask the agent to verify the connection. Discover `get_connected_instances`, select the intended instance ID, inspect actual schemas/state/place/tree read-only, and only then run scoped validation. Never assume an installed server is a connected Studio session. Inspect capabilities before relying on runtime evaluation/multiplayer features that may exist only in other editions/forks.

MCP and computer-use access are separate. Earlier computer-use capture was denied; later Studio capture, viewport focus and E input succeeded in this session. No persistent permission setting was inspected/changed.

## Runtime validation verified — 2026-11-03

Only Edit is discoverable; its RunService state is not the live test VM. `StudioTestService.EditModeActive` identifies idle Edit. The real pickup regression uses temporary server/client fixtures and `StudioTestService:EndTest` JSON to collect engine results: **14/14 assertions PASS**, cleanup verified, followed by a clean Windows viewport E test. See [runtime_pickup_startup_fix.md](runtime_pickup_startup_fix.md) and `python scripts/studio-pickup-check.py`. The driver refuses an existing active test. In this session `stop_playtest` did not end a test; normal Studio Shift+F5 worked. An empty MCP log buffer alone did not reveal the original startup exception. No public publishing, Open Cloud access or game HTTP change was needed.

## Reproduce on another Windows host

```powershell
npm.cmd install --global robloxstudio-mcp@2.6.0
$mcpRoot = Join-Path (npm.cmd root --global) 'robloxstudio-mcp'
$studioPlugins = Join-Path $env:LOCALAPPDATA 'Roblox/Plugins'
New-Item -ItemType Directory -Force $studioPlugins | Out-Null
# Preserve an existing MCPPlugin.rbxmx before replacing it.
Copy-Item (Join-Path $mcpRoot 'studio-plugin/MCPPlugin.rbxmx') $studioPlugins
codex mcp add robloxstudio --env ROBLOX_STUDIO_HOST=127.0.0.1 -- node (Join-Path $mcpRoot 'dist/index.js')
codex mcp get robloxstudio
```

Local installation paths/credentials belong to the host configuration, not repository MCP entries. No Open Cloud key, Roblox password or OAuth secret is needed for this local bridge. Follow the user actions above after installation; keep existing release/validation gates in effect.
