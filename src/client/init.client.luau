--!strict
-- Steal Reality client: input, aim preview, HUD, FX. Presentation only.
-- Every button sends a bounded intent; every outcome shown comes from a server snapshot.
-- Essential cues (chicken, capsule, lawball, well ring, vault, bot telegraph, drone vision)
-- are server-built parts and look identical on every Adaptive Reality tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local AQ = require(Shared:WaitForChild("AdaptiveQuality"))

local L = Config.Law
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local intentRemote = ReplicatedStorage:WaitForChild(Protocol.REMOTE_INTENT) :: RemoteEvent
local stateRemote = ReplicatedStorage:WaitForChild(Protocol.REMOTE_STATE) :: RemoteEvent

-- Original synthesized cues live in assets/audio (see docs/art/ASSET_PROVENANCE.csv).
-- They must be uploaded by the owner before ids exist; empty id => silent, visuals still carry
-- every cue (sound-off parity is a requirement, not a fallback).
local SOUND_IDS: { [string]: string } = {
	steal = "",
	throw = "",
	plant = "",
	bounce = "",
	botTelegraph = "",
	recover = "",
	goal = "",
	miss = "",
	ui = "",
	blackout = "",
	caught = "",
	escaped = "",
}

local TOK = {
	gravity = Color3.fromRGB(51, 224, 255),
	objective = Color3.fromRGB(255, 176, 32),
	field = Color3.fromRGB(155, 92, 255),
	hostile = Color3.fromRGB(255, 46, 136),
	cue = Color3.fromRGB(255, 246, 194),
	ink = Color3.fromRGB(24, 22, 40),
	vault = Color3.fromRGB(70, 230, 170),
}

-- ---------------- settings ----------------
local settings = { reducedMotion = false, sound = true }
local quality = AQ.new(3, true, os.clock())

-- ---------------- intent sending ----------------
local seq = 0
local function send(action: string, fields: { [string]: any }?)
	seq += 1
	local payload: { [string]: any } = { seq = seq, action = action }
	if fields then
		for k, v in fields do
			payload[k] = v
		end
	end
	intentRemote:FireServer(payload)
end

local function play(name: string)
	if not settings.sound then
		return
	end
	local id = SOUND_IDS[name]
	if id == nil or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = SoundService
	s.PlayOnRemove = false
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- ---------------- UI construction ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "StealRealityHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end
local function stroke(inst: GuiObject, color: Color3, th: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextStrokeColor3 = TOK.ink
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = textSize
	c.Parent = t
	t.Parent = parent
	return t
end
local function button(
	parent: Instance,
	text: string,
	color: Color3,
	size: UDim2,
	pos: UDim2,
	glyph: string?
): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = size
	b.Position = pos
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = if glyph then glyph .. "\n" .. text else text
	b.TextColor3 = TOK.ink
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 26
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = b
	corner(b, 999)
	stroke(b, Color3.new(1, 1, 1), 3)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = b
	b.Parent = parent
	return b
end

-- Right-thumb cluster (anchored bottom-right, generous targets, clear of the jump button
-- by sitting above/left of it; sizes in scale so small phones keep large targets).
local cluster = Instance.new("Frame")
cluster.Name = "ActionCluster"
cluster.BackgroundTransparency = 1
cluster.AnchorPoint = Vector2.new(1, 1)
cluster.Position = UDim2.new(1, -12, 1, -12)
cluster.Size = UDim2.new(0.42, 0, 0.62, 0)
cluster.Parent = gui

local throwBtn =
	button(cluster, "THROW", TOK.gravity, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.42, 0.42), "➶")
local plantBtn =
	button(cluster, "PLANT", TOK.field, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.78, 0.2), "◎")
local recoverBtn =
	button(cluster, "RECOVER", TOK.cue, UDim2.fromScale(0.26, 0.26), UDim2.fromScale(0.12, 0.2), "↺")
plantBtn.TextColor3 = Color3.new(1, 1, 1)

local hint = label(gui, "", UDim2.new(0.6, 0, 0, 44), UDim2.new(0.2, 0, 0, 56), 34)
local timerLbl = label(gui, "1:30", UDim2.new(0, 120, 0, 40), UDim2.new(0.5, -60, 0, 8), 36)
local aimInfo = label(gui, "", UDim2.new(0.4, 0, 0, 30), UDim2.new(0.3, 0, 0.7, 0), 24)

