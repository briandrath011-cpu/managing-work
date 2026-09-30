--[[
	VFXLib (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.VFXLib

	PHASE 21 - Every visual effect, built from Parts, ParticleEmitter, Beam, Trail, Attachment,
	Highlight, PointLight, TweenService, ColorCorrection / Bloom / Blur. No external assets.
	Quality presets (Low/Medium/High) scale particle counts and disable heavy extras.
	All temporary objects live in Workspace.Effects and are cleaned up automatically.
]]
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local QualityConfig = require(ReplicatedStorage.Modules.Config.QualityConfig)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local ObjectPool = require(ReplicatedStorage.Modules.Shared.ObjectPool)

local VFXLib = {}
VFXLib.Quality = QualityConfig.Presets.High
VFXLib.ShowDamageNumbers = true
VFXLib.Shake = nil :: ((intensity: number, duration: number) -> ())?
VFXLib.ActiveCount = 0

local localPlayer = Players.LocalPlayer
local rng = Random.new()

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- HELPERS -------------------------------------------------------------------------------------------

local function effectsFolder(): Instance
	local folder = Workspace:FindFirstChild("Effects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = Workspace
	end
	return folder
end

local function tween(instance: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t =
		TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function newPart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Shape" and key ~= "CFrame" and key ~= "Position" and key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.Position = props.Position
	end
	part.Parent = props.Parent or effectsFolder()
	return part
end

local function life(instance: Instance, seconds: number)
	VFXLib.ActiveCount += 1
	task.delay(seconds, function()
		VFXLib.ActiveCount -= 1
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function fadeOut(part: BasePart, time: number, size: Vector3?)
	local props: { [string]: any } = { Transparency = 1 }
	if size then
		props.Size = size
	end
	tween(part, time, props)
	life(part, time + 0.05)
end

local function particleCount(n: number): number
	return math.max(1, math.floor(n * VFXLib.Quality.ParticleMultiplier))
end

-- One-shot particle burst at a position.
local function burst(position: Vector3, color: Color3, count: number, options)
	local opts = options or {}
	local holder = newPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = opts.Texture or SPARK
	emitter.Color = ColorSequence.new(color, opts.Color2 or color)
	emitter.LightEmission = opts.LightEmission or 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Size or 1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(opts.LifeMin or 0.25, opts.LifeMax or 0.6)
	emitter.Speed = NumberRange.new(opts.SpeedMin or 10, opts.SpeedMax or 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = opts.Drag or 4
	emitter.Acceleration = opts.Acceleration or Vector3.zero
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(particleCount(count))
	life(holder, (opts.LifeMax or 0.6) + 0.2)
end

local function light(position: Vector3, color: Color3, range: number, duration: number)
	if not VFXLib.Quality.Lights then
		return
	end
	local holder = newPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = 3
	pointLight.Parent = holder
	tween(pointLight, duration, { Brightness = 0 })
	life(holder, duration + 0.05)
end

local function rootOf(model: Instance?): BasePart?
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = { Workspace.Terrain }
	local map = Workspace:FindFirstChild("Map")
	if map then
		table.insert(list, map)
	end
	params.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

local function localRoot(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function shake(position: Vector3?, intensity: number, radius: number?)
	if not VFXLib.Shake then
		return
	end
	local root = localRoot()
	if position and root then
		local dist = (root.Position - position).Magnitude
		local r = radius or 60
		if dist > r then
			return
		end
		intensity *= 1 - dist / r
	end
	VFXLib.Shake(intensity, 0.25 + intensity * 0.3)
end

local function horizontalRing(
	position: Vector3,
	color: Color3,
	startSize: number,
	endSize: number,
	time: number,
	thickness: number?,
	transparency: number?
)
	local ring = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.4, startSize, startSize),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency or 0.25,
	})
	tween(ring, time, { Size = Vector3.new(thickness or 0.4, endSize, endSize), Transparency = 1 })
	life(ring, time + 0.05)
	return ring
end

-- Screen overlay flash (local UI)
local flashGui: ScreenGui? = nil
local function screenFlash(color: Color3, duration: number, startTransparency: number?)
	if not flashGui or not flashGui.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "VFXOverlay"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		gui.Parent = localPlayer:WaitForChild("PlayerGui")
		flashGui = gui
	end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = startTransparency or 0.3
	frame.BorderSizePixel = 0
	frame.Parent = flashGui
	tween(frame, duration, { BackgroundTransparency = 1 })
	Debris:AddItem(frame, duration + 0.05)
end
VFXLib.ScreenFlashLocal = screenFlash

local function colorCorrection(props, duration: number, fadeTime: number?)
	if not VFXLib.Quality.PostProcessing then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "VFX_CC"
	for key, value in pairs(props) do
		(cc :: any)[key] = value
	end
	cc.Parent = Lighting
	task.delay(duration, function()
		tween(cc, fadeTime or 0.3, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		Debris:AddItem(cc, (fadeTime or 0.3) + 0.05)
	end)
end
VFXLib.ColorCorrection = colorCorrection

local function withinDistance(position: Vector3?): boolean
	if not position then
		return true
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return true
	end
	return (camera.CFrame.Position - position).Magnitude <= VFXLib.Quality.MaxDistance
end
VFXLib.WithinDistance = withinDistance

-- DAMAGE NUMBERS (pooled) ---------------------------------------------------------------------------

local numberPool = ObjectPool.new(function()
	local holder = Instance.new("Part")
	holder.Name = "DamageNumber"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Gui"
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	holder.Parent = effectsFolder()
	return holder
end, 40)

-- EFFECTS -------------------------------------------------------------------------------------------

local Effects = {}
VFXLib.Effects = Effects

function Effects.DamageNumber(p)
	if not VFXLib.ShowDamageNumbers or not VFXLib.Quality.DamageNumbers then
		return
	end
	local holder = numberPool:Get() :: Part
	local gui = holder:FindFirstChild("Gui") :: BillboardGui
	local label = gui:FindFirstChild("Label") :: TextLabel
	gui.Enabled = true
	local start = p.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), 2.5, rng:NextNumber(-1.5, 1.5))
	holder.CFrame = CFrame.new(start)
	local text = p.Text or tostring(p.Amount or 0)
	local color = p.Color or Color3.fromRGB(255, 255, 255)
	local size = 1
	if p.Heal then
		text = "+" .. text
		color = Color3.fromRGB(90, 255, 120)
	elseif p.Crit then
		text = text .. "!"
		color = Color3.fromRGB(255, 200, 40)
		size = 1.4
	elseif p.Blocked then
		color = Color3.fromRGB(150, 180, 255)
		size = 0.8
	end
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.2
	gui.Size = UDim2.fromOffset(60 * size, 30 * size)
	tween(gui, 0.12, { Size = UDim2.fromOffset(160 * size, 50 * size) }, Enum.EasingStyle.Back)
	tween(holder, 0.8, { CFrame = CFrame.new(start + Vector3.new(0, 3.5, 0)) })
	task.delay(0.45, function()
		tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		numberPool:Release(holder)
	end)
end

function Effects.HitSpark(p)
	local color = p.Blocked and Color3.fromRGB(140, 180, 255) or (p.Color or Color3.new(1, 1, 1))
	local size = p.Heavy and 4 or 2.2
	local flash = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Position = p.Position,
		Color = color,
		Transparency = 0.1,
	})
	fadeOut(flash, 0.15, Vector3.new(size * 1.8, size * 1.8, size * 1.8))
	burst(p.Position, color, p.Heavy and 22 or 10, { SpeedMin = 15, SpeedMax = p.Heavy and 50 or 30, Size = p.Heavy and 1.2 or 0.7 })
	if p.Heavy then
		horizontalRing(p.Position, color, 2, 14, 0.25, 0.3)
		light(p.Position, color, 16, 0.2)
	end
