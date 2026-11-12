--!strict
-- Steal Reality: every gameplay constant lives here. Server-authoritative values only;
-- client FX tiers never read or change anything in Law/Heist/Security.

local Config = {}

Config.RULESET_VERSION = "law-1.0.0"
Config.HEIST_RULESET_VERSION = "heist-1.0.0"
Config.TICK = 1 / 30
Config.ROUND_SECONDS = 90
Config.ARENA_SPACING = 600 -- studs between solo arenas (CR-002 spatial isolation)

Config.Law = table.freeze({
	-- Arena (local XZ coordinates, origin = arena center, +Z points to the Vault)
	halfX = 40,
	minZ = -60,
	maxZ = 60,
	wallRestitution = 0.62,
	hoverHeight = 14,
	platformY = 6,

	chickenStart = { x = 0, z = -38 },
	chickenRadius = 6,
	chickenDragPerSecond = 0.38, -- exponential velocity decay (floaty but controllable)
	chickenMaxSpeed = 72,
	stealRange = 18,
	gravitySnapSeconds = 14, -- no causal action for this long => gravity returns

	vault = { x = 0, z = 52, hx = 11, hz = 6 }, -- legal goal volume (XZ box)
	dwellTicks = 8, -- consecutive server ticks inside vault
	causalWindowSeconds = 10, -- a player action must precede the goal

	pylons = { { x = -15, z = 10, r = 5 }, { x = 16, z = 24, r = 5 } },
	pylonRestitution = 0.75,

	-- THROW: kinetic, precise, short commitment
	lawballSpeed = 125,
	lawballRange = 95,
	lawballRadius = 1.5,
	throwMinPower = 0.35,
	throwImpulse = 58,
	lawballReturnSeconds = 2.2,

	-- PLANT: area control, long commitment, cannot be planted in/near the Vault
	plantRange = 46,
	wellRadius = 26,
	wellStrength = 150,
	wellSeconds = 4.0,
	wellCooldownSeconds = 1.5,
	wellVaultExclusion = 12,

	-- Elastic Recovery Tether (ADR-0010 #1), feature flagged
	recoveryWindowSeconds = 2.5,
	recoveryCooldownSeconds = 6.0,

	-- Rogue Law Bot
	botStart = { x = 0, z = 34 },
	botSpeed = 15,
	botRadius = 3.5,
	botAggroRange = 22,
	botTelegraphSeconds = 1.1,
	botCounterRange = 24,
	botCounterImpulse = 46,
	botRecoverSeconds = 2.6,
	botStunSeconds = 3.2,
})

Config.Heist = table.freeze({
	halfX = 70,
	minZ = -70,
	maxZ = 70,
	playerStart = { x = -58, z = -58 },
	maxRunSpeed = 30, -- includes dash allowance; anti-teleport bound
	teleportSlack = 4,
	coreSpot = { x = 0, z = 0, r = 7 },
	substation = { x = -56, z = -36, r = 9 },
	rerouteConsole = { x = 8, z = -52, r = 9 },
	escapeGate = { x = 56, z = 30, r = 8 },
	exitZone = { x = 60, z = 60, r = 9 },
	blackoutSeconds = 22,
	rerouteSeconds = 16,
	visionLit = 34,
	visionDark = 13,
	visionHalfAngle = math.rad(50),
	detectSeconds = 0.7,
	droneSpeed = 16,
	droneAlarmSpeed = 24,
	-- buildings block line of sight: axis-aligned XZ boxes {x,z,hx,hz}
	blocks = {
		{ x = -30, z = -30, hx = 14, hz = 14 },
		{ x = 30, z = -30, hx = 14, hz = 14 },
		{ x = -30, z = 30, hx = 14, hz = 14 },
		{ x = 30, z = 30, hx = 14, hz = 14 },
	},
	routeA = { { x = 0, z = -56 }, { x = 0, z = 56 }, { x = 52, z = 56 }, { x = 52, z = 0 }, { x = -52, z = 0 } },
	routeB = { { x = -56, z = 56 }, { x = -56, z = -56 }, { x = 56, z = -56 } },
})

Config.Security = table.freeze({
	bucketCapacity = 8,
	bucketRefillPerSecond = 6,
	maxPayloadKeys = 6,
	maxStringLength = 24,
	strikeKickThreshold = 400, -- log-only by default; never auto-kick in v1
})

Config.Flags = {
	ElasticRecovery = true, -- ADR-0010 #1 (A/B: set false for the control arm)
	RicochetAnchor = false, -- experimental, OFF by default per directive
	Podium = false, -- optional skippable podium; off until replay is proven
	CosmeticPreview = true, -- preview only; purchases are not wired to any product id
}

Config.Modes = table.freeze({ LawSport = "LawSport", GridHeist = "GridHeist" })

return Config
