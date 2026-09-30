--[[
	WorldBuilder (ModuleScript)
	Location: ServerScriptService.Services.WorldBuilder

	PHASE 15 - Builds the complete open world procedurally from WorldConfig
	(terrain, 6 regions, roads, village, ruins, pyramid, sky islands, fortress, lava realm,
	celestial temples, caves, parkour tower, boss arenas, waypoints, portals, chests, gates).
	Deterministic (fixed seed) so every server looks identical.
	Everything goes into Workspace.Map. All parts are anchored + grouped per region.

	Want a hand-built map? Set GameConfig.World.AutoBuild = false and build your own inside
	Workspace.Map using the positions from WorldConfig (or edit WorldConfig to match).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local WorldConfig = require(Modules.World.WorldConfig)

local WorldBuilder = {}

local built = false
local rng = Random.new(20240601)
local terrain = workspace.Terrain
local mapFolder: Folder
local waypointParts: { [string]: BasePart } = {}
local clearZones: { { Position: Vector3, Radius: number } } = {}

local C = Color3.fromRGB
local V = Vector3.new

-- HELPERS ------------------------------------------------------------------------------------------

local function folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function P(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	-- Shape must be applied before Size (balls/cylinders clamp their size).
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Shape" and key ~= "CFrame" and key ~= "Position" then
			(part :: any)[key] = value
		end
	end
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.Position = props.Position
	end
	part.Parent = props.Parent
	return part
end

local function W(props: { [string]: any }): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

local function isClear(position: Vector3, margin: number): boolean
	for _, zone in ipairs(clearZones) do
		local flat = Vector3.new(position.X - zone.Position.X, 0, position.Z - zone.Position.Z)
		if flat.Magnitude < zone.Radius + margin then
			return false
		end
	end
	return true
end

local function addClear(position: Vector3, radius: number)
	table.insert(clearZones, { Position = position, Radius = radius })
end

local function randomIn(center: Vector3, halfSize: number): Vector3
	return center + V(rng:NextNumber(-halfSize, halfSize), 0, rng:NextNumber(-halfSize, halfSize))
end

-- PROPS --------------------------------------------------------------------------------------------

local function tree(parent: Instance, position: Vector3, leafColor: Color3, scale: number?)
	local s = scale or rng:NextNumber(0.8, 1.4)
	local trunkHeight = 12 * s
	P({
		Name = "Trunk",
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = V(trunkHeight, 2.2 * s, 2.2 * s),
		CFrame = CFrame.new(position + V(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(110, 80, 55),
		Material = Enum.Material.Wood,
	})
	P({
		Name = "Leaves",
		Parent = parent,
		Shape = Enum.PartType.Ball,
		Size = V(11, 11, 11) * s,
		Position = position + V(0, trunkHeight + 3 * s, 0),
		Color = leafColor,
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function pine(parent: Instance, position: Vector3, color: Color3)
	local s = rng:NextNumber(0.9, 1.5)
	P({
		Name = "Trunk",
		Parent = parent,
		Size = V(1.6, 6, 1.6) * s,
		Position = position + V(0, 3 * s, 0),
		Color = C(90, 65, 45),
		Material = Enum.Material.Wood,
	})
	for i = 0, 2 do
		local size = (9 - i * 2.5) * s
		P({
			Name = "Needles",
			Parent = parent,
			Size = V(size, 5 * s, size),
			CFrame = CFrame.new(position + V(0, (6 + i * 4) * s, 0)) * CFrame.Angles(0, math.rad(45 * i), 0),
			Color = color,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

local function rock(parent: Instance, position: Vector3, color: Color3, material: Enum.Material?)
	local s = rng:NextNumber(3, 9)
	P({
		Name = "Rock",
		Parent = parent,
		Size = V(s, s * rng:NextNumber(0.5, 0.9), s * rng:NextNumber(0.7, 1.2)),
		CFrame = CFrame.new(position + V(0, s * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = color,
		Material = material or Enum.Material.Slate,
	})
end

local function house(parent: Instance, cf: CFrame, wallColor: Color3, roofColor: Color3)
	local model = Instance.new("Model")
	model.Name = "House"
	local w, d, h = 18, 14, 10
	-- walls (hollow with door gap)
	P({
		Parent = model,
		Size = V(w, h, 1),
		CFrame = cf * CFrame.new(0, h / 2, -d / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	P({
		Parent = model,
		Size = V(1, h, d),
		CFrame = cf * CFrame.new(-w / 2, h / 2, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	P({
		Parent = model,
		Size = V(1, h, d),
		CFrame = cf * CFrame.new(w / 2, h / 2, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	P({
		Parent = model,
		Size = V(w / 2 - 3, h, 1),
		CFrame = cf * CFrame.new(-w / 4 - 1.5, h / 2, d / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	P({
		Parent = model,
		Size = V(w / 2 - 3, h, 1),
		CFrame = cf * CFrame.new(w / 4 + 1.5, h / 2, d / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	P({
		Parent = model,
		Size = V(6, 3, 1),
		CFrame = cf * CFrame.new(0, h - 1.5, d / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	-- roof (two wedges)
	W({
		Parent = model,
		Size = V(w + 2, 6, d / 2 + 1),
		CFrame = cf * CFrame.new(0, h + 3, -d / 4) * CFrame.Angles(0, math.pi, 0),
		Color = roofColor,
		Material = Enum.Material.Slate,
	})
	W({
		Parent = model,
		Size = V(w + 2, 6, d / 2 + 1),
		CFrame = cf * CFrame.new(0, h + 3, d / 4),
		Color = roofColor,
		Material = Enum.Material.Slate,
	})
	-- window glow
	P({
		Parent = model,
		Size = V(3, 2.5, 0.3),
		CFrame = cf * CFrame.new(-w / 4, h / 2 + 1, -d / 2 - 0.4),
		Color = C(255, 220, 140),
		Material = Enum.Material.Neon,
	})
	model.Parent = parent
end

local function tent(parent: Instance, cf: CFrame, color: Color3)
	W({
		Parent = parent,
		Size = V(10, 7, 6),
		CFrame = cf * CFrame.new(0, 3.5, -3) * CFrame.Angles(0, math.pi, 0),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	W({ Parent = parent, Size = V(10, 7, 6), CFrame = cf * CFrame.new(0, 3.5, 3), Color = color, Material = Enum.Material.Fabric })
end

local function pillar(parent: Instance, position: Vector3, height: number, color: Color3, material: Enum.Material?, broken: boolean?)
	local h = broken and height * rng:NextNumber(0.3, 0.8) or height
	P({
		Name = "Pillar",
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = V(h, 4, 4),
		CFrame = CFrame.new(position + V(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Marble,
	})
	P({
		Name = "Base",
		Parent = parent,
		Size = V(5.5, 1.2, 5.5),
		Position = position + V(0, 0.6, 0),
		Color = color,
		Material = material or Enum.Material.Marble,
	})
	if not broken then
		P({
			Name = "Cap",
			Parent = parent,
			Size = V(5.5, 1.2, 5.5),
			Position = position + V(0, h + 0.6, 0),
			Color = color,
			Material = material or Enum.Material.Marble,
		})
	end
end

local function arena(parent: Instance, center: Vector3, radius: number, color: Color3, material: Enum.Material)
	local count = 12
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		pillar(parent, center + V(math.cos(angle) * radius, -3, math.sin(angle) * radius), 26, color, material, i % 3 == 0)
	end
	P({
		Name = "ArenaFloor",
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = V(1, radius * 2, radius * 2),
		CFrame = CFrame.new(center + V(0, -2.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
	addClear(center, radius)
end

local function crystal(parent: Instance, position: Vector3, color: Color3, height: number): Part
	local part = P({
		Name = "Crystal",
		Parent = parent,
		Size = V(3, height, 3),
		CFrame = CFrame.new(position + V(0, height / 2 + 1, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = part
	return part
end

-- WORLD OBJECTS (waypoints, portals, chests, gates) -----------------------------------------------

local function buildWaypoint(parent: Instance, waypoint)
	local base = P({
		Name = "WaypointBase_" .. waypoint.Id,
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = V(1, 12, 12),
		CFrame = CFrame.new(waypoint.Position - V(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(70, 80, 110),
		Material = Enum.Material.Slate,
	})
	local gem = crystal(parent, waypoint.Position - V(0, 2, 0), C(90, 200, 255), 7)
	gem.Name = "Waypoint_" .. waypoint.Id
	gem:SetAttribute("WaypointId", waypoint.Id)
	gem:SetAttribute("DisplayName", waypoint.DisplayName)
	waypointParts[waypoint.Id] = base
	addClear(waypoint.Position, 14)
end

local function buildPortal(parent: Instance, portal)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. portal.Id
	local base = P({
		Name = "Base",
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = V(1, 14, 14),
		CFrame = CFrame.new(portal.Position - V(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(40, 40, 50),
		Material = Enum.Material.Slate,
	})
	local ring = P({
		Name = "Ring",
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = V(0.6, 12, 12),
		CFrame = CFrame.new(portal.Position + V(0, 5, 0)),
		Color = portal.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = ring
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(portal.Color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.6, 0)
	particles.Rate = 20
	particles.Lifetime = NumberRange.new(1, 1.6)
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = attachment
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = "Enter (Lv. " .. portal.LevelRequired .. ")"
	prompt.ObjectText = portal.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	model:SetAttribute("PortalId", portal.Id)
	model.PrimaryPart = base
	model.Parent = parent
	addClear(portal.Position, 12)
end

local CHEST_COLORS = { C(140, 100, 60), C(120, 160, 200), C(170, 90, 230), C(255, 190, 50), C(255, 90, 120) }

local function buildChest(parent: Instance, chest)
	local model = Instance.new("Model")
	model.Name = "Chest_" .. chest.Id
	local color = CHEST_COLORS[math.clamp(chest.Tier, 1, #CHEST_COLORS)]
	local body = P({
		Name = "Body",
		Parent = model,
		Size = V(4, 2.5, 2.6),
		Position = chest.Position + V(0, -1.2, 0),
		Color = color,
		Material = Enum.Material.Wood,
	})
	P({
		Name = "Lid",
		Parent = model,
		Size = V(4.2, 1, 2.8),
		Position = chest.Position + V(0, 0.5, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.Wood,
	})
	P({
		Name = "Lock",
		Parent = model,
		Size = V(0.8, 0.8, 0.3),
		Position = chest.Position + V(0, -0.3, -1.45),
		Color = C(255, 215, 80),
		Material = Enum.Material.Neon,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Treasure Chest"
	prompt.HoldDuration = 0.6
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	model:SetAttribute("ChestId", chest.Id)
	model:SetAttribute("Tier", chest.Tier)
	model.PrimaryPart = body
	model.Parent = parent
end

local function buildGate(
	parent: Instance,
	position: Vector3,
	name: string,
	color: Color3,
	promptText: string,
	attribute: string,
	value: string
)
	local model = Instance.new("Model")
	model.Name = name
	P({ Parent = model, Size = V(3, 18, 3), Position = position + V(-8, 6, 0), Color = C(50, 50, 60), Material = Enum.Material.Slate })
	P({ Parent = model, Size = V(3, 18, 3), Position = position + V(8, 6, 0), Color = C(50, 50, 60), Material = Enum.Material.Slate })
	P({ Parent = model, Size = V(20, 3, 3), Position = position + V(0, 15, 0), Color = C(50, 50, 60), Material = Enum.Material.Slate })
	local veil = P({
		Name = "Veil",
		Parent = model,
		Size = V(13, 15, 0.5),
		Position = position + V(0, 5, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GatePrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = value
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = veil
	model:SetAttribute(attribute, value)
	model.PrimaryPart = veil
	model.Parent = parent
	addClear(position, 14)
end

-- REGIONS ------------------------------------------------------------------------------------------

local function ground(region, material: Enum.Material, thickness: number?)
	local t = thickness or 16
	terrain:FillBlock(CFrame.new(region.Center - V(0, t / 2, 0)), V(region.Size.X, t, region.Size.Z), material)
end

local function hillsAround(region, material: Enum.Material, count: number)
	local half = region.Size.X / 2
	for _ = 1, count do
		local edge = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-half, half)
		local offset
		if edge == 1 then
			offset = V(along, 0, -half + 20)
		elseif edge == 2 then
			offset = V(along, 0, half - 20)
		elseif edge == 3 then
			offset = V(-half + 20, 0, along)
		else
			offset = V(half - 20, 0, along)
		end
		local position = region.Center + offset
		if isClear(position, 30) then
			terrain:FillBall(position - V(0, 10, 0), rng:NextNumber(25, 55), material)
		end
	end
end

local function scatter(region, count: number, margin: number, fn: (Vector3) -> ())
	local placed = 0
	local attempts = 0
	while placed < count and attempts < count * 6 do
		attempts += 1
		local position = randomIn(region.Center, region.Size.X / 2 - 30)
		if isClear(position, margin) then
			fn(position)
			placed += 1
		end
	end
end

local function buildGreenwood(root: Folder)
	local region = WorldConfig.GetRegion("Greenwood")
	local f = folder("Greenwood", root)
	ground(region, Enum.Material.Grass)
	-- village plaza
	terrain:FillBlock(CFrame.new(V(0, -1, 20)), V(90, 2.2, 90), Enum.Material.Cobblestone)
	addClear(V(0, 0, 20), 75)
	local houseSpots = {
		{ V(-55, 0, -45), 0.3 },
		{ V(55, 0, -50), -0.3 },
		{ V(-70, 0, 25), 1.4 },
		{ V(75, 0, 20), -1.4 },
		{ V(-50, 0, 85), 2.6 },
		{ V(55, 0, 90), -2.6 },
		{ V(0, 0, -70), 0 },
	}
	for i, spot in ipairs(houseSpots) do
		house(
			f,
			CFrame.new(spot[1]) * CFrame.Angles(0, spot[2], 0),
			i % 2 == 0 and C(200, 170, 130) or C(180, 140, 100),
			i % 2 == 0 and C(150, 60, 50) or C(80, 90, 130)
		)
	end
	-- well + banners in plaza
	P({
		Name = "Well",
		Parent = f,
		Shape = Enum.PartType.Cylinder,
		Size = V(3, 8, 8),
		CFrame = CFrame.new(V(-15, 1.5, 5)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(140, 140, 150),
		Material = Enum.Material.Cobblestone,
	})
	-- forest (west)
	for _ = 1, 70 do
		local position = V(rng:NextNumber(-360, -110), 0, rng:NextNumber(-340, 340))
		if isClear(position, 8) then
			tree(f, position, C(rng:NextInteger(50, 90), rng:NextInteger(130, 170), rng:NextInteger(50, 80)))
		end
	end
	scatter(region, 40, 10, function(position)
		tree(f, position, C(70, 160, 70))
	end)
	scatter(region, 30, 6, function(position)
		rock(f, position, C(120, 120, 115))
	end)
	-- bandit camp (north-east)
	for i = 1, 5 do
		local angle = i * 1.25
		tent(f, CFrame.new(V(190 + math.cos(angle) * 30, 0, -170 + math.sin(angle) * 30)) * CFrame.Angles(0, angle, 0), C(150, 90, 60))
	end
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		P({
			Name = "Palisade",
			Parent = f,
			Size = V(2, 10, 2),
			Position = V(200 + math.cos(angle) * 55, 5, -180 + math.sin(angle) * 55),
			Color = C(100, 70, 45),
			Material = Enum.Material.Wood,
		})
	end
	-- parkour watchtower (south-east) - top at y ~80
	local towerBase = V(260, 0, 220)
	P({
		Name = "Tower",
		Parent = f,
		Size = V(10, 76, 10),
		Position = towerBase + V(0, 38, 0),
		Color = C(120, 110, 100),
		Material = Enum.Material.Cobblestone,
	})
	P({
		Name = "TowerTop",
		Parent = f,
		Size = V(18, 2, 18),
		Position = towerBase + V(0, 81, 0),
		Color = C(100, 80, 60),
		Material = Enum.Material.WoodPlanks,
	})
	for step = 0, 18 do
		local angle = step * 0.75
		local height = 4 + step * 4
		P({
			Name = "ParkourStep",
			Parent = f,
			Size = V(6, 1.2, 6),
			Position = towerBase + V(math.cos(angle) * 12, height, math.sin(angle) * 12),
			Color = C(160, 130, 90),
			Material = Enum.Material.WoodPlanks,
		})
	end
	addClear(towerBase, 20)
	-- hermit cave (south-west): hollow rock dome
	local cave = V(-290, 0, 220)
	terrain:FillBall(cave, 34, Enum.Material.Rock)
	terrain:FillBall(cave + V(0, 2, 0), 26, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(cave + V(28, 6, 0)), V(26, 14, 12), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(cave - V(0, 4, 0)), V(50, 8, 50), Enum.Material.Ground)
	crystal(f, cave + V(-10, 0, -10), C(120, 255, 200), 5)
	addClear(cave, 36)
	-- graveyard (night boss arena)
	local graveyard = V(-250, 0, 250)
	for _ = 1, 14 do
		local pos = graveyard + V(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
		P({
			Name = "Grave",
			Parent = f,
			Size = V(3, 4, 0.8),
			CFrame = CFrame.new(pos + V(0, 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), 0),
			Color = C(110, 110, 120),
			Material = Enum.Material.Slate,
		})
	end
	addClear(graveyard, 40)
end

local function buildDesert(root: Folder)
	local region = WorldConfig.GetRegion("Desert")
	local f = folder("Desert", root)
	ground(region, Enum.Material.Sand)
	-- oasis
	terrain:FillBall(V(900, -7, 0), 22, Enum.Material.Water)
	addClear(V(900, 0, 0), 60)
	for i = 1, 8 do
		local angle = i * 0.8
		tree(f, V(900 + math.cos(angle) * 34, 0, math.sin(angle) * 34), C(90, 170, 70), 1.1)
	end
	for i = 1, 6 do
		local angle = i * 1.05 + 0.3
		house(
			f,
			CFrame.new(V(900 + math.cos(angle) * 70, 0, math.sin(angle) * 70)) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			C(230, 210, 160),
			C(200, 150, 80)
		)
	end
	-- ruins (west)
	for _ = 1, 22 do
		local pos = V(760 + rng:NextNumber(-60, 60), 0, -180 + rng:NextNumber(-60, 60))
		if isClear(pos, 4) then
			pillar(f, pos, 22, C(220, 200, 150), Enum.Material.Sandstone, rng:NextNumber() < 0.6)
		end
	end
	-- pyramid (east) - top at y ~60
	local pyramid = V(1180, 0, 60)
	for layer = 0, 11 do
		local size = 120 - layer * 10
		P({
			Name = "Pyramid",
			Parent = f,
			Size = V(size, 5, size),
			Position = pyramid + V(0, 2.5 + layer * 5, 0),
			Color = C(220, 190, 120):Lerp(C(250, 220, 150), layer / 11),
			Material = Enum.Material.Sandstone,
		})
	end
	addClear(pyramid, 70)
	-- temple arena (boss)
	arena(f, V(1100, 3, 200), 45, C(230, 200, 140), Enum.Material.Sandstone)
	scatter(region, 40, 8, function(position)
		rock(f, position, C(200, 170, 120), Enum.Material.Sandstone)
	end)
	hillsAround(region, Enum.Material.Sand, 18)
end

local function buildSky(root: Folder)
	local f = folder("SkyIslands", root)
	for _, island in ipairs(WorldConfig.SkyIslands) do
		local c = island.Center
		terrain:FillCylinder(CFrame.new(c - V(0, 4, 0)), 8, island.Radius, Enum.Material.Grass)
		terrain:FillBall(c - V(0, island.Radius * 0.55, 0), island.Radius * 0.85, Enum.Material.Rock)
		terrain:FillCylinder(CFrame.new(c - V(0, 1, 0)), 2, island.Radius, Enum.Material.Grass)
		for _ = 1, 5 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(island.Radius * 0.4, island.Radius * 0.85)
			local pos = c + V(math.cos(angle) * dist, 0, math.sin(angle) * dist)
			if isClear(pos, 6) then
				tree(f, pos, C(120, 220, 140))
			end
		end
	end
	-- cloud bridges from hub to each island
	local hub = WorldConfig.SkyIslands[1]
	for i = 2, #WorldConfig.SkyIslands do
		local island = WorldConfig.SkyIslands[i]
		local from = hub.Center + V(0, 0, 0)
		local to = island.Center
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		P({
			Name = "CloudBridge",
			Parent = f,
			Size = V(10, 2, length),
			CFrame = CFrame.lookAt(mid - V(0, 1, 0), to - V(0, 1, 0)),
			Color = C(245, 250, 255),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
	end
	-- summit arena + cloud nest
	arena(f, V(1080, 346, 1080), 40, C(200, 210, 240), Enum.Material.Marble)
	P({
		Name = "CloudNest",
		Parent = f,
		Shape = Enum.PartType.Cylinder,
		Size = V(2, 20, 20),
		CFrame = CFrame.new(V(700, 318, 850)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C(250, 250, 255),
		Material = Enum.Material.SmoothPlastic,
	})
end

local function buildFrozen(root: Folder)
	local region = WorldConfig.GetRegion("Frozen")
	local f = folder("Frozen", root)
	ground(region, Enum.Material.Snow)
	hillsAround(region, Enum.Material.Glacier, 20)
	-- fortress
	local fortress = V(0, 0, 1100)
	for _, side in ipairs({
		{ V(0, 0, -70), V(140, 30, 6) },
		{ V(-70, 0, 0), V(6, 30, 140) },
		{ V(70, 0, 0), V(6, 30, 140) },
		{ V(0, 0, 70), V(140, 30, 6) },
	}) do
		local offset, size = side[1], side[2]
		if offset.Z < 0 then
			-- front wall with gate opening
			P({
				Name = "Wall",
				Parent = f,
				Size = V(55, 30, 6),
				Position = fortress + offset + V(-42, 15, 0),
				Color = C(190, 215, 240),
				Material = Enum.Material.Ice,
			})
			P({
				Name = "Wall",
				Parent = f,
				Size = V(55, 30, 6),
				Position = fortress + offset + V(42, 15, 0),
				Color = C(190, 215, 240),
				Material = Enum.Material.Ice,
			})
		else
			P({
				Name = "Wall",
				Parent = f,
				Size = size,
				Position = fortress + offset + V(0, 15, 0),
				Color = C(190, 215, 240),
				Material = Enum.Material.Ice,
			})
		end
	end
	for _, corner in ipairs({ V(-70, 0, -70), V(70, 0, -70), V(-70, 0, 70), V(70, 0, 70) }) do
		P({
			Name = "Tower",
			Parent = f,
			Shape = Enum.PartType.Cylinder,
			Size = V(44, 16, 16),
			CFrame = CFrame.new(fortress + corner + V(0, 22, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C(170, 200, 235),
			Material = Enum.Material.Ice,
		})
	end
	arena(f, V(0, 3, 1150), 32, C(210, 235, 255), Enum.Material.Glacier)
	-- ice spikes + pines
	scatter(region, 50, 8, function(position)
		pine(f, position, C(60, 110, 80))
	end)
	scatter(region, 25, 6, function(position)
		P({
			Name = "IceSpike",
			Parent = f,
			Size = V(3, rng:NextNumber(8, 20), 3),
			CFrame = CFrame.new(position + V(0, 5, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			Color = C(170, 220, 255),
			Material = Enum.Material.Ice,
		})
	end)
	-- ice grotto
	local grotto = V(250, 0, 1050)
	terrain:FillBall(grotto, 30, Enum.Material.Glacier)
	terrain:FillBall(grotto + V(0, 2, 0), 22, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(grotto + V(-24, 6, 0)), V(22, 12, 10), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(grotto - V(0, 4, 0)), V(44, 8, 44), Enum.Material.Snow)
	addClear(grotto, 32)
end

local function buildDemon(root: Folder)
	local region = WorldConfig.GetRegion("Demon")
	local f = folder("Demon", root)
	ground(region, Enum.Material.Basalt)
	hillsAround(region, Enum.Material.Basalt, 16)
	-- lava pools (damage handled by ExplorationService via the "Lava" tag)
	for _ = 1, 14 do
		local pos = randomIn(region.Center, 300)
		if isClear(pos, 20) then
			local size = rng:NextNumber(14, 30)
			local lava = P({
				Name = "Lava",
				Parent = f,
				Shape = Enum.PartType.Cylinder,
				Size = V(1, size, size),
				CFrame = CFrame.new(pos + V(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = C(255, 90, 20),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			lava:SetAttribute("Lava", true)
			addClear(pos, size / 2)
		end
	end
	scatter(region, 45, 6, function(position)
		P({
			Name = "Spike",
			Parent = f,
			Size = V(3, rng:NextNumber(10, 26), 3),
			CFrame = CFrame.new(position + V(0, 6, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)),
			Color = C(40, 20, 20),
			Material = Enum.Material.Basalt,
		})
	end)
	scatter(region, 10, 10, function(position)
		crystal(f, position, C(255, 40, 30), rng:NextNumber(6, 14))
	end)
	arena(f, V(-900, 3, 1180), 45, C(60, 20, 20), Enum.Material.Basalt)
	-- lava sanctum secret
	local sanctum = V(-1120, 0, 1120)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		P({
			Name = "LavaRing",
			Parent = f,
			Size = V(6, 1, 12),
			CFrame = CFrame.new(sanctum + V(math.cos(angle) * 16, 0.2, math.sin(angle) * 16)) * CFrame.Angles(0, -angle, 0),
			Color = C(255, 110, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	addClear(sanctum, 20)
end

local function buildCelestial(root: Folder)
	local f = folder("Celestial", root)
	for _, platform in ipairs(WorldConfig.CelestialPlatforms) do
		local c = platform.Center
		P({
			Name = "Platform",
			Parent = f,
			Shape = Enum.PartType.Cylinder,
			Size = V(6, platform.Radius * 2, platform.Radius * 2),
			CFrame = CFrame.new(c - V(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C(245, 240, 225),
			Material = Enum.Material.Marble,
		})
		P({
			Name = "Trim",
			Parent = f,
			Shape = Enum.PartType.Cylinder,
			Size = V(1, platform.Radius * 2 + 2, platform.Radius * 2 + 2),
			CFrame = CFrame.new(c - V(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C(255, 215, 120),
			Material = Enum.Material.Neon,
		})
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			pillar(
				f,
				c + V(math.cos(angle) * (platform.Radius - 6), 0, math.sin(angle) * (platform.Radius - 6)),
				24,
				C(250, 248, 240),
				Enum.Material.Marble,
				false
			)
		end
	end
	-- bridges between platforms and the sanctum
	local hub = WorldConfig.CelestialPlatforms[1]
	for i = 2, #WorldConfig.CelestialPlatforms do
		local target = WorldConfig.CelestialPlatforms[i]
		local from, to = hub.Center, target.Center
		local mid = (from + to) / 2
		P({
			Name = "LightBridge",
			Parent = f,
			Size = V(12, 2, (to - from).Magnitude),
			CFrame = CFrame.lookAt(mid - V(0, 1, 0), to - V(0, 1, 0)),
			Color = C(255, 245, 200),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
	arena(f, V(-900, 446, 220), 40, C(255, 250, 235), Enum.Material.Marble)
	-- star peak parkour
	local start = V(-900, 410, -200)
	for step = 1, 22 do
		local angle = step * 0.55
		P({
			Name = "StarStep",
			Parent = f,
			Size = V(7, 1.2, 7),
			Position = start + V(math.cos(angle) * 20, step * 5, math.sin(angle) * 20),
			Color = C(255, 240, 180),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
	end
	P({
		Name = "StarPeak",
		Parent = f,
		Size = V(16, 2, 16),
		Position = V(-900, 517, -200),
		Color = C(255, 250, 220),
		Material = Enum.Material.Marble,
	})
end

local function buildRoads(root: Folder)
	local f = folder("Roads", root)
	-- Terrain paths connecting the ground regions.
	terrain:FillBlock(CFrame.new(V(450, -8, 0)), V(200, 16, 60), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(V(0, -8, 450)), V(60, 16, 200), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(V(-450, -8, 900)), V(200, 16, 60), Enum.Material.Basalt)
	-- Stone road markers
	for x = 400, 500, 25 do
		P({ Name = "Lamp", Parent = f, Size = V(1, 10, 1), Position = V(x, 5, 30), Color = C(60, 60, 60), Material = Enum.Material.Metal })
		P({
			Name = "LampLight",
			Parent = f,
			Size = V(1.6, 1.6, 1.6),
			Position = V(x, 10.5, 30),
			Color = C(255, 220, 150),
			Material = Enum.Material.Neon,
		})
	end
	-- Safety sea far below everything (prevents falling into the void).
	for _, offset in ipairs({ V(-1024, 0, -1024), V(1024, 0, -1024), V(-1024, 0, 1024), V(1024, 0, 1024) }) do
		P({
			Name = "Sea",
			Parent = f,
			Size = V(2048, 4, 2048),
			Position = V(0, -60, 450) + offset,
			Color = C(40, 110, 170),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
	end
end

-- PUBLIC -------------------------------------------------------------------------------------------

function WorldBuilder:WaitUntilBuilt()
	while not built do
		task.wait(0.2)
	end
end

function WorldBuilder:IsBuilt(): boolean
	return built
end

function WorldBuilder:GetWaypointCFrame(id: string): CFrame?
	local waypoint = WorldConfig.GetWaypoint(id)
	if not waypoint then
		return nil
	end
	return CFrame.new(waypoint.Position + V(4, 3, 4))
end

function WorldBuilder:Init()
	mapFolder = folder("Map", workspace)
	for _, name in ipairs({ "NPCs", "Enemies", "Bosses", "Interactables", "Effects", "Drops" }) do
		folder(name, workspace)
	end
end

function WorldBuilder:Start()
	if not GameConfig.World.AutoBuild or mapFolder:GetAttribute("Handcrafted") then
		built = true
		return
	end
	local start = os.clock()
	-- Reserve areas that must stay free of random props.
	for _, npc in ipairs(WorldConfig.NPCs) do
		addClear(npc.Position, 6)
	end
	for _, spawner in ipairs(WorldConfig.EnemySpawns) do
		addClear(spawner.Center, math.min(spawner.Radius, 20))
	end
	for _, chest in ipairs(WorldConfig.Chests) do
		addClear(chest.Position, 6)
	end

	local interactables = folder("Interactables", workspace)
	for _, waypoint in ipairs(WorldConfig.Waypoints) do
		buildWaypoint(folder("Waypoints", interactables), waypoint)
	end
	for _, portal in ipairs(WorldConfig.Portals) do
		buildPortal(folder("Portals", interactables), portal)
	end
	for _, gate in ipairs(WorldConfig.DungeonGates) do
		buildGate(
			folder("DungeonGates", interactables),
			gate.Position,
			"DungeonGate_" .. gate.Dungeon,
			C(150, 80, 255),
			"Enter Dungeon",
			"DungeonId",
			gate.Dungeon
		)
	end
	buildGate(
		folder("RaidGates", interactables),
		WorldConfig.RaidGate.Position,
		"RaidGate",
		C(255, 190, 60),
		"Join Raid",
		"RaidId",
		WorldConfig.RaidGate.Raid
	)

	local builders = { buildRoads, buildGreenwood, buildDesert, buildSky, buildFrozen, buildDemon, buildCelestial }
	for _, builder in ipairs(builders) do
		local ok, err = pcall(builder, mapFolder)
		if not ok then
			warn("[WorldBuilder] " .. tostring(err))
		end
		task.wait() -- spread the work across frames
	end
	for _, chest in ipairs(WorldConfig.Chests) do
		buildChest(folder("Chests", interactables), chest)
	end
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Size = V(8, 1, 8)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Position = V(0, 1, 40)
	spawnLocation.Parent = mapFolder
	built = true
	print(string.format("[WorldBuilder] World built in %.2fs", os.clock() - start))
end

return WorldBuilder
