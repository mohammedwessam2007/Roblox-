-- STUDIO WRAPPER for tools/opencloud/engine_task.luau (generated: header + engine_task minus its final `return`).
-- run-in-roblox and the Studio Command Bar need PRINTED output, not a return value; engine_task already prints
-- "ENGINE_TESTS: N passed, M failed" and every FAIL line. Do not edit below the marker: tools/verify.sh checks
-- that it matches engine_task.luau. Regenerate with:
--   { sed -n '1,/^-- BEGIN engine_task/p' tools/studio/studio_engine_tests.luau; sed '$d' tools/opencloud/engine_task.luau; } > tmp && mv tmp tools/studio/studio_engine_tests.luau
-- Use it in a RUNNING server (run-in-roblox, or Studio Test > Run then the server Command Bar). In plain edit mode
-- the Server script does not run, so "ENGINE: server script booted and created remotes" fails after 10 s by design.
-- BEGIN engine_task
-- Runs INSIDE a real Roblox game server via Open Cloud Luau Execution (no Studio needed).
-- Executes the same spec files as the Lune runner, plus real-engine checks of WorldBuilder.
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Tests = SS:WaitForChild("Tests")
local Shared = RS:WaitForChild("Shared")
local out, passed, failed = {}, 0, 0
local T = {}
function T.test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; table.insert(out, "FAIL " .. name .. " :: " .. tostring(err)) end
end
function T.eq(a, b, msg) if a ~= b then error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2) end end
function T.ok(v, msg) if not v then error(msg or "expected truthy", 2) end end
function T.mod(n) return require(Shared:WaitForChild(n)) end
function T.helper(n) return require(Tests:WaitForChild(n)) end
function T.fixture(n) return require(Tests:WaitForChild("fixtures"):WaitForChild(n)) end
for _, name in { "adaptive.spec", "heist.spec", "law.spec", "security.spec" } do
	require(Tests:WaitForChild(name))(T)
end
-- real-engine checks: build an arena with real Instances and verify rule geometry matches Config
local Config = require(Shared.Config)
local WB = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("WorldBuilder"))
T.test("ENGINE: Law arena builds; Vault volume matches server goal box", function()
	local a = WB.buildLawArena(Vector3.new(90000, 0, 0), "EngineCheck")
	local v = a.folder:FindFirstChild("VaultVolume")
	T.ok(v, "vault")
	T.eq(v.Size.X, Config.Law.vault.hx * 2); T.eq(v.Size.Z, Config.Law.vault.hz * 2)
	T.ok(a.chicken.PrimaryPart and a.chicken.PrimaryPart.Anchored, "chicken root anchored")
	a.chicken:PivotTo(CFrame.new(90000, 20, 10))
	T.ok((a.chicken.PrimaryPart.Position - Vector3.new(90000, 20, 10)).Magnitude < 1e-3, "PivotTo moves welded chicken")
	a.folder:Destroy()
end)
T.test("ENGINE: Heist city builds with prompts and essential vision disc", function()
	local a = WB.buildHeistArena(Vector3.new(-90000, 0, 0), "EngineCheckH")
	T.ok(a.vision:GetAttribute("Essential") == true)
	local n = 0
	for _ in a.prompts do n += 1 end
	T.eq(n, 4)
	a.folder:Destroy()
end)
T.test("ENGINE: server script booted and created remotes", function()
	T.ok(RS:WaitForChild("SR_Intent", 10) and RS:WaitForChild("SR_State", 10), "remotes")
end)
local summary = string.format("ENGINE_TESTS: %d passed, %d failed", passed, failed)
print(summary)
for _, l in out do print(l) end
