--!strict
-- Steal Reality server entrypoint: Roblox glue around the pure MatchCore.
-- Authority: the server owns every match, cargo, bot, drone, goal and award. Clients send
-- bounded intents through one RemoteEvent and receive presentation snapshots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local MatchCore = require(Shared:WaitForChild("MatchCore"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))

local L = Config.Law
local H = Config.Heist
local TICK = Config.TICK

-- ---------------- remotes ----------------
local intentRemote = Instance.new("RemoteEvent")
intentRemote.Name = Protocol.REMOTE_INTENT
intentRemote.Parent = ReplicatedStorage
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = Protocol.REMOTE_STATE
stateRemote.Parent = ReplicatedStorage

-- ---------------- analytics (server-side, minimal, no PII) ----------------
local AnalyticsService: any = nil
pcall(function()
	AnalyticsService = game:GetService("AnalyticsService")
end)
local sessionIndex: { [number]: number } = {}
local nextIndex = 0
local function sink(userId: number, name: string, fields: { [string]: any })
	local idx = sessionIndex[userId] or -1
	print(string.format("[SR] t=%.2f s#%d %s", os.clock(), idx, name))
	local player = Players:GetPlayerByUserId(userId)
	if AnalyticsService and player then
		pcall(function()
			AnalyticsService:LogCustomEvent(player, name, 1)
		end)
	end
end

local core = MatchCore.new(sink)

-- ---------------- per-player arenas (CR-002 spatial isolation) ----------------
type Arena = { mode: string, matchKey: string, parts: { [string]: any }, origin: Vector3 }
local arenas: { [number]: Arena } = {}

local function rootOf(player: Player): BasePart?
	local ch = player.Character
	if not ch then
		return nil
	end
	local r = ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function worldPos(userId: number): MatchCore.Vec?
	local p = Players:GetPlayerByUserId(userId)
	local r = if p then rootOf(p) else nil
	if r then
		return { x = r.Position.X, z = r.Position.Z }
	end
	return nil
end

local function matchKey(m: MatchCore.Match): string
	return m.mode .. "#" .. tostring(m.nextMatchNo)
end

local function spawnCFrame(m: MatchCore.Match): CFrame
	local o = Vector3.new(m.origin.x, 0, m.origin.z)
	if m.mode == Config.Modes.GridHeist then
		return CFrame.new(o + Vector3.new(H.playerStart.x, 10, H.playerStart.z))
			* CFrame.Angles(0, math.rad(-135), 0)
	end
	return CFrame.lookAt(o + Vector3.new(0, L.platformY + 5, -52), o + Vector3.new(0, L.platformY + 5, 0))
end

local function routePrompt(player: Player, action: string)
	local m = core.matches[player.UserId]
	if not m then
		return
	end
	-- prompts are server-side triggers; own path, never touches the client's seq space
	MatchCore.serverIntent(core, player.UserId, action, worldPos(player.UserId), os.clock())
end

local function buildArena(player: Player, m: MatchCore.Match)
	local old = arenas[player.UserId]
	if old then
		old.parts.folder:Destroy()
	end
	local origin = Vector3.new(m.origin.x, 0, m.origin.z)
	local parts
	local name = "Arena_" .. tostring(m.slot)
	if m.mode == Config.Modes.GridHeist then
		parts = WorldBuilder.buildHeistArena(origin, name)
		for action, pp in parts.prompts :: { [string]: ProximityPrompt } do
			pp.Triggered:Connect(function(who: Player)
				if who == player then
					routePrompt(who, action)
				end
			end)
		end
	else
		parts = WorldBuilder.buildLawArena(origin, name);
		(parts.prompt :: ProximityPrompt).Triggered:Connect(function(who: Player)
			if who == player then
				routePrompt(who, "Steal")
			end
		end)
	end
	arenas[player.UserId] = { mode = m.mode, matchKey = matchKey(m), parts = parts, origin = origin }
	local character = player.Character
	if character and rootOf(player) then
		character:PivotTo(spawnCFrame(m))
		MatchCore.resetTrack(core, player.UserId)
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	nextIndex += 1
	sessionIndex[player.UserId] = nextIndex
	local m = MatchCore.join(core, player.UserId, os.clock())
	buildArena(player, m)
	player.CharacterAdded:Connect(function(character: Model)
		local mm = core.matches[player.UserId]
		if mm then
			character:WaitForChild("HumanoidRootPart", 5)
			task.defer(function()
				character:PivotTo(spawnCFrame(mm))
				MatchCore.resetTrack(core, player.UserId)
			end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	MatchCore.leave(core, player.UserId)
	local a = arenas[player.UserId]
	if a then
		a.parts.folder:Destroy()
		arenas[player.UserId] = nil
	end
	sessionIndex[player.UserId] = nil
end)

intentRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local before = core.matches[player.UserId]
	local beforeKey = if before then matchKey(before) else ""
	local ok, reason = MatchCore.intent(core, player.UserId, payload, worldPos(player.UserId), os.clock())
	local m = core.matches[player.UserId]
	if m and ok and reason == "mode_set" then
		buildArena(player, m)
	elseif
		m
		and matchKey(m) ~= beforeKey
		and arenas[player.UserId]
		and arenas[player.UserId].mode ~= m.mode
	then
		buildArena(player, m)
	end
	if not ok and RunService:IsStudio() then
		print("[SR] rejected", reason)
	end
	stateRemote:FireClient(
		player,
		{ ack = if type(payload) == "table" then payload.seq else nil, ok = ok, reason = reason },
		nil
	)
end)

