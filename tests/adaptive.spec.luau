--!nocheck
return function(T)
	local AQ = T.mod("AdaptiveQuality")
	local Config = T.mod("Config")
	T.test("auto tier drops only after sustained overload, with cooldown hysteresis", function()
		local c = AQ.new(3, true, 0)
		local t = 6
		local switches = 0
		for _ = 1, 4000 do
			t += 0.016
			local reason
			c, reason = AQ.sample(c, 50, 0.016, t, 5)
			if reason == "reduce_optional_fx" then switches += 1 end
		end
		T.eq(c.tier, 1, "reaches Survival under sustained load")
		T.ok(switches == 2, "stepwise, no oscillation: " .. switches)
	end)
	T.test("respects user cap, manual override, invalid samples", function()
		local c = AQ.new(5, true, 0)
		local r
		c, r = AQ.sample(c, 16, 0.016, 10, 2)
		T.eq(c.tier, 2)
		local m = AQ.setManual(c, 4)
		local m2, r2 = AQ.sample(m, 100, 1, 100, 5)
		T.eq(m2.tier, 4); T.eq(r2, "manual_override")
		local _, r3 = AQ.sample(AQ.new(3), 0 / 0, 0.1, 10, 5)
		T.eq(r3, "invalid_sample")
	end)
	T.test("fairness: no profile field touches gameplay constants", function()
		for _, p in AQ.PROFILES do
			for k in p do
				T.ok(Config.Law[k] == nil and Config.Heist[k] == nil, "profile key collides: " .. k)
			end
		end
	end)
end
