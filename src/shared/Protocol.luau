--!strict
-- Zero-trust intent schema + per-player rate limiting. Clients send *intents* only:
-- never positions, scores, wins, timestamps, prices, receipts or owner ids.

local Config = require(script.Parent.Config)
local S = Config.Security

local Protocol = {}

Protocol.REMOTE_INTENT = "SR_Intent"
Protocol.REMOTE_STATE = "SR_State"

-- action -> allowed numeric fields (besides seq/action)
local SCHEMA: { [string]: { [string]: { min: number, max: number } } } = {
	Steal = {},
	Throw = {
		aimX = { min = -1.5, max = 1.5 },
		aimZ = { min = -1.5, max = 1.5 },
		power = { min = 0, max = 1 },
	},
	Plant = { x = { min = -200, max = 200 }, z = { min = -200, max = 200 } },
	Recover = {},
	Again = {},
	ChooseMode = {}, -- mode carried as string field "mode"
	-- Grid Heist
	CutPower = {},
	Reroute = {},
	OpenEscape = {},
	GrabCore = {},
}

local MODES = { LawSport = true, GridHeist = true }

export type Intent = {
	seq: number,
	action: string,
	aimX: number?,
	aimZ: number?,
	power: number?,
	x: number?,
	z: number?,
	mode: string?,
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Protocol.validate(raw: any, lastSeq: number): (Intent?, string)
	if type(raw) ~= "table" then
		return nil, "not_table"
	end
	if getmetatable(raw) ~= nil then
		return nil, "metatable"
	end
	local count = 0
	for k, _ in raw do
		count += 1
		if type(k) ~= "string" or count > S.maxPayloadKeys then
			return nil, "bad_keys"
		end
	end
	local action = raw.action
	if type(action) ~= "string" or #action > S.maxStringLength then
		return nil, "bad_action"
	end
	local fields = SCHEMA[action]
	if fields == nil then
		return nil, "unknown_action"
	end
	local seq = raw.seq
	if type(seq) ~= "number" or not finite(seq) or seq ~= math.floor(seq) or seq < 1 or seq > 2 ^ 31 then
		return nil, "bad_seq"
	end
	if seq <= lastSeq then
		return nil, "replayed_seq"
	end
	local out: Intent = { seq = seq, action = action }
	for k, v in raw do
		if k == "seq" or k == "action" then
			continue
		end
		if action == "ChooseMode" and k == "mode" then
			if type(v) ~= "string" or not MODES[v] then
				return nil, "bad_mode"
			end
			out.mode = v
			continue
		end
		local spec = fields[k]
		if spec == nil then
			return nil, "unknown_field:" .. string.sub(k, 1, S.maxStringLength)
		end
		if type(v) ~= "number" or not finite(v) or v < spec.min or v > spec.max then
			return nil, "bad_value:" .. k
		end
		(out :: any)[k] = v
	end
	for k, _ in fields do
		if (out :: any)[k] == nil then
			return nil, "missing_field:" .. k
		end
	end
	if action == "ChooseMode" and out.mode == nil then
		return nil, "missing_field:mode"
	end
	return out, "ok"
end

export type Bucket = { tokens: number, at: number }

function Protocol.newBucket(now: number): Bucket
	return { tokens = S.bucketCapacity, at = now }
end

function Protocol.take(b: Bucket, now: number): boolean
	local dt = math.max(0, now - b.at)
	b.at = now
	b.tokens = math.min(S.bucketCapacity, b.tokens + dt * S.bucketRefillPerSecond)
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

return table.freeze(Protocol)