-- Heist HUD
local meterBack = Instance.new("Frame")
meterBack.Size = UDim2.new(0.3, 0, 0, 14)
meterBack.Position = UDim2.new(0.35, 0, 0, 104)
meterBack.BackgroundColor3 = TOK.ink
meterBack.BackgroundTransparency = 0.3
corner(meterBack, 7)
meterBack.Parent = gui
local meter = Instance.new("Frame")
meter.Size = UDim2.fromScale(0, 1)
meter.BackgroundColor3 = TOK.hostile
corner(meter, 7)
meter.Parent = meterBack
local _meterLbl = label(meterBack, "SEEN", UDim2.new(0, 60, 0, 20), UDim2.new(1, 6, 0, -3), 18)

-- Outcome card (AGAIN is one tap, always immediately available; no shop, no forced podium)
local card = Instance.new("Frame")
card.Name = "Outcome"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.45)
card.Size = UDim2.fromScale(0.46, 0.5)
card.BackgroundColor3 = TOK.ink
card.BackgroundTransparency = 0.15
card.Visible = false
corner(card, 22)
stroke(card, TOK.objective, 4)
card.Parent = gui
local cardTitle = label(card, "IMPOSSIBLE!", UDim2.fromScale(0.9, 0.28), UDim2.fromScale(0.05, 0.04), 64)
local cardBody = label(card, "", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.33), 26)
local againBtn = Instance.new("TextButton")
againBtn.Size = UDim2.fromScale(0.5, 0.26)
againBtn.Position = UDim2.fromScale(0.06, 0.66)
againBtn.BackgroundColor3 = TOK.objective
againBtn.Font = Enum.Font.FredokaOne
againBtn.TextScaled = true
againBtn.Text = "AGAIN"
againBtn.TextColor3 = TOK.ink
corner(againBtn, 16)
againBtn.Parent = card
local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.fromScale(0.32, 0.2)
switchBtn.Position = UDim2.fromScale(0.62, 0.69)
switchBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 120)
switchBtn.Font = Enum.Font.FredokaOne
switchBtn.TextScaled = true
switchBtn.Text = "OTHER GAME"
switchBtn.TextColor3 = Color3.new(1, 1, 1)
corner(switchBtn, 14)
switchBtn.Parent = card

