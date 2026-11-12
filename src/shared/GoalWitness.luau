--!strict
-- CR-001: the ONLY path to a score. Observes server-owned cargo geometry over consecutive
-- simulation ticks, requires a recent server-recorded causal player action, and mints
-- exactly one idempotent scoredEventId per round. Nothing the client sends is an input.

local GoalWitness = {}

export type Box = { x: number, z: number, hx: number, hz: number }

export type Witness = {
	matchId: string,
	round: number,
	ruleset: string,
	dwell: number,
	dwellTicks: number,
	causalWindow: number,
	certified: string?, -- scoredEventId once minted
}

export type Certificate = {
	scoredEventId: string,
	matchId: string,
	round: number,
	ruleset: string,
	atSeconds: number,
	causeAtSeconds: number,
	causeKind: string,
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function GoalWitness.new(
	matchId: string,
	round: number,
	ruleset: string,
	dwellTicks: number,
	causalWindow: number
): Witness
	return {
		matchId = matchId,
		round = round,
		ruleset = ruleset,
		dwell = 0,
		dwellTicks = dwellTicks,
		causalWindow = causalWindow,
		certified = nil,
	}
end

function GoalWitness.inside(box: Box, x: number, z: number): boolean
	if not (finite(x) and finite(z)) then
		return false
	end
	return math.abs(x - box.x) <= box.hx and math.abs(z - box.z) <= box.hz
end

-- Called once per authoritative server tick with the server's own cargo position.
-- Returns a certificate exactly once; afterwards always nil for this round.
function GoalWitness.observe(
	w: Witness,
	box: Box,
	x: number,
	z: number,
	nowSeconds: number,
	causeAtSeconds: number?,
	causeKind: string?
): Certificate?
	if w.certified ~= nil then
		return nil
	end
	if not GoalWitness.inside(box, x, z) then
		w.dwell = 0 -- interrupted dwell resets
		return nil
	end
	w.dwell += 1
	if w.dwell < w.dwellTicks then
		return nil
	end
	if causeAtSeconds == nil or not finite(causeAtSeconds) then
		return nil -- inside without a legal cause: never scores
	end
	local age = nowSeconds - causeAtSeconds
	if age < 0 or age > w.causalWindow then
		return nil
	end
	local id = string.format("%s:r%d:%s", w.matchId, w.round, w.ruleset)
	w.certified = id
	return {
		scoredEventId = id,
		matchId = w.matchId,
		round = w.round,
		ruleset = w.ruleset,
		atSeconds = nowSeconds,
		causeAtSeconds = causeAtSeconds,
		causeKind = causeKind or "unknown",
	}
end

return table.freeze(GoalWitness)