end

function Effects.BlockHit(p)
	burst(p.Position, Color3.fromRGB(150, 190, 255), 8, { SpeedMin = 8, SpeedMax = 20, Size = 0.6 })
end

function Effects.PerfectBlock(p)
	local flash = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = p.Position,
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
	})
	fadeOut(flash, 0.25, Vector3.new(12, 12, 12))
	horizontalRing(p.Position, Color3.new(1, 1, 1), 2, 20, 0.3, 0.3, 0)
	burst(p.Position, Color3.fromRGB(200, 230, 255), 30, { SpeedMin = 20, SpeedMax = 50 })
	Effects.DamageNumber({ Position = p.Position + Vector3.new(0, 1, 0), Text = "PERFECT", Color = Color3.fromRGB(150, 230, 255) })
end

function Effects.GuardBreak(p)
	for _ = 1, particleCount(10) do
		local shard = newPart({
			Size = Vector3.new(0.4, 1.2, 0.2),
			CFrame = CFrame.new(p.Position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = Color3.fromRGB(150, 190, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)).Unit
		tween(shard, 0.5, { CFrame = shard.CFrame + dir * 8, Transparency = 1 })
		life(shard, 0.55)
	end
	Effects.DamageNumber({ Position = p.Position + Vector3.new(0, 1, 0), Text = "GUARD BREAK", Color = Color3.fromRGB(255, 120, 120) })
	shake(p.Position, 0.5, 40)
end

function Effects.ElementProc(p)
	burst(p.Position, p.Color, 16, { SpeedMin = 5, SpeedMax = 18, Size = 1.1, Texture = p.Effect == "Burn" and FIRE or SPARK })
	horizontalRing(p.Position, p.Color, 1, 8, 0.25, 0.2)
end

-- Crescent slash: a curved Beam between two attachments.
function Effects.Slash(p)
	local cf: CFrame = p.CFrame
	local size = p.Size or 8
	local holder = newPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = cf })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-size / 2, 0, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(size / 2, 0, 0)
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1), p.Color or Color3.new(1, 1, 1))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 20
	beam.CurveSize0 = -size * 0.55
	beam.CurveSize1 = size * 0.55
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = holder
	local thickness = p.Heavy and size * 0.22 or size * 0.12
	-- animate width out then in
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / 0.28
		if t >= 1 or not holder.Parent then
			connection:Disconnect()
			return
		end
		local w = math.sin(t * math.pi) * thickness
		beam.Width0 = w * 0.3
		beam.Width1 = w
	end)
	holder.CFrame = cf * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5))
	life(holder, 0.3)
	if p.Heavy then
		light(cf.Position, p.Color or Color3.new(1, 1, 1), size, 0.25)
	end
end