-- Settings (gear): graphics tier, reduced motion, sound
local gear = Instance.new("TextButton")
gear.Size = UDim2.new(0, 44, 0, 44)
gear.Position = UDim2.new(0, 8, 0, 56)
gear.BackgroundColor3 = TOK.ink
gear.BackgroundTransparency = 0.3
gear.Text = "⚙"
gear.TextScaled = true
gear.TextColor3 = Color3.new(1, 1, 1)
corner(gear, 22)
gear.Parent = gui
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 230, 0, 150)
panel.Position = UDim2.new(0, 8, 0, 104)
panel.BackgroundColor3 = TOK.ink
panel.BackgroundTransparency = 0.15
panel.Visible = false
corner(panel, 12)
panel.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = panel
local function toggleRow(textFn: () -> string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = Color3.fromRGB(60, 58, 90)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = textFn()
	corner(b, 8)
	b.Parent = panel
	b.Activated:Connect(function()
		onClick()
		b.Text = textFn()
	end)
	return b
end
toggleRow(function()
	return "Graphics: "
		.. (if quality.auto then "Auto (" .. AQ.TIERS[quality.tier] .. ")" else AQ.TIERS[quality.tier])
end, function()
	-- cycle Auto -> Survival -> Lite -> Balanced -> High -> Ultra -> Auto
	if quality.auto then
		quality = AQ.setManual(quality, 1)
	elseif quality.tier >= 5 then
		quality = AQ.setAuto(quality)
	else
		quality = AQ.setManual(quality, quality.tier + 1)
	end
end)
toggleRow(function()
	return "Reduced motion: " .. (if settings.reducedMotion then "ON" else "OFF")
end, function()
	settings.reducedMotion = not settings.reducedMotion
end)
toggleRow(function()
	return "Sound: " .. (if settings.sound then "ON" else "OFF")
end, function()
	settings.sound = not settings.sound
end)
gear.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- ---------------- local-only FX layer ----------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "SR_LocalFX"
fxFolder.Parent = workspace

local preview = Instance.new("Part")
preview.Name = "AimPreview"
preview.Anchored = true
preview.CanCollide = false
preview.CanQuery = false
preview.Material = Enum.Material.Neon
preview.Color = TOK.gravity
preview.Transparency = 1
preview.Parent = fxFolder
local plantPreview = Instance.new("Part")
plantPreview.Name = "PlantPreview"
plantPreview.Shape = Enum.PartType.Cylinder
plantPreview.Anchored = true
plantPreview.CanCollide = false
plantPreview.CanQuery = false
plantPreview.Material = Enum.Material.ForceField
plantPreview.Color = TOK.field
plantPreview.Size = Vector3.new(0.4, L.wellRadius * 2, L.wellRadius * 2)
plantPreview.Transparency = 1
plantPreview.Parent = fxFolder

local blackoutCC = Instance.new("ColorCorrectionEffect")
blackoutCC.Name = "SR_Blackout"
blackoutCC.Enabled = false
blackoutCC.Brightness = -0.25
blackoutCC.Contrast = 0.15
blackoutCC.TintColor = Color3.fromRGB(150, 160, 255)
blackoutCC.Parent = Lighting

local function popText(text: string, color: Color3)
	local t = label(gui, text, UDim2.new(0.5, 0, 0, 70), UDim2.new(0.25, 0, 0.28, 0), 64)
	t.TextColor3 = color
	if settings.reducedMotion then
		task.delay(0.9, function()
			t:Destroy()
		end)
		return
	end
	local tw = TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.25, 0, 0.2, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tw:Play()
	tw.Completed:Once(function()
		t:Destroy()
	end)
end

local function burst(at: Vector3, color: Color3, amount: number)
	local profile = AQ.PROFILES[quality.tier]
	local n = math.floor(amount * profile.particles)
	if n <= 0 then
		return
	end
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = at
	a.Parent = fxFolder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 0.6
	pe.Speed = NumberRange.new(18, 40)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(n)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

-- decorative clouds scale with tier (never placed in the play volume)
local clouds: { BasePart } = {}
local cloudOrigin: Vector3? = nil
local function rebuildClouds(origin: Vector3)
	for _, c in clouds do
		c:Destroy()
	end
	table.clear(clouds)
	local count = AQ.PROFILES[quality.tier].clouds
	local rng = Random.new(42)
	for _ = 1, count do
		local c = Instance.new("Part")
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.Shape = Enum.PartType.Ball
		local s = rng:NextNumber(20, 46)
		c.Size = Vector3.new(s, s, s)
		c.Color = Color3.new(1, 1, 1)
		c.Material = Enum.Material.SmoothPlastic
		c.Transparency = 0.15
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(150, 260)
		c.Position = origin + Vector3.new(math.cos(ang) * r, rng:NextNumber(-60, 40), math.sin(ang) * r)
		c.Parent = fxFolder
		table.insert(clouds, c)
	end
end

-- ---------------- smoothed visual proxies (presentation only) ----------------
-- The server moves anchored rule-objects at its tick; replication of those CFrames is stepped.
-- The client hides the server copies locally and renders local clones that ease toward the
-- latest server state. Rules, hitboxes and scoring stay 100% on the server copies.
type Proxy = { source: Model, clone: Model, target: CFrame?, lastPos: Vector3? }
local proxies: { [Model]: Proxy } = {}
local function proxyFor(source: Model?): Proxy?
	if source == nil or source.PrimaryPart == nil then
		return nil
	end
	local p = proxies[source]
	if p and p.clone.Parent then
		return p
	end
	local ok, cloned = pcall(function(): Model?
		return source:Clone()
	end)
	if not ok or not cloned then
		return nil
	end
	local clone = cloned :: Model
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("ProximityPrompt") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	clone.Name = source.Name .. "_Smooth"
	clone.Parent = fxFolder
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	local created: Proxy = { source = source, clone = clone, target = nil, lastPos = nil }
	proxies[source] = created
	return created
end
local function clearProxies()
	for src, p in proxies do
		p.clone:Destroy()
		proxies[src] = nil
	end
end
local function stepProxy(p: Proxy, dt: number, reduced: boolean)
	local src = p.source
	if src.Parent == nil then
		p.clone:Destroy()
		proxies[src] = nil
		return
	end
	-- mirror per-part visibility the server toggles (capsule, telegraph ring)
	local srcRoot = src.PrimaryPart :: BasePart
	local target = srcRoot.CFrame
	local cur = (p.clone.PrimaryPart :: BasePart).CFrame
	local alpha = 1 - math.exp(-18 * dt)
	local nextCf = cur:Lerp(target, alpha)
	if (target.Position - cur.Position).Magnitude > 40 then
		nextCf = target -- teleport/reset: snap, never drift across the arena
	end
	-- presentation-only lean into motion (disabled under reduced motion)
	if not reduced and p.lastPos then
		local v = (nextCf.Position - p.lastPos) / math.max(dt, 1e-3)
		local lean = math.clamp(v.Magnitude / 80, 0, 0.35)
		if lean > 0.01 then
			local axis = Vector3.yAxis:Cross(Vector3.new(v.X, 0, v.Z))
			if axis.Magnitude > 1e-3 then
				nextCf = CFrame.fromAxisAngle(axis.Unit, lean) * (nextCf - nextCf.Position) + nextCf.Position
			end
		end
	end
	p.lastPos = nextCf.Position
	p.clone:PivotTo(nextCf)
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") then
			local twin = p.clone:FindFirstChild(d.Name, true)
			if twin and twin:IsA("BasePart") and twin.Transparency ~= d.Transparency then
				twin.Transparency = d.Transparency
			end
		end
	end
end

-- ---------------- state from server ----------------
local snap: { [string]: any } = {}
local lastPhase = ""
local originV = Vector3.zero

local function originOf(s: { [string]: any }): Vector3
	return Vector3.new(s.originX or 0, 0, s.originZ or 0)
end

local function rootPart(): BasePart?
	local ch = player.Character
	local r = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
	return if r and r:IsA("BasePart") then r else nil
end

local function chickenWorld(): Vector3
	return originV + Vector3.new(snap.cx or 0, L.platformY + L.hoverHeight, snap.cz or 0)
end

local function onEvent(e: { [string]: any })
	local at = if e.x then originV + Vector3.new(e.x, L.platformY + L.hoverHeight, e.z) else nil
	local k = e.kind
	if k == "steal" then
		play("steal")
		popText("GRAVITY STOLEN!", TOK.gravity)
		if at then
			burst(at, TOK.gravity, 60)
		end
	elseif k == "hit" then
		play("throw")
		if at then
			burst(at, TOK.objective, 30)
		end
	elseif k == "miss" then
		play("miss")
		popText("MISS", TOK.cue)
	elseif k == "bounce" then
		play("bounce")
	elseif k == "plant" then
		play("plant")
	elseif k == "botTelegraph" then
		play("botTelegraph")
	elseif k == "botStunned" then
		popText("BOT STUNNED", TOK.gravity)
	elseif k == "botCounter" then
		popText("SHOVED!", TOK.hostile)
	elseif k == "recover" then
		play("recover")
		popText("RECOVERED", TOK.cue)
	elseif k == "goal" then
		play("goal")
		if at then
			burst(at, TOK.objective, 140)
		end
	elseif k == "gravitySnap" then
		popText("GRAVITY SNAPPED BACK", TOK.cue)
	elseif k == "blackout" then
		play("blackout")
		popText("BLACKOUT!", TOK.gravity)
	elseif k == "reroute" then
		popText("SECURITY REROUTED", TOK.gravity)
	elseif k == "gateOpen" then
		popText("GATE OPEN — ALARM!", TOK.hostile)
	elseif k == "coreGrabbed" then
		popText("CORE GRABBED", TOK.objective)
	elseif k == "caught" then
		play("caught")
	elseif k == "escaped" then
		play("escaped")
	elseif k == "teleportRejected" then
		-- server ignored an impossible jump; nothing to show the player
	end
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function refreshHUD()
	local s = snap
	local mode = s.mode
	local phase = s.phase
	timerLbl.Text = fmtTime(s.remaining or Config.ROUND_SECONDS)
	local over = phase == "Won" or phase == "Lost"
	card.Visible = over
	local isLaw = mode == "LawSport"
	throwBtn.Visible = isLaw and phase == "Live"
	plantBtn.Visible = isLaw and phase == "Live"
	local held = s.lawball == "Held"
	throwBtn.AutoButtonColor = held
	throwBtn.BackgroundTransparency = if held then 0 else 0.6
	plantBtn.BackgroundTransparency = if held then 0 else 0.6
	recoverBtn.Visible = isLaw and s.recoverOpen == true
	meterBack.Visible = mode == "GridHeist" and phase == "Live"
	meter.Size = UDim2.fromScale(math.clamp(s.detect or 0, 0, 1), 1)
	blackoutCC.Enabled = mode == "GridHeist" and s.blackout == true
	if isLaw then
		if phase == "Ready" then
			hint.Text = "Grab the chicken's GRAVITY ⤴"
		elseif phase == "Live" then
			hint.Text = if s.botState == "Telegraph"
				then "⚠ BOT WINDING UP"
				elseif held then "THROW or PLANT → get it in the VAULT"
				else ""
		else
			hint.Text = ""
		end
		if over then
			if phase == "Won" then
				cardTitle.Text = "IMPOSSIBLE!"
				cardTitle.TextColor3 = TOK.objective
				local st = s.stats or {}
				cardBody.Text = string.format(
					"Vaulted in %.1fs · %d throws · %d wells · %d bank bounces",
					s.elapsed or 0,
					st.throws or 0,
					st.plants or 0,
					st.bounces or 0
				)
			else
				cardTitle.Text = "SO CLOSE!"
				cardTitle.TextColor3 = TOK.cue
				cardBody.Text = "Time ran out. Try the other choice?"
			end
		end
	elseif mode == "GridHeist" then
		if phase == "Ready" then
			hint.Text = "Cut the power at the substation ⚡"
		elseif phase == "Live" then
			if not s.powerCut then
				hint.Text = "Cut the power ⚡"
			elseif s.choice == nil and not s.carrying then
				hint.Text = "REROUTE security  or  OPEN the escape gate"
			elseif not s.carrying then
				hint.Text = "Grab the CORE (center)"
			else
				hint.Text = if s.gateOpen then "Escape: gate or far corner!" else "Escape to the far corner!"
			end
		else
			hint.Text = ""
		end
		if over then
			if phase == "Won" then
				cardTitle.Text = "ESCAPED!"
				cardTitle.TextColor3 = TOK.vault
				cardBody.Text = string.format("Heist in %.1fs", s.elapsed or 0)
			else
				cardTitle.Text = "CAUGHT!"
				cardTitle.TextColor3 = TOK.hostile
				cardBody.Text = "The drone saw you. Different route?"
			end
		end
	end
end

stateRemote.OnClientEvent:Connect(function(s: any, events: any)
	if type(s) ~= "table" then
		return
	end
	if s.ack ~= nil then
		return -- intent acknowledgement (diagnostics only)
	end
	snap = s
	local o = originOf(s)
	if cloudOrigin == nil or (cloudOrigin :: Vector3 - o).Magnitude > 1 then
		cloudOrigin = o
		rebuildClouds(o)
	end
	if s.mode == "LawSport" then
		for _, arena in workspace:GetChildren() do
			if arena:IsA("Model") and string.sub(arena.Name, 1, 6) == "Arena_" then
				local ch = arena:FindFirstChild("GoldenChicken")
				local root = if ch and ch:IsA("Model") then ch.PrimaryPart else nil
				if root and (root.Position - o).Magnitude < Config.ARENA_SPACING / 2 then
					proxyFor(ch :: Model)
					local bot = arena:FindFirstChild("RogueLawBot")
					if bot and bot:IsA("Model") then
						proxyFor(bot)
					end
				end
			end
		end
	elseif next(proxies) ~= nil then
		clearProxies()
	end
	originV = o
	if type(events) == "table" then
		for _, e in events do
			if type(e) == "table" then
				onEvent(e)
			end
		end
	end
	if s.phase ~= lastPhase then
		if s.phase == "Won" then
			popText(if s.mode == "LawSport" then "IMPOSSIBLE!" else "ESCAPED!", TOK.objective)
		end
		lastPhase = s.phase
	end
	refreshHUD()
end)

-- ---------------- aiming: two-step preview then commit ----------------
-- Touch: press THROW, drag sideways to angle (±60° from camera forward), drag up for power,
-- release to fire; drag far down to cancel. Mouse/keyboard: hold F (aim at cursor, power by
-- hold time). Gamepad: hold R2 (aim camera forward, power by hold time).
type Aim = { kind: string, startPos: Vector2, cur: Vector2, startedAt: number, device: string }
local aim: Aim? = nil
local MAX_ANGLE = math.rad(60)
local stick2 = Vector2.zero

local function flatForward(): Vector3
	local f = camera.CFrame.LookVector
	local v = Vector3.new(f.X, 0, f.Z)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.new(0, 0, 1)
end

local function mouseGround(): Vector3?
	local m = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(m.X, m.Y)
	local planeY = L.platformY
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function aimParams(a: Aim): (Vector3, number, boolean)
	local root = rootPart()
	local base = flatForward()
	if a.device == "touch" then
		local d = a.cur - a.startPos
		local ang = math.clamp(d.X / 140, -1, 1) * MAX_ANGLE
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, -ang) * base)
		local power = math.clamp(0.55 - d.Y / 220, L.throwMinPower, 1)
		return dir, power, d.Y > 150
	elseif a.device == "mouse" and root then
		local g = mouseGround()
		local dir = base
		if g then
			local v = Vector3.new(g.X - root.Position.X, 0, g.Z - root.Position.Z)
			if v.Magnitude > 1 then
				dir = v.Unit
			end
		end
		return dir, math.clamp(L.throwMinPower + (os.clock() - a.startedAt) / 0.9, L.throwMinPower, 1), false
	elseif a.device == "gamepad" and stick2.Magnitude > 0.25 then
		-- right stick steers the aim up to ±60° off camera-forward (no auto-target)
		local ang = math.clamp(stick2.X, -1, 1) * MAX_ANGLE
		local dir = CFrame.fromAxisAngle(Vector3.yAxis, -ang) * base
		return dir, math.clamp(L.throwMinPower + (os.clock() - a.startedAt) / 0.9, L.throwMinPower, 1), false
	end
	return base, math.clamp(L.throwMinPower + (os.clock() - a.startedAt) / 0.9, L.throwMinPower, 1), false
