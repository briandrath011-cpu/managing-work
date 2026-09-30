--[[
	GameConfig (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.GameConfig
	Central tuning values. Change numbers here - no other script needs to be edited.
]]
local GameConfig = {}

GameConfig.GameName = "Ascendant Realms"
GameConfig.Version = "1.0.0"

GameConfig.Data = {
	StoreName = "AscendantRealms_PlayerData_v1",
	SchemaVersion = 1,
	AutosaveInterval = 120, -- seconds
	SessionLockTimeout = 1800, -- a lock older than this is considered dead (server crash)
	MaxLoadRetries = 5,
	MaxSaveRetries = 4,
	-- When Studio has no API access, data lives in memory only (warns in output).
	AllowMemoryFallbackInStudio = true,
}

GameConfig.Progression = {
	MaxLevel = 200,
	StatPointsPerLevel = 3,
	StartingStatPoints = 0,
	MaxStatPerAttribute = 600,
	StartingGold = 250,
	StartingGems = 25,
	StartingSpins = 5,
	StartingTraitRolls = 1,
	SpinEveryNLevels = 5, -- free spin every N levels
	GemsPerLevelMilestone = 10, -- every 10 levels
}

GameConfig.Stats = { "Strength", "Defense", "Energy", "Weapon", "Agility" }

GameConfig.StatDescriptions = {
	Strength = "Boosts fighting style (M1/Heavy) damage.",
	Defense = "Increases max health and reduces incoming damage.",
	Energy = "Boosts power damage, max energy and energy regen.",
	Weapon = "Boosts weapon damage and weapon skills.",
	Agility = "Increases move speed, dash cooldown and critical chance.",
}

GameConfig.Character = {
	BaseHealth = 120,
	HealthPerLevel = 12,
	HealthPerDefense = 6,
	BaseEnergy = 100,
	EnergyPerStat = 2,
	EnergyRegenPerSecond = 6,
	EnergyRegenPerStat = 0.05,
	WalkSpeed = 18,
	SprintSpeed = 30,
	SpeedPerAgility = 0.02, -- +0.02 speed per agility point
	MaxBonusSpeed = 10,
	JumpPower = 55,
	OutOfCombatRegenDelay = 6,
	OutOfCombatRegenPercent = 0.04, -- per second
	RespawnTime = 4,
}

GameConfig.Movement = {
	DashCooldown = 1.1,
	MinDashCooldown = 0.6,
	DashCooldownPerAgility = 0.001,
	DashSpeed = 95,
	DashDuration = 0.18,
	AirDashes = 1,
	DoubleJumpPower = 55,
	WallJumpPower = 60,
	WallJumpPush = 40,
	WallRunDuration = 1.6,
	WallRunSpeed = 38,
	FlightSpeed = 55,
	FlightUnlockLevel = 110,
	-- Server anti-exploit: allowed horizontal speed = max(sprint, walk) * tolerance + allowance
	SpeedTolerance = 1.45,
	CheckInterval = 1,
	MaxStrikesBeforeRubberband = 2,
}

GameConfig.Combat = {
	M1ComboLength = 4,
	ComboResetTime = 1.1,
	M1BaseCooldown = 0.32, -- scaled by weapon attack speed
	M1FinisherEndLag = 0.55,
	HeavyCooldown = 2.5,
	BlockDamageReduction = 0.8,
	MaxGuard = 100,
	GuardRegenPerSecond = 18,
	GuardBreakStun = 1.6,
	PerfectBlockWindow = 0.22,
	PerfectBlockStun = 0.9,
	CounterCooldown = 6,
	BaseCritChance = 0.05,
	CritPerAgility = 0.0004,
	MaxCritChance = 0.4,
	CritMultiplier = 1.6,
	HitRangeTolerance = 6, -- extra studs allowed for latency
	MaxSkillRangeTolerance = 12,
	PvPEnabled = false,
	InCombatDuration = 8,
	AwakeningPerDamageDealt = 0.06, -- per point of damage (scaled by max health)
	AwakeningPerDamageTaken = 0.12,
	AwakeningPerComboHit = 1.2,
}

GameConfig.Spins = {
	SpinGemCost = 50, -- buy one spin with gems
	TenSpinGemCost = 450,
	GoldConversion = { Common = 150, Rare = 400, Epic = 1200, Legendary = 4000, Mythic = 12000, Secret = 40000 },
	DefaultStorageSlots = 12,
	MaxStorageSlots = 60,
	StorageUpgradeGemCost = 100,
	StorageUpgradeSlots = 4,
}

GameConfig.Traits = {
	RollGemCost = 75,
}

GameConfig.World = {
	AutoBuild = true, -- build the procedural greybox world on server start
	DayLengthMinutes = 18, -- full day/night cycle length in real minutes
	WeatherIntervalRange = { 180, 420 },
	WorldEventIntervalRange = { 420, 780 },
	EnemyActivationDistance = 220,
	RegionCheckInterval = 1,
}

GameConfig.Dungeons = {
	MaxPlayers = 4,
	LobbyCountdown = 12,
	RoomOriginSpacing = 1600,
	InstanceOrigin = Vector3.new(8000, 400, 0),
}

GameConfig.Raids = {
	MaxPlayers = 8,
	LobbyCountdown = 15,
	ReviveTime = 3,
	DownedDuration = 25,
	InstanceOrigin = Vector3.new(-8000, 400, 0),
}

GameConfig.Transform = {
	Duration = 30,
	MaxAwakening = 100,
	DrainPerSecond = 0,
}

GameConfig.Debug = {
	-- Studio-only chat commands like "/level 50" for testing. Ignored in live servers.
	EnableStudioCommands = true,
	AdminUserIds = {},
}

return GameConfig
