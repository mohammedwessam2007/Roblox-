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
				MatchCore.intent(c, 101, { seq = 2, action = "Throw", aimX = 0, aimZ = 1, power = 1 }, posA(a, 0, -50), 0.1)
			end
			for _ = 1, 12 / DT do MatchCore.step(c, DT, function() return nil end) end
			return c, a, b
		end
		local c1, a1, b1 = scenario(true)
		local _, _, b0 = scenario(false)
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
		MatchCore.intent(c, 101, { seq = 2, action = "Throw", aimX = 0, aimZ = 1, power = 1 }, posA(a, 0, -50), 0.1)
		for _ = 1, 1400 do MatchCore.step(c, DT, function() return nil end) end
		T.eq(c.awards[101], 1)
		local n = 0
		for _, e in log do if e.name == "goal_server_certified" then n += 1 end end
		T.eq(n, 1)
	end)

	T.test("AGAIN after win starts a new round with a distinct scoredEventId", function()
		local c, a = core2()
		local p = posA(a, 0, -50)
		MatchCore.intent(c, 101, { seq = 1, action = "Steal" }, p, 0)
		MatchCore.intent(c, 101, { seq = 2, action = "Throw", aimX = 0, aimZ = 1, power = 1 }, p, 0.2)
		for _ = 1, 400 do MatchCore.step(c, DT, function() return nil end) end
		local id1 = a.law.certificate.scoredEventId
		T.ok(MatchCore.intent(c, 101, { seq = 3, action = "Again" }, p, 2))
		MatchCore.intent(c, 101, { seq = 4, action = "Steal" }, p, 3)
		MatchCore.intent(c, 101, { seq = 5, action = "Throw", aimX = 0, aimZ = 1, power = 1 }, p, 4)
		for _ = 1, 400 do MatchCore.step(c, DT, function() return nil end) end
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
end
