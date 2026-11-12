--!strict
-- Adaptive Reality Engine (client-only optional FX budget). Derived from the V1.1
-- AdaptiveQualityPolicy design adapter. It NEVER touches physics, hitboxes, timing, score,
-- network authority, or essential cues (chicken, lawball, vault, bot telegraph, well ring,
-- drone vision cone stay identical on every tier). It only scales decorative extras.

local AdaptiveQuality = {}

AdaptiveQuality.TIERS = table.freeze({ "Survival", "Lite", "Balanced", "High", "Ultra" })

-- Decorative budget per tier. Essential gameplay cues are not in this table on purpose.
AdaptiveQuality.PROFILES = table.freeze({
	table.freeze({ particles = 0.0, trails = false, decor = 0.0, shadows = false, bloom = false, clouds = 0 }),
	table.freeze({
		particles = 0.25,
		trails = false,
		decor = 0.3,
		shadows = false,
		bloom = false,
		clouds = 4,
	}),
	table.freeze({ particles = 0.5, trails = true, decor = 0.6, shadows = true, bloom = false, clouds = 10 }),
	table.freeze({ particles = 0.8, trails = true, decor = 0.85, shadows = true, bloom = true, clouds = 18 }),
	table.freeze({ particles = 1.0, trails = true, decor = 1.0, shadows = true, bloom = true, clouds = 28 }),
})

local UNDERPERFORM_MS = 35.0
local HEADROOM_MS = 23.0
local DOWN_SECONDS = 15.0
local UP_SECONDS = 45.0
local CHANGE_COOLDOWN_SECONDS = 20.0
local WARMUP_SECONDS = 5.0

export type Controller = {
	tier: number,
	auto: boolean,
	slowSeconds: number,
	fastSeconds: number,
	lastSwitchSeconds: number,
	startedAt: number,
}

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function clampTier(v: number): number
	return math.max(1, math.min(5, math.floor(v)))
end

function AdaptiveQuality.new(startTier: number?, auto: boolean?, now: number?): Controller
	return {
		tier = clampTier(startTier or 3),
		auto = if auto == nil then true else auto,
		slowSeconds = 0,
		fastSeconds = 0,
		lastSwitchSeconds = -1e9,
		startedAt = now or 0,
	}
end

function AdaptiveQuality.setManual(c: Controller, tier: number): Controller
	return {
		tier = clampTier(tier),
		auto = false,
		slowSeconds = 0,
		fastSeconds = 0,
		lastSwitchSeconds = c.lastSwitchSeconds,
		startedAt = c.startedAt,
	}
end

function AdaptiveQuality.setAuto(c: Controller): Controller
	return {
		tier = c.tier,
		auto = true,
		slowSeconds = 0,
		fastSeconds = 0,
		lastSwitchSeconds = c.lastSwitchSeconds,
		startedAt = c.startedAt,
	}
end

-- frameMs: measured client frame time; maxTier: cap (e.g. from the player's own Roblox
-- graphics quality level), respected so we never fight the user's platform setting.
function AdaptiveQuality.sample(
	c: Controller,
	frameMs: number,
	elapsed: number,
	now: number,
	maxTier: number
): (Controller, string)
	if not c.auto then
		return c, "manual_override"
	end
	if
		not (
			finite(frameMs)
			and frameMs > 0
			and finite(elapsed)
			and elapsed > 0
			and finite(now)
			and finite(maxTier)
		)
	then
		return c, "invalid_sample"
	end
	if now - c.startedAt < WARMUP_SECONDS then
		return c, "warmup"
	end
	local dt = math.min(elapsed, 0.25)
	local cap = clampTier(maxTier)
	local slow = if frameMs > UNDERPERFORM_MS then c.slowSeconds + dt else 0
	local fast = if frameMs < HEADROOM_MS then c.fastSeconds + dt else 0
	local nextTier = math.min(c.tier, cap)
	local reason = if nextTier < c.tier then "capped_by_user_setting" else "stable"
	if now - c.lastSwitchSeconds >= CHANGE_COOLDOWN_SECONDS then
		if slow >= DOWN_SECONDS and nextTier > 1 then
			nextTier -= 1
			reason = "reduce_optional_fx"
		elseif fast >= UP_SECONDS and nextTier < cap then
			nextTier += 1
			reason = "increase_optional_fx"
		end
	end
	local switched = nextTier ~= c.tier
	return {
		tier = nextTier,
		auto = true,
		slowSeconds = if switched then 0 else slow,
		fastSeconds = if switched then 0 else fast,
		lastSwitchSeconds = if switched then now else c.lastSwitchSeconds,
		startedAt = c.startedAt,
	},
		reason
end

return table.freeze(AdaptiveQuality)
