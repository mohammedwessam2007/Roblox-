--!strict
-- LAW SPORT authoritative simulation (pure Luau, no Roblox APIs).
-- Runs identically on the Roblox server and in the Lune test runner.
-- Loop: STEAL -> CHOOSE (THROW | PLANT) -> REDIRECT -> COUNTER (bot) -> SCORE/FAIL -> RECOVER/RETRY.
-- No hidden steering: the cargo only moves from player impulses, player wells, bot counters,
-- drag and wall/pylon bounces. It can and does miss.

local Config = require(script.Parent.Config)
local GoalWitness = require(script.Parent.GoalWitness)
local ElasticRecovery = require(script.Parent.ElasticRecovery)

local L = Config.Law
local LawSim = {}

export type Vec = { x: number, z: number }
export type Event = { kind: string, x: number?, z: number?, info: string? }

export type State = {
	matchId: string,
	ruleset: string,
	round: number,
	phase: string, -- "Ready" | "Live" | "Won" | "Lost"
	now: number,
	startedAt: number?,
	endedAt: number?,
	chicken: { x: number, z: number, vx: number, vz: number },
	lawball: string, -- "None" | "Held" | "Flying" | "Planted" | "Returning"
	ball: { x: number, z: number, dx: number, dz: number, dist: number, power: number }?,
	ballReturnAt: number,
	well: { x: number, z: number, expiresAt: number }?,
	miss: { at: number, used: boolean, ballId: number }?,
	ballId: number,
	nextRecoveryAt: number,
	bot: { x: number, z: number, state: string, untilT: number },
	lastCause: { at: number, kind: string }?,
	witness: GoalWitness.Witness,
	certificate: GoalWitness.Certificate?,
	stats: { throws: number, hits: number, plants: number, misses: number, recoveries: number, bounces: number, botStuns: number, botCounters: number },
	events: { Event },
	flags: { elasticRecovery: boolean },
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function emit(s: State, kind: string, x: number?, z: number?, info: string?)
	if #s.events < 64 then
		table.insert(s.events, { kind = kind, x = x, z = z, info = info })
	end
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function resetChicken(s: State)
	s.chicken = { x = L.chickenStart.x, z = L.chickenStart.z, vx = 0, vz = 0 }
end

function LawSim.new(matchId: string, round: number?, flags: { elasticRecovery: boolean }?): State
	local r = round or 1
	local s: State = {
		matchId = matchId,
		ruleset = Config.RULESET_VERSION,
		round = r,
		phase = "Ready",
		now = 0,
		startedAt = nil,
		endedAt = nil,
		chicken = { x = 0, z = 0, vx = 0, vz = 0 },
		lawball = "None",
		ball = nil,
		ballReturnAt = 0,
		well = nil,
		miss = nil,
		ballId = 0,
		nextRecoveryAt = 0,
		bot = { x = L.botStart.x, z = L.botStart.z, state = "Idle", untilT = 0 },
		lastCause = nil,
		witness = GoalWitness.new(matchId, r, Config.RULESET_VERSION, L.dwellTicks, L.causalWindowSeconds),
		certificate = nil,
		stats = { throws = 0, hits = 0, plants = 0, misses = 0, recoveries = 0, bounces = 0, botStuns = 0, botCounters = 0 },
		events = {},
		flags = flags or { elasticRecovery = Config.Flags.ElasticRecovery },
	}
	resetChicken(s)
	return s
end

-- Fresh round, same match. Round number increments so the witness id can never collide.
function LawSim.again(s: State): State
	local nextState = LawSim.new(s.matchId, s.round + 1, s.flags)
	nextState.now = s.now
	emit(nextState, "again")
	return nextState
end

-- ===================== intents (already schema-validated by Protocol) =====================

export type Intent = { action: string, aimX: number?, aimZ: number?, power: number?, x: number?, z: number? }

function LawSim.apply(s: State, intent: Intent, player: Vec): (boolean, string)
	if not (finite(player.x) and finite(player.z)) then
		return false, "bad_player_position"
	end
	local a = intent.action
	if a == "Again" then
		if s.phase == "Won" or s.phase == "Lost" then
			return true, "again"
		end
		return false, "round_active"
	end
	if s.phase == "Won" or s.phase == "Lost" then
		return false, "round_over"
	end

	if a == "Steal" then
		if s.phase ~= "Ready" then
			return false, "not_ready"
		end
		if dist(player.x, player.z, s.chicken.x, s.chicken.z) > L.stealRange then
			return false, "too_far"
		end
		s.phase = "Live"
		s.startedAt = s.startedAt or s.now
		s.lawball = "Held"
		s.ballId += 1
		s.lastCause = { at = s.now, kind = "steal" }
		s.chicken.vz += 4 -- tiny lift-off wobble, below any scoring relevance
		emit(s, "steal", s.chicken.x, s.chicken.z)
		return true, "stolen"
	end

	if s.phase ~= "Live" then
		return false, "not_live"
	end

	if a == "Throw" then
		if s.lawball ~= "Held" then
			return false, "no_lawball"
		end
		local ax, az, p = intent.aimX :: number, intent.aimZ :: number, intent.power :: number
		local len = math.sqrt(ax * ax + az * az)
		if len < 1e-3 then
			return false, "bad_aim"
		end
		local power = math.clamp(p, L.throwMinPower, 1)
		local ox = math.clamp(player.x, -L.halfX, L.halfX)
		local oz = math.clamp(player.z, L.minZ, L.maxZ)
		s.lawball = "Flying"
		s.ball = { x = ox, z = oz, dx = ax / len, dz = az / len, dist = 0, power = power }
		s.stats.throws += 1
		emit(s, "throw", ox, oz)
		return true, "thrown"
	end

	if a == "Plant" then
		if s.lawball ~= "Held" then
			return false, "no_lawball"
		end
		local x, z = intent.x :: number, intent.z :: number
		if dist(player.x, player.z, x, z) > L.plantRange then
			return false, "plant_too_far"
		end
		if math.abs(x) > L.halfX or z < L.minZ or z > L.maxZ then
			return false, "plant_out_of_arena"
		end
		local v = L.vault
		if math.abs(x - v.x) <= v.hx + L.wellVaultExclusion and math.abs(z - v.z) <= v.hz + L.wellVaultExclusion then
			return false, "plant_in_vault_zone"
		end
		s.lawball = "Planted"
		s.well = { x = x, z = z, expiresAt = s.now + L.wellSeconds }
		s.stats.plants += 1
		emit(s, "plant", x, z)
		return true, "planted"
	end

	if a == "Recover" then
		if not s.flags.elasticRecovery then
			return false, "flag_off"
		end
		local m = s.miss
		local decision = ElasticRecovery.evaluate({
			matchActive = s.phase == "Live",
			missCertifiedByServer = m ~= nil,
			missAtSeconds = if m then m.at else -math.huge,
			nowSeconds = s.now,
			recoveryAlreadyUsed = if m then m.used else false,
			nextRecoveryAllowedAt = s.nextRecoveryAt,
			lawballMatches = m ~= nil and m.ballId == s.ballId,
			lawballReturning = s.lawball == "Returning",
		})
		if not decision.allowed then
			return false, decision.reason
		end
		assert(m ~= nil)
		m.used = true
		s.lawball = "Held"
		s.nextRecoveryAt = s.now + L.recoveryCooldownSeconds
		s.stats.recoveries += 1
		emit(s, "recover", player.x, player.z)
		-- grantScore/nudgeCargo are structurally false in the policy; nothing touches cargo here.
		return true, "recovered"
	end

	return false, "unknown_action"
end

-- ===================== physics step =====================

local function bounceWalls(s: State)
	local c = s.chicken
	local r = L.chickenRadius
	local bounced = false
	if c.x < -L.halfX + r then
		c.x = -L.halfX + r
		c.vx = math.abs(c.vx) * L.wallRestitution
		bounced = true
	elseif c.x > L.halfX - r then
		c.x = L.halfX - r
		c.vx = -math.abs(c.vx) * L.wallRestitution
		bounced = true
	end
	if c.z < L.minZ + r then
		c.z = L.minZ + r
		c.vz = math.abs(c.vz) * L.wallRestitution
		bounced = true
	elseif c.z > L.maxZ - r then
		c.z = L.maxZ - r
		c.vz = -math.abs(c.vz) * L.wallRestitution
		bounced = true
	end
	for _, p in L.pylons do
		local dx, dz = c.x - p.x, c.z - p.z
		local d = math.sqrt(dx * dx + dz * dz)
		local minD = r + p.r
		if d < minD and d > 1e-6 then
			local nx, nz = dx / d, dz / d
			c.x, c.z = p.x + nx * minD, p.z + nz * minD
			local vn = c.vx * nx + c.vz * nz
			if vn < 0 then
				c.vx -= (1 + L.pylonRestitution) * vn * nx
				c.vz -= (1 + L.pylonRestitution) * vn * nz
				bounced = true
			end
		end
	end
	if bounced then
		s.stats.bounces += 1
		emit(s, "bounce", c.x, c.z)
	end
end

local function certifyMiss(s: State, x: number, z: number, why: string)
	s.lawball = "Returning"
	s.ballReturnAt = s.now + L.lawballReturnSeconds
	s.ball = nil
	s.miss = { at = s.now, used = false, ballId = s.ballId }
	s.stats.misses += 1
	emit(s, "miss", x, z, why)
end

local function stepBall(s: State, dt: number)
	local b = s.ball
	if b == nil then
		return
	end
	local step = L.lawballSpeed * dt
	-- sub-step so a fast ball cannot tunnel through the chicken or bot
	local n = math.max(1, math.ceil(step / 2))
	local ds = step / n
	for _ = 1, n do
		b.x += b.dx * ds
		b.z += b.dz * ds
		b.dist += ds
		local c = s.chicken
		if dist(b.x, b.z, c.x, c.z) <= L.chickenRadius + L.lawballRadius then
			local imp = L.throwImpulse * b.power
			c.vx += b.dx * imp
			c.vz += b.dz * imp
			s.lastCause = { at = s.now, kind = "throw" }
			s.stats.hits += 1
			s.lawball = "Returning"
			s.ballReturnAt = s.now + L.lawballReturnSeconds
			s.ball = nil
			emit(s, "hit", c.x, c.z)
			return
		end
		local bot = s.bot
		if bot.state ~= "Stunned" and dist(b.x, b.z, bot.x, bot.z) <= L.botRadius + L.lawballRadius then
			bot.state = "Stunned"
			bot.untilT = s.now + L.botStunSeconds
			s.stats.botStuns += 1
			s.lawball = "Returning"
			s.ballReturnAt = s.now + L.lawballReturnSeconds
			s.ball = nil
			emit(s, "botStunned", bot.x, bot.z)
			return
		end
		for _, p in L.pylons do
			if dist(b.x, b.z, p.x, p.z) <= p.r + L.lawballRadius then
				certifyMiss(s, b.x, b.z, "pylon")
				return
			end
		end
		if math.abs(b.x) > L.halfX or b.z < L.minZ or b.z > L.maxZ then
			certifyMiss(s, b.x, b.z, "wall")
			return
		end
		if b.dist >= L.lawballRange then
			certifyMiss(s, b.x, b.z, "range")
			return
		end
	end
end

local function stepBot(s: State, dt: number)
	local bot, c, v = s.bot, s.chicken, L.vault
	if bot.state == "Stunned" or bot.state == "Recover" then
		if s.now >= bot.untilT then
			bot.state = "Idle"
			emit(s, "botReady", bot.x, bot.z)
		end
		return
	end
	if bot.state == "Telegraph" then
		if s.now >= bot.untilT then
			if dist(bot.x, bot.z, c.x, c.z) <= L.botCounterRange then
				-- shove the cargo directly away from the bot: readable, dodgeable, never lethal
				local dx, dz = c.x - bot.x, c.z - bot.z
				local d = math.max(1e-3, math.sqrt(dx * dx + dz * dz))
				c.vx += dx / d * L.botCounterImpulse
				c.vz += dz / d * L.botCounterImpulse
				s.stats.botCounters += 1
				emit(s, "botCounter", bot.x, bot.z)
			else
				emit(s, "botWhiff", bot.x, bot.z)
			end
			bot.state = "Recover"
			bot.untilT = s.now + L.botRecoverSeconds
		end
		return
	end
	-- Idle/guard: drift toward a guard point on the chicken->vault line (no perfect info,
	-- capped speed, never enters the vault volume)
	local gx = c.x + (v.x - c.x) * 0.55
	local gz = c.z + (v.z - c.z) * 0.55
	gz = math.min(gz, v.z - v.hz - 6)
	local dx, dz = gx - bot.x, gz - bot.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > 0.5 then
		local m = math.min(d, L.botSpeed * dt)
		bot.x += dx / d * m
		bot.z += dz / d * m
	end
	if s.phase == "Live" and dist(bot.x, bot.z, c.x, c.z) <= L.botAggroRange then
		bot.state = "Telegraph"
		bot.untilT = s.now + L.botTelegraphSeconds
		emit(s, "botTelegraph", bot.x, bot.z)
	end
end

function LawSim.step(s: State, dt: number)
	if not finite(dt) or dt <= 0 then
		return
	end
	dt = math.min(dt, 0.1)
	s.now += dt
	if s.phase ~= "Live" then
		if s.phase == "Ready" then
			stepBot(s, dt)
		end
		return
	end

	-- round clock (starts on first steal)
	if s.startedAt and s.now - s.startedAt >= Config.ROUND_SECONDS then
		s.phase = "Lost"
		s.endedAt = s.now
		emit(s, "timeout")
		return
	end

	local c = s.chicken
	-- planted gravity well: attraction toward its center, linear falloff, bounded
	local w = s.well
	if w then
		if s.now >= w.expiresAt then
			s.well = nil
			s.lawball = "Returning"
			s.ballReturnAt = s.now + L.wellCooldownSeconds
			emit(s, "wellExpired", w.x, w.z)
		else
			local dx, dz = w.x - c.x, w.z - c.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < L.wellRadius and d > 0.25 then
				local a = L.wellStrength * (1 - d / L.wellRadius)
				c.vx += dx / d * a * dt
				c.vz += dz / d * a * dt
				s.lastCause = { at = s.now, kind = "plant" }
			end
		end
	end

	stepBall(s, dt)
	stepBot(s, dt)

	-- integrate cargo
	local decay = math.exp(-L.chickenDragPerSecond * dt)
	c.vx *= decay
	c.vz *= decay
	local sp = math.sqrt(c.vx * c.vx + c.vz * c.vz)
	if sp > L.chickenMaxSpeed then
		c.vx = c.vx / sp * L.chickenMaxSpeed
		c.vz = c.vz / sp * L.chickenMaxSpeed
	end
	c.x += c.vx * dt
	c.z += c.vz * dt
	bounceWalls(s)

	if s.lawball == "Returning" and s.now >= s.ballReturnAt then
		s.lawball = "Held"
		s.ballId += 1
		emit(s, "lawballReady")
	end

	-- CR-001 goal witness (server geometry only)
	local lc = s.lastCause
	local cert = GoalWitness.observe(
		s.witness,
		L.vault,
		c.x,
		c.z,
		s.now,
		if lc and lc.kind ~= "steal" then lc.at else nil,
		if lc then lc.kind else nil
	)
	if cert then
		s.certificate = cert
		s.phase = "Won"
		s.endedAt = s.now
		emit(s, "goal", c.x, c.z, cert.scoredEventId)
		return
	end

	-- gravity snaps back if the player abandons the cargo (recoverable, not a loss)
	if lc and s.now - lc.at >= L.gravitySnapSeconds then
		s.phase = "Ready"
		s.lawball = "None"
		s.ball, s.well, s.miss = nil, nil, nil
		s.lastCause = nil
		s.witness.dwell = 0
		resetChicken(s)
		emit(s, "gravitySnap")
	end
end

function LawSim.drainEvents(s: State): { Event }
	local e = s.events
	s.events = {}
	return e
end

-- Compact snapshot for the owning client (presentation only)
function LawSim.snapshot(s: State): { [string]: any }
	local remaining = if s.startedAt then math.max(0, Config.ROUND_SECONDS - (s.now - s.startedAt)) else Config.ROUND_SECONDS
	if s.endedAt and s.startedAt then
		remaining = math.max(0, Config.ROUND_SECONDS - (s.endedAt - s.startedAt))
	end
	local m = s.miss
	return {
		mode = "LawSport",
		phase = s.phase,
		round = s.round,
		remaining = remaining,
		lawball = s.lawball,
		cx = s.chicken.x,
		cz = s.chicken.z,
		bx = s.bot.x,
		bz = s.bot.z,
		botState = s.bot.state,
		ballX = if s.ball then s.ball.x else nil,
		ballZ = if s.ball then s.ball.z else nil,
		wellX = if s.well then s.well.x else nil,
		wellZ = if s.well then s.well.z else nil,
		recoverOpen = s.flags.elasticRecovery
			and m ~= nil
			and not m.used
			and s.now - m.at <= L.recoveryWindowSeconds
			and s.now >= s.nextRecoveryAt,
		scoredEventId = if s.certificate then s.certificate.scoredEventId else nil,
		elapsed = if s.startedAt and s.endedAt then s.endedAt - s.startedAt else nil,
		stats = s.stats,
	}
end

return LawSim
