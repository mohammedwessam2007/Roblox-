--!nocheck
-- EMULATED ROBLOX RUNTIME (not Studio). Loads the Rojo-built place file, runs the REAL
-- ServerScriptService.Server Script and StarterPlayerScripts.Client LocalScript sources against
-- Lune's Roblox instance model (property names/types validated by the Roblox reflection
-- database), with engine services (signals, remotes, prompts, input, heartbeat) emulated here.
-- Catches runtime errors, wrong property names, nil paths and broken game flow.
-- It does NOT emulate physics, rendering, replication, real networking or devices.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance, Vector3, CFrame, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Enum
local placePath = process.args[1] or "build/StealReality.rbxl"
local game = roblox.deserializePlace(fs.readFile(placePath))
local workspace = game:GetService("Workspace")

-- ---------- identity keys + signals ----------
local nextId = 0
local function key(inst)
	local k = inst:GetAttribute("__emu")
	if not k then
		nextId += 1
		k = nextId
		inst:SetAttribute("__emu", k)
	end
	return k
end
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ fns = {} }, Signal) end
function Signal:Connect(fn)
	local entry = { fn = fn, on = true }
	table.insert(self.fns, entry)
	return { Disconnect = function() entry.on = false end, Connected = true }
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c.Disconnect(); fn(...) end)
	return c
end
function Signal:Fire(...)
	for _, e in table.clone(self.fns) do
		if e.on then e.fn(...) end
	end
end
local signals = {}
local function sig(inst, name)
	local k = key(inst) .. ":" .. name
	signals[k] = signals[k] or Signal.new()
	return signals[k]
end
local function eventProp(class, name)
	roblox.implementProperty(class, name, function(self) return sig(self, name) end)
end
for _, pair in {
	{ "Players", "PlayerAdded" }, { "Players", "PlayerRemoving" }, { "Player", "CharacterAdded" },
	{ "RemoteEvent", "OnServerEvent" }, { "RemoteEvent", "OnClientEvent" },
	{ "RunService", "Heartbeat" }, { "RunService", "RenderStepped" },
	{ "ProximityPrompt", "Triggered" }, { "GuiButton", "Activated" }, { "GuiObject", "InputBegan" },
	{ "UserInputService", "InputBegan" }, { "UserInputService", "InputChanged" }, { "UserInputService", "InputEnded" },
	{ "Sound", "Ended" },
} do
	eventProp(pair[1], pair[2])
end

-- ---------- engine methods ----------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local localPlayer = nil
roblox.implementMethod("Players", "GetPlayers", function(self) return self:GetChildren() end)
roblox.implementMethod("Players", "GetPlayerByUserId", function(self, id)
	for _, p in self:GetChildren() do if p.UserId == id then return p end end
	return nil
end)
roblox.implementMethod("RunService", "IsStudio", function() return true end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local c = self:FindFirstChild(name)
	if not c then error("WaitForChild would yield forever: " .. self:GetFullName() .. "." .. name) end
	return c
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	local pp = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	if pp then pp.CFrame = cf; pp.Position = cf.Position end
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	local pp = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	return if pp then pp.CFrame else CFrame.new()
end)
local firedToClient = {}
roblox.implementMethod("RemoteEvent", "FireServer", function(self, ...)
	sig(self, "OnServerEvent"):Fire(localPlayer, ...)
end)
roblox.implementMethod("RemoteEvent", "FireClient", function(self, plr, ...)
	assert(plr and plr:IsA("Player"), "FireClient needs a Player")
	table.insert(firedToClient, { plr = plr.UserId, args = { ... } })
	if plr == localPlayer then sig(self, "OnClientEvent"):Fire(...) end
end)
local mouse = roblox.Vector2.new(400, 300)
roblox.implementMethod("UserInputService", "GetMouseLocation", function() return mouse end)
-- Lune quirk (NR-003): CFrame.lookAt(...).LookVector points away from the target, unlike Roblox.
-- The harness records the intended camera target and builds the screen-center ray from it.
local camTarget = Vector3.new(0, 0, 1)
local function aimCamera(cam, from, to)
	cam.CFrame = CFrame.lookAt(from, to)
	camTarget = to
end
roblox.implementMethod("Camera", "ViewportPointToRay", function(self, x, y)
	local o = self.CFrame.Position
	return roblox.Ray.new(o, (camTarget - o).Unit)
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Instance", "GetFullName", function(self)
	local n, p = self.Name, self.Parent
	while p and p ~= game do n = p.Name .. "." .. n; p = p.Parent end
	return n
end)
local logged = {}
roblox.implementMethod("AnalyticsService", "LogCustomEvent", function(self, plr, name) table.insert(logged, name) end)

