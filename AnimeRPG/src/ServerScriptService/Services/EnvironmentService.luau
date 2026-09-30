--[[
	EnvironmentService (ModuleScript)
	Location: ServerScriptService.Services.EnvironmentService

	PHASE 19-21 - Day/Night + Weather (server authority, replicated through attributes)
	Workspace attributes:
		TimePhase  = "Morning" | "Day" | "Evening" | "Night"
		Weather    = "Clear" | "Rain" | "Storm" | "Snow" | "Fog"   (global weather roll)
		BloodMoon  = boolean (world event)
	The client WeatherController renders particles/fog per region (snow region always snows).
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Signal = require(Modules.Shared.Signal)
local WeightedRandom = require(Modules.Shared.WeightedRandom)
local Registry = require(ServerScriptService.ServerModules.Registry)

local EnvironmentService = {}
EnvironmentService.PhaseChanged = Signal.new() -- (phase)
EnvironmentService.WeatherChanged = Signal.new() -- (weather)

local rng = Random.new()

-- ClockTime ranges
local PHASES = {
	{ Name = "Morning", From = 5, To = 9 },
	{ Name = "Day", From = 9, To = 17 },
	{ Name = "Evening", From = 17, To = 20 },
	{ Name = "Night", From = 20, To = 29 }, -- wraps past midnight (29 = 5 AM)
}

local function phaseFor(clock: number): string
	local t = clock < 5 and clock + 24 or clock
	for _, phase in ipairs(PHASES) do
		if t >= phase.From and t < phase.To then
			return phase.Name
		end
	end
	return "Night"
end

function EnvironmentService:GetPhase(): string
	return workspace:GetAttribute("TimePhase") or "Day"
end

function EnvironmentService:IsNight(): boolean
	return self:GetPhase() == "Night"
end

function EnvironmentService:SetWeather(weather: string)
	workspace:SetAttribute("Weather", weather)
	self.WeatherChanged:Fire(weather)
end

function EnvironmentService:SetClock(clock: number)
	Lighting.ClockTime = clock % 24
end

function EnvironmentService:Init()
	Lighting.ClockTime = 8
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(200, 215, 235)
		atmosphere.Decay = Color3.fromRGB(110, 120, 140)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
	workspace:SetAttribute("TimePhase", phaseFor(Lighting.ClockTime))
	workspace:SetAttribute("Weather", "Clear")
	workspace:SetAttribute("BloodMoon", false)
end

function EnvironmentService:Start()
	-- Weather rolls
	task.spawn(function()
		local range = GameConfig.World.WeatherIntervalRange
		while true do
			task.wait(rng:NextNumber(range[1], range[2]))
			local weather = WeightedRandom.PickKey({ Clear = 6, Rain = 2, Storm = 1, Fog = 1 }, rng, { "Clear", "Rain", "Storm", "Fog" })
			if workspace:GetAttribute("EventWeatherLock") ~= true then
				self:SetWeather(weather or "Clear")
			end
		end
	end)

	-- Day / night cycle (smooth, one update per 0.5s)
	local secondsPerHour = GameConfig.World.DayLengthMinutes * 60 / 24
	local lastPhase = workspace:GetAttribute("TimePhase")
	while true do
		task.wait(0.5)
		Lighting.ClockTime = (Lighting.ClockTime + 0.5 / secondsPerHour) % 24
		local phase = phaseFor(Lighting.ClockTime)
		if phase ~= lastPhase then
			lastPhase = phase
			workspace:SetAttribute("TimePhase", phase)
			self.PhaseChanged:Fire(phase)
			if Registry.Has("FXService") and phase == "Morning" then
				Registry.Get("FXService"):Notify(nil, "Event", "☀ A new day dawns.")
			end
		end
	end
end

return EnvironmentService