function Effects.Shockwave(p)
	local size = p.Size or 20
	local pos = p.Position
	horizontalRing(pos, p.Color or Color3.new(1, 1, 1), size * 0.1, size, 0.35, 0.6, 0.2)
	if VFXLib.Quality.ParticleMultiplier > 0.5 then
		local sphere = newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			Position = pos,
			Color = p.Color or Color3.new(1, 1, 1),
			Material = Enum.Material.ForceField,
			Transparency = 0,
		})
		fadeOut(sphere, 0.35, Vector3.new(size, size * 0.6, size))
	end
	burst(
		pos,
		Color3.fromRGB(200, 200, 200),
		12,
		{ Texture = SMOKE, LightEmission = 0, SpeedMin = 10, SpeedMax = size, Size = 3, LifeMax = 0.8 }
	)
end

function Effects.EnergyRing(p)
	local ring = horizontalRing(p.Position, p.Color or Color3.new(1, 1, 1), (p.Size or 16) * 0.4, p.Size or 16, 0.3, 0.8, 0.1)
	tween(ring, 0.3, { CFrame = ring.CFrame + Vector3.new(0, 2, 0) })
end

function Effects.Beam(p)
	local from, to = p.From, p.To
	local length = (to - from).Magnitude
	local width = p.Width or 2
	local beam = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, width, width),
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
		Color = p.Color or Color3.new(1, 1, 1),
		Transparency = 0,
	})
	local core = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, width * 0.45, width * 0.45),
		CFrame = beam.CFrame,
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
	})
	local duration = p.Duration or 0.4
	tween(beam, duration, { Size = Vector3.new(length, 0, 0), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(core, duration, { Size = Vector3.new(length, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	life(beam, duration + 0.05)
	life(core, duration + 0.05)
	burst(to, p.Color or Color3.new(1, 1, 1), 12, { SpeedMax = 25 })
	light(from, p.Color or Color3.new(1, 1, 1), 20, duration)
end

function Effects.Stretch(p)
	local from, to = p.From, p.To
	local length = (to - from).Magnitude
	local arm = newPart({
		Size = Vector3.new(p.Width or 1, p.Width or 1, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = p.Color,
		Material = Enum.Material.SmoothPlastic,
	})
	local fist = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = to,
		Color = p.Color,
		Material = Enum.Material.SmoothPlastic,
	})
	life(arm, p.Duration or 0.2)
	life(fist, p.Duration or 0.2)
end

function Effects.GroundCracks(p)
	if not VFXLib.Quality.GroundCracks then
		return
	end
	local center = groundAt(p.Position) + Vector3.new(0, 0.1, 0)
	local count = particleCount(8)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local length = (p.Size or 8) * rng:NextNumber(0.6, 1.1)
		local crack = newPart({
			Size = Vector3.new(0.6, 0.25, length),
			CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2),
			Color = Color3.fromRGB(35, 30, 30),
			Material = Enum.Material.Slate,
			Transparency = 0,
		})
		task.delay(2.5, function()
			fadeOut(crack, 1)
		end)
		life(crack, 3.6)
	end
end

function Effects.Debris(p)
	if not VFXLib.Quality.Debris then
		return
	end
	local count = math.min(p.Count or 6, VFXLib.Quality.MaxDebrisPieces)
	local base = groundAt(p.Position)
	for _ = 1, count do
		local s = rng:NextNumber(0.8, 2.2)
		local rock = newPart({
			Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-3, 3), 1, rng:NextNumber(-3, 3)))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = p.Color or Color3.fromRGB(120, 110, 100),
			Material = Enum.Material.Slate,
		})
		if p.PullTo then
			tween(
				rock,
				1.2,
				{ CFrame = CFrame.new(p.PullTo) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			life(rock, 1.3)
		else
			rock.Anchored = false
			rock.CanCollide = true
			rock.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(25, 55), rng:NextNumber(-25, 25))
			task.delay(1.8, function()
				if rock.Parent then
					rock.Anchored = true
					rock.CanCollide = false
					fadeOut(rock, 0.6)
				end
			end)
			life(rock, 2.6)
		end
	end
end

function Effects.Dust(p)
	burst(
		groundAt(p.Position),
		Color3.fromRGB(190, 180, 160),
		18,
		{ Texture = SMOKE, LightEmission = 0, SpeedMin = 6, SpeedMax = p.Size or 16, Size = 4, LifeMin = 0.5, LifeMax = 1.2, Drag = 3 }
	)
end

function Effects.Explosion(p)
	local size = p.Size or 16
	local color = p.Color or Color3.fromRGB(255, 150, 60)
	local core = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = p.Position,
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
	})
	tween(core, 0.15, { Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6) })
	task.delay(0.15, function()
		fadeOut(core, 0.3)
	end)
	local shell =
		newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = p.Position, Color = color, Transparency = 0.2 })
	fadeOut(shell, 0.5, Vector3.new(size, size, size))
	horizontalRing(p.Position, color, size * 0.2, size * 1.4, 0.4, 0.5, 0.2)
	burst(p.Position, color, 30, { SpeedMin = 20, SpeedMax = size * 3, Size = 1.6, Texture = FIRE })
	burst(
		p.Position,
		Color3.fromRGB(80, 80, 80),
		14,
		{ Texture = SMOKE, LightEmission = 0, SpeedMin = 5, SpeedMax = size, Size = 5, LifeMax = 1.2 }
	)
	light(p.Position, color, size * 2, 0.4)
	shake(p.Position, math.min(1, size / 40), size * 4)
end

