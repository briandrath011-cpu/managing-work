--[[
	QualityConfig (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.QualityConfig
	VFX quality presets. "Auto" picks Low on phones/tablets and High on PC/console.
]]
local QualityConfig = {}

QualityConfig.Presets = {
	Low = {
		ParticleMultiplier = 0.35,
		MaxActiveEffects = 25,
		MaxDistance = 140,
		GroundCracks = false,
		Debris = false,
		Afterimages = false,
		PostProcessing = false,
		Lights = false,
		DamageNumbers = true,
		MaxDebrisPieces = 0,
		WeatherParticles = 0.3,
	},
	Medium = {
		ParticleMultiplier = 0.7,
		MaxActiveEffects = 60,
		MaxDistance = 240,
		GroundCracks = true,
		Debris = true,
		Afterimages = true,
		PostProcessing = true,
		Lights = false,
		DamageNumbers = true,
		MaxDebrisPieces = 6,
		WeatherParticles = 0.65,
	},
	High = {
		ParticleMultiplier = 1,
		MaxActiveEffects = 120,
		MaxDistance = 380,
		GroundCracks = true,
		Debris = true,
		Afterimages = true,
		PostProcessing = true,
		Lights = true,
		DamageNumbers = true,
		MaxDebrisPieces = 12,
		WeatherParticles = 1,
	},
}

QualityConfig.Options = { "Auto", "Low", "Medium", "High" }

return QualityConfig
