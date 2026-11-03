#!/usr/bin/env python3
"""Run real pickup/adventure regressions through an existing local MCP bridge.

Requires robloxstudio-mcp 2.6.0, one connected Edit instance, and the current
source already synchronized to Studio. Never publishes, changes game source or
settings, or stops a user's playtest. Temporary fixtures finish their own test.
An ambiguous HTTP timeout deliberately leaves fixtures for inspected recovery.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


ROOT = Path(__file__).resolve().parents[1]
ATTRIBUTE = "RollboxTestFixture"
STATE_CODE = """return game:GetService("HttpService"):JSONEncode({
    editModeActive = game:GetService("StudioTestService").EditModeActive
})"""


class CheckFailure(Exception):
    """A missing precondition or failed assertion, never a successful test."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise CheckFailure("HTTP redirects are forbidden")


def local_url(value):
    parsed = urlsplit(value)
    if (
        parsed.scheme != "http"
        or parsed.hostname not in ("127.0.0.1", "localhost")
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
    ):
        raise argparse.ArgumentTypeError("base URL must be http://localhost[:port] or http://127.0.0.1[:port]")
    try:
        parsed.port
    except ValueError as exc:
        raise argparse.ArgumentTypeError("invalid local bridge port") from exc
    return value.rstrip("/")


def long_string(value):
    """Encode JSON as a Luau long string without allowing a terminator escape."""
    equals = "="
    # Also guard a terminator that starts in the payload's final characters
    # and finishes in the closing delimiter (JSON arrays end with a bracket).
    while "]" + equals + "]" in value + ("]" + equals + "]")[:-1]:
        equals += "="
    return "[" + equals + "[" + value + "]" + equals + "]"


def fixtures(suite="pickup"):
    stem = "Pickup" if suite == "pickup" else "Adventure"
    specs = (
        ("ServerScriptService", "__Rollbox" + stem + "RuntimeProbe", "Script", suite + ".server.luau"),
        ("StarterPlayerScripts", "__Rollbox" + stem + "RuntimeClient", "LocalScript", suite + ".client.luau"),
    )
    return [
        {"parent": parent, "name": name, "className": class_name,
         "source": (ROOT / "tests" / "studio" / filename).read_text(encoding="utf-8")}
        for parent, name, class_name, filename in specs
    ]


def fixture_code(specs, cleanup=False):
    """Preflight every name before any edit; mutate only exact owned fixtures."""
    encoded = long_string(json.dumps(specs, ensure_ascii=True))
    common = """
local Http = game:GetService("HttpService")
local Test = game:GetService("StudioTestService")
assert(Test.EditModeActive == true, "Refusing fixture edits while a test is active")
local Editor = game:GetService("ScriptEditorService")
local History = game:GetService("ChangeHistoryService")
local specs = Http:JSONDecode(ENCODED)
local rows = {}
for _, spec in specs do
    local parent = if spec.parent == "StarterPlayerScripts"
        then game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
        else game:GetService("ServerScriptService")
    assert(parent, "Missing fixture parent")
    local matches = {}
    for _, child in parent:GetChildren() do
        if child.Name == spec.name then table.insert(matches, child) end
    end
    assert(#matches <= 1, "Duplicate fixture name; preserving all objects")
    local existing = matches[1]
    if existing then
        assert(existing.ClassName == spec.className
            and existing:GetAttribute("RollboxTestFixture") == true,
            "Unowned fixture collision; preserving object")
        assert(existing.Source == spec.source and Editor:GetEditorSource(existing) == spec.source,
            "Fixture source differs; preserving object")
    end
    table.insert(rows, {spec = spec, parent = parent, existing = existing})
end
assert(Test.EditModeActive == true, "Test started during fixture preflight")
local recording = History:TryBeginRecording("RollboxPickupFixtures", "Rollbox pickup test fixtures")
assert(recording, "Cannot begin fixture history recording")
local changed, reused = 0, 0
local ok, problem = pcall(function()
BODY
end)
History:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
assert(ok, tostring(problem))
return Http:JSONEncode({verified = true, changed = changed, reused = reused})
"""
    if cleanup:
        body = """for _, row in rows do
    if row.existing then row.existing:Destroy(); changed += 1 end
end
for _, row in rows do
    assert(row.parent:FindFirstChild(row.spec.name) == nil, "Fixture cleanup readback failed")
end"""
    else:
        body = """for _, row in rows do
    if row.existing then
        reused += 1
    else
        assert(Test.EditModeActive == true, "Test started during fixture installation")
        local script = Instance.new(row.spec.className)
        script.Name = row.spec.name
        script:SetAttribute("RollboxTestFixture", true)
        script.Parent = row.parent
        Editor:UpdateSourceAsync(script, function() return row.spec.source end)
        assert(script.Source == row.spec.source and Editor:GetEditorSource(script) == row.spec.source,
            "Fixture readback mismatch")
        assert(Test.EditModeActive == true, "Test started during fixture source update")
        row.existing = script
        changed += 1
    end
end
for _, row in rows do
    assert(row.existing.Parent == row.parent and row.existing.Source == row.spec.source
        and Editor:GetEditorSource(row.existing) == row.spec.source, "Fixture verification failed")
end"""
    return common.replace("ENCODED", encoded).replace("BODY", body)


