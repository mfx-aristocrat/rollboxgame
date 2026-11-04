#!/usr/bin/env python3
"""Generate bounded official-Studio-MCP fixture operations; never contact Studio.

Run install, start, poll, cleanup through execute_luau in the SAME selected Edit
Studio, passing its explicit studio_id. Save each tool response as evidence.
The official tool owns change-history recording, so these snippets never nest it.
Poll once per call until COMPLETED/ERROR, then validate the captured poll JSON.
Only cleanup after the asynchronous start has returned and Studio is idle.
An ambiguous tool timeout requires inspection before another mutation.

Example: python scripts/studio-official-check.py start --suite ocean --run-id g03-ocean
         python scripts/studio-official-check.py validate --suite ocean --run-id g03-ocean --input poll.json

Timeouts flag a stalled operation without stopping Studio or deleting fixtures.
The existing server fixtures call EndTest on their own bounded suite timeout.
An engine/API stall may still require inspected manual recovery. No runtime pass
is implied by successfully generating snippets or installing fixtures.
"""

import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
DRIVER = "studio-official-check-v1"
RESULT_NAME = "__RollboxOfficialTestResult"
SUITES = ("pickup", "adventure", "powerups", "ocean")
TIMEOUTS = {"pickup": 45, "adventure": 45, "powerups": 160, "ocean": 240}
_spec = importlib.util.spec_from_file_location("rollbox_legacy_studio_check", ROOT / "scripts/studio-pickup-check.py")
legacy = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(legacy)


def literal(value):
    return legacy.long_string(json.dumps(value, ensure_ascii=True))


def preflight(suite, run_id, require_fixtures=False):
    """Check all selected fixture names/sources before any mutation."""
    return """
local Http = game:GetService("HttpService")
local Test = game:GetService("StudioTestService")
local Editor = game:GetService("ScriptEditorService")
local Storage = game:GetService("ServerStorage")
local driver, suite, runId = DRIVER, SUITE, RUN_ID
assert(Test.EditModeActive == true, "Refusing mutation while a test is active")
local specs = Http:JSONDecode(SPECS)
local rows = {}
local function unique(parent, name)
    local found = nil
    for _, child in parent:GetChildren() do
        if child.Name == name then
            assert(found == nil, "Duplicate owned name; preserving all objects")
            found = child
        end
    end
    return found
end
for _, spec in specs do
    local parent = if spec.parent == "StarterPlayerScripts"
        then game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
        else game:GetService("ServerScriptService")
    assert(parent, "Missing fixture parent")
    local existing = unique(parent, spec.name)
    if existing then
        assert(existing.ClassName == spec.className
            and existing:GetAttribute("RollboxTestFixture") == true,
            "Unowned fixture collision; preserving object")
        assert(existing.Source == spec.source and Editor:GetEditorSource(existing) == spec.source,
            "Fixture source differs; preserving object")
    end
    if REQUIRE_FIXTURES then assert(existing, "Install exact suite fixtures before starting") end
    table.insert(rows, {spec = spec, parent = parent, existing = existing})
end
local result = unique(Storage, "__RollboxOfficialTestResult")
local function resultData()
    assert(result and result.ClassName == "StringValue"
        and result:GetAttribute("RollboxTestFixture") == true
        and result:GetAttribute("Driver") == driver
        and result:GetAttribute("Suite") == suite
        and result:GetAttribute("RunId") == runId,
        "Result ownership differs; preserving object")
    local data = Http:JSONDecode(result.Value)
    assert(type(data) == "table" and data.driver == driver and data.suite == suite and data.runId == runId,
        "Result contents differ; preserving object")
    assert(data.state == "RUNNING" or data.state == "COMPLETED" or data.state == "ERROR",
        "Unknown result state; preserving object")
    return data
end
assert(Test.EditModeActive == true, "Test started during preflight")
""".replace("DRIVER", json.dumps(DRIVER)).replace("SUITE", json.dumps(suite)).replace("RUN_ID", json.dumps(run_id)).replace("REQUIRE_FIXTURES", "true" if require_fixtures else "false").replace("SPECS", literal(legacy.fixtures(suite)))


