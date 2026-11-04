"""Focused offline generator/validator checks; these do not run a Studio test."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("official_check", ROOT / "scripts/studio-official-check.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


def passing_result(suite):
    result = {"fixture": suite + "-engine-v1", "finished": True,
              "reason": suite + "_succeeded", "serverErrors": [], "assertions": {}}
    if suite == "pickup":
        result.update(worldPresent=True, remoteFolders=1, fallenPartsDestroyHeight=-100,
                      immediate={"parcel": True}, delayed={"parcel": True},
                      client={"eEvents": 1, "inputOk": True, "guiPresent": True,
                              "snapshot": {"state": "Running"}, "clientErrors": []})
    else:
        result["assertions"] = {key: True for key in driver.legacy.validate_result(result, suite)}
    return result


def capture(suite):
    return {"driver": driver.DRIVER, "suite": suite, "runId": "offline-test",
            "state": "COMPLETED", "editModeActive": True, "deadlineExceeded": False,
            "testResult": json.dumps(passing_result(suite))}


class OfficialCheckTests(unittest.TestCase):
    def test_validator_preserves_all_legacy_assertions(self):
        for suite, count in (("pickup", 14), ("adventure", 22), ("powerups", 23), ("ocean", 27)):
            with self.subTest(suite=suite):
                value = capture(suite)
                report = driver.validate_capture(value, suite, "offline-test")
                self.assertEqual(report["status"], "PASS")
                self.assertEqual(report["assertionsTotal"], count)
                self.assertEqual(report["assertions"], driver.legacy.validate_result(passing_result(suite), suite))
                result = passing_result(suite)
                result["serverErrors"] = ["deliberate offline failure"]
                value["testResult"] = json.dumps(result)
                self.assertEqual(driver.validate_capture(value, suite, "offline-test")["status"], "FAIL")

    def test_capture_requires_matching_completed_idle_run(self):
        for key, invalid in (("runId", "stale"), ("suite", "ocean"), ("driver", "other"),
                             ("state", "RUNNING"), ("editModeActive", False),
                             ("editModeActive", 1), ("deadlineExceeded", True),
                             ("testResult", None)):
            with self.subTest(key=key, invalid=invalid):
                value = capture("pickup")
                value[key] = invalid
                with self.assertRaises(ValueError):
                    driver.validate_capture(value, "pickup", "offline-test")

    def test_explicit_mcp_text_capture(self):
        value = {"content": [{"type": "text", "text": json.dumps(json.dumps(capture("pickup")))}]}
        self.assertEqual(driver.validate_capture(value, "pickup", "offline-test")["status"], "PASS")
        value["isError"] = True
        with self.assertRaises(ValueError):
            driver.validate_capture(value, "pickup", "offline-test")

    def test_generators_preserve_source_and_preflight_before_mutation(self):
        for suite in driver.SUITES:
            install = driver.fixture_code(suite, "offline-test")
            cleanup = driver.fixture_code(suite, "offline-test", cleanup=True)
            start = driver.start_code(suite, "offline-test")
            poll = driver.poll_code(suite, "offline-test")
            self.assertIn(driver.literal(driver.legacy.fixtures(suite)), install)
            self.assertIn('existing.Source == spec.source and Editor:GetEditorSource(existing) == spec.source', cleanup)
            # Embedded fixture source also contains Destroy calls; inspect the
            # generated mutation body, rather than matching inside its payload.
            mutation = cleanup.index('if row.existing then row.existing:Destroy()')
            self.assertLess(cleanup.index('"Fixture source differs; preserving object"'), mutation)
            self.assertLess(cleanup.index('data.state ~= "RUNNING"'), mutation)
            self.assertIn('local driver, suite, runId = "studio-official-check-v1", "' + suite + '", "offline-test"', start)
            self.assertIn('task.spawn(function()', start)
            self.assertIn('return Test:ExecutePlayModeAsync(', start)
            self.assertIn('result.Value ~= initial', start)
            self.assertIn('data.deadlineExceeded =', poll)
            self.assertNotIn('assert(Test.EditModeActive == true', poll)
            for code in (install, cleanup, start, poll):
                self.assertNotIn('ChangeHistoryService', code)
                self.assertNotIn('TryBeginRecording', code)

    def test_generated_luau_compiles(self):
        lune = ROOT / ".tools/bin" / ("lune.exe" if sys.platform == "win32" else "lune")
        if not lune.is_file():
            self.skipTest("Pinned Lune unavailable")
        with tempfile.TemporaryDirectory(prefix="rollbox-official-check-") as temporary:
            directory = Path(temporary)
            paths = []
            for suite in driver.SUITES:
                generated = {"install": driver.fixture_code(suite, "offline-test"),
                             "cleanup": driver.fixture_code(suite, "offline-test", cleanup=True),
                             "start": driver.start_code(suite, "offline-test"),
                             "poll": driver.poll_code(suite, "offline-test")}
                for command, code in generated.items():
                    path = directory / (suite + "-" + command + ".luau")
                    path.write_text(code, encoding="utf-8")
                    paths.append(path.as_posix())
            runner = directory / "compile.luau"
            runner.write_text('local fs = require("@lune/fs")\nlocal luau = require("@lune/luau")\n'
                              + 'for _, path in ' + json.dumps(paths).replace('[', '{', 1).removesuffix(']') + '} do\n'
                              + 'luau.load(fs.readFile(path), {debugName = path})\nend\n', encoding="utf-8")
            result = subprocess.run([str(lune), "run", str(runner)], capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
