--!nocheck
-- A scripted "skilled player" line used by tests: stun the bot with the lawball, wait for the
-- ball to return, then throw the chicken straight at the Vault. Pure simulation helper.
return function(LawSim, Config, apply, step, state, player)
	local function aimAt(px, pz, tx, tz)
		local dx, dz = tx - px, tz - pz
		local d = math.sqrt(dx * dx + dz * dz)
		return dx / d, dz / d
	end
	local s = state()
	-- sidestep so the chicken does not block the line to the bot
	local side = { x = player.x - 16, z = player.z }
	local ax, az = aimAt(side.x, side.z, s.law.bot.x, s.law.bot.z)
	assert(apply({ action = "Throw", aimX = ax, aimZ = az, power = 1 }, side))
	for _ = 1, math.floor(3 / Config.TICK) do
		step()
		if state().law.lawball == "Held" then break end
	end
	s = state()
	assert(s.law.bot.state == "Stunned" or s.law.stats.botStuns >= 1, "bot was not stunned")
	local cx, cz = s.law.chicken.x, s.law.chicken.z
	local tx, tz = aimAt(player.x, player.z, cx, cz)
	assert(apply({ action = "Throw", aimX = tx, aimZ = tz, power = 1 }, player))
	for _ = 1, math.floor(12 / Config.TICK) do
		step()
		if state().law.phase ~= "Live" then break end
	end
end
