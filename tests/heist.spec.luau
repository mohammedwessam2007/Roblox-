--!nocheck
return function(T)
	local Config = T.mod("Config")
	local HeistSim = T.mod("HeistSim")
	local H = Config.Heist
	local DT = Config.TICK

	local function at(spot) return { x = spot.x, z = spot.z } end

	T.test("CUT POWER requires proximity; blackout shrinks drone vision", function()
		local s = HeistSim.new("h")
		local ok, why = HeistSim.apply(s, { action = "CutPower" }, { x = 50, z = 50 })
		T.eq(ok, false); T.eq(why, "too_far")
		T.eq(HeistSim.visionRadius(s), H.visionLit)
		T.ok(HeistSim.apply(s, { action = "CutPower" }, at(H.substation)))
		T.eq(HeistSim.visionRadius(s), H.visionDark); T.eq(s.phase, "Live")
	end)

	T.test("choice: REROUTE vs OPEN ESCAPE are exclusive and need power cut", function()
		local s = HeistSim.new("h")
		local ok, why = HeistSim.apply(s, { action = "Reroute" }, at(H.rerouteConsole))
		T.eq(ok, false); T.eq(why, "power_on")
		HeistSim.apply(s, { action = "CutPower" }, at(H.substation))
		s.player = at(H.rerouteConsole)
		T.ok(HeistSim.apply(s, { action = "Reroute" }, at(H.rerouteConsole)))
		T.eq(s.drone.route, "B")
		s.player = at(H.escapeGate)
		local ok2, why2 = HeistSim.apply(s, { action = "OpenEscape" }, at(H.escapeGate))
		T.eq(ok2, false); T.eq(why2, "choice_locked")
	end)

	T.test("buildings block drone line of sight", function()
		T.ok(HeistSim._segBlocked(-30, -50, -30, -10), "through block")
		T.ok(not HeistSim._segBlocked(0, -50, 0, 50), "open street")
	end)

	T.test("anti-teleport: impossible displacement rejected, track kept", function()
		local s = HeistSim.new("h")
		HeistSim.step(s, DT, at(H.playerStart))
		HeistSim.step(s, DT, at(H.exitZone))
		T.eq(s.teleportFlags, 1)
		T.eq(s.player.x, H.playerStart.x)
	end)

	T.test("teleporting to the exit with the core does not win", function()
		local s = HeistSim.new("h")
		HeistSim.step(s, DT, at(H.coreSpot))
		T.ok(HeistSim.apply(s, { action = "GrabCore" }, at(H.coreSpot)))
		HeistSim.step(s, DT, at(H.exitZone))
		T.ok(s.phase ~= "Won")
	end)

	T.test("standing in drone view gets caught; escape without core impossible", function()
		local s = HeistSim.new("h")
		s.phase, s.startedAt = "Live", 0
		s.drone.x, s.drone.z, s.drone.fx, s.drone.fz = 0, -20, 0, 1
		s.drone.route = "Hold"
		local caught = false
		for _ = 1, 60 do
			s.drone.x, s.drone.z = 0, -20
			HeistSim.step(s, DT, { x = 0, z = -5 })
			if s.phase == "Lost" then caught = true break end
		end
		T.ok(caught, "caught")
		local s2 = HeistSim.new("h2")
		s2.player = at(H.exitZone); s2.phase = "Live"; s2.startedAt = 0
		s2.drone.x, s2.drone.z = -60, -60
		HeistSim.step(s2, DT, at(H.exitZone))
		T.ok(s2.phase ~= "Won")
	end)

	T.test("walking (speed-bounded) to exit with core wins exactly once", function()
		local s = HeistSim.new("h")
		s.player = { x = 60, z = 40 }
		s.carrying = true; s.phase = "Live"; s.startedAt = 0
		s.drone.x, s.drone.z = -60, -60
		local p = { x = 60, z = 40 }
		for _ = 1, 120 do
			p.z = math.min(60, p.z + 20 * DT)
			HeistSim.step(s, DT, { x = p.x, z = p.z })
			if s.phase == "Won" then break end
		end
		T.eq(s.phase, "Won"); T.ok(s.scoredEventId ~= nil)
		local id = s.scoredEventId
		HeistSim.step(s, DT, p)
		T.eq(s.scoredEventId, id)
	end)
end
