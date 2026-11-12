--!strict
-- Procedural, original world art built from Roblox Parts (no marketplace assets).
-- Visual geometry mirrors the server rule geometry in Config exactly (vault box, pylons,
-- walls, buildings) so what players see is what the server evaluates.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local L = Config.Law
local H = Config.Heist

local WorldBuilder = {}

local TOK = {
	gravity = Color3.fromRGB(51, 224, 255),
	objective = Color3.fromRGB(255, 176, 32),
	field = Color3.fromRGB(155, 92, 255),
	hostile = Color3.fromRGB(255, 46, 136),
	cue = Color3.fromRGB(255, 246, 194),
	gold = Color3.fromRGB(255, 196, 40),
	goldDeep = Color3.fromRGB(230, 150, 20),
	vault = Color3.fromRGB(70, 230, 170),
	turf = Color3.fromRGB(122, 214, 120),
	stone = Color3.fromRGB(236, 232, 245),
	night = Color3.fromRGB(26, 28, 48),
	asphalt = Color3.fromRGB(52, 54, 70),
}
WorldBuilder.TOKENS = TOK

type Props = { [string]: any }

local function part(parent: Instance, props: Props): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Mesh" then
			(p :: any)[k] = v
		end
	end
	if props.Mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = props.Mesh
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function weldAll(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	root.Anchored = true
	root.CanCollide = false
	model.PrimaryPart = root
end

-- ===================== LAW SPORT: THE CHICKEN RUN =====================

function WorldBuilder.buildChicken(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "GoldenChicken"
	local root = part(m, {
		Name = "Root",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(12, 12, 12),
		Color = TOK.gold,
		Material = Enum.Material.SmoothPlastic,
	})
	part(m, {
		Name = "Chest",
		Size = Vector3.new(1, 1, 1),
		Mesh = Vector3.new(11, 10, 9),
		CFrame = CFrame.new(0, -0.5, 3.6),
		Color = Color3.fromRGB(255, 220, 90),
	})
	part(m, {
		Name = "Neck",
		Size = Vector3.new(1, 1, 1),
		Mesh = Vector3.new(4.2, 6, 4.2),
		CFrame = CFrame.new(0, 5.6, 3.2),
		Color = TOK.gold,
	})
	local head = part(m, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.4, 6.4, 6.4),
		CFrame = CFrame.new(0, 8.6, 4.2),
		Color = TOK.gold,
	})
	part(m, {
		Name = "Beak",
		ClassName = "WedgePart",
		Size = Vector3.new(2.2, 1.6, 2.8),
		CFrame = head.CFrame * CFrame.new(0, -0.4, 3.6) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(255, 120, 30),
	})
	for i, x in { -1.6, 1.6 } do
		part(m, {
			Name = "Eye" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.1, 2.1, 2.1),
			CFrame = head.CFrame * CFrame.new(x, 0.9, 2.2),
			Color = Color3.new(1, 1, 1),
		})
		part(m, {
			Name = "Pupil" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = head.CFrame * CFrame.new(x, 1.0, 3.05),
			Color = Color3.fromRGB(20, 20, 30),
		})
	end
	for i = -1, 1 do
		part(m, {
			Name = "Comb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = head.CFrame * CFrame.new(0, 3.1 - math.abs(i) * 0.5, i * 1.1),
			Color = Color3.fromRGB(235, 50, 60),
		})
	end
	for i, x in { -6.2, 6.2 } do
		part(m, {
			Name = "Wing" .. i,
			Size = Vector3.new(1, 1, 1),
			Mesh = Vector3.new(2.2, 7, 9),
			CFrame = CFrame.new(x, 0.5, -0.5) * CFrame.Angles(0, 0, math.rad(if x < 0 then 12 else -12)),
			Color = TOK.goldDeep,
		})
		part(m, {
			Name = "Leg" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 1.1, 1.1),
			CFrame = CFrame.new(x * 0.4, -7.5, 1) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 140, 40),
		})
		part(m, {
			Name = "Foot" .. i,
			Size = Vector3.new(2.6, 0.6, 3.2),
			CFrame = CFrame.new(x * 0.4, -10, 1.8),
			Color = Color3.fromRGB(255, 140, 40),
		})
	end
	part(m, {
		Name = "Tail",
		Size = Vector3.new(1, 1, 1),
		Mesh = Vector3.new(6, 7, 3),
		CFrame = CFrame.new(0, 3, -6) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = TOK.goldDeep,
	})
	-- the GRAVITY capsule: a literal, visible causal promise
	local cap = part(m, {
		Name = "GravityCapsule",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.5, 2.6, 2.6),
		CFrame = CFrame.new(0, 7.2, -3) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TOK.gravity,
		Material = Enum.Material.Neon,
	})
	cap:SetAttribute("Essential", true)
	part(m, {
		Name = "CapsuleRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 6.5, 6.5),
		CFrame = CFrame.new(0, 7.2, -3) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TOK.gravity,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	weldAll(m, root)
	m.Parent = parent
	return m
end

function WorldBuilder.buildBot(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "RogueLawBot"
	local root = part(m, {
		Name = "Root",
		Size = Vector3.new(6, 6, 6),
		Color = Color3.fromRGB(90, 96, 130),
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Visor",
		Size = Vector3.new(5, 1.4, 0.4),
		CFrame = CFrame.new(0, 1.2, -3.1),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
	})
	for i, x in { -1.6, 1.6 } do
		part(m, {
			Name = "Boot" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(x, -3.6, 0),
			Color = Color3.fromRGB(60, 60, 80),
			Material = Enum.Material.Metal,
		})
	end
	part(m, {
		Name = "Antenna",
		Size = Vector3.new(0.4, 3, 0.4),
		CFrame = CFrame.new(0, 4.5, 0),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
	})
	-- telegraph chevron ring (shape cue, not only color); shown by server during Telegraph
	local ring = part(m, {
		Name = "TelegraphRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, L.botCounterRange * 2, L.botCounterRange * 2),
		CFrame = CFrame.new(0, -4.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	ring:SetAttribute("Essential", true)
	weldAll(m, root)
	m.Parent = parent
	return m
end

function WorldBuilder.buildLawArena(origin: Vector3, name: string): { [string]: Instance }
	local folder = Instance.new("Model")
	folder.Name = name
	local y0 = L.platformY
	local floorSize = Vector3.new(L.halfX * 2, 2, L.maxZ - L.minZ)
	local center = origin + Vector3.new(0, y0 - 1, (L.maxZ + L.minZ) / 2)
	part(folder, {
		Name = "Floor",
		Size = floorSize,
		CFrame = CFrame.new(center),
		Color = TOK.turf,
		Material = Enum.Material.Grass,
	})
	-- floating island underside (silhouette from below / afar)
	part(folder, {
		Name = "Underside",
		Size = Vector3.new(1, 1, 1),
		Mesh = Vector3.new(floorSize.X * 1.1, 40, floorSize.Z * 1.05),
		CFrame = CFrame.new(center - Vector3.new(0, 16, 0)),
		Color = Color3.fromRGB(170, 140, 120),
		CanCollide = false,
	})
	-- lane stripes (readable trajectory space)
	for i = -1, 1, 2 do
		part(folder, {
			Name = "Lane",
			Size = Vector3.new(0.6, 0.1, floorSize.Z - 6),
			CFrame = CFrame.new(center + Vector3.new(i * 13, 1.05, 0)),
			Color = TOK.cue,
			CanCollide = false,
		})
	end
	-- low bumper walls (match server wall bounds exactly)
	local wallH = 5
	for _, spec in
		{
			{ Vector3.new(1.5, wallH, floorSize.Z), Vector3.new(-L.halfX - 0.75, 0, 0) },
			{ Vector3.new(1.5, wallH, floorSize.Z), Vector3.new(L.halfX + 0.75, 0, 0) },
			{
				Vector3.new(floorSize.X, wallH, 1.5),
				Vector3.new(0, 0, L.minZ - 0.75 - (L.maxZ + L.minZ) / 2),
			},
			{
				Vector3.new(floorSize.X, wallH, 1.5),
				Vector3.new(0, 0, L.maxZ + 0.75 - (L.maxZ + L.minZ) / 2),
			},
		}
	do
		part(folder, {
			Name = "Bumper",
			Size = spec[1],
			CFrame = CFrame.new(center + spec[2] + Vector3.new(0, wallH / 2 + 1, 0)),
			Color = TOK.stone,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- pylons (exact server collision radii) — protective obstacles / bank-shot geometry
	for i, p in L.pylons do
		part(folder, {
			Name = "Pylon" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(26, p.r * 2, p.r * 2),
			CFrame = CFrame.new(origin + Vector3.new(p.x, y0 + 13, p.z)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 120, 180),
			Material = Enum.Material.SmoothPlastic,
		})
		part(folder, {
			Name = "PylonCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(p.r * 2.2, p.r * 2.2, p.r * 2.2),
			CFrame = CFrame.new(origin + Vector3.new(p.x, y0 + 26, p.z)),
			Color = TOK.cue,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	-- two ramps for player angles
	for i, x in { -28, 28 } do
		part(folder, {
			Name = "Ramp" .. i,
			ClassName = "WedgePart",
			Size = Vector3.new(10, 6, 16),
			CFrame = CFrame.new(origin + Vector3.new(x, y0 + 3, -14)),
			Color = Color3.fromRGB(120, 170, 255),
		})
	end
	-- chicken freight platform
	local sp = L.chickenStart
	part(folder, {
		Name = "FreightPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 18, 18),
		CFrame = CFrame.new(origin + Vector3.new(sp.x, y0 + 0.5, sp.z)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TOK.objective,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	-- THE VAULT: arch + mint volume exactly matching the server goal box
	local v = L.vault
	local vc = origin + Vector3.new(v.x, y0, v.z)
	local goal = part(folder, {
		Name = "VaultVolume",
		Size = Vector3.new(v.hx * 2, 22, v.hz * 2),
		CFrame = CFrame.new(vc + Vector3.new(0, 11, 0)),
		Color = TOK.vault,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
	})
	goal:SetAttribute("Essential", true)
	for i, x in { -v.hx - 2, v.hx + 2 } do
		part(folder, {
			Name = "VaultPillar" .. i,
			Size = Vector3.new(4, 30, 4),
			CFrame = CFrame.new(vc + Vector3.new(x, 15, -v.hz)),
			Color = TOK.vault,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	part(folder, {
		Name = "VaultArch",
		Size = Vector3.new(v.hx * 2 + 8, 5, 5),
		CFrame = CFrame.new(vc + Vector3.new(0, 31, -v.hz)),
		Color = TOK.objective,
		Material = Enum.Material.Neon,
	})
	part(folder, {
		Name = "VaultBack",
		Size = Vector3.new(v.hx * 2 + 8, 30, 2),
		CFrame = CFrame.new(vc + Vector3.new(0, 15, v.hz + 3)),
		Color = Color3.fromRGB(40, 150, 120),
		Material = Enum.Material.SmoothPlastic,
	})
	-- player spawn
	local spawnPad = part(folder, {
		Name = "PlayerSpawnMarker",
		Size = Vector3.new(8, 0.3, 8),
		CFrame = CFrame.new(origin + Vector3.new(0, y0 + 0.2, -52)),
		Color = TOK.cue,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
	})
	-- runtime pieces
	local chicken = WorldBuilder.buildChicken(folder)
	local bot = WorldBuilder.buildBot(folder)
	local ball = part(folder, {
		Name = "Lawball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Color = TOK.gravity,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 1,
	})
	ball:SetAttribute("Essential", true)
	local well = part(folder, {
		Name = "GravityWell",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, L.wellRadius * 2, L.wellRadius * 2),
		Color = TOK.field,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 1,
	})
	well:SetAttribute("Essential", true)
	-- ProximityPrompt on the capsule: discoverable STEAL on touch, mouse and gamepad
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "STEAL GRAVITY"
	prompt.ObjectText = "Golden Chicken"
	prompt.MaxActivationDistance = L.stealRange + 4
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.Parent = chicken:FindFirstChild("GravityCapsule")
	folder.Parent = workspace
	return {
		folder = folder,
		chicken = chicken,
		bot = bot,
		ball = ball,
		well = well,
		prompt = prompt,
		spawn = spawnPad,
	}
end

-- ===================== GRID HEIST: THE CITY BLINKS =====================

function WorldBuilder.buildHeistArena(origin: Vector3, name: string): { [string]: any }
	local folder = Instance.new("Model")
	folder.Name = name
	local y0 = 4
	part(folder, {
		Name = "Street",
		Size = Vector3.new(H.halfX * 2, 2, H.maxZ - H.minZ),
		CFrame = CFrame.new(origin + Vector3.new(0, y0 - 1, 0)),
		Color = TOK.asphalt,
		Material = Enum.Material.Asphalt,
	})
	for _, spec in
		{
			{ Vector3.new(2, 40, H.maxZ - H.minZ), Vector3.new(-H.halfX - 1, 0, 0) },
			{ Vector3.new(2, 40, H.maxZ - H.minZ), Vector3.new(H.halfX + 1, 0, 0) },
			{ Vector3.new(H.halfX * 2, 40, 2), Vector3.new(0, 0, H.minZ - 1) },
			{ Vector3.new(H.halfX * 2, 40, 2), Vector3.new(0, 0, H.maxZ + 1) },
		}
	do
		part(folder, {
			Name = "CityWall",
			Size = spec[1],
			CFrame = CFrame.new(origin + spec[2] + Vector3.new(0, y0 + 20, 0)),
			Color = TOK.night,
			Material = Enum.Material.Concrete,
		})
	end
	local lamps: { Light } = {}
	local signs: { BasePart } = {}
	for i, b in H.blocks do
		local height = 34 + (i % 2) * 14
		part(folder, {
			Name = "Block" .. i,
			Size = Vector3.new(b.hx * 2, height, b.hz * 2),
			CFrame = CFrame.new(origin + Vector3.new(b.x, y0 + height / 2, b.z)),
			Color = Color3.fromRGB(60, 66, 100),
			Material = Enum.Material.SmoothPlastic,
		})
		-- neon window bands: go dark during blackout (functional visibility change)
		for j = 1, 3 do
			local sgn = part(folder, {
				Name = "Neon",
				Size = Vector3.new(b.hx * 2 + 0.4, 1.2, b.hz * 2 + 0.4),
				CFrame = CFrame.new(origin + Vector3.new(b.x, y0 + j * 9, b.z)),
				Color = if j % 2 == 0 then TOK.gravity else TOK.hostile,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			table.insert(signs, sgn)
		end
	end
	for _, xz in
		{ { 0, -30 }, { 0, 30 }, { -30, 0 }, { 30, 0 }, { 56, 56 }, { -56, -56 }, { 56, -56 }, { -56, 56 } }
	do
		local post = part(folder, {
			Name = "Lamp",
			Size = Vector3.new(1, 14, 1),
			CFrame = CFrame.new(origin + Vector3.new(xz[1], y0 + 7, xz[2])),
			Color = TOK.stone,
		})
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 2
		light.Color = TOK.cue
		light.Parent = post
		table.insert(lamps, light)
	end
	local function pad(spot: { x: number, z: number, r: number }, label: string, color: Color3): BasePart
		local p = part(folder, {
			Name = label,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, spot.r * 2, spot.r * 2),
			CFrame = CFrame.new(origin + Vector3.new(spot.x, y0 + 0.25, spot.z))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
		})
		p:SetAttribute("Essential", true)
		return p
	end
	local substation = pad(H.substation, "Substation", TOK.objective)
	part(folder, {
		Name = "SubstationBox",
		Size = Vector3.new(6, 8, 6),
		CFrame = CFrame.new(origin + Vector3.new(H.substation.x, y0 + 4, H.substation.z)),
		Color = TOK.objective,
		Material = Enum.Material.Metal,
	})
	local console = pad(H.rerouteConsole, "RerouteConsole", TOK.gravity)
	local gatePad = pad(H.escapeGate, "EscapeGatePad", TOK.vault)
	local core = part(folder, {
		Name = "DataCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = CFrame.new(origin + Vector3.new(H.coreSpot.x, y0 + 4, H.coreSpot.z)),
		Color = TOK.objective,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	core:SetAttribute("Essential", true)
	pad(H.coreSpot, "CorePad", TOK.objective)
	pad(H.exitZone, "ExitZone", TOK.vault)
	local gateDoor = part(folder, {
		Name = "EscapeGateDoor",
		Size = Vector3.new(2, 18, 14),
		CFrame = CFrame.new(origin + Vector3.new(H.halfX - 1, y0 + 9, H.escapeGate.z)),
		Color = TOK.vault,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	})
	-- drone + vision disc (essential, identical on every tier)
	local drone = part(folder, {
		Name = "Drone",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Color = Color3.fromRGB(80, 80, 110),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	local eye = part(folder, {
		Name = "DroneEye",
		Size = Vector3.new(2, 1, 1),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local vision = part(folder, {
		Name = "DroneVision",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, H.visionLit * 2, H.visionLit * 2),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
		Transparency = 0.75,
		CanCollide = false,
	})
	vision:SetAttribute("Essential", true)
	local beam = part(folder, {
		Name = "DroneFacing",
		ClassName = "WedgePart",
		Size = Vector3.new(1, 0.3, 1),
		Color = TOK.hostile,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	})
	beam:SetAttribute("Essential", true)
	local prompts: { [string]: ProximityPrompt } = {}
	local promptHolders: { [string]: BasePart } =
		{ CutPower = substation, Reroute = console, OpenEscape = gatePad, GrabCore = core }
	for action: string, holder: BasePart in promptHolders do
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = ({
			CutPower = "CUT POWER",
			Reroute = "REROUTE SECURITY",
			OpenEscape = "OPEN ESCAPE",
			GrabCore = "GRAB CORE",
		})[action]
		pp.MaxActivationDistance = 12
		pp.RequiresLineOfSight = false
		pp.HoldDuration = 0
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.GamepadKeyCode = Enum.KeyCode.ButtonX
		pp:SetAttribute("Action", action)
		pp.Parent = holder
		prompts[action] = pp
	end
	folder.Parent = workspace
	return {
		folder = folder,
		lamps = lamps,
		signs = signs,
		drone = drone,
		eye = eye,
		vision = vision,
		beam = beam,
		core = core,
		gateDoor = gateDoor,
		prompts = prompts,
		y0 = y0,
	}
end

return WorldBuilder
