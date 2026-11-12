--!nocheck
-- Opens the Rojo-built place file and asserts the expected script/module tree exists.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local path = process.args[1] or "build/StealReality.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local expect = {
	{ "ReplicatedStorage", "Shared", "ModuleScript", { "Config", "LawSim", "HeistSim", "GoalWitness", "MatchCore", "Protocol", "ElasticRecovery", "AdaptiveQuality" } },
	{ "ServerScriptService", "Server", "Script", { "WorldBuilder" } },
}
local bad = 0
for _, e in expect do
	local svc = game:GetService(e[1])
	local folder = svc:FindFirstChild(e[2])
	print(string.format("%s.%s -> %s", e[1], e[2], folder and folder.ClassName or "MISSING"))
	if not folder then bad += 1 continue end
	for _, n in e[4] do
		local c = folder:FindFirstChild(n)
		print(string.format("  %-16s %s %d bytes", n, c and c.ClassName or "MISSING", c and #c.Source or 0))
		if not c then bad += 1 end
	end
end
local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local client = sps and sps:FindFirstChild("Client")
print("StarterPlayerScripts.Client -> " .. (client and client.ClassName or "MISSING") .. (client and (" " .. #client.Source .. " bytes") or ""))
if not client or client.ClassName ~= "LocalScript" then bad += 1 end
print(bad == 0 and "PLACE_STRUCTURE_OK" or ("PLACE_STRUCTURE_FAIL " .. bad))
process.exit(bad == 0 and 0 or 1)