-- ---------------- presentation of server truth ----------------
local function presentLaw(a: Arena, s: { [string]: any }, t: number)
	local o = a.origin
	local p = a.parts
	local chicken = p.chicken :: Model
	local bob = if s.phase == "Live" then math.sin(t * 2.2) * 1.2 else 0
	local y = if s.phase == "Ready" then L.platformY + 11 else L.platformY + L.hoverHeight + bob
	local pos = o + Vector3.new(s.cx, y, s.cz)
	chicken:PivotTo(
		CFrame.new(pos) * CFrame.Angles(0, if s.phase == "Live" then math.sin(t * 0.7) * 0.6 else 0, 0)
	)
	local cap = chicken:FindFirstChild("GravityCapsule") :: BasePart?
	if cap then
		cap.Transparency = if s.phase == "Ready" then 0 else 0.85
	end
	(p.prompt :: ProximityPrompt).Enabled = s.phase == "Ready"
	local bot = p.bot :: Model
	bot:PivotTo(
		CFrame.lookAt(
			o + Vector3.new(s.bx, L.platformY + 5.5, s.bz),
			pos * Vector3.new(1, 0, 1) + Vector3.new(0, L.platformY + 5.5, 0)
		)
	)
	local ring = bot:FindFirstChild("TelegraphRing") :: BasePart?
	if ring then
		ring.Transparency = if s.botState == "Telegraph" then 0.35 else 1
	end
	local ball = p.ball :: BasePart
	if s.ballX then
		ball.Transparency = 0
		ball.Position = o + Vector3.new(s.ballX, L.platformY + L.hoverHeight, s.ballZ)
	else
		ball.Transparency = 1
	end
	local well = p.well :: BasePart
	if s.wellX then
		well.Transparency = 0.55
		well.CFrame = CFrame.new(o + Vector3.new(s.wellX, L.platformY + 0.4, s.wellZ))
			* CFrame.Angles(0, 0, math.pi / 2)
	else
		well.Transparency = 1
	end
end

local function presentHeist(a: Arena, s: { [string]: any })
	local p = a.parts
	local o = a.origin
	local y = p.y0 + 9
	local dpos = o + Vector3.new(s.dx, y, s.dz)
	local face = Vector3.new(s.dfx, 0, s.dfz)
	if face.Magnitude < 1e-3 then
		face = Vector3.new(0, 0, 1)
	end
	(p.drone :: BasePart).CFrame = CFrame.lookAt(dpos, dpos + face);
	(p.eye :: BasePart).CFrame = CFrame.lookAt(dpos + face * 2.6, dpos + face * 4)
	local vr = s.vision :: number
	local vision = p.vision :: BasePart
	vision.Size = Vector3.new(0.3, vr * 2, vr * 2)
	vision.CFrame = CFrame.new(o + Vector3.new(s.dx, p.y0 + 0.3, s.dz)) * CFrame.Angles(0, 0, math.pi / 2)
	local beam = p.beam :: BasePart
	beam.Size = Vector3.new(vr * 1.2, 0.3, vr)
	beam.CFrame = CFrame.lookAt(
		o + Vector3.new(s.dx, p.y0 + 0.5, s.dz) + face * (vr / 2),
		o + Vector3.new(s.dx, p.y0 + 0.5, s.dz) + face * vr
	) * CFrame.Angles(0, math.pi, 0)
	for _, light in p.lamps :: { PointLight } do
		light.Enabled = not s.blackout
	end
	for _, sign in p.signs :: { BasePart } do
		sign.Transparency = if s.blackout then 0.92 else 0
	end
	(p.core :: BasePart).Transparency = if s.carrying then 1 else 0
	(p.gateDoor :: BasePart).Transparency = if s.gateOpen then 0.9 else 0.2
	(p.gateDoor :: BasePart).CanCollide = not s.gateOpen
	local prompts = p.prompts :: { [string]: ProximityPrompt }
	prompts.CutPower.Enabled = not s.powerCut and s.phase ~= "Won" and s.phase ~= "Lost"
	prompts.Reroute.Enabled = s.powerCut and s.choice == nil
	prompts.OpenEscape.Enabled = s.powerCut and s.choice == nil
	prompts.GrabCore.Enabled = not s.carrying and s.phase ~= "Won" and s.phase ~= "Lost"
end

local acc = 0
local tickNo = 0
local pendingEvents: { [number]: { any } } = {}
RunService.Heartbeat:Connect(function(dt: number)
	acc = math.min(acc + dt, TICK * 5)
	while acc >= TICK do
		acc -= TICK
		tickNo += 1
		local outputs = MatchCore.step(core, TICK, worldPos)
		for _, o in outputs do
			local player = Players:GetPlayerByUserId(o.userId)
			local a = arenas[o.userId]
			local m = core.matches[o.userId]
			if player and a and m then
				if a.mode ~= m.mode then
					buildArena(player, m)
					a = arenas[o.userId]
				end
				if o.snapshot.mode == "LawSport" then
					presentLaw(a, o.snapshot, os.clock())
				else
					presentHeist(a, o.snapshot)
				end
				local pe = pendingEvents[o.userId] or {}
				for _, e in o.events do
					table.insert(pe, e)
				end
				pendingEvents[o.userId] = pe
				if tickNo % 3 == 0 or #pe > 0 then
					stateRemote:FireClient(player, o.snapshot, pe)
					pendingEvents[o.userId] = {}
				end
			end
		end
	end
end)

-- Falling off a floating island respawns (never a loss of round state)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local r = rootOf(player)
			local m = core.matches[player.UserId]
			local character = player.Character
			if r and m and character and r.Position.Y < -60 then
				character:PivotTo(spawnCFrame(m))
				MatchCore.resetTrack(core, player.UserId)
			end
		end
	end
end)

print("[SR] Steal Reality server ready", Config.RULESET_VERSION, Config.HEIST_RULESET_VERSION)