function Effects.Pillar(p)
	local base = groundAt(p.Position)
	local height = p.Height or 40
	local size = p.Size or 6
	local pillar = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, size, size),
		CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		Color = p.Color or Color3.new(1, 1, 1),
		Transparency = 0.1,
	})
	tween(pillar, 0.15, {
		Size = Vector3.new(height, size, size),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	task.delay(0.2, function()
		fadeOut(pillar, 0.35, Vector3.new(height, 0.5, 0.5))
	end)
	horizontalRing(base + Vector3.new(0, 0.3, 0), p.Color or Color3.new(1, 1, 1), size, size * 2.5, 0.35, 0.4)
	light(base + Vector3.new(0, 4, 0), p.Color or Color3.new(1, 1, 1), size * 3, 0.4)
end

function Effects.Meteor(p)
	local target = groundAt(p.Position)
	local size = p.Size or 6
	local start = target + Vector3.new(rng:NextNumber(-30, 30), 120, rng:NextNumber(-30, 30))
	local rock = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Position = start,
		Color = p.Color or Color3.fromRGB(255, 120, 40),
	})
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, size / 2, 0)
	attachment0.Parent = rock
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -size / 2, 0)
	attachment1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new(p.Color or Color3.fromRGB(255, 120, 40))
	trail.LightEmission = 1
	trail.Lifetime = 0.3
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = rock
	tween(rock, 0.35, { Position = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	life(rock, 0.4)
	task.delay(0.35, function()
		Effects.Explosion({ Position = target, Color = p.Color, Size = size * 3 })
		Effects.GroundCracks({ Position = target, Size = size * 1.5 })
	end)
end

function Effects.Crater(p)
	local center = groundAt(p.Position)
	local size = p.Size or 12
	local count = math.max(6, particleCount(12))
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local s = rng:NextNumber(1.5, 3) * size / 12
		local rock = newPart({
			Size = Vector3.new(s * 1.5, s, s),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * size * 0.5, 0, math.sin(angle) * size * 0.5))
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), -angle, rng:NextNumber(-0.6, 0.6)),
			Color = Color3.fromRGB(90, 85, 80),
			Material = Enum.Material.Slate,
		})
		task.delay(3.5, function()
			tween(rock, 1, { CFrame = rock.CFrame - Vector3.new(0, s * 1.5, 0) })
		end)
		life(rock, 4.6)
	end
	Effects.Dust({ Position = center, Size = size })
end

function Effects.Domain(p)
	local size = p.Size or 60
	local duration = p.Duration or 3
	local sphere = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = p.Position,
		Color = p.Color or Color3.fromRGB(80, 40, 160),
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	tween(sphere, 0.6, { Size = Vector3.new(size, size, size) }, Enum.EasingStyle.Back)
	local inner = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = p.Position,
		Color = p.Color or Color3.fromRGB(80, 40, 160),
		Material = Enum.Material.Glass,
		Transparency = 0.85,
	})
	tween(inner, 0.6, { Size = Vector3.new(size * 0.98, size * 0.98, size * 0.98) })
	task.delay(duration, function()
		fadeOut(sphere, 0.5, Vector3.new(size * 1.1, size * 1.1, size * 1.1))
		fadeOut(inner, 0.5)
	end)
	life(sphere, duration + 0.6)
	life(inner, duration + 0.6)
	local root = localRoot()
	if root and (root.Position - p.Position).Magnitude < size / 2 then
		colorCorrection(
			{ TintColor = (p.Color or Color3.new(0.6, 0.4, 1)):Lerp(Color3.new(1, 1, 1), 0.5), Saturation = -0.3, Contrast = 0.2 },
			duration,
			0.5
		)
	end
	horizontalRing(p.Position, p.Color or Color3.new(1, 1, 1), 4, size, 0.6, 1, 0)
end

function Effects.Tornado(p)
	local size = p.Size or 10
	for i = 0, 3 do
		local ring = newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, size * (0.5 + i * 0.25), size * (0.5 + i * 0.25)),
			CFrame = CFrame.new(p.Position + Vector3.new(0, i * 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = p.Color,
			Transparency = 0.45,
			Material = Enum.Material.ForceField,
		})
		tween(ring, 0.3, { CFrame = ring.CFrame * CFrame.Angles(math.rad(180), 0, 0), Transparency = 1 })
		life(ring, 0.32)
	end
	burst(p.Position + Vector3.new(0, 4, 0), p.Color, 8, { Texture = SMOKE, LightEmission = 0.3, SpeedMin = 4, SpeedMax = 12, Size = 3 })
end

function Effects.Lightning(p)
	local from, to = p.From, p.To
	local segments = 8
	local previous = from
	local width = p.Thick and 1.6 or 0.6
	for i = 1, segments do
		local t = i / segments
		local point = from:Lerp(to, t)
		if i < segments then
			point += Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)) * (p.Thick and 2 or 1)
		end
		local length = (point - previous).Magnitude
		local bolt = newPart({
			Size = Vector3.new(width, width, length),
			CFrame = CFrame.lookAt((previous + point) / 2, point),
			Color = p.Color or Color3.fromRGB(200, 220, 255),
		})
		fadeOut(bolt, 0.2)
		previous = point
	end
	burst(to, p.Color or Color3.new(1, 1, 1), 14, { SpeedMax = 40 })
	light(to, p.Color or Color3.new(1, 1, 1), 30, 0.25)
	if p.Thick then
		shake(to, 0.6, 80)
	end
end

