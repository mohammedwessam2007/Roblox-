#!/usr/bin/env python3
"""Safe, secret-free Open Cloud preflight for private test CI.

This script never receives a Roblox API key. GitHub passes only the boolean
indicating that a key exists. No network calls or account changes occur here.
"""
import json
import os
import re
from pathlib import Path


def assess(env):
    allowed = env.get("OPEN_CLOUD_ALLOWED_EVENT", "false").lower() == "true"
    key_set = env.get("ROBLOX_KEY_PRESENT", "false").lower() == "true"
    universe = env.get("ROBLOX_UNIVERSE_ID", "")
    place = env.get("ROBLOX_PLACE_ID", "")
    missing = []
    if not key_set:
        missing.append("ROBLOX_API_KEY secret")
    if not re.fullmatch(r"[1-9][0-9]*", universe):
        missing.append("ROBLOX_UNIVERSE_ID repository variable")
    if not re.fullmatch(r"[1-9][0-9]*", place):
        missing.append("ROBLOX_PLACE_ID repository variable")
    if not allowed:
        state = "SKIPPED_UNTRUSTED_OR_NONDEFAULT_EVENT"
    elif missing:
        state = "BLOCKED_MISSING_CONFIG"
    else:
        state = "READY_TO_TEST_PRIVATE_PLACE"
    return {"state": state, "ready": state == "READY_TO_TEST_PRIVATE_PLACE", "missing": missing,
            "real_engine_executed": False, "note": "Preflight is not an engine test."}


def main():
    result = assess(os.environ)
    target = Path("reports/OPEN_CLOUD_PREFLIGHT.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as fh:
            fh.write(f"ready={'true' if result['ready'] else 'false'}\n")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write("### Roblox private-engine preflight\n")
            fh.write("- State: " + result["state"] + "\n")
            if result["missing"]:
                fh.write("- Missing: " + ", ".join(result["missing"]) + "\n")
            fh.write("- This step never accesses the Roblox API key or executes a real engine test.\n")
    print("ROBLOX_PRIVATE_ENGINE_PREFLIGHT=" + result["state"])
    if result["missing"]:
        print("Missing configuration: " + ", ".join(result["missing"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