end

local function plantTarget(a: Aim): Vector3?
	local root = rootPart()
	if not root then
		return nil
	end
	local p = root.Position
	if a.device == "mouse" then
		local g = mouseGround()
		if g then
			local off = Vector3.new(g.X - p.X, 0, g.Z - p.Z)
			if off.Magnitude > L.plantRange - 1 then
				off = off.Unit * (L.plantRange - 1)
			end
			return Vector3.new(p.X + off.X, L.platformY, p.Z + off.Z)
		end
	end
	local dir, power = aimParams(a)
	local distance = 8 + (power - L.throwMinPower) / (1 - L.throwMinPower) * (L.plantRange - 10)
	local t = p + dir * distance
	return Vector3.new(t.X, L.platformY, t.Z)
end

local function beginAim(kind: string, device: string, pos: Vector2)
	if snap.mode ~= "LawSport" or snap.phase ~= "Live" or snap.lawball ~= "Held" then
		return
	end
	aim = { kind = kind, startPos = pos, cur = pos, startedAt = os.clock(), device = device }
	play("ui")
end

local function endAim(commit: boolean)
	local a = aim
	aim = nil
	preview.Transparency = 1
	plantPreview.Transparency = 1
	aimInfo.Text = ""
	if not a or not commit then
		return
	end
	local root = rootPart()
	if not root then
		return
	end
	local dir, power, cancel = aimParams(a)
	if cancel then
		popText("CANCELLED", TOK.cue)
		return
	end
	if a.kind == "throw" then
		send("Throw", { aimX = dir.X, aimZ = dir.Z, power = power })
	else
		local t = plantTarget(a)
		if t then
			send("Plant", { x = t.X - originV.X, z = t.Z - originV.Z })
		end
	end