function Effects.Singularity(p)
	local duration = p.Duration or 1.5
	local size = p.Size or 6
	local core = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5),
		Position = p.Position,
		Color = Color3.new(0, 0, 0),
		Material = Enum.Material.SmoothPlastic,
	})
	tween(core, 0.3, { Size = Vector3.new(size, size, size) }, Enum.EasingStyle.Back)
	local glow = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size * 1.3, size * 1.3, size * 1.3),
		Position = p.Position,
		Color = p.Color or Color3.fromRGB(120, 60, 255),
		Transparency = 0.6,
		Material = Enum.Material.ForceField,
	})
	local ring = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, size * 3, size * 3),
		CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = p.Color or Color3.fromRGB(160, 100, 255),
		Transparency = 0.3,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = glow
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = ColorSequence.new(p.Color or Color3.fromRGB(160, 100, 255))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(-30, -20) -- negative = particles flow INTO the core
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 60 * VFXLib.Quality.ParticleMultiplier
	emitter.Parent = attachment
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - start > duration or not ring.Parent then
			connection:Disconnect()
			return
		end
		ring.CFrame = ring.CFrame * CFrame.Angles(0.15, 0, 0)
	end)
	task.delay(duration, function()
		emitter.Enabled = false
		fadeOut(core, 0.2, Vector3.new(0.2, 0.2, 0.2))
		fadeOut(glow, 0.2)
		fadeOut(ring, 0.2)
	end)
	life(core, duration + 0.3)
	life(glow, duration + 0.3)
	life(ring, duration + 0.3)
end

function Effects.IceSpikes(p)
	local center = groundAt(p.Position)
	local count = math.max(4, particleCount(10))
	local radius = (p.Size or 8) * 0.6
	for _ = 1, count do
		local offset = Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		local height = rng:NextNumber(3, 7) * math.max(1, (p.Size or 8) / 10)
		local spike = newPart({
			Size = Vector3.new(1.2, 0.2, 1.2),
			CFrame = CFrame.new(center + offset)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			Color = p.Color or Color3.fromRGB(170, 230, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.1,
		})
		tween(spike, 0.12, { Size = Vector3.new(1.2, height, 1.2), CFrame = spike.CFrame * CFrame.new(0, height / 2, 0) })
		task.delay(1.2, function()
			fadeOut(spike, 0.4)
		end)
		life(spike, 1.7)
	end
	burst(center, Color3.fromRGB(220, 245, 255), 16, { SpeedMax = 20 })
end

-- Persistent auras (per model), replaced when a new aura starts.
local auras: { [Model]: { Instance } } = {}

local function clearAura(model: Model)
	local list = auras[model]
	if list then
		for _, instance in ipairs(list) do
			instance:Destroy()
		end
		auras[model] = nil
	end
end
VFXLib.ClearAura = clearAura

function Effects.Aura(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	clearAura(model)
	local color = p.Color or Color3.new(1, 1, 1)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = FIRE
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, p.Intense and 3.5 or 2.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, 12, 0)
	emitter.Rate = (p.Intense and 70 or 40) * VFXLib.Quality.ParticleMultiplier
	emitter.LockedToPart = true
	emitter.Parent = attachment
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	local list = { attachment, highlight }
	if VFXLib.Quality.Lights then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = color
		pointLight.Range = 14
		pointLight.Brightness = 1.5
		pointLight.Parent = root
		table.insert(list, pointLight)
	end
	auras[model] = list
	local duration = p.Duration or 3
	if duration < 999 then
		task.delay(duration, function()
			if auras[model] == list then
				clearAura(model)
			end
		end)
	end
	model.Destroying:Once(function()
		auras[model] = nil
	end)
end

function Effects.Afterimage(p)
	if not VFXLib.Quality.Afterimages then
		return
	end
	local model = p.Model
	if not model then
		return
	end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
			local ghost =
				newPart({ Size = part.Size, CFrame = part.CFrame, Color = p.Color or Color3.fromRGB(150, 200, 255), Transparency = 0.4 })
			fadeOut(ghost, 0.35)
		end
	end
end

function Effects.ScreenFlash(p)
	local root = localRoot()
	if p.Position and root and (root.Position - p.Position).Magnitude > 150 then
		return
	end
	screenFlash(p.Color or Color3.new(1, 1, 1), p.Duration or 0.2, 0.25)
end

function Effects.ImpactFrame(p)
	local root = localRoot()
	if p.Position and root and (root.Position - p.Position).Magnitude > 120 then
		return
	end
	-- Anime impact frame: invert-ish high contrast black/white flashes.
	if VFXLib.Quality.PostProcessing then
		colorCorrection({ Saturation = -1, Contrast = 2.5, Brightness = 0.1 }, 0.06, 0.05)
		task.delay(0.07, function()
			colorCorrection({ Saturation = -1, Contrast = -2, Brightness = -0.3 }, 0.05, 0.08)
		end)
	end
	screenFlash(Color3.new(1, 1, 1), 0.12, 0.5)
	shake(p.Position, 0.9, 120)
end

function Effects.CameraShake(p)
	shake(p.Position, p.Intensity or 0.5, p.Radius or 60)
end

function Effects.Telegraph(p)
	local pos = groundAt(p.Position) + Vector3.new(0, 0.15, 0)
	local radius = p.Radius or 8
	local color = p.Color or Color3.fromRGB(255, 40, 40)
	local outer = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.65,
	})
	local inner = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 0.2, 0.2),
		CFrame = outer.CFrame,
		Color = color,
		Transparency = 0.35,
	})
	local duration = p.Duration or 1
	tween(inner, duration, { Size = Vector3.new(0.15, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	life(outer, duration + 0.05)
	life(inner, duration + 0.05)
end

function Effects.SafeZone(p)
	local pos = groundAt(p.Position) + Vector3.new(0, 0.15, 0)
	local radius = p.Radius or 12
	local disc = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 250, 200),
		Transparency = 0.3,
	})
	local beam = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 250, 220),
		Transparency = 0.85,
	})
	life(disc, p.Duration or 4)
	life(beam, p.Duration or 4)
