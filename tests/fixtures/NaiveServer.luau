--!nocheck
-- VULNERABLE FIXTURE (do not ship). Reproduces the two defects the directive names:
--  CR-001: trusts a client "SCORE" remote.
--  CR-002: one global cargo shared by every player's independent solo state machine.
-- The test suite proves these are exploitable here and NOT exploitable in MatchCore.
local Naive = {}
function Naive.new()
	return { cargo = { x = 0, z = -38 }, scores = {} }
end
function Naive.onRemote(s, userId, payload)
	if payload.action == "SCORE" then
		s.scores[userId] = (s.scores[userId] or 0) + 1
	elseif payload.action == "Throw" then
		s.cargo.z += 40 * (payload.power or 1) -- moves THE shared cargo
	end
end
return Naive