-- TweenService:Create returns a tween whose Completed fires on Play (instant)
local TweenService = game:GetService("TweenService")
roblox.implementMethod("TweenService", "Create", function(self, inst, info, goal)
	local completed = Signal.new()
	return {
		Completed = completed,
		Play = function()
			for k, v in goal do inst[k] = v end
			task.defer(function() completed:Fire(Enum.PlaybackState.Completed) end)
		end,
	}
end)

local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.Parent = workspace
workspace.CurrentCamera = camera

-- ---------- globals for script environments ----------
local RandomShim = {}
function RandomShim.new(seed)
	local s = (seed or 1) % 2147483647
	local o = {}
	function o:NextNumber(a, b)
		s = (s * 48271) % 2147483647
		return a + (b - a) * (s / 2147483647)
	end
	return o
end
local TweenInfoShim = { new = function(...) return { ... } end }
local function UserSettings()
	return { GetService = function() return { SavedQualityLevel = Enum.SavedQualitySetting.Automatic } end }
end

local moduleCache = {}
local scriptErrors = {}
local function makeEnv(scriptInst)
	local env = {}
	env.game, env.workspace, env.script = game, workspace, scriptInst
	env.Instance, env.Vector3, env.Vector2, env.CFrame, env.Color3 = Instance, Vector3, roblox.Vector2, CFrame, roblox.Color3
	env.UDim, env.UDim2, env.Enum = roblox.UDim, roblox.UDim2, Enum
	env.ColorSequence, env.NumberSequence, env.NumberSequenceKeypoint, env.NumberRange = roblox.ColorSequence, roblox.NumberSequence, roblox.NumberSequenceKeypoint, roblox.NumberRange
	env.TweenInfo, env.Random, env.UserSettings = TweenInfoShim, RandomShim, UserSettings
	env.task = task
	env.require = function(m)
		local k = key(m)
		if moduleCache[k] == nil then
			local fn = luau.load(m.Source, { debugName = m:GetFullName(), environment = makeEnv(m) })
			moduleCache[k] = fn()
		end
		return moduleCache[k]
	end
	return env
end
local function runScript(inst)
	local fn = luau.load(inst.Source, { debugName = inst:GetFullName(), environment = makeEnv(inst) })
	local ok, err = pcall(fn)
	if not ok then
		table.insert(scriptErrors, inst:GetFullName() .. ": " .. tostring(err))
	end
	return ok
end

-- ---------- test helpers ----------
local results = { pass = 0, fail = 0, lines = {} }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	local line = string.format("%s %s%s", cond and "PASS" or "FAIL", name, (not cond and detail) and (" :: " .. tostring(detail)) or "")
	table.insert(results.lines, line)
	print(line)
end
local function pump(seconds)
	local frames = math.floor(seconds * 60)
	for _ = 1, frames do
		sig(RunService, "Heartbeat"):Fire(1 / 60)
		sig(RunService, "RenderStepped"):Fire(1 / 60)
	end
	task.wait(0) -- let deferred tasks run
end
local lastSnap = nil
local function setCF(part, cf) part.CFrame = cf; part.Position = cf.Position end
local function makeCharacter(plr)
	local ch = Instance.new("Model")
	ch.Name = plr.Name
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	setCF(hrp, CFrame.new(0, 50, 0))
	hrp.Position = Vector3.new(0, 50, 0)
	hrp.Parent = ch
	local hum = Instance.new("Humanoid")
	hum.Parent = ch
	ch.PrimaryPart = hrp
	ch.Parent = workspace
	plr.Character = ch
	sig(plr, "CharacterAdded"):Fire(ch)
	return ch, hrp
end
local function addPlayer(id)
	local p = Instance.new("Player")
	p.Name = "Tester" .. id
	p.UserId = id
	local pg = Instance.new("PlayerGui")
	pg.Parent = p
	p.Parent = Players
	sig(Players, "PlayerAdded"):Fire(p)
	return p
end
local function arenaOf(slot) return workspace:FindFirstChild("Arena_" .. slot) end
local function findDesc(root, name)
	for _, d in root:GetDescendants() do if d.Name == name then return d end end
	return nil
end