def no_other_fixtures(suite):
    others = [spec for other in SUITES if other != suite for spec in legacy.fixtures(other)]
    # One suite per session: another probe could call EndTest first.
    return """
for _, spec in Http:JSONDecode(OTHER_SPECS) do
    local parent = if spec.parent == "StarterPlayerScripts"
        then game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
        else game:GetService("ServerScriptService")
    assert(parent and parent:FindFirstChild(spec.name) == nil,
        "Another suite fixture exists; inspect and clean it before running")
end
""".replace("OTHER_SPECS", literal([{k: s[k] for k in ("parent", "name")} for s in others]))


def fixture_code(suite, run_id, cleanup=False):
    common = preflight(suite, run_id)
    if cleanup:
        return common + """
if result then
    local data = resultData()
    assert(data.state ~= "RUNNING", "Async operation pending; preserving fixtures")
end
assert(Test.EditModeActive == true, "Test started before cleanup")
local changed = 0
for _, row in rows do
    if row.existing then row.existing:Destroy(); changed += 1 end
end
if result then result:Destroy(); changed += 1 end
for _, row in rows do
    assert(row.parent:FindFirstChild(row.spec.name) == nil, "Fixture cleanup readback failed")
end
assert(Storage:FindFirstChild("__RollboxOfficialTestResult") == nil, "Result cleanup readback failed")
return Http:JSONEncode({verified = true, status = "CLEANED", changed = changed, suite = suite, runId = runId})
"""
    return common + no_other_fixtures(suite) + """
assert(result == nil, "Previous result exists; inspect and cleanup before installation")
local changed, reused = 0, 0
for _, row in rows do
    if row.existing then
        reused += 1
    else
        assert(Test.EditModeActive == true, "Test started during installation")
        local script = Instance.new(row.spec.className)
        script.Name = row.spec.name
        script:SetAttribute("RollboxTestFixture", true)
        script.Parent = row.parent
        Editor:UpdateSourceAsync(script, function() return row.spec.source end)
        row.existing = script
        changed += 1
    end
end
for _, row in rows do
    assert(row.existing.Parent == row.parent and row.existing.Source == row.spec.source
        and Editor:GetEditorSource(row.existing) == row.spec.source, "Fixture readback mismatch")
end
assert(Test.EditModeActive == true, "Test started during installation")
return Http:JSONEncode({verified = true, changed = changed, reused = reused, suite = suite, runId = runId})
"""


def start_code(suite, run_id):
    return preflight(suite, run_id, require_fixtures=True) + no_other_fixtures(suite) + """
assert(result == nil, "Result already exists; refusing duplicate or ambiguous start")
local data = {driver = driver, suite = suite, runId = runId, state = "RUNNING",
    startedUnix = os.time(), timeoutSeconds = TIMEOUT}
result = Instance.new("StringValue")
result.Name = "__RollboxOfficialTestResult"
result:SetAttribute("RollboxTestFixture", true)
result:SetAttribute("Driver", driver)
result:SetAttribute("Suite", suite)
result:SetAttribute("RunId", runId)
local initial = Http:JSONEncode(data)
result.Value = initial
result.Parent = Storage
assert(result.Value == initial, "Result installation readback failed")
task.spawn(function()
    -- Yield before the async launch so execute_luau returns promptly.
    task.wait()
    local ok, value = pcall(function()
        assert(Test.EditModeActive == true, "Another test started before async launch")
        return Test:ExecutePlayModeAsync({driver = driver, suite = suite, runId = runId})
    end)
    -- Never overwrite a removed, replaced or edited result after yielding.
    if result.Parent ~= Storage or result.Value ~= initial
        or result:GetAttribute("Driver") ~= driver or result:GetAttribute("Suite") ~= suite
        or result:GetAttribute("RunId") ~= runId or result:GetAttribute("RollboxTestFixture") ~= true then return end
    data.finishedUnix = os.time()
    data.state = if ok then "COMPLETED" else "ERROR"
    if ok then
        if type(value) == "string" then data.testResult = value
        else data.problem = "Test ended without a structured fixture JSON string" end
    else data.problem = tostring(value) end
    result.Value = Http:JSONEncode(data)
end)
return Http:JSONEncode({driver = driver, suite = suite, runId = runId, state = "STARTED", timeoutSeconds = TIMEOUT})
""".replace("TIMEOUT", str(TIMEOUTS[suite]))


