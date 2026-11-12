--!nocheck
return function(T)
	local Config = T.mod("Config")
	local MatchCore = T.mod("MatchCore")
	local Protocol = T.mod("Protocol")
	local Naive = T.fixture("NaiveServer")
	local DT = Config.TICK
	local SP = Config.ARENA_SPACING

	T.test("RED reproduction: naive fixture accepts forged SCORE (CR-001 defect exists there)", function()
		local n = Naive.new()
		Naive.onRemote(n, 1, { action = "SCORE" })
		T.eq(n.scores[1], 1, "fixture is exploitable")
	end)

	T.test("RED reproduction: naive fixture leaks A's throw into B's cargo (CR-002 defect)", function()
		local n = Naive.new()
		local before = n.cargo.z
		Naive.onRemote(n, 1, { action = "Throw", power = 1 })
		T.ok(n.cargo.z ~= before, "B's (shared) cargo moved")
	end)

	local function core2()
		local log = {}
		local c = MatchCore.new(function(u, name, f) table.insert(log, { u = u, name = name, f = f }) end)
		local a = MatchCore.join(c, 101, 0)
		local b = MatchCore.join(c, 202, 0)
		return c, a, b, log
	end
	local function posA(m, x, z) return { x = m.origin.x + x, z = m.origin.z + z } end
	local LawSim = T.mod("LawSim")
	local seqs = {}
	local function skilledWin(c, m, t0)
		local P = { x = 0, z = -50 }
		seqs[m.userId] = math.max(seqs[m.userId] or 0, m.lastSeq)
		local now = t0
		T.helper("skilled")(LawSim, Config, function(i, pos)
			seqs[m.userId] += 1
			now += 1
			local raw = { seq = seqs[m.userId], action = i.action, aimX = i.aimX, aimZ = i.aimZ, power = i.power }
			local at = pos or P
			return MatchCore.intent(c, m.userId, raw, posA(m, at.x, at.z), now)
		end, function() MatchCore.step(c, DT, function() return nil end) end, function() return m end, P)
	end

	T.test("GREEN: forged SCORE / win / goal remotes are rejected and award nothing", function()
		local c, a = core2()
		for i, forged in { { seq = 1, action = "SCORE" }, { seq = 2, action = "Goal" }, { seq = 3, action = "Win" } } do
			local ok, why = MatchCore.intent(c, 101, forged, posA(a, 0, -50), i)
			T.eq(ok, false); T.eq(why, "unknown_action")
		end
		for _ = 1, 300 do MatchCore.step(c, DT, function() return nil end) end
		T.eq(c.awards[101], nil)
	end)

	T.test("GREEN: forged fields (score, userId, position, matchId) rejected", function()
		local c, a = core2()
		for i, extra in { "score", "userId", "position", "matchId", "win", "price" } do
			local raw = { seq = i, action = "Steal" }
			raw[extra] = 1
			local ok, why = MatchCore.intent(c, 101, raw, posA(a, 0, -50), i)
			T.eq(ok, false); T.ok(string.find(why, "unknown_field") == 1, why)
		end
		T.eq(a.law.phase, "Ready")
	end)

	T.test("schema: replay, NaN, inf, wrong types, metatables, oversize, missing fields", function()
		local bad = {
			{ { seq = 1, action = "Throw", aimX = 0 / 0, aimZ = 1, power = 1 }, "bad_value:aimX" },
			{ { seq = 1, action = "Throw", aimX = math.huge, aimZ = 1, power = 1 }, "bad_value:aimX" },
			{ { seq = 1, action = "Throw", aimX = 0, aimZ = 1 }, "missing_field:power" },
			{ { seq = 1, action = "Throw", aimX = 0, aimZ = 1, power = 9 }, "bad_value:power" },
			{ { seq = "1", action = "Steal" }, "bad_seq" },
			{ { seq = 1.5, action = "Steal" }, "bad_seq" },
			{ { seq = 0, action = "Steal" }, "bad_seq" },
			{ "Steal", "not_table" },
			{ setmetatable({ seq = 1, action = "Steal" }, {}), "metatable" },
			{ { seq = 1, action = "Steal", a = 1, b = 2, c = 3, d = 4, e = 5 }, "bad_keys" },
			{ { seq = 1, action = string.rep("x", 100) }, "bad_action" },
			{ { seq = 1, action = "ChooseMode", mode = "AdminMode" }, "bad_mode" },
			{ { [1] = "x", seq = 1, action = "Steal" }, "bad_keys" },
		}
		for _, case in bad do
			local out, why = Protocol.validate(case[1], 0)
			T.eq(out, nil); T.eq(why, case[2], "case " .. case[2])
		end
		local _, why = Protocol.validate({ seq = 5, action = "Steal" }, 5)
		T.eq(why, "replayed_seq")
	end)

	T.test("rate limit: burst of 30 intents -> only bucket capacity accepted", function()
		local c, a = core2()
		local accepted = 0
		for i = 1, 30 do
			local _, why = MatchCore.intent(c, 101, { seq = i, action = "Again" }, posA(a, 0, 0), 1.0)
			if why ~= "rate_limited" then accepted += 1 end
		end
		T.eq(accepted, Config.Security.bucketCapacity)
	end)

	T.test("CR-002: A's throw leaves B bit-identical to a control run without it", function()
		local function scenario(aThrows)
			local c, a, b = core2()
			MatchCore.intent(c, 101, { seq = 1, action = "Steal" }, posA(a, 0, -50), 0)
			MatchCore.intent(c, 202, { seq = 1, action = "Steal" }, posA(b, 0, -50), 0)
			if aThrows then
				skilledWin(c, a, 0)
			end
			return c, a, b
		end
		local c1, a1, b1 = scenario(true)
		local c0, _, b0 = scenario(false)
		-- run both worlds to the same simulated time for B before comparing
		while b0.law.now < b1.law.now - 1e-9 do MatchCore.step(c0, DT, function() return nil end) end
		T.ok(math.abs(b0.law.now - b1.law.now) < 1e-9, "same simulated time")
		T.eq(a1.law.phase, "Won", "A scored")
		for _, k in { "x", "z", "vx", "vz" } do T.eq(b1.law.chicken[k], b0.law.chicken[k], "B chicken " .. k) end
		T.eq(b1.law.bot.x, b0.law.bot.x); T.eq(b1.law.bot.state, b0.law.bot.state)
		T.eq(b1.law.phase, b0.law.phase); T.eq(b1.law.stats.hits, 0)
		T.eq(c1.awards[202], nil); T.eq(c1.awards[101], 1)
	end)

	T.test("CR-002: standing in another player's arena cannot steal their chicken", function()
		local c, a, b = core2()
		-- player A physically walks into B's arena coordinates
		local ok, why = MatchCore.intent(c, 101, { seq = 1, action = "Steal" }, posA(b, 0, -50), 0)
		T.eq(ok, false); T.eq(why, "too_far")
		T.eq(b.law.phase, "Ready")
	end)

	T.test("award ledger: certified goal awarded exactly once across 1000 extra ticks", function()
		local c, a, _, log = core2()
		MatchCore.intent(c, 101, { seq = 1, action = "Steal" }, posA(a, 0, -50), 0)
		skilledWin(c, a, 0)
		for _ = 1, 1000 do MatchCore.step(c, DT, function() return nil end) end
		T.eq(c.awards[101], 1)
		local n = 0
		for _, e in log do if e.name == "goal_server_certified" then n += 1 end end
		T.eq(n, 1)
	end)

	T.test("AGAIN after win starts a new round with a distinct scoredEventId", function()
		local c, a = core2()
		local p = posA(a, 0, -50)
		MatchCore.intent(c, 101, { seq = 1, action = "Steal" }, p, 0)
		skilledWin(c, a, 0)
		local id1 = a.law.certificate.scoredEventId
		T.ok(MatchCore.intent(c, 101, { seq = 50, action = "Again" }, p, 100))
		MatchCore.intent(c, 101, { seq = 51, action = "Steal" }, p, 101)
		skilledWin(c, a, 102)
		T.ok(a.law.certificate.scoredEventId ~= id1, "distinct id")
		T.eq(c.awards[101], 2)
	end)

	T.test("slots are distinct, freed on leave and reused; no state carries over", function()
		local c, a, b = core2()
		T.ok(a.origin.x ~= b.origin.x)
		T.eq(math.abs(a.origin.x - b.origin.x), SP)
		MatchCore.leave(c, 101)
		local d = MatchCore.join(c, 303, 0)
		T.eq(d.slot, a.slot); T.eq(d.law.phase, "Ready"); T.eq(d.lastSeq, 0)
	end)

	T.test("ChooseMode switches to Grid Heist only between rounds", function()
		local c, a = core2()
		T.ok(MatchCore.intent(c, 101, { seq = 1, action = "ChooseMode", mode = "GridHeist" }, posA(a, 0, 0), 0))
		T.ok(a.heist ~= nil and a.law == nil)
		MatchCore.intent(c, 101, { seq = 2, action = "ChooseMode", mode = "LawSport" }, posA(a, 0, 0), 1)
		MatchCore.intent(c, 101, { seq = 3, action = "Steal" }, posA(a, 0, -50), 2)
		local ok, why = MatchCore.intent(c, 101, { seq = 4, action = "ChooseMode", mode = "GridHeist" }, posA(a, 0, -50), 3)
		T.eq(ok, false); T.eq(why, "round_active")
	end)

	T.test("REGRESSION (emulated runtime): prompt STEAL does not burn client seq; next THROW accepted", function()
		local c, a = core2()
		T.ok(MatchCore.serverIntent(c, 101, "Steal", posA(a, 0, -50), 0))
		local ok, why = MatchCore.intent(c, 101, { seq = 1, action = "Throw", aimX = 0, aimZ = 1, power = 1 }, posA(a, 0, -50), 0.1)
		T.ok(ok, why)
		local ok2, why2 = MatchCore.serverIntent(c, 101, "Throw", posA(a, 0, -50), 0.2)
		T.eq(ok2, false); T.eq(why2, "not_server_trigger")
	end)

	T.test("REGRESSION (emulated runtime): server respawn resets heist anti-teleport track", function()
		local c, a = core2()
		MatchCore.intent(c, 101, { seq = 1, action = "ChooseMode", mode = "GridHeist" }, posA(a, 0, 0), 0)
		MatchCore.step(c, DT, function() return posA(a, -58, -58) end)
		-- server pivots the character far away (respawn); without reset every sample is rejected
		MatchCore.resetTrack(c, 101)
		MatchCore.step(c, DT, function() return posA(a, -56, -36) end)
		T.eq(a.heist.player.z, -36)
		T.ok(MatchCore.serverIntent(c, 101, "CutPower", posA(a, -56, -36), 1))
	end)
end