end

local function hookTouchButton(btn: TextButton, kind: string)
	btn.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			beginAim(kind, "touch", Vector2.new(input.Position.X, input.Position.Y))
		elseif t == Enum.UserInputType.MouseButton1 then
			beginAim(kind, "mouse", Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
end
hookTouchButton(throwBtn, "throw")
hookTouchButton(plantBtn, "plant")

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick2 = Vector2.new(input.Position.X, input.Position.Y)
	end
	local a = aim
	if a and a.device == "touch" and input.UserInputType == Enum.UserInputType.Touch then
		a.cur = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	local a = aim
	if not a then
		return
	end
	local t = input.UserInputType
	if
		(a.device == "touch" and t == Enum.UserInputType.Touch)
		or (a.device == "mouse" and (t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.R))
		or (
			a.device == "gamepad"
			and (input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL2)
		)
	then
		endAim(true)
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.F then
		beginAim("throw", "mouse", UserInputService:GetMouseLocation())
	elseif k == Enum.KeyCode.R then
		beginAim("plant", "mouse", UserInputService:GetMouseLocation())
	elseif k == Enum.KeyCode.ButtonR2 then
		beginAim("throw", "gamepad", Vector2.zero)
	elseif k == Enum.KeyCode.ButtonL2 then
		beginAim("plant", "gamepad", Vector2.zero)
	elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonB then
		if snap.recoverOpen then
			send("Recover")
		end
	elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
		if snap.phase == "Won" or snap.phase == "Lost" then
			send("Again")
		end
	end
end)