end

function Effects.Charge(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = ColorSequence.new(p.Color or Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.5)
	emitter.Speed = NumberRange.new(-25, -15)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 80 * VFXLib.Quality.ParticleMultiplier
	emitter.Parent = attachment
	light(root.Position, p.Color or Color3.new(1, 1, 1), 16, p.Duration or 0.5)
	task.delay(p.Duration or 0.5, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(attachment, (p.Duration or 0.5) + 0.6)
end

local function ghostClone(model: Model, color: Color3, scale: number, transparency: number): Model
	local ghost = Instance.new("Model")
	ghost.Name = "Ghost"
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local copy = newPart({
				Size = part.Size * scale,
				CFrame = part.CFrame,
				Color = color,
				Material = Enum.Material.ForceField,
				Transparency = transparency,
				Parent = ghost,
			})
			copy:SetAttribute("Offset", part.Name)
		end
	end
	ghost.Parent = effectsFolder()
	return ghost
end

function Effects.Stand(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local ghost = ghostClone(model, p.Color or Color3.fromRGB(255, 215, 90), 1.15, 0.1)
	local offsets = {}
	for _, part in ipairs(ghost:GetChildren()) do
		local source = model:FindFirstChild(part:GetAttribute("Offset"))
		if source then
			offsets[part] = root.CFrame:ToObjectSpace((source :: BasePart).CFrame)
		end
	end
	local duration = p.Duration or 1.5
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - start > duration or not root.Parent then
			connection:Disconnect()
			ghost:Destroy()
			return
		end
		local base = root.CFrame * CFrame.new(1.5, 1, -3.5)
		local jitter = p.Pose == "Barrage" and CFrame.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), 0) or CFrame.new()
		for part, offset in pairs(offsets) do
			(part :: BasePart).CFrame = base * jitter * offset
		end
		if p.Pose == "Barrage" and rng:NextNumber() < 0.5 then
			local fist = newPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = (base * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 1), -3)).Position,
				Color = p.Color or Color3.new(1, 1, 1),
				Transparency = 0.3,
			})
			fadeOut(fist, 0.12)
		end
	end)
end

function Effects.TimeStop(p)
	local radius = p.Radius or 35
	local duration = p.Duration or 3
	local sphere = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = p.Position,
		Color = Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	tween(sphere, 0.4, { Size = Vector3.new(radius * 2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		fadeOut(sphere, 0.4)
	end)
	local root = localRoot()
	if root and (root.Position - p.Position).Magnitude < radius * 1.5 then
		colorCorrection({ Saturation = -1, Contrast = 0.3, TintColor = Color3.fromRGB(220, 220, 255) }, duration, 0.4)
		screenFlash(Color3.new(1, 1, 1), 0.3, 0.2)
	end
end

function Effects.EyeFlash(p)
	local head = p.Model and p.Model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for _, x in ipairs({ -0.25, 0.25 }) do
		local eye = newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.35, 0.35),
			CFrame = head.CFrame * CFrame.new(x, 0.1, -0.6),
			Color = p.Color or Color3.new(1, 0, 0),
		})
		fadeOut(eye, 0.6, Vector3.new(0.8, 0.8, 0.8))
	end
	light(head.Position, p.Color or Color3.new(1, 0, 0), 10, 0.5)
end

function Effects.Genjutsu(p)
	local head = p.Model and p.Model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local ring = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 4, 4),
		CFrame = head.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = p.Color or Color3.new(1, 0, 0),
		Transparency = 0.2,
	})
	local duration = p.Duration or 2.5
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - start > duration or not head.Parent then
			connection:Disconnect()
			ring:Destroy()
			return
		end
		ring.CFrame = head.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, (os.clock() - start) * 8, math.rad(90))
	end)
end

function Effects.Susanoo(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local ghost = ghostClone(model, p.Color or Color3.fromRGB(140, 60, 255), 3, 0.35)
	local offsets = {}
	for _, part in ipairs(ghost:GetChildren()) do
		local source = model:FindFirstChild(part:GetAttribute("Offset"))
		if source then
			local rel = root.CFrame:ToObjectSpace((source :: BasePart).CFrame)
			offsets[part] = CFrame.new(rel.Position * 3) * rel.Rotation
		end
	end
	local duration = p.Duration or 3
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - start > duration or not root.Parent then
			connection:Disconnect()
			for part in pairs(offsets) do
				fadeOut(part :: BasePart, 0.3)
			end
			Debris:AddItem(ghost, 0.4)
			return
		end
		local base = root.CFrame * CFrame.new(0, 5, 2)
		for part, offset in pairs(offsets) do
			(part :: BasePart).CFrame = base * offset
		end
	end)
end

