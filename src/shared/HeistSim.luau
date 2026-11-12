--!strict
-- GRID HEIST (challenger) authoritative simulation, pure Luau.
-- Loop: CUT POWER -> CHOOSE (REROUTE SECURITY | OPEN ESCAPE) -> DRONE COUNTER -> GRAB CORE -> ESCAPE -> REPLAY.
-- The runner's position comes from the server-observed character and is speed-bounded
-- (anti-teleport). Detection is server line-of-sight; the client only renders it.

local Config = require(script.Parent.Config)
local H = Config.Heist

local HeistSim = {}

export type Event = { kind: string, x: number?, z: number?, info: string? }
export type Vec = { x: number, z: number }

export type State = {
	matchId: string,
	ruleset: string,
	round: number,
	phase: string, -- "Ready" | "Live" | "Won" | "Lost"
	now: number,
	startedAt: number?,
	endedAt: number?,
	player: Vec?,
	blackoutUntil: number,
	powerCut: boolean,
	choice: string?, -- "Reroute" | "OpenEscape"
	rerouteUntil: number,
	gateOpen: boolean,
	alarm: boolean,
	carrying: boolean,
	drone: { x: number, z: number, fx: number, fz: number, route: string, wp: number },
	detect: number,
	teleportFlags: number,
	scoredEventId: string?,
	stats: { detections: number, seenSeconds: number },
	events: { Event },
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function emit(s: State, kind: string, x: number?, z: number?, info: string?)
	if #s.events < 64 then
		table.insert(s.events, { kind = kind, x = x, z = z, info = info })
	end
end

local function near(p: Vec, spot: { x: number, z: number, r: number }): boolean
	local dx, dz = p.x - spot.x, p.z - spot.z
	return dx * dx + dz * dz <= spot.r * spot.r
end

function HeistSim.new(matchId: string, round: number?): State
	local a = H.routeA[1]
	return {
		matchId = matchId,
		ruleset = Config.HEIST_RULESET_VERSION,
		round = round or 1,
		phase = "Ready",
		now = 0,
		startedAt = nil,
		endedAt = nil,
		player = nil,
		blackoutUntil = 0,
		powerCut = false,
		choice = nil,
		rerouteUntil = 0,
		gateOpen = false,
		alarm = false,
		carrying = false,
		drone = { x = a.x, z = a.z, fx = 0, fz = 1, route = "A", wp = 2 },
		detect = 0,
		teleportFlags = 0,
		scoredEventId = nil,
		stats = { detections = 0, seenSeconds = 0 },
		events = {},
	}
end

function HeistSim.again(s: State): State
	local n = HeistSim.new(s.matchId, s.round + 1)
	n.now = s.now
	emit(n, "again")
	return n
end

local function start(s: State)
	if s.phase == "Ready" then
		s.phase = "Live"
		s.startedAt = s.now
	end
end

function HeistSim.apply(s: State, intent: { action: string }, player: Vec): (boolean, string)
	if not (finite(player.x) and finite(player.z)) then
		return false, "bad_player_position"
	end
	local p = s.player or player -- trust only the speed-bounded server track once it exists
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
	if a == "CutPower" then
		if s.powerCut then
			return false, "already_cut"
		end
		if not near(p, H.substation) then
			return false, "too_far"
		end
		start(s)
		s.powerCut = true
		s.blackoutUntil = s.now + H.blackoutSeconds
		emit(s, "blackout", H.substation.x, H.substation.z)
		return true, "blackout"
	end
	if a == "Reroute" or a == "OpenEscape" then
		if not s.powerCut then
			return false, "power_on"
		end
		if s.choice ~= nil then
			return false, "choice_locked"
		end
		if a == "Reroute" then
			if not near(p, H.rerouteConsole) then
				return false, "too_far"
			end
			s.choice = "Reroute"
			s.rerouteUntil = s.now + H.rerouteSeconds
			s.drone.route, s.drone.wp = "B", 1
			emit(s, "reroute", H.rerouteConsole.x, H.rerouteConsole.z)
			return true, "rerouted"
		else
			if not near(p, H.escapeGate) then
				return false, "too_far"
			end
			s.choice = "OpenEscape"
			s.gateOpen = true
			s.alarm = true -- trade-off: shortcut exit, but the drone hunts the gate faster
			emit(s, "gateOpen", H.escapeGate.x, H.escapeGate.z)
			return true, "gate_open"
		end
	end
	if a == "GrabCore" then
		if s.carrying then
			return false, "already_carrying"
		end
		if not near(p, H.coreSpot) then
			return false, "too_far"
		end
		start(s)
		s.carrying = true
		emit(s, "coreGrabbed", H.coreSpot.x, H.coreSpot.z)
		return true, "grabbed"
	end
	return false, "unknown_action"
end

-- segment vs axis-aligned box (slab test) for line of sight
local function segBlocked(ax: number, az: number, bx: number, bz: number): boolean
	for _, b in H.blocks do
		local tmin, tmax = 0, 1
		local dx, dz = bx - ax, bz - az
		local ok = true
		for axis = 1, 2 do
			local o = if axis == 1 then ax else az
			local d = if axis == 1 then dx else dz
			local lo = (if axis == 1 then b.x else b.z) - (if axis == 1 then b.hx else b.hz)
			local hi = (if axis == 1 then b.x else b.z) + (if axis == 1 then b.hx else b.hz)
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then
					ok = false
					break
				end
			else
				local t1, t2 = (lo - o) / d, (hi - o) / d
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		if ok then
			return true
		end
	end
	return false
end
HeistSim._segBlocked = segBlocked

function HeistSim.visionRadius(s: State): number
	return if s.now < s.blackoutUntil then H.visionDark else H.visionLit
end

function HeistSim.sees(s: State, p: Vec): boolean
	local d = s.drone
	local dx, dz = p.x - d.x, p.z - d.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > HeistSim.visionRadius(s) then
		return false
	end
	if dist > 2 then
		local cosA = (dx * d.fx + dz * d.fz) / dist
		if cosA < math.cos(H.visionHalfAngle) then
			return false
		end
	end
	return not segBlocked(d.x, d.z, p.x, p.z)
end

local function stepDrone(s: State, dt: number)
	local d = s.drone
	if s.choice == "Reroute" and d.route == "B" and s.now >= s.rerouteUntil then
		d.route, d.wp = "A", 1
		emit(s, "rerouteEnded")
	end
	local tx, tz
	if s.alarm and d.route ~= "B" then
		tx, tz = H.escapeGate.x, H.escapeGate.z
	else
		local route = if d.route == "B" then H.routeB else H.routeA
		local wp = route[d.wp]
		tx, tz = wp.x, wp.z
		if math.abs(tx - d.x) + math.abs(tz - d.z) < 1 then
			d.wp = d.wp % #route + 1
			wp = route[d.wp]
			tx, tz = wp.x, wp.z
		end
	end
	local dx, dz = tx - d.x, tz - d.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > 1e-3 then
		local speed = if s.alarm then H.droneAlarmSpeed else H.droneSpeed
		local m = math.min(dist, speed * dt)
		d.fx, d.fz = dx / dist, dz / dist
		d.x += d.fx * m
		d.z += d.fz * m
	end
end

-- player: server-observed character position this tick (may be nil if no character)
function HeistSim.step(s: State, dt: number, player: Vec?)
	if not finite(dt) or dt <= 0 then
		return
	end
	dt = math.min(dt, 0.1)
	s.now += dt
	if player and finite(player.x) and finite(player.z) then
		local last = s.player
		if last == nil then
			s.player = { x = player.x, z = player.z }
		else
			local dx, dz = player.x - last.x, player.z - last.z
			local moved = math.sqrt(dx * dx + dz * dz)
			if moved > H.maxRunSpeed * dt + H.teleportSlack then
				s.teleportFlags += 1
				emit(s, "teleportRejected", player.x, player.z)
			else
				s.player = { x = player.x, z = player.z }
			end
		end
	end
	if s.phase ~= "Live" then
		return
	end
	if s.startedAt and s.now - s.startedAt >= Config.ROUND_SECONDS then
		s.phase = "Lost"
		s.endedAt = s.now
		emit(s, "timeout")
		return
	end
	if s.powerCut and s.blackoutUntil > 0 and s.now >= s.blackoutUntil then
		s.blackoutUntil = 0
		emit(s, "lightsBack")
	end
	stepDrone(s, dt)
	local p = s.player
	if p then
		if HeistSim.sees(s, p) then
			s.detect += dt
			s.stats.seenSeconds += dt
			if s.detect >= H.detectSeconds then
				s.phase = "Lost"
				s.endedAt = s.now
				s.stats.detections += 1
				emit(s, "caught", p.x, p.z)
				return
			end
		else
			s.detect = math.max(0, s.detect - dt * 0.5)
		end
		if s.carrying and (near(p, H.exitZone) or (s.gateOpen and near(p, H.escapeGate))) then
			s.phase = "Won"
			s.endedAt = s.now
			s.scoredEventId = string.format("%s:r%d:%s", s.matchId, s.round, s.ruleset)
			emit(s, "escaped", p.x, p.z, s.scoredEventId)
		end
	end
end

function HeistSim.drainEvents(s: State): { Event }
	local e = s.events
	s.events = {}
	return e
end

function HeistSim.snapshot(s: State): { [string]: any }
	local remaining = if s.startedAt
		then math.max(0, Config.ROUND_SECONDS - ((s.endedAt or s.now) - s.startedAt))
		else Config.ROUND_SECONDS
	return {
		mode = "GridHeist",
		phase = s.phase,
		round = s.round,
		remaining = remaining,
		dx = s.drone.x,
		dz = s.drone.z,
		dfx = s.drone.fx,
		dfz = s.drone.fz,
		vision = HeistSim.visionRadius(s),
		blackout = s.now < s.blackoutUntil,
		powerCut = s.powerCut,
		choice = s.choice,
		gateOpen = s.gateOpen,
		alarm = s.alarm,
		carrying = s.carrying,
		detect = s.detect / H.detectSeconds,
		scoredEventId = s.scoredEventId,
		elapsed = if s.startedAt and s.endedAt then s.endedAt - s.startedAt else nil,
	}
end

return HeistSim
