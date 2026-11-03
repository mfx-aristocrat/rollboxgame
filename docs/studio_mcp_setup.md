# Roblox Studio MCP installation

Installed 2026-11-03 on this Windows host at the user's request: the exact unscoped npm package **robloxstudio-mcp@latest**, resolved to **2.6.0**. This package belongs to [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp), whose repository is archived and recommends a maintained fork. No different package was substituted.

## Verified installation

- `npm install --global robloxstudio-mcp@2.6.0` succeeded.
- Copied the package's `studio-plugin/MCPPlugin.rbxmx` to `%LOCALAPPDATA%/Roblox/Plugins/MCPPlugin.rbxmx`. SHA256 matches the v2.6.0 GitHub release: `946996ddfcf553ff26f8122b2ff39a4c165d4317f1084d9ea7631dba356d87b0`.
- Registered enabled global Codex MCP entry `robloxstudio`, STDIO transport, using the installed Node executable and installed package entrypoint. Set `ROBLOX_STUDIO_HOST=127.0.0.1` to keep the bridge local. Existing Codex MCP entries were preserved; prior config backed up under the user's private `.codex/backups` folder.
- SDK smoke check initialized server version 2.6.0, discovered **69 tools**, and called `get_connected_instances`: **0 instances**. Server startup/tool discovery passed; Studio connection and runtime tests have **not** passed. The temporary check process was closed after verification.
- No game, place, scripts, account permissions, publishing settings or saved data were modified by the installation.

## Finish connecting (user actions)

1. Save current Studio work. Fully close and reopen Roblox Studio to load the local plugin. Do not discard unsaved work or publish publicly for this setup.
2. In the intended private/test place, enable **Allow HTTP Requests** under **Experience/Game Settings > Security**, as required by the package's [installation guide](https://github.com/boshyxd/robloxstudio-mcp/blob/main/studio-plugin/INSTALLATION.md). This is an app security setting; the user must make the change.
3. Reload MCP servers in the Codex desktop app (Settings > MCP servers > Restart), or restart the app. Confirm `robloxstudio` is enabled. [Official OpenAI MCP configuration instructions](https://learn.chatgpt.com/docs/extend/mcp).
4. In Studio's **Plugins** toolbar, open **MCP Server** and connect it to `http://127.0.0.1:58741` (the package's default local port). Approve any Studio plugin access prompt yourself. The plugin should show **Connected** when Codex's server is running.
5. Ask the agent to verify the connection. Discover `get_connected_instances`, select the intended instance ID, inspect actual schemas/state/place/tree read-only, and only then run scoped validation. Never assume an installed server is a connected Studio session. Inspect capabilities before relying on runtime evaluation/multiplayer features that may exist only in other editions/forks.

The earlier computer-use window-access denial remains a separate permission. This MCP installation has its own explicit setup/connection and does not grant computer-use access or prove any game playtest.

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