function Effects.GiantFist(p)
	local target = groundAt(p.Position)
	local size = p.Size or 16
	local fist = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Position = target + Vector3.new(0, 90, 0),
		Color = p.Color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0,
	})
	tween(fist, p.Delay or 1, { Position = target + Vector3.new(0, size / 3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(p.Delay or 1, function()
		Effects.Shockwave({ Position = target, Color = p.Color, Size = size * 3 })
		fadeOut(fist, 0.4)
	end)
	life(fist, (p.Delay or 1) + 0.5)
end

function Effects.UltimateBanner(p)
	local head = p.Model and p.Model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(360, 60)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = string.upper(p.Name or "")
	label.TextColor3 = p.Color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = head
	tween(gui, 0.2, { StudsOffset = Vector3.new(0, 6, 0) }, Enum.EasingStyle.Back)
	task.delay(1.2, function()
		tween(label, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(gui, 1.6)
end

function Effects.CounterReady(p)
	local model = p.Model
	if not model then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = p.Color or Color3.fromRGB(150, 220, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Parent = model
	tween(highlight, p.Duration or 0.5, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, (p.Duration or 0.5) + 0.05)
end

function Effects.DashFX(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	Effects.Afterimage({ Model = p.Model, Color = Color3.fromRGB(200, 220, 255) })
	burst(
		root.Position - Vector3.new(0, 2.5, 0),
		Color3.fromRGB(210, 200, 190),
		8,
		{ Texture = SMOKE, LightEmission = 0, SpeedMin = 4, SpeedMax = 10, Size = 2.5, LifeMax = 0.6 }
	)
end

function Effects.Death(p)
	local model = p.Model
	if not model then
		return
	end
	local color = p.Color or Color3.fromRGB(255, 255, 255)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			part.Material = Enum.Material.Neon
			tween(part, 0.4, { Color = color })
			task.delay(0.6, function()
				if part.Parent then
					tween(part, 0.8, { Transparency = 1 })
				end
			end)
		end
	end
	local root = rootOf(model)
	if root then
		burst(root.Position, color, 25, { SpeedMin = 3, SpeedMax = 12, Size = 1.2, LifeMax = 1.5, Acceleration = Vector3.new(0, 10, 0) })
	end
end

function Effects.LevelUp(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	local gold = Color3.fromRGB(255, 215, 90)
	Effects.Pillar({ Position = root.Position, Color = gold, Size = 6, Height = 30 })
	horizontalRing(root.Position - Vector3.new(0, 2.5, 0), gold, 2, 20, 0.5, 0.4, 0)
	burst(root.Position, gold, 30, { SpeedMin = 5, SpeedMax = 20, LifeMax = 1.2, Acceleration = Vector3.new(0, 15, 0) })
end

local transformed: { [Model]: RBXScriptConnection } = {}
function Effects.Transform(p)
	local model = p.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local color = p.Color or Color3.new(1, 1, 1)
	Effects.Pillar({ Position = root.Position, Color = color, Size = 12, Height = 70 })
	Effects.Shockwave({ Position = root.Position, Color = color, Size = 50 })
	Effects.Explosion({ Position = root.Position, Color = p.Color2 or color, Size = 18 })
	Effects.Aura({ Model = model, Color = color, Duration = 9999, Intense = true })
	if transformed[model] then
		transformed[model]:Disconnect()
	end
	transformed[model] = model:GetAttributeChangedSignal("Transformed"):Connect(function()
		if not model:GetAttribute("Transformed") then
			clearAura(model)
			if transformed[model] then
				transformed[model]:Disconnect()
				transformed[model] = nil
			end
		end
	end)
end

function Effects.Summon(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	horizontalRing(root.Position - Vector3.new(0, 2.5, 0), p.Color or Color3.new(0.4, 0.2, 1), 1, 10, 0.5, 0.3, 0)
	burst(
		root.Position - Vector3.new(0, 2, 0),
		Color3.fromRGB(20, 10, 30),
		16,
		{ Texture = SMOKE, LightEmission = 0, SpeedMin = 3, SpeedMax = 8, Size = 3, LifeMax = 1, Acceleration = Vector3.new(0, 8, 0) }
	)
end

function Effects.BossRoar(p)
	local root = rootOf(p.Model)
	if not root then
		return
	end
	for i = 0, 2 do
		task.delay(i * 0.2, function()
			horizontalRing(root.Position, p.Color or Color3.new(1, 0.3, 0.3), 5, 70, 0.6, 1, 0.3)
		end)
	end
	shake(root.Position, 0.8, 150)
end

function Effects.RareDrop(p)
	local color = p.Color or RarityConfig.GetColor(p.Rarity)
	local base = groundAt(p.Position)
	local beam = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, 1.5, 1.5),
		CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.2,
	})
	fadeOut(beam, 2.5, Vector3.new(80, 0.2, 0.2))
	burst(base + Vector3.new(0, 2, 0), color, 40, { SpeedMin = 10, SpeedMax = 35, LifeMax = 1.2, Size = 1.4 })
	light(base, color, 30, 2)
	local target = rootOf(p.Target)
	if target then
		local orb = newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			Position = base + Vector3.new(0, 3, 0),
			Color = color,
		})
		task.delay(0.4, function()
			if target.Parent and orb.Parent then
				tween(
					orb,
					0.5,
					{ Position = target.Position, Size = Vector3.new(0.2, 0.2, 0.2) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end
		end)
		life(orb, 1)
	end
	if RarityConfig.IsAtLeast(p.Rarity or "Common", "Mythic") then
		shake(p.Position, 0.5, 80)
	end
end

function Effects.ChestOpen(p)
	local colors = {
		Color3.fromRGB(230, 200, 120),
		Color3.fromRGB(120, 180, 255),
		Color3.fromRGB(200, 120, 255),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(255, 100, 140),
	}
	local color = colors[math.clamp(p.Tier or 1, 1, #colors)]
	burst(p.Position, color, 40, { SpeedMin = 10, SpeedMax = 30, LifeMax = 1.2, Acceleration = Vector3.new(0, -20, 0), Size = 1.1 })
	Effects.Pillar({ Position = p.Position, Color = color, Size = 4, Height = 20 })
end

function Effects.Teleport(p)
	Effects.Pillar({ Position = p.Position, Color = p.Color or Color3.fromRGB(120, 200, 255), Size = 5, Height = 25 })
	burst(p.Position, p.Color or Color3.fromRGB(120, 200, 255), 20, { SpeedMax = 20 })
end

function Effects.Revive(p)
	local root = rootOf(p.Model)
	if root then
		Effects.Pillar({ Position = root.Position, Color = Color3.fromRGB(120, 255, 150), Size = 6, Height = 25 })
	end
end

-- PROJECTILE VISUALS -----------------------------------------------------------------------------

local projectiles: { [string]: { Part: BasePart, Connection: RBXScriptConnection } } = {}

local function projectileModel(kind: string, color: Color3, size: number): BasePart
	local part
	if kind == "Knife" or kind == "Spear" or kind == "Shard" then
		local length = kind == "Spear" and size * 1.4 or size * 1.6
		part = newPart({ Size = Vector3.new(size * 0.25, size * 0.25, length), Color = color })
	elseif kind == "Crescent" or kind == "Cross" then
		part = newPart({ Size = Vector3.new(size, 0.4, size * 0.35), Color = color, Transparency = 0.15 })
		if kind == "Cross" then
			local second = newPart({ Size = Vector3.new(0.4, size, size * 0.35), CFrame = part.CFrame, Color = color, Parent = part })
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = second
			weld.Parent = part
			second.Anchored = false
		end
	else
		part = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Color = color })
		if kind == "Fireball" then
			local attachment = Instance.new("Attachment")
			attachment.Parent = part
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = FIRE
			emitter.Color = ColorSequence.new(color)
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(size, 0)
			emitter.Lifetime = NumberRange.new(0.2, 0.35)
			emitter.Speed = NumberRange.new(1, 3)
			emitter.Rate = 60 * VFXLib.Quality.ParticleMultiplier
			emitter.Parent = attachment
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.3, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.3, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = part
	if VFXLib.Quality.Lights then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = color
		pointLight.Range = size * 4
		pointLight.Parent = part
	end
	return part
end

function Effects.Projectile(p)
	local part = projectileModel(p.Kind or "Orb", p.Color or Color3.new(1, 1, 1), p.Size or 2)
	local position = p.Origin
	local direction = p.Direction.Unit
	local traveled = 0
	local targetRoot = rootOf(p.Target)
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if targetRoot and targetRoot.Parent then
			local toTarget = targetRoot.Position - position
			if toTarget.Magnitude > 1 then
				direction = direction:Lerp(toTarget.Unit, math.min(1, dt * 8)).Unit
			end
		end
		local step = direction * p.Speed * dt
		position += step
		traveled += step.Magnitude
		part.CFrame = CFrame.lookAt(position, position + direction)
		if traveled >= p.Range + 5 then
			connection:Disconnect()
			projectiles[p.Id] = nil
			fadeOut(part, 0.1)
		end
	end)
	projectiles[p.Id] = { Part = part, Connection = connection }
	life(part, (p.Range / math.max(1, p.Speed)) + 2)
end

function Effects.ProjectileEnd(p)
	local entry = projectiles[p.Id]
	if entry then
		entry.Connection:Disconnect()
		projectiles[p.Id] = nil
		burst(p.Position, entry.Part.Color, 12, { SpeedMax = 25 })
		fadeOut(entry.Part, 0.08)
	end
end

-- Weapon trail during swings (Trail between TrailA/TrailB attachments of the weapon)
function VFXLib.WeaponTrail(model: Model, color: Color3?, duration: number)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == "TrailA" then
			local other = descendant.Parent and descendant.Parent:FindFirstChild("TrailB")
			if other then
				local trail = Instance.new("Trail")
				trail.Attachment0 = descendant
				trail.Attachment1 = other :: Attachment
				trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.new(1, 1, 1))
				trail.LightEmission = 1
				trail.Lifetime = 0.18
				trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				trail.WidthScale = NumberSequence.new(1, 0.2)
				trail.Parent = descendant.Parent
				Debris:AddItem(trail, duration + 0.2)
				task.delay(duration, function()
					trail.Enabled = false
				end)
			end
		end
	end
end

function VFXLib.Play(effect: string, params)
	local handler = Effects[effect]
	if not handler then
		return false
	end
	if VFXLib.ActiveCount > VFXLib.Quality.MaxActiveEffects and effect ~= "DamageNumber" and effect ~= "ProjectileEnd" then
		return true -- too many effects alive: skip cosmetic extras
	end
	local ok, err = pcall(handler, params)
	if not ok then
		warn("[VFXLib] " .. effect .. " failed: " .. tostring(err))
	end
	return true
end

return VFXLib