-- ================= RUN =================
print("== boot server Script")
check("server script runs without error", runScript(game:GetService("ServerScriptService"):FindFirstChild("Server")), scriptErrors[#scriptErrors])
local RS = game:GetService("ReplicatedStorage")
check("remotes created", RS:FindFirstChild("SR_Intent") ~= nil and RS:FindFirstChild("SR_State") ~= nil)

print("== player joins (zero other players, no DataStore, no ghosts)")
localPlayer = addPlayer(1001)
Players.LocalPlayer = localPlayer
local ch, hrp = makeCharacter(localPlayer)
task.wait(0)
local arena = arenaOf(0)
check("solo Law arena built for first player", arena ~= nil)
check("chicken + capsule + vault + bot exist", arena and findDesc(arena, "GravityCapsule") and findDesc(arena, "VaultVolume") and findDesc(arena, "RogueLawBot") ~= nil)

-- capture snapshots the server sends this client
sig(RS:FindFirstChild("SR_State"), "OnClientEvent"):Connect(function(s, events)
	if type(s) == "table" and s.ack == nil then lastSnap = s end
	if process.env.EMU_TRACE and type(events) == "table" then
		for _, e in events do print("[EVT]", e.kind, e.x and math.floor(e.x), e.z and math.floor(e.z), e.info) end
	end
end)

print("== boot client LocalScript")
local client = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")
check("client script runs without error", runScript(client), scriptErrors[#scriptErrors])
local hud = localPlayer.PlayerGui:FindFirstChild("StealRealityHUD")
check("HUD built", hud ~= nil)
pump(0.5)
check("server snapshot reaches client (Ready)", lastSnap and lastSnap.phase == "Ready", lastSnap and lastSnap.phase)

print("== T=0-8s: walk to chicken, STEAL via ProximityPrompt")
local origin = Vector3.new(lastSnap.originX, 0, lastSnap.originZ)
setCF(hrp, CFrame.new(origin + Vector3.new(0, 8, -50)))
local prompt = findDesc(arena, "GravityCapsule"):FindFirstChildOfClass("ProximityPrompt")
check("steal prompt enabled while Ready", prompt and prompt.Enabled)
sig(prompt, "Triggered"):Fire(localPlayer)
pump(0.3)
check("phase Live after STEAL", lastSnap.phase == "Live", lastSnap.phase)
local cluster = hud:FindFirstChild("ActionCluster")
local throwBtn
for _, b in cluster:GetChildren() do if b:IsA("TextButton") and string.find(b.Text, "THROW") then throwBtn = b end end
check("THROW button visible after steal", throwBtn and throwBtn.Visible)
check("prompt disabled after steal", not prompt.Enabled)

print("== T=8-30s: THROW via real client input path (hold F, release) aimed at the Vault")
aimCamera(camera, origin + Vector3.new(0, 30, -70), origin + Vector3.new(0, 6, -20))
local function key(kc, ended)
	local input = { KeyCode = kc, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.new(400, 300, 0) }
	sig(UIS, ended and "InputEnded" or "InputBegan"):Fire(input, false)
end
key(Enum.KeyCode.F, false)
pump(1.0) -- charge power by holding ~1s (real os.clock based)
task.wait(0.95)
key(Enum.KeyCode.F, true)
pump(0.2)
check("lawball left the hand (Flying/Returning)", lastSnap.lawball ~= "Held", lastSnap.lawball)
local won = false
for _ = 1, 40 do
	pump(0.5)
	if lastSnap.phase == "Won" then won = true break end
	if lastSnap.lawball == "Held" and lastSnap.phase == "Live" then
		-- keep playing like a player: re-aim from behind the chicken toward the vault
		setCF(hrp, CFrame.new(origin + Vector3.new(lastSnap.cx, 8, lastSnap.cz - 10)))
		aimCamera(camera, origin + Vector3.new(lastSnap.cx, 30, lastSnap.cz - 30), origin + Vector3.new(lastSnap.cx, 6, lastSnap.cz + 25))
		key(Enum.KeyCode.F, false); task.wait(0.95); key(Enum.KeyCode.F, true)
	end
end
check("goal certified by server within the round", won, lastSnap.phase)
check("scoredEventId present", lastSnap.scoredEventId ~= nil, lastSnap.scoredEventId)
local card = hud:FindFirstChild("Outcome")
check("IMPOSSIBLE! outcome card visible", card and card.Visible)

print("== T=60-90s: one-tap AGAIN")
local again
for _, b in card:GetChildren() do if b:IsA("TextButton") and b.Text == "AGAIN" then again = b end end
sig(again, "Activated"):Fire()
pump(0.3)
check("AGAIN -> new round Ready", lastSnap.phase == "Ready" and lastSnap.round == 2, tostring(lastSnap.phase) .. " r" .. tostring(lastSnap.round))
check("card hidden after AGAIN", not card.Visible)

print("== zero-trust: forged payloads from this client")
local intent = RS:FindFirstChild("SR_Intent")
intent:FireServer({ seq = 9001, action = "SCORE" })
intent:FireServer({ seq = 9002, action = "Steal", score = 999 })
intent:FireServer("Win")
intent:FireServer({ seq = 9003, action = "Throw", aimX = 0 / 0, aimZ = 1, power = 1 })
pump(0.5)
check("forged remotes produce no score and no phase change", lastSnap.phase == "Ready" and lastSnap.scoredEventId == nil, lastSnap.phase)

print("== second player gets an isolated arena; leaving cleans up")
local p2 = addPlayer(2002)
makeCharacter(p2)
task.wait(0)
check("player 2 arena built in separate slot", arenaOf(1) ~= nil)
sig(Players, "PlayerRemoving"):Fire(p2)
p2.Parent = nil
task.wait(0)
check("player 2 arena destroyed on leave", arenaOf(1) == nil)

print("== OTHER GAME: switch to Grid Heist")
local switch
for _, b in card:GetChildren() do if b:IsA("TextButton") and b.Text == "OTHER GAME" then switch = b end end
sig(switch, "Activated"):Fire()
pump(0.5)
check("snapshot mode GridHeist", lastSnap.mode == "GridHeist", lastSnap.mode)
arena = arenaOf(0)
check("heist city built (drone vision, core, substation)", arena and findDesc(arena, "DroneVision") and findDesc(arena, "DataCore") and findDesc(arena, "Substation") ~= nil)
check("old Law arena removed", arena and findDesc(arena, "GravityCapsule") == nil)
pump(0.6) -- character respawn pivot
local H = { sub = { -56, -36 }, console = { 8, -52 }, core = { 0, 0 } }
-- legal walk (speed-bounded) to console
local function walkTo(x, z)
	local p = hrp.CFrame.Position
	local target = origin + Vector3.new(x, 8, z)
	for _ = 1, 400 do
		local d = target - hrp.Position
		if d.Magnitude < 1 then break end
		setCF(hrp, CFrame.new(hrp.CFrame.Position + d.Unit * math.min(d.Magnitude, 16 / 30)))
		pump(1 / 30)
	end
end
walkTo(H.sub[1], H.sub[2] + 8)
walkTo(H.sub[1], H.sub[2])
pump(0.1)
local cut = findDesc(arena, "Substation"):FindFirstChildOfClass("ProximityPrompt")
sig(cut, "Triggered"):Fire(localPlayer)
pump(0.3)
check("CUT POWER -> blackout", lastSnap.blackout == true and lastSnap.vision == 13, tostring(lastSnap.blackout) .. " v" .. tostring(lastSnap.vision))
local lampsOff = true
for _, d in arena:GetDescendants() do if d:IsA("PointLight") and d.Enabled then lampsOff = false end end
check("server lamps go dark", lampsOff)
check("client blackout color grade on", game:GetService("Lighting"):FindFirstChild("SR_Blackout").Enabled)
walkTo(H.console[1] - 30, H.console[2]) -- along the south street
walkTo(H.console[1], H.console[2])
sig(findDesc(arena, "RerouteConsole"):FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(localPlayer)
pump(0.3)
check("REROUTE SECURITY chosen (exclusive)", lastSnap.choice == "Reroute", lastSnap.choice)
print("== teleport exploit: jump straight to the exit")
setCF(hrp, CFrame.new(origin + Vector3.new(60, 8, 60)))
pump(0.5)
check("teleport to exit does not win", lastSnap.phase ~= "Won", lastSnap.phase)

print("== analytics events logged server-side (names only, no PII)")
check("goal + steal + replay events logged", table.find(logged, "goal_server_certified") and table.find(logged, "steal_succeeded") and table.find(logged, "voluntary_replay") ~= nil)

print(string.format("\nEMULATED_RUNTIME: %d passed, %d failed, %d script errors", results.pass, results.fail, #scriptErrors))
for _, e in scriptErrors do print("  SCRIPT ERROR: " .. e) end
process.exit(if results.fail == 0 and #scriptErrors == 0 then 0 else 1)
