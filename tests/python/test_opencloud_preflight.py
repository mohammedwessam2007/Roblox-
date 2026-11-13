import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("opencloud_preflight", ROOT / "tools/automation/opencloud_preflight.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestOpenCloudPreflight(unittest.TestCase):
    def test_missing_credentials_are_explicit(self):
        r = mod.assess({"OPEN_CLOUD_ALLOWED_EVENT": "true"})
        self.assertEqual(r["state"], "BLOCKED_MISSING_CONFIG")
        self.assertFalse(r["ready"])
        self.assertEqual(len(r["missing"]), 3)

    def test_valid_config_allows_gate_only(self):
        r = mod.assess({"OPEN_CLOUD_ALLOWED_EVENT": "true", "ROBLOX_KEY_PRESENT": "true",
                        "ROBLOX_UNIVERSE_ID": "123", "ROBLOX_PLACE_ID": "456"})
        self.assertTrue(r["ready"])
        self.assertFalse(r["real_engine_executed"])

    def test_pr_events_cannot_activate_credentials(self):
        r = mod.assess({"OPEN_CLOUD_ALLOWED_EVENT": "false", "ROBLOX_KEY_PRESENT": "true",
                        "ROBLOX_UNIVERSE_ID": "123", "ROBLOX_PLACE_ID": "456"})
        self.assertEqual(r["state"], "SKIPPED_UNTRUSTED_OR_NONDEFAULT_EVENT")
        self.assertFalse(r["ready"])

    def test_invalid_ids_are_rejected(self):
        r = mod.assess({"OPEN_CLOUD_ALLOWED_EVENT": "true", "ROBLOX_KEY_PRESENT": "true",
                        "ROBLOX_UNIVERSE_ID": "--help", "ROBLOX_PLACE_ID": "0"})
        self.assertFalse(r["ready"])
        self.assertEqual(len(r["missing"]), 2)

    def test_secret_value_not_needed(self):
        r = mod.assess({"OPEN_CLOUD_ALLOWED_EVENT": "true", "ROBLOX_KEY_PRESENT": "true",
                        "ROBLOX_UNIVERSE_ID": "1", "ROBLOX_PLACE_ID": "2",
                        "ROBLOX_API_KEY": "do-not-print-this"})
        self.assertNotIn("do-not-print-this", repr(r))

if __name__ == "__main__":
    unittest.main()
