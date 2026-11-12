--!strict
-- CR-002: SoloGauntlet topology. Every player owns exactly one logical match with its own
-- cargo, bot/drone and arena slot. Matches are keyed by the server-side UserId, never by any
-- id the client sends, so player A's intents can only ever touch player A's state.
-- Pure Luau: the Roblox glue (server/init.server.luau) feeds positions and time in.

local Config = require(script.Parent.Config)
local Protocol = require(script.Parent.Protocol)
local LawSim = require(script.Parent.LawSim)
local HeistSim = require(script.Parent.HeistSim)

local MatchCore = {}

export type Vec = { x: number, z: number }

export type Match = {
	userId: number,
	slot: number,
	origin: Vec,
	mode: string,
	law: LawSim.State?,
	heist: HeistSim.State?,
	lastSeq: number,
	bucket: Protocol.Bucket,
	rejects: { [string]: number },
	strikes: number,
	nextMatchNo: number,
}

export type AnalyticsSink = (userId: number, name: string, fields: { [string]: any }) -> ()

export type Core = {
	matches: { [number]: Match },
	freeSlots: { number },
	nextSlot: number,
	sink: AnalyticsSink?,
	certified: { [string]: boolean }, -- scoredEventId ledger (idempotent awards)
	awards: { [number]: number }, -- userId -> certified goal count
}

function MatchCore.new(sink: AnalyticsSink?): Core
	return { matches = {}, freeSlots = {}, nextSlot = 0, sink = sink, certified = {}, awards = {} }
end

local function log(core: Core, userId: number, name: string, fields: { [string]: any })
	local sink = core.sink
	if sink then
		sink(userId, name, fields)
	end
end

local function newSim(m: Match)
	local id = string.format("u%d-m%d", m.userId, m.nextMatchNo)
	m.nextMatchNo += 1
	if m.mode == Config.Modes.GridHeist then
		m.heist = HeistSim.new(id)
		m.law = nil
	else
		m.law = LawSim.new(id)
		m.heist = nil
	end
end

function MatchCore.join(core: Core, userId: number, now: number, mode: string?): Match
	local existing = core.matches[userId]
	if existing then
		return existing
	end
	local slot: number
	if #core.freeSlots > 0 then
		slot = table.remove(core.freeSlots) :: number
	else
		slot = core.nextSlot
		core.nextSlot += 1
	end
	local m: Match = {
		userId = userId,
		slot = slot,
		origin = { x = slot * Config.ARENA_SPACING, z = 0 },
		mode = mode or Config.Modes.LawSport,
		law = nil,
		heist = nil,
		lastSeq = 0,
		bucket = Protocol.newBucket(now),
		rejects = {},
		strikes = 0,
		nextMatchNo = 1,
	}
	newSim(m)
	core.matches[userId] = m
	log(core, userId, "session_started", { mode = m.mode, slot = slot })
	return m
end

function MatchCore.leave(core: Core, userId: number)
	local m = core.matches[userId]
	if m then
		core.matches[userId] = nil
		table.insert(core.freeSlots, m.slot)
		log(core, userId, "exit", { mode = m.mode })
	end
end

local function toLocal(m: Match, world: Vec): Vec
	return { x = world.x - m.origin.x, z = world.z - m.origin.z }
end

local function reject(core: Core, m: Match, reason: string): (boolean, string)
	m.rejects[reason] = (m.rejects[reason] or 0) + 1
	m.strikes += 1
	return false, reason
end

-- raw: untrusted client payload. world: server-observed character position (or nil).
function MatchCore.intent(core: Core, userId: number, raw: any, world: Vec?, now: number): (boolean, string)
	local m = core.matches[userId]
	if m == nil then
		return false, "no_match"
	end
	if not Protocol.take(m.bucket, now) then
		return reject(core, m, "rate_limited")
	end
	local intent, why = Protocol.validate(raw, m.lastSeq)
	if intent == nil then
		return reject(core, m, why)
	end
	m.lastSeq = intent.seq
	return MatchCore._apply(core, m, intent, world)
end

