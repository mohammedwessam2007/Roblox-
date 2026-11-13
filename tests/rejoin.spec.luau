--!nocheck
-- Regression: a reconnect cannot reuse previously certified score identifiers.
-- Executed by Lune CI, with no Studio or Roblox credentials.
return function(T)
    local MatchCore = T.mod("MatchCore")
    local LawSim = T.mod("LawSim")
    local Config = T.mod("Config")

    local function position(m, p)
        return { x = m.origin.x + p.x, z = m.origin.z + p.z }
    end

    local function certifiedWin(core, m, now)
        local player = { x = 0, z = -50 }
        local ok, reason = MatchCore.serverIntent(core, m.userId, "Steal", position(m, player), now)
        T.ok(ok, "steal must start legitimate round: " .. tostring(reason))
        local seq = 0
        T.helper("skilled")(
            LawSim,
            Config,
            function(intent, from)
                seq += 1
                now += 1
                local raw = {seq = seq, action = intent.action, aimX = intent.aimX,
                             aimZ = intent.aimZ, power = intent.power}
                local accepted, why = MatchCore.intent(core, m.userId, raw, position(m, from or player), now)
                T.ok(accepted, "valid action rejected: " .. tostring(why))
                return accepted, why
            end,
            function() MatchCore.step(core, Config.TICK, function() return nil end) end,
            function() return m end,
            player
        )
        T.eq(m.law.phase, "Won", "skilled legitimate player must win")
        T.ok(m.law.certificate, "server witness must certify goal")
        return m.law.certificate.scoredEventId
    end

    T.test("RECONNECT: same player gets fresh match identity after leaving", function()
        local core = MatchCore.new()
        local first = MatchCore.join(core, 707, 0)
        local oldId = first.law.matchId
        MatchCore.leave(core, 707)
        local second = MatchCore.join(core, 707, 10)
        T.ok(second.law.matchId ~= oldId, "reused matchId after reconnect: " .. oldId)
        T.eq(second.lastSeq, 0, "new client gets fresh sequence window")
    end)

    T.test("RECONNECT: two real goals count separately across disconnect in one server", function()
        local core = MatchCore.new()
        local first = MatchCore.join(core, 708, 0)
        local id1 = certifiedWin(core, first, 0)
        T.eq(core.awards[708], 1, "first server-certified goal")
        MatchCore.leave(core, 708)
        local second = MatchCore.join(core, 708, 100)
        local id2 = certifiedWin(core, second, 100)
        T.ok(id1 ~= id2, "new goal reused prior score ID")
        T.eq(core.awards[708], 2, "second goal swallowed by old certificate ledger")
    end)

    T.test("RECONNECT: mode switch then disconnect does not recycle match identities", function()
        local core = MatchCore.new()
        local m = MatchCore.join(core, 709, 0)
        local p = position(m, { x = 0, z = 0 })
        local used = { [m.law.matchId] = true }
        T.ok(MatchCore.intent(core, 709, { seq = 1, action = "ChooseMode", mode = "GridHeist" }, p, 1))
        used[m.heist.matchId] = true
        T.ok(MatchCore.intent(core, 709, { seq = 2, action = "ChooseMode", mode = "LawSport" }, p, 2))
        used[m.law.matchId] = true
        MatchCore.leave(core, 709)
        local nextMatch = MatchCore.join(core, 709, 10)
        T.ok(not used[nextMatch.law.matchId], "session recycled a mode-switch ID")
    end)
end