class Bridge:
    def __init__(self, base_url, evidence):
        self.base_url = base_url
        self.evidence = evidence
        # Ignore ambient proxy credentials and forbid redirects off loopback.
        self.opener = build_opener(ProxyHandler({}), NoRedirect())

    def call(self, name, args, timeout=15):
        row = {"tool": name, "startedUtc": datetime.now(timezone.utc).isoformat()}
        self.evidence["calls"].append(row)
        request = Request(self.base_url + "/mcp/" + name,
                          data=json.dumps(args).encode("utf-8"),
                          headers={"Content-Type": "application/json"}, method="POST")
        try:
            with self.opener.open(request, timeout=timeout) as response:
                payload = json.load(response)
            row["response"] = payload
            if payload.get("isError"):
                raise CheckFailure(name + " returned an MCP error")
            content = payload.get("content", [])
            if len(content) != 1 or content[0].get("type") != "text":
                raise CheckFailure(name + " returned an unexpected MCP envelope")
            result = json.loads(content[0]["text"])
            if not isinstance(result, dict) or result.get("success") is False or "error" in result:
                raise CheckFailure(name + " returned an unsuccessful response")
            return result
        except Exception as exc:
            row["error"] = str(exc)
            if isinstance(exc, HTTPError):
                row["httpErrorBody"] = exc.read().decode("utf-8", errors="replace")
            raise

    def execute(self, code):
        result = self.call("execute_luau", {"target": "edit", "code": code})
        if result.get("success") is not True or not isinstance(result.get("returnValue"), str):
            raise CheckFailure("execute_luau did not return verified JSON")
        value = json.loads(result["returnValue"])
        if not isinstance(value, dict):
            raise CheckFailure("execute_luau JSON was not an object")
        return value

    def require_unique_edit(self, expected=None):
        result = self.call("get_connected_instances", {})
        instances = result.get("instances")
        if not isinstance(instances, list):
            raise CheckFailure("Missing connected instance list")
        edits = [row for row in instances if str(row.get("role", "")).lower() == "edit"]
        if len(edits) != 1 or (expected is not None and edits[0].get("instanceId") != expected):
            raise CheckFailure("Exactly one unchanged Edit instance is required")
        identity = edits[0].get("instanceId")
        if not isinstance(identity, str) or not identity:
            raise CheckFailure("Edit instance has no identity")
        return identity

    def require_idle(self):
        state = self.execute(STATE_CODE)
        if state.get("editModeActive") is not True:
            raise CheckFailure("User playtest is active; it will not be stopped")
        return state


def validate_result(result, suite="pickup"):
    if suite == "adventure":
        names = ("outfit", "outfitPhysics", "world", "floorLayersSeparated", "catalog", "walkCollection", "hud", "tokenOnce", "farCrate", "cratePrompt", "crateReward", "crateOnce", "deliveryEconomy", "springMotion", "pickup", "respawn", "respawnCollection", "noClientErrors")
        assertions = {name: result.get("assertions", {}).get(name) is True for name in names}
        assertions.update(fixture=result.get("fixture") == "adventure-engine-v1",
                          completed=result.get("finished") is True,
                          succeeded=result.get("reason") == "adventure_succeeded",
                          noServerErrors=result.get("serverErrors") == [])
        return assertions
    client = result.get("client", {})
    assertions = {
        "fixture": result.get("fixture") == "pickup-engine-v1",
        "completed": result.get("finished") is True,
        "pickupSucceeded": result.get("reason") == "pickup_succeeded",
        "worldPresent": result.get("worldPresent") is True,
        "oneRemoteFolder": result.get("remoteFolders") == 1,
        "fallenPartsDestroyHeight": result.get("fallenPartsDestroyHeight") == -100,
        "realEInput": isinstance(client.get("eEvents"), (int, float)) and client["eEvents"] >= 1,
        "virtualInputSucceeded": client.get("inputOk") is True,
        "guiPresent": client.get("guiPresent") is True,
        "runningSnapshot": client.get("snapshot", {}).get("state") == "Running",
        "immediateParcel": result.get("immediate", {}).get("parcel") is True,
        "delayedParcel": result.get("delayed", {}).get("parcel") is True,
        "noServerErrors": result.get("serverErrors") == [],
        "noClientErrors": client.get("clientErrors") == [],
    }
    return assertions


