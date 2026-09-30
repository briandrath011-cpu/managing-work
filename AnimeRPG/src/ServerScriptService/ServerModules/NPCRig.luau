--[[
	NPCRig (ModuleScript)
	Location: ServerScriptService.ServerModules.NPCRig
	Creates humanoid rigs for enemies, bosses, summons and friendly NPCs without any
	external assets. Tries an R15 rig via HumanoidDescription first, falls back to a
	hand-built R6 rig. Rigs are cached per look and cloned (object pooling of templates).

	To use a custom model: put a Model (with Humanoid + HumanoidRootPart) named after the
	enemy/NPC Id into ReplicatedStorage.Assets.Rigs - it will be cloned instead.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NPCRig = {}

local cacheFolder = Instance.new("Folder")
cacheFolder.Name = "RigCache"
cacheFolder.Parent = ServerStorage

local templates: { [string]: Model } = {}
local useR15 = true

local function makePart(name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
end

local function buildR6(body: Color3, accent: Color3, head: Color3): Model
	local model = Instance.new("Model")
	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), body)
	root.Transparency = 1
	root.CanCollide = false
	local torso = makePart("Torso", Vector3.new(2, 2, 1), body)
	local headPart = makePart("Head", Vector3.new(2, 1, 1), head)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = headPart
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = headPart
	local leftArm = makePart("Left Arm", Vector3.new(1, 2, 1), head)
	local rightArm = makePart("Right Arm", Vector3.new(1, 2, 1), head)
	local leftLeg = makePart("Left Leg", Vector3.new(1, 2, 1), accent)
	local rightLeg = makePart("Right Leg", Vector3.new(1, 2, 1), accent)
	for _, p in ipairs({ root, torso, headPart, leftArm, rightArm, leftLeg, rightLeg }) do
		p.Parent = model
	end
	motor("RootJoint", root, torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, headPart, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor(
		"Left Shoulder",
		torso,
		leftArm,
		CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)
	motor(
		"Right Shoulder",
		torso,
		rightArm,
		CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)
	motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	model.PrimaryPart = root
	return model
end

local function buildR15(body: Color3, accent: Color3, head: Color3): Model?
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = head
		description.TorsoColor = body
		description.LeftArmColor = head
		description.RightArmColor = head
		description.LeftLegColor = accent
		description.RightLegColor = accent
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		return result
	end
	warn("[NPCRig] R15 creation failed, using R6 fallback: " .. tostring(result))
	useR15 = false
	return nil
end

local function templateKey(look): string
	local function c(color: Color3?)
		if not color then
			return "x"
		end
		return string.format("%d_%d_%d", color.R * 255, color.G * 255, color.B * 255)
	end
	return (look.Id or "npc") .. "|" .. c(look.Body) .. "|" .. c(look.Accent) .. "|" .. c(look.Head)
end

--[[
	look = { Id, Body: Color3, Accent: Color3, Head: Color3? }
	Returns a fresh Model (not parented), Humanoid and HumanoidRootPart.
]]
function NPCRig.Create(look): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local rigs = assets and assets:FindFirstChild("Rigs")
	local custom = rigs and look.Id and rigs:FindFirstChild(look.Id)
	if custom and custom:IsA("Model") then
		return custom:Clone()
	end
	local key = templateKey(look)
	local template = templates[key]
	if not template then
		local body = look.Body or Color3.fromRGB(180, 180, 180)
		local accent = look.Accent or Color3.fromRGB(80, 80, 80)
		local head = look.Head or Color3.fromRGB(234, 184, 146)
		local built = useR15 and buildR15(body, accent, head) or nil
		if not built then
			built = buildR6(body, accent, head)
		end
		local model = built :: Model
		model.Name = look.Id or "NPC"
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		model.Parent = cacheFolder
		templates[key] = model
		template = model
	end
	return (template :: Model):Clone()
end

-- Adds a floating name / level / health bar.
function NPCRig.AddOverhead(model: Model, text: string, color: Color3, showHealth: boolean, scale: number?)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Overhead"
	billboard.Size = UDim2.fromOffset(180, showHealth and 42 or 26)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * (scale or 1), 0)
	billboard.MaxDistance = 110
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard
	if showHealth then
		local back = Instance.new("Frame")
		back.Name = "HealthBack"
		back.Position = UDim2.fromOffset(20, 26)
		back.Size = UDim2.new(1, -40, 0, 8)
		back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		back.BorderSizePixel = 0
		back.Parent = billboard
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = back
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 60, 70)
		fill.BorderSizePixel = 0
		fill.Parent = back
		local corner2 = corner:Clone()
		corner2.Parent = fill
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.HealthChanged:Connect(function(health)
				fill.Size = UDim2.fromScale(math.clamp(health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
			end)
		end
	end
	billboard.Parent = head
end

function NPCRig.Prepare(model: Model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanQuery = part.Name == "HumanoidRootPart"
			part.CollisionGroup = "NPCs"
		end
	end
end

return NPCRig
