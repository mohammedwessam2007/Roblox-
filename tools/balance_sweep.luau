--!nocheck
-- Bot-free single-throw skill sweep (zero-CCU benchmark). Measures how often ONE throw from a
-- given spot/angle/power scores, with the bot active. A healthy skill curve: precise shots
-- score, sloppy ones don't; no region of "always scores". Pure simulation, not player data.
local Loader = require("../tests/loader")
local Config = Loader.require("src/shared/Config.luau")
local LawSim = Loader.require("src/shared/LawSim.luau")
local DT = Config.TICK
local total, scored = 0, 0
local byErr = {}
for px = -12, 12, 4 do
	for pz = -54, -46, 4 do
		for angDeg = -30, 30, 2 do
			for _, power in { 0.35, 0.55, 0.75, 1.0 } do
				local s = LawSim.new("sweep")
				if LawSim.apply(s, { action = "Steal" }, { x = px, z = pz }) then
					local ideal = math.deg(math.atan2(Config.Law.vault.x - s.chicken.x, Config.Law.vault.z - s.chicken.z))
					local a = math.rad(angDeg)
					LawSim.apply(s, { action = "Throw", aimX = math.sin(a), aimZ = math.cos(a), power = power }, { x = px, z = pz })
					for _ = 1, math.floor(14 / DT) do
						LawSim.step(s, DT)
						if s.phase ~= "Live" then break end
					end
					total += 1
					local won = s.phase == "Won"
					if won then scored += 1 end
					local b = math.floor(math.abs(angDeg - ideal) / 5) * 5
					local key = b .. "|" .. power
					byErr[key] = byErr[key] or { 0, 0 }
					byErr[key][1] += 1
					if won then byErr[key][2] += 1 end
				end
			end
		end
	end
end
print(string.format("single-throw shots simulated=%d scored=%d (%.1f%%)", total, scored, 100 * scored / total))
print("aim_error_deg_bucket,power,shots,scored,rate")
local keys = {}
for k in byErr do table.insert(keys, k) end
table.sort(keys, function(a, b)
	local ea, pa = string.match(a, "(%d+)|(.+)"); local eb, pb = string.match(b, "(%d+)|(.+)")
	if tonumber(ea) ~= tonumber(eb) then return tonumber(ea) < tonumber(eb) end
	return tonumber(pa) < tonumber(pb)
end)
for _, k in keys do
	local e, p = string.match(k, "(%d+)|(.+)")
	if tonumber(e) <= 30 then
		local v = byErr[k]
		print(string.format("%s-%d,%s,%d,%d,%.2f", e, tonumber(e) + 5, p, v[1], v[2], v[2] / v[1]))
	end
end