def run(args, evidence):
    bridge = Bridge(args.base_url, evidence)
    specs = fixtures(args.suite)
    evidence["fixtures"] = [
        {"name": spec["name"], "parent": spec["parent"],
         "sha256": hashlib.sha256(spec["source"].encode("utf-8")).hexdigest()}
        for spec in specs
    ]
    identity = bridge.require_unique_edit()
    evidence["editInstanceId"] = identity
    evidence["initialState"] = bridge.require_idle()
    touched = False
    ambiguous = False
    stopped = False
    try:
        # If this request times out, it may still run in the plugin queue.
        touched, ambiguous = True, True
        evidence["installation"] = bridge.execute(fixture_code(specs))
        ambiguous = False
        if evidence["installation"].get("verified") is not True:
            raise CheckFailure("Fixture installation was not verified")
        bridge.require_unique_edit(identity)
        bridge.require_idle()
        ambiguous = True
        evidence["start"] = bridge.call("start_playtest", {"mode": "play"}, timeout=45)
        ambiguous = False
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            output = bridge.call("get_playtest_output", {"target": "edit"},
                                 timeout=max(0.1, min(8, deadline - time.monotonic())))
            evidence["lastOutput"] = output
            if output.get("isRunning") is False:
                stopped = True
                raw = output.get("testResult")
                if not isinstance(raw, str) or not raw:
                    raise CheckFailure("Stopped test has no structured fixture result")
                result = json.loads(raw)
                if not isinstance(result, dict):
                    raise CheckFailure("Fixture result is not an object")
                evidence["testResult"] = result
                evidence["assertions"] = validate_result(result, args.suite)
                if not all(evidence["assertions"].values()):
                    raise CheckFailure("Runtime assertions failed")
                break
            if output.get("isRunning") is not True:
                raise CheckFailure("Unknown playtest state")
            time.sleep(min(1, max(0, deadline - time.monotonic())))
        else:
            raise CheckFailure("Playtest did not finish within 45 seconds")
    finally:
        if touched:
            # Never enqueue a delete behind a timed-out start/install request.
            if ambiguous:
                evidence["cleanup"] = {"status": "LEFT_FIXTURES", "reason": "ambiguous mutating request"}
            else:
                try:
                    bridge.require_unique_edit(identity)
                    bridge.require_idle()
                    # EditModeActive, not RunService:IsRunning in the Edit VM,
                    # proves no test is running. Repeat inside the cleanup code.
                    evidence["cleanup"] = bridge.execute(fixture_code(specs, cleanup=True))
                    evidence["cleanup"]["status"] = "CLEANED"
                except (Exception, KeyboardInterrupt) as exc:
                    evidence["cleanup"] = {"status": "LEFT_FIXTURES", "reason": str(exc),
                                           "observedStopped": stopped}
            if evidence["cleanup"]["status"] != "CLEANED" and sys.exc_info()[0] is None:
                raise CheckFailure("Fixture cleanup could not be verified")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", type=local_url, default="http://127.0.0.1:58741")
    parser.add_argument("--suite", choices=("pickup", "adventure"), default="pickup")
    parser.add_argument("--output", type=Path, default=ROOT / ".tools" / "pickup-engine-result.json")
    args = parser.parse_args()
    evidence = {"driver": "studio-pickup-check-v1", "status": "FAIL",
                "startedUtc": datetime.now(timezone.utc).isoformat(), "calls": []}
    try:
        run(args, evidence)
        evidence["status"] = "PASS"
    except Exception as exc:
        evidence["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    except KeyboardInterrupt:
        evidence["failure"] = {"type": "KeyboardInterrupt", "message": "Interrupted"}
    evidence["finishedUtc"] = datetime.now(timezone.utc).isoformat()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    assertions = evidence.get("assertions", {})
    result = evidence.get("testResult", {})
    client = result.get("client", {})
    # No raw bridge output, exception details, source, or identifiers on console.
    print(json.dumps({"status": evidence["status"], "assertionsPassed": sum(assertions.values()),
                      "assertionsTotal": len(assertions), "eEvents": client.get("eEvents", 0),
                      "cleanup": evidence.get("cleanup", {}).get("status", "NOT_INSTALLED"),
                      "bridgeCalls": len(evidence["calls"])}))
    return 0 if evidence["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
