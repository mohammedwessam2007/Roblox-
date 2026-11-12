#!/usr/bin/env python3
"""Roblox Open Cloud automation (no Studio): build -> save PRIVATE place version -> run the
test suite inside a real Roblox server (Luau Execution) -> optionally upload original audio.

Never publishes: place versions are uploaded with versionType=Saved (not Published).
Endpoints follow Roblox Open Cloud docs (create.roblox.com/docs/cloud); first live run is the
verification. Credentials: ROBLOX_API_KEY env (or proxy-injected x-api-key header).

Usage:
  pipeline.py engine-test --universe U --place P [--dry-run]
  pipeline.py upload-audio --creator-user-id N [--dry-run]
"""
import argparse, json, os, subprocess, sys, time, urllib.request, uuid, pathlib

API = "https://apis.roblox.com"
ROOT = pathlib.Path(__file__).resolve().parents[2]

def req(method, url, body=None, ctype="application/json", dry=False):
    if dry:
        print(f"[dry-run] {method} {url} ({len(body) if body else 0} bytes)")
        return {}
    headers = {"Content-Type": ctype}
    key = os.environ.get("ROBLOX_API_KEY", "proxy-injected")
    headers["x-api-key"] = key
    r = urllib.request.Request(url, data=body, method=method, headers=headers)
    with urllib.request.urlopen(r, timeout=120) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else {}

def build(project, out):
    rojo = os.environ.get("ROJO", "rojo")
    subprocess.run([rojo, "build", str(ROOT / project), "-o", str(out)], check=True)
    return out.read_bytes()

def engine_test(a):
    place = build("test.project.json", ROOT / "build" / "StealRealityTest.rbxl")
    v = req("POST", f"{API}/universes/v1/{a.universe}/places/{a.place}/versions?versionType=Saved",
            place, "application/octet-stream", a.dry_run)
    version = v.get("versionNumber", 0)
    print("saved private place version:", version)
    script = (ROOT / "tools/opencloud/engine_task.luau").read_text()
    task = req("POST", f"{API}/cloud/v2/universes/{a.universe}/places/{a.place}/versions/{version}/luau-execution-session-tasks",
               json.dumps({"script": script}).encode(), dry=a.dry_run)
    if a.dry_run:
        return 0
    path = task["path"]
    for _ in range(120):
        time.sleep(3)
        t = req("GET", f"{API}/cloud/v2/{path}")
        state = t.get("state")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    print("task state:", state)
    print(json.dumps(t.get("output") or t.get("error"), indent=2))
    try:
        logs = req("GET", f"{API}/cloud/v2/{path}/logs")
        for chunk in logs.get("luauExecutionSessionTaskLogs", []):
            for m in chunk.get("messages", []):
                print("LOG:", m)
    except Exception as e:  # logs are best-effort
        print("logs unavailable:", e)
    report = ROOT / "reports" / "ENGINE_RUN.json"
    report.write_text(json.dumps(t, indent=2))
    ok = state == "COMPLETE" and "0 failed" in json.dumps(t.get("output"))
    return 0 if ok else 1

def upload_audio(a):
    ids = {}
    for wav in sorted((ROOT / "assets/audio").glob("*.wav")):
        meta = {"assetType": "Audio", "displayName": f"SR {wav.stem}"[:50],
                "description": "Original synthesized cue for Steal Reality (tools/synth_audio.py)",
                "creationContext": {"creator": {"userId": str(a.creator_user_id)}}}
        b = uuid.uuid4().hex
        body = (f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
                f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{wav.name}\"\r\n"
                f"Content-Type: audio/wav\r\n\r\n").encode() + wav.read_bytes() + f"\r\n--{b}--\r\n".encode()
        op = req("POST", f"{API}/assets/v1/assets", body, f"multipart/form-data; boundary={b}", a.dry_run)
        if a.dry_run:
            continue
        for _ in range(40):
            if op.get("done"):
                break
            time.sleep(3)
            op = req("GET", f"{API}/assets/v1/{op['path']}")
        aid = (op.get("response") or {}).get("assetId")
        ids[wav.stem] = aid
        print(wav.stem, "->", aid, "(moderation state per Creator Hub)")
    if not a.dry_run:
        (ROOT / "reports" / "AUDIO_ASSET_IDS.json").write_text(json.dumps(ids, indent=2))
    return 0

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("engine-test"); e.add_argument("--universe", required=True); e.add_argument("--place", required=True); e.add_argument("--dry-run", action="store_true")
    u = sub.add_parser("upload-audio"); u.add_argument("--creator-user-id", required=True); u.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    sys.exit(engine_test(a) if a.cmd == "engine-test" else upload_audio(a))

if __name__ == "__main__":
    main()
