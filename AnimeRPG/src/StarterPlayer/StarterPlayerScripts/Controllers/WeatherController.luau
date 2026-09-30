--[[
	WeatherController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.WeatherController
	Renders weather + time of day locally (server only replicates Workspace attributes):
	Rain / Storm (lightning flashes + thunder) / Snow / Fog / Clear, region fog colors,
	night tint and the Blood Moon. Particle density follows the quality setting.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local WorldConfig = require(ReplicatedStorage.Modules.World.WorldConfig)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local WeatherController = {}

local player = Players.LocalPlayer
local emitterPart: Part
local rainEmitter: ParticleEmitter
local snowEmitter: ParticleEmitter
local colorCorrection: ColorCorrectionEffect
local currentWeather = "Clear"

local function makeEmitter(
	texture: string,
	color: Color3,
	size: number,
	speed: NumberRange,
	rate: number,
	lifetime: number
): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(size)
	emitter.Speed = speed
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Lifetime = NumberRange.new(lifetime)
	emitter.Rate = rate
	emitter.LightInfluence = 0.6
	emitter.Enabled = false
	emitter.Parent = emitterPart
	return emitter
end

local function effectiveWeather(): string
	local character = player.Character
	local regionId = character and character:GetAttribute("Region")
	local weather = Workspace:GetAttribute("Weather") or "Clear"
	if regionId == "Frozen" then
		return weather == "Clear" and "Snow" or (weather == "Rain" and "Snow" or weather)
	end
	if regionId == "Desert" and weather == "Rain" then
		return "Clear"
	end
	if regionId == "Celestial" then
		return "Clear"
	end
	return weather
end

local function applyAtmosphere()
	local character = player.Character
	local regionId = character and character:GetAttribute("Region")
	local region = regionId and WorldConfig.GetRegion(regionId)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local weather = effectiveWeather()
	local phase = Workspace:GetAttribute("TimePhase")
	local bloodMoon = Workspace:GetAttribute("BloodMoon") == true
	if atmosphere and region then
		local density = 0.3
		if weather == "Fog" then
			density = 0.65
		elseif weather == "Storm" then
			density = 0.5
		elseif weather == "Snow" then
			density = 0.45
		end
		TweenService:Create(atmosphere, TweenInfo.new(3), { Density = density, Color = region.Theme.Fog }):Play()
	end
	local tint = Color3.new(1, 1, 1)
	local saturation = 0
	if bloodMoon then
		tint = Color3.fromRGB(255, 140, 140)
		saturation = -0.1
	elseif phase == "Night" then
		tint = Color3.fromRGB(190, 200, 255)
	elseif phase == "Evening" then
		tint = Color3.fromRGB(255, 220, 190)
	elseif weather == "Storm" then
		tint = Color3.fromRGB(200, 205, 220)
		saturation = -0.25
	end
	TweenService:Create(colorCorrection, TweenInfo.new(3), { TintColor = tint, Saturation = saturation }):Play()
	currentWeather = weather
	local mult = VFXLib.Quality.WeatherParticles
	rainEmitter.Enabled = (weather == "Rain" or weather == "Storm") and mult > 0
	rainEmitter.Rate = (weather == "Storm" and 900 or 500) * mult
	snowEmitter.Enabled = weather == "Snow" and mult > 0
	snowEmitter.Rate = 250 * mult
end

function WeatherController:Init()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "WeatherEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(120, 1, 120)
	emitterPart.Parent = Workspace:FindFirstChild("Effects") or Workspace
	rainEmitter = makeEmitter(
		"rbxasset://textures/particles/sparkles_main.dds",
		Color3.fromRGB(170, 190, 230),
		0.15,
		NumberRange.new(90, 110),
		500,
		1.2
	)
	rainEmitter.Squash = NumberSequence.new(-3)
	snowEmitter =
		makeEmitter("rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 255, 255), 0.35, NumberRange.new(8, 14), 250, 6)
	snowEmitter.Acceleration = Vector3.new(2, 0, 1)
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "WeatherCC"
	colorCorrection.Parent = Lighting
	for _, attribute in ipairs({ "Weather", "TimePhase", "BloodMoon" }) do
		Workspace:GetAttributeChangedSignal(attribute):Connect(applyAtmosphere)
	end
	player.CharacterAdded:Connect(function(character)
		character:GetAttributeChangedSignal("Region"):Connect(applyAtmosphere)
		task.delay(1, applyAtmosphere)
	end)
	if player.Character then
		player.Character:GetAttributeChangedSignal("Region"):Connect(applyAtmosphere)
	end
	applyAtmosphere()
end

function WeatherController:Start()
	local nextThunder = 0
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
		if currentWeather == "Storm" and os.clock() > nextThunder then
			nextThunder = os.clock() + math.random(6, 14)
			VFXLib.ScreenFlashLocal(Color3.fromRGB(220, 230, 255), 0.25, 0.55)
			task.delay(math.random() * 1.5 + 0.3, function()
				SoundLib.Play("Thunder", nil, 0.6)
			end)
		end
	end)
end

return WeatherController
