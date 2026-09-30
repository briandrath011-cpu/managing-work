--[[
	WeaponVisual (ModuleScript)
	Location: ServerScriptService.ServerModules.WeaponVisual
	Builds a weapon model from parts (no external meshes needed) and welds it to the hands.
	To use a real mesh: put a Model named after the weapon Id inside
	ReplicatedStorage.Assets.Weapons with a part named "Handle"; it will be used instead.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponVisual = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0
	w.Parent = b
end

-- Builds a model whose Handle's +Y axis points along the blade.
local function buildSingle(def, class): Model
	local model = Instance.new("Model")
	model.Name = def.Id
	local spec = class.Model
	local color = def.Color or Color3.new(0.8, 0.8, 0.8)
	local accent = def.Accent or Color3.new(0.3, 0.3, 0.3)
	local glowMaterial = def.Glow and Enum.Material.Neon or Enum.Material.Metal
	local handle = part("Handle", Vector3.new(0.3, 1.2, 0.3), accent, Enum.Material.Fabric)
	handle.Parent = model
	model.PrimaryPart = handle

	if spec.Kind == "Blade" then
		if spec.Guard then
			local guard = part("Guard", Vector3.new(0.9, 0.15, 0.5), accent, Enum.Material.Metal)
			guard.Parent = model
			weld(handle, guard, CFrame.new(0, 0.65, 0))
		end
		local blade = part("Blade", Vector3.new(spec.Width, spec.Length, spec.Thickness), def.Glow or color, glowMaterial)
		blade.Parent = model
		weld(handle, blade, CFrame.new(0, 0.7 + spec.Length / 2, 0))
		local trailA0 = Instance.new("Attachment")
		trailA0.Name = "TrailA"
		trailA0.Position = Vector3.new(0, -spec.Length / 2 + 0.3, 0)
		trailA0.Parent = blade
		local trailA1 = Instance.new("Attachment")
		trailA1.Name = "TrailB"
		trailA1.Position = Vector3.new(0, spec.Length / 2, 0)
		trailA1.Parent = blade
	elseif spec.Kind == "Scythe" or spec.Kind == "Spear" or spec.Kind == "Staff" then
		handle.Size = Vector3.new(0.3, spec.Length, 0.3)
		handle.Color = accent
		if spec.Kind == "Scythe" then
			local blade = part("Blade", Vector3.new(0.12, 0.7, 3.4), def.Glow or color, glowMaterial)
			blade.Parent = model
			weld(handle, blade, CFrame.new(0, spec.Length / 2 - 0.2, -1.6))
		elseif spec.Kind == "Spear" then
			local tip = part("Blade", Vector3.new(0.35, 1.6, 0.12), def.Glow or color, glowMaterial)
			tip.Parent = model
			weld(handle, tip, CFrame.new(0, spec.Length / 2 + 0.8, 0))
		else
			local orb = part("Orb", Vector3.new(0.9, 0.9, 0.9), def.Glow or def.Accent or color, Enum.Material.Neon)
			orb.Shape = Enum.PartType.Ball
			orb.Parent = model
			weld(handle, orb, CFrame.new(0, spec.Length / 2 + 0.4, 0))
			local light = Instance.new("PointLight")
			light.Color = orb.Color
			light.Range = 8
			light.Brightness = 1.5
			light.Parent = orb
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = Vector3.new(0, spec.Length / 2 - 1, 0)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = Vector3.new(0, spec.Length / 2 + 1, 0)
		a1.Parent = handle
	end
	return model
end

local function buildGauntlet(def, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local fist = part("Handle", Vector3.new(1.1, 1.1, 1.1), def.Color or Color3.new(0.6, 0.6, 0.6), Enum.Material.Metal)
	fist.Parent = model
	model.PrimaryPart = fist
	local knuckle = part(
		"Knuckle",
		Vector3.new(1.15, 0.35, 0.4),
		def.Glow or def.Accent or Color3.new(0.8, 0.2, 0.2),
		def.Glow and Enum.Material.Neon or Enum.Material.Metal
	)
	knuckle.Parent = model
	weld(fist, knuckle, CFrame.new(0, -0.2, -0.45))
	return model
end

function WeaponVisual.Clear(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("WeaponVisual") then
			child:Destroy()
		end
	end
end

function WeaponVisual.Attach(character: Model, def, class)
	WeaponVisual.Clear(character)
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if not rightHand then
		return
	end
	local grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Weapons") and assets.Weapons:FindFirstChild(def.Id)
	local models = {}
	if custom and custom:IsA("Model") and custom:FindFirstChild("Handle") then
		local clone = custom:Clone()
		clone.PrimaryPart = clone:FindFirstChild("Handle") :: BasePart
		table.insert(models, { clone, rightHand })
	elseif class.Model.Kind == "Gauntlets" then
		table.insert(models, { buildGauntlet(def, "GauntletR"), rightHand, CFrame.new(0, -0.1, 0) })
		if leftHand then
			table.insert(models, { buildGauntlet(def, "GauntletL"), leftHand, CFrame.new(0, -0.1, 0) })
		end
	else
		table.insert(models, { buildSingle(def, class), rightHand })
		if class.Model.Dual and leftHand then
			table.insert(models, { buildSingle(def, class), leftHand })
		end
	end
	for _, entry in ipairs(models) do
		local model, hand, c0 = entry[1], entry[2], entry[3]
		model:SetAttribute("WeaponVisual", true)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.Massless = true
				d.CanQuery = false
			end
		end
		weld(hand, model.PrimaryPart, c0 or grip)
		model.Parent = character
	end
end

return WeaponVisual