recoverBtn.Activated:Connect(function()
	send("Recover")
end)
againBtn.Activated:Connect(function()
	play("ui")
	send("Again")
end)
switchBtn.Activated:Connect(function()
	play("ui")
	send("ChooseMode", { mode = if snap.mode == "LawSport" then "GridHeist" else "LawSport" })
end)

-- ---------------- per-frame: previews + adaptive reality ----------------
local lastNow = os.clock()
RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	-- Adaptive Reality: sample frame time; cap by the player's own Roblox quality setting
	local cap = 5
	pcall(function()
		local lvl = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		if lvl ~= Enum.SavedQualitySetting.Automatic then
			cap = math.clamp(math.ceil(lvl.Value / 2), 1, 5)
		end
	end)
	local prevTier = quality.tier
	quality = AQ.sample(quality, dt * 1000, now - lastNow, now, cap)
	lastNow = now
	if quality.tier ~= prevTier and cloudOrigin then
		rebuildClouds(cloudOrigin :: Vector3)
	end

	for _, p in proxies do
		stepProxy(p, dt, settings.reducedMotion)
	end
	local a = aim
	local root = rootPart()
	if a and root and snap.phase == "Live" then
		local dir, power, cancel = aimParams(a)
		if a.kind == "throw" then
			local from = Vector3.new(root.Position.X, L.platformY + L.hoverHeight, root.Position.Z)
			local len = L.lawballRange
			preview.Size = Vector3.new(0.6 + power * 0.8, 0.3, len)
			preview.CFrame = CFrame.lookAt(from + dir * (len / 2), from + dir * len)
			preview.Transparency = if cancel then 0.85 else 0.35
			aimInfo.Text = if cancel
				then "release to CANCEL"
				else string.format("POWER %d%%", math.floor(power * 100))
		else
			local t = plantTarget(a)
			if t then
				plantPreview.CFrame = CFrame.new(t + Vector3.new(0, 0.6, 0))
					* CFrame.Angles(0, 0, math.pi / 2)
				plantPreview.Transparency = if cancel then 0.85 else 0.4
			end
			aimInfo.Text = if cancel then "release to CANCEL" else "release to PLANT"
		end
	end
	-- subtle capsule pulse to draw the first tap (reduced motion: static)
	if snap.mode == "LawSport" and snap.phase == "Ready" and not settings.reducedMotion then
		hint.TextTransparency = 0.15 + 0.15 * math.sin(now * 4)
	else
		hint.TextTransparency = 0
	end
	local _ = chickenWorld
end)

refreshHUD()