def poll_code(suite, run_id):
    # Poll runs only in Edit, including while server/client VMs are active.
    # Source preflight is for mutations; polling must not require an idle VM.
    common = preflight(suite, run_id)
    start = common.index("local result = unique(")
    helpers = common[common.index("local function unique("):common.index("for _, spec in specs do")]
    result_helpers = common[start:common.rindex('assert(Test.EditModeActive')]
    return """
local Http = game:GetService("HttpService")
local Test = game:GetService("StudioTestService")
local Storage = game:GetService("ServerStorage")
local driver, suite, runId = DRIVER, SUITE, RUN_ID
""".replace("DRIVER", json.dumps(DRIVER)).replace("SUITE", json.dumps(suite)).replace("RUN_ID", json.dumps(run_id)) + helpers + result_helpers + """
local data = resultData()
data.editModeActive = Test.EditModeActive
data.elapsedSeconds = (data.finishedUnix or os.time()) - data.startedUnix
data.deadlineExceeded = data.elapsedSeconds > data.timeoutSeconds
return Http:JSONEncode(data)
"""


def decode_capture(value):
    """Accept decoded poll JSON, JSON-encoded JSON, or one text MCP envelope."""
    for _ in range(5):
        if isinstance(value, str):
            value = json.loads(value)
        elif isinstance(value, dict) and "content" in value:
            if value.get("isError"):
                raise ValueError("MCP returned an error")
            content = value["content"]
            if not isinstance(content, list) or len(content) != 1 or content[0].get("type") != "text":
                raise ValueError("Expected exactly one MCP text response; save decoded poll JSON instead")
            value = content[0]["text"]
        else:
            break
    if not isinstance(value, dict):
        raise ValueError("Captured result must be a JSON object")
    return value


def validate_capture(value, suite, run_id):
    data = decode_capture(value)
    required = {"driver": DRIVER, "suite": suite, "runId": run_id, "state": "COMPLETED"}
    if any(data.get(key) != expected for key, expected in required.items()):
        raise ValueError("Poll identity/state is not a completed, idle, matching operation")
    if data.get("editModeActive") is not True or data.get("deadlineExceeded") is not False:
        raise ValueError("Poll must confirm idle Studio and completion within the suite timeout")
    raw = data.get("testResult")
    if not isinstance(raw, str):
        raise ValueError("Test did not return the fixture JSON string")
    result = json.loads(raw)
    if not isinstance(result, dict):
        raise ValueError("Fixture JSON must be an object")
    assertions = legacy.validate_result(result, suite)
    return {"driver": DRIVER, "suite": suite, "runId": run_id,
            "status": "PASS" if all(assertions.values()) else "FAIL",
            "assertionsPassed": sum(assertions.values()), "assertionsTotal": len(assertions),
            "assertions": assertions, "testResult": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("install", "start", "poll", "cleanup", "validate"))
    parser.add_argument("--suite", choices=SUITES, required=True)
    parser.add_argument("--run-id", required=True, help="Unique operation token; reuse for all commands in one suite run")
    parser.add_argument("--input", type=Path, help="Captured poll JSON for validate; omitted means stdin")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,96}", args.run_id):
        parser.error("run-id must be 1-96 ASCII letters, digits, underscores or hyphens")
    if args.command != "validate":
        if args.input:
            parser.error("--input only applies to validate")
        generators = {"install": lambda: fixture_code(args.suite, args.run_id),
                      "start": lambda: start_code(args.suite, args.run_id),
                      "poll": lambda: poll_code(args.suite, args.run_id),
                      "cleanup": lambda: fixture_code(args.suite, args.run_id, cleanup=True)}
        print(generators[args.command]())
        return 0
    try:
        raw = args.input.read_text(encoding="utf-8-sig") if args.input else sys.stdin.read()
        result = validate_capture(json.loads(raw), args.suite, args.run_id)
    except (ValueError, TypeError, AttributeError, KeyError, OSError) as exc:
        result = {"status": "FAIL", "suite": args.suite, "problem": str(exc)}
    print(json.dumps(result, ensure_ascii=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