-- Server-originated triggers (ProximityPrompts). Roblox already attributes the prompt to the
-- server-side Player; these never consume or advance the client's sequence space (a shared
-- counter made the client's next THROW look like a replay — found by the emulated runtime).
local SERVER_TRIGGERS = { Steal = true, CutPower = true, Reroute = true, OpenEscape = true, GrabCore = true }
function MatchCore.serverIntent(
	core: Core,
	userId: number,
	action: string,
	world: Vec?,
	now: number
): (boolean, string)
	local m = core.matches[userId]
	if m == nil then
		return false, "no_match"
	end
	if not SERVER_TRIGGERS[action] then
		return reject(core, m, "not_server_trigger")
	end
	if not Protocol.take(m.bucket, now) then
		return reject(core, m, "rate_limited")
	end
	return MatchCore._apply(core, m, { seq = m.lastSeq, action = action } :: any, world)
end

-- After the server itself moves a character (spawn/respawn/fall recovery) the anti-teleport
-- track must restart from the new legal position, otherwise every later sample is rejected.
function MatchCore.resetTrack(core: Core, userId: number)
	local m = core.matches[userId]
	if m and m.heist then
		m.heist.player = nil
	end
end

function MatchCore._apply(core: Core, m: Match, intent: Protocol.Intent, world: Vec?): (boolean, string)
	local userId = m.userId
	if world == nil then
		return reject(core, m, "no_character")
	end
	local p = toLocal(m, world)

	if intent.action == "ChooseMode" then
		local active = (m.law and m.law.phase == "Live") or (m.heist and m.heist.phase == "Live")
		if active then
			return reject(core, m, "round_active")
		end
		m.mode = intent.mode :: string
		newSim(m)
		log(core, userId, "mode_chosen", { mode = m.mode })
		return true, "mode_set"
	end

	local ok, reason
	if m.law then
		local before = m.law.phase
		ok, reason = LawSim.apply(m.law, intent :: any, p)
		if ok and reason == "again" then
			log(core, userId, "voluntary_replay", { mode = m.mode, previous = before, round = m.law.round })
			m.law = LawSim.again(m.law)
		elseif ok then
			local name = ({
				stolen = "steal_succeeded",
				thrown = "throw_selected",
				planted = "plant_selected",
				recovered = "recovery_used",
			})[reason]
			if name then
				log(core, userId, name, { round = m.law.round, t = m.law.now })
			end
		end
	elseif m.heist then
		ok, reason = HeistSim.apply(m.heist, intent :: any, p)
		if ok and reason == "again" then
			log(core, userId, "voluntary_replay", { mode = m.mode, round = m.heist.round })
			m.heist = HeistSim.again(m.heist)
		elseif ok then
			log(core, userId, "heist_" .. reason, { round = m.heist.round, t = m.heist.now })
		end
	else
		ok, reason = false, "no_sim"
	end
	if not ok then
		return reject(core, m, reason)
	end
	return true, reason
end

export type StepOutput = { userId: number, events: { any }, snapshot: { [string]: any } }

-- positionOf(userId) -> server-observed world position or nil
function MatchCore.step(core: Core, dt: number, positionOf: (number) -> Vec?): { StepOutput }
	local out = {}
	for userId, m in core.matches do
		local events
		local snap
		if m.law then
			LawSim.step(m.law, dt)
			events = LawSim.drainEvents(m.law)
			snap = LawSim.snapshot(m.law)
			local cert = m.law.certificate
			if cert and not core.certified[cert.scoredEventId] then
				core.certified[cert.scoredEventId] = true -- exactly-once award ledger
				core.awards[userId] = (core.awards[userId] or 0) + 1
				log(
					core,
					userId,
					"goal_server_certified",
					{ id = cert.scoredEventId, cause = cert.causeKind, elapsed = snap.elapsed }
				)
			end
		elseif m.heist then
			local w = positionOf(userId)
			HeistSim.step(m.heist, dt, if w then toLocal(m, w) else nil)
			events = HeistSim.drainEvents(m.heist)
			snap = HeistSim.snapshot(m.heist)
			local id = m.heist.scoredEventId
			if id and not core.certified[id] then
				core.certified[id] = true
				core.awards[userId] = (core.awards[userId] or 0) + 1
				log(core, userId, "goal_server_certified", { id = id, elapsed = snap.elapsed })
			end
		else
			events, snap = {}, {}
		end
		for _, e in events do
			if e.kind == "timeout" or e.kind == "caught" then
				log(core, userId, "round_fail", { mode = m.mode, why = e.kind })
			end
		end
		snap.originX = m.origin.x
		snap.originZ = m.origin.z
		table.insert(out, { userId = userId, events = events, snapshot = snap })
	end
	return out
end

return MatchCore
