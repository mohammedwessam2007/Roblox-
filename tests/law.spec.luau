--!nocheck
return function(T)
	local Config = T.mod("Config")
	local LawSim = T.mod("LawSim")
	local GW = T.mod("GoalWitness")
	local L = Config.Law
	local DT = Config.TICK

	local function run(s, seconds)
		for _ = 1, math.floor(seconds / DT) do
			LawSim.step(s, DT)
			if s.phase ~= "Live" then
				break
			end
		end
	end
	local function live()
		local s = LawSim.new("t")
		local ok = LawSim.apply(s, { action = "Steal" }, { x = 0, z = -50 })
		T.ok(ok, "steal should succeed")
		return s
	end

	T.test("steal rejected when far from chicken", function()
		local s = LawSim.new("t")
		local ok, why = LawSim.apply(s, { action = "Steal" }, { x = 30, z = 40 })
		T.eq(ok, false); T.eq(why, "too_far"); T.eq(s.phase, "Ready")
	end)

	T.test("steal near chicken -> Live, lawball held", function()
		local s = live()
		T.eq(s.phase, "Live"); T.eq(s.lawball, "Held")
	end)

	T.test("skilled straight THROW scores exactly once via server witness", function()
		local s = live()
		T.ok(LawSim.apply(s, { action = "Throw", aimX = 0, aimZ = 1, power = 1 }, { x = 0, z = -50 }))
		run(s, 12)
		T.eq(s.phase, "Won", "phase")
		T.ok(s.certificate and s.certificate.scoredEventId == "t:r1:" .. Config.RULESET_VERSION, "id")
		T.eq(s.certificate.causeKind, "throw")
		-- further observation cannot mint a second certificate
		T.eq(GW.observe(s.witness, L.vault, L.vault.x, L.vault.z, s.now, s.now, "throw"), nil)
	end)

	T.test("a THROW aimed away genuinely misses: no score, miss certified", function()
		local s = live()
		LawSim.apply(s, { action = "Throw", aimX = -1, aimZ = 0, power = 1 }, { x = 0, z = -50 })
		run(s, 1.0)
		T.eq(s.stats.misses, 1); T.eq(s.stats.hits, 0); T.eq(s.certificate, nil); T.eq(s.phase, "Live")
	end)

	T.test("weak/off-angle throw can hit yet still fail to score (no hidden steering)", function()
		local s = live()
		LawSim.apply(s, { action = "Throw", aimX = 0.45, aimZ = 1, power = 0.35 }, { x = -4, z = -50 })
		run(s, 6)
		T.eq(s.stats.hits, 1, "hit")
		T.ok(s.phase ~= "Won", "must not auto-score")
	end)

	T.test("elastic recovery: once per real miss, inside window only, never scores", function()
		local s = live()
		LawSim.apply(s, { action = "Throw", aimX = -1, aimZ = 0, power = 1 }, { x = 0, z = -50 })
		run(s, 0.6)
		T.eq(s.lawball, "Returning")
		local cx, cz = s.chicken.x, s.chicken.z
		local ok, why = LawSim.apply(s, { action = "Recover" }, { x = 0, z = -50 })
		T.ok(ok, why); T.eq(s.lawball, "Held")
		T.eq(s.chicken.x, cx); T.eq(s.chicken.z, cz)
		local ok2, why2 = LawSim.apply(s, { action = "Recover" }, { x = 0, z = -50 })
		T.eq(ok2, false); T.eq(why2, "unknown_lawball")
		T.eq(s.certificate, nil)
	end)

	T.test("elastic recovery denied after window, without miss, and when flag off", function()
		local s = live()
		local ok0, w0 = LawSim.apply(s, { action = "Recover" }, { x = 0, z = -50 })
		T.eq(ok0, false); T.eq(w0, "miss_not_observed")
		LawSim.apply(s, { action = "Throw", aimX = -1, aimZ = 0, power = 1 }, { x = 0, z = -50 })
		run(s, 0.5)
		s.miss.at -= 3 -- age the miss past 2.5s window while ball still returning
		s.ballReturnAt = s.now + 5
		local ok, why = LawSim.apply(s, { action = "Recover" }, { x = 0, z = -50 })
		T.eq(ok, false); T.eq(why, "expired_window")
		local f = LawSim.new("f", 1, { elasticRecovery = false })
		LawSim.apply(f, { action = "Steal" }, { x = 0, z = -50 })
		local ok3, w3 = LawSim.apply(f, { action = "Recover" }, { x = 0, z = -50 })
		T.eq(ok3, false); T.eq(w3, "flag_off")
	end)

	T.test("cargo inside vault without causal action never scores", function()
		local s = live()
		s.lastCause = nil
		s.chicken.x, s.chicken.z = L.vault.x, L.vault.z
		run(s, 2)
		T.eq(s.certificate, nil)
		-- steal alone is not a causal redirect either
		local s2 = live()
		s2.chicken.x, s2.chicken.z = L.vault.x, L.vault.z
		run(s2, 2)
		T.eq(s2.certificate, nil)
	end)

	T.test("expired cause cannot score", function()
		local s = live()
		s.lastCause = { at = s.now - (L.causalWindowSeconds + 1), kind = "throw" }
		s.chicken.x, s.chicken.z = L.vault.x, L.vault.z
		for _ = 1, 20 do LawSim.step(s, DT) end
		T.eq(s.certificate, nil)
	end)

	T.test("witness: interrupted dwell resets; NaN rejected; idempotent", function()
		local w = GW.new("m", 1, "r", 3, 10)
		local v = L.vault
		T.eq(GW.observe(w, v, v.x, v.z, 1, 0.5, "throw"), nil)
		T.eq(GW.observe(w, v, v.x, v.z, 1, 0.5, "throw"), nil)
		T.eq(GW.observe(w, v, 999, v.z, 1, 0.5, "throw"), nil) -- leaves
		T.eq(w.dwell, 0)
		T.eq(GW.observe(w, v, 0 / 0, v.z, 1, 0.5, "throw"), nil)
		GW.observe(w, v, v.x, v.z, 1, 0.5, "throw"); GW.observe(w, v, v.x, v.z, 1, 0.5, "throw")
		local c = GW.observe(w, v, v.x, v.z, 1, 0.5, "throw")
		T.ok(c ~= nil, "certifies on 3rd consecutive tick")
		T.eq(GW.observe(w, v, v.x, v.z, 1, 0.5, "throw"), nil)
	end)

	T.test("PLANT: range, vault exclusion, and real attraction", function()
		local s = live()
		local ok, why = LawSim.apply(s, { action = "Plant", x = 0, z = 50 }, { x = 0, z = 30 })
		T.eq(ok, false); T.eq(why, "plant_in_vault_zone")
		ok, why = LawSim.apply(s, { action = "Plant", x = 0, z = 40 }, { x = 0, z = -50 })
		T.eq(ok, false); T.eq(why, "plant_too_far")
		ok = LawSim.apply(s, { action = "Plant", x = 15, z = -30 }, { x = 0, z = -50 })
		T.ok(ok, "plant ok")
		local d0 = math.abs(s.chicken.x - 15)
		run(s, 1.5)
		T.ok(math.abs(s.chicken.x - 15) < d0, "chicken pulled toward well")
		run(s, 4)
		T.eq(s.well, nil, "well expires")
	end)

	T.test("bot telegraphs before countering; a lawball stuns it", function()
		local s = live()
		s.chicken.x, s.chicken.z = s.bot.x, s.bot.z - 10
		local sawTelegraph = false
		for _ = 1, 60 do
			LawSim.step(s, DT)
			for _, e in s.events do
				if e.kind == "botTelegraph" then sawTelegraph = true end
				if e.kind == "botCounter" then T.ok(sawTelegraph, "telegraph precedes counter") end
			end
		end
		T.ok(sawTelegraph, "telegraph seen")
		local s2 = live()
		s2.bot.x, s2.bot.z = 30, -50
		LawSim.apply(s2, { action = "Throw", aimX = 1, aimZ = 0, power = 1 }, { x = 0, z = -50 })
		run(s2, 0.5)
		T.eq(s2.bot.state, "Stunned")
	end)

	T.test("timeout -> Lost; AGAIN only after outcome and bumps round", function()
		local s = live()
		local ok0, w0 = LawSim.apply(s, { action = "Again" }, { x = 0, z = 0 })
		T.eq(ok0, false); T.eq(w0, "round_active")
		-- keep acting so gravity never snaps back
		for i = 1, math.floor(91 / DT) do
			if i % 150 == 0 then s.lastCause = { at = s.now, kind = "plant" } end
			LawSim.step(s, DT)
			if s.phase ~= "Live" then break end
		end
		T.eq(s.phase, "Lost")
		T.ok(LawSim.apply(s, { action = "Again" }, { x = 0, z = 0 }))
		local n = LawSim.again(s)
		T.eq(n.round, 2); T.eq(n.phase, "Ready")
	end)

	T.test("gravity snaps back after abandonment (recoverable, not a loss)", function()
		local s = live()
		for _ = 1, math.floor(15 / DT) do LawSim.step(s, DT) end
		T.eq(s.phase, "Ready"); T.eq(s.chicken.z, L.chickenStart.z)
	end)

	T.test("fuzz: 20k random intents/steps keep sim finite and bounded", function()
		local rng = Random and Random.new(7) or nil
		local seed = 12345
		local function rnd()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local s = LawSim.new("fz")
		local acts = { "Steal", "Throw", "Plant", "Recover", "Again" }
		for i = 1, 20000 do
			local a = acts[math.floor(rnd() * #acts) + 1]
			local p = { x = rnd() * 100 - 50, z = rnd() * 140 - 70 }
			local ok, why = LawSim.apply(s, { action = a, aimX = rnd() * 2 - 1, aimZ = rnd() * 2 - 1, power = rnd(), x = rnd() * 100 - 50, z = rnd() * 140 - 70 }, p)
			if ok and why == "again" then s = LawSim.again(s) end
			LawSim.step(s, if i % 97 == 0 then 0 / 0 else DT)
			local c = s.chicken
			T.ok(c.x == c.x and c.z == c.z, "finite")
			T.ok(math.abs(c.x) <= L.halfX and c.z >= L.minZ and c.z <= L.maxZ, "bounded")
			T.ok(#s.events <= 64, "event cap")
			LawSim.drainEvents(s)
		end
	end)
end
