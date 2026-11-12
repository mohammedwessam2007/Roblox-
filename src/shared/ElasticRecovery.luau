--!strict
-- ADR-0010 #1 Elastic Recovery Tether: pure server-side authorization.
-- Derived from V1.1 SOURCE_ADAPTERS/ElasticRecoveryPolicy.luau (design adapter); ownership and
-- match identity are enforced structurally by MatchCore (a player can only address the match
-- keyed by their own server-side UserId), so this policy checks miss provenance and timing.
-- It can never grant score or move cargo: both fields are constant false.

local Config = require(script.Parent.Config)

export type Context = {
	matchActive: boolean,
	missCertifiedByServer: boolean,
	missAtSeconds: number,
	nowSeconds: number,
	recoveryAlreadyUsed: boolean,
	nextRecoveryAllowedAt: number,
	lawballMatches: boolean,
	lawballReturning: boolean,
}

export type Decision = {
	allowed: boolean,
	reason: string,
	recallLawball: boolean,
	grantScore: boolean,
	nudgeCargo: boolean,
}

local ElasticRecovery = {}

local function deny(reason: string): Decision
	return { allowed = false, reason = reason, recallLawball = false, grantScore = false, nudgeCargo = false }
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

function ElasticRecovery.evaluate(c: Context): Decision
	if not c.matchActive then
		return deny("inactive_match")
	end
	if not c.missCertifiedByServer then
		return deny("miss_not_observed")
	end
	if not c.lawballMatches or not c.lawballReturning then
		return deny("unknown_lawball")
	end
	if c.recoveryAlreadyUsed then
		return deny("already_recovered")
	end
	if not (finite(c.nowSeconds) and finite(c.missAtSeconds) and finite(c.nextRecoveryAllowedAt)) then
		return deny("invalid_time")
	end
	local delay = c.nowSeconds - c.missAtSeconds
	if delay < 0 or delay > Config.Law.recoveryWindowSeconds then
		return deny("expired_window")
	end
	if c.nowSeconds < c.nextRecoveryAllowedAt then
		return deny("cooldown")
	end
	return {
		allowed = true,
		reason = "server_authorized_recall",
		recallLawball = true,
		grantScore = false,
		nudgeCargo = false,
	}
end

return table.freeze(ElasticRecovery)
