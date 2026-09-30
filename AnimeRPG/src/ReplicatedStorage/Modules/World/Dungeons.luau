--[[
	Dungeons (ModuleScript)
	Location: ReplicatedStorage.Modules.World.Dungeons
	PHASE 16 - Dungeon definitions (1-4 players).
	Flow: Lobby -> Room 1 (wave) -> Room 2 (elites) -> Room 3 (miniboss) -> Final Room (boss) -> Reward Chest
]]
local C = Color3.fromRGB

local Dungeons = {}

Dungeons.Difficulties = {
	Normal = { Order = 1, LevelBonus = 0, Health = 1, Damage = 1, Rewards = 1, Color = C(120, 220, 120) },
	Hard = { Order = 2, LevelBonus = 10, Health = 1.6, Damage = 1.3, Rewards = 1.9, Color = C(255, 170, 60) },
	Nightmare = { Order = 3, LevelBonus = 25, Health = 2.4, Damage = 1.7, Rewards = 3.2, Color = C(255, 60, 80) },
}
Dungeons.DifficultyOrder = { "Normal", "Hard", "Nightmare" }

Dungeons.List = {
	GoblinHollow = {
		DisplayName = "Goblin Hollow",
		LevelRequired = 10,
		BaseLevel = 14,
		TimeLimit = 900,
		Theme = { Floor = C(90, 80, 60), Wall = C(70, 60, 50), Accent = C(160, 255, 120), Material = Enum.Material.Slate },
		Rooms = {
			{ Kind = "Wave", Enemies = { "DungeonMinion", "DungeonMinion", "DungeonCaster" }, Count = 6, Waves = 2 },
			{ Kind = "Elite", Enemies = { "DungeonElite" }, Count = 2, Waves = 1 },
			{ Kind = "Miniboss", Enemies = { "BanditBrute" }, Count = 1, HealthScale = 5, Waves = 1 },
			{ Kind = "Boss", Boss = "HollowWarlord" },
		},
		Rewards = {
			Exp = 2500,
			Gold = 1200,
			Gems = 8,
			Drops = {
				{ Id = "SpinToken", Chance = 0.15, Min = 1, Max = 1 },
				{ Id = "BanditCleaver", Chance = 0.08, Min = 1, Max = 1 },
				{ Id = "WolfToothCharm", Chance = 0.2, Min = 1, Max = 1 },
				{ Id = "ExpScroll", Chance = 0.3, Min = 1, Max = 1 },
			},
		},
	},
	SunkenTomb = {
		DisplayName = "Sunken Tomb",
		LevelRequired = 30,
		BaseLevel = 36,
		TimeLimit = 900,
		Theme = { Floor = C(200, 170, 110), Wall = C(170, 140, 90), Accent = C(60, 210, 200), Material = Enum.Material.Sandstone },
		Rooms = {
			{ Kind = "Wave", Enemies = { "MummyGuard", "SandScorpion", "SandMage" }, Count = 6, Waves = 2 },
			{ Kind = "Elite", Enemies = { "SandGolem" }, Count = 2, Waves = 1 },
			{ Kind = "Miniboss", Enemies = { "DungeonElite" }, Count = 1, HealthScale = 5, Waves = 1 },
			{ Kind = "Boss", Boss = "TombGuardian" },
		},
		Rewards = {
			Exp = 22000,
			Gold = 6000,
			Gems = 12,
			Drops = {
				{ Id = "SpinToken", Chance = 0.2, Min = 1, Max = 1 },
				{ Id = "PharaohStaff", Chance = 0.05, Min = 1, Max = 1 },
				{ Id = "SunAmulet", Chance = 0.1, Min = 1, Max = 1 },
				{ Id = "SunShard", Chance = 0.8, Min = 2, Max = 5 },
			},
		},
	},
	CloudCitadel = {
		DisplayName = "Cloud Citadel",
		LevelRequired = 55,
		BaseLevel = 62,
		TimeLimit = 900,
		Theme = { Floor = C(235, 240, 255), Wall = C(200, 215, 240), Accent = C(255, 240, 120), Material = Enum.Material.Marble },
		Rooms = {
			{ Kind = "Wave", Enemies = { "CloudSprite", "Harpy", "StormKnight" }, Count = 7, Waves = 2 },
			{ Kind = "Elite", Enemies = { "ThunderBeast" }, Count = 2, Waves = 1 },
			{ Kind = "Miniboss", Enemies = { "StormKnight" }, Count = 1, HealthScale = 6, Waves = 1 },
			{ Kind = "Boss", Boss = "SkyWarden" },
		},
		Rewards = {
			Exp = 110000,
			Gold = 20000,
			Gems = 18,
			Drops = {
				{ Id = "SpinToken", Chance = 0.25, Min = 1, Max = 1 },
				{ Id = "ThunderSpear", Chance = 0.03, Min = 1, Max = 1 },
				{ Id = "StormRing", Chance = 0.08, Min = 1, Max = 1 },
				{ Id = "ThunderFeather", Chance = 0.8, Min = 2, Max = 5 },
			},
		},
	},
	GlacierDepths = {
		DisplayName = "Glacier Depths",
		LevelRequired = 85,
		BaseLevel = 95,
		TimeLimit = 900,
		Theme = { Floor = C(200, 230, 255), Wall = C(150, 200, 240), Accent = C(120, 220, 255), Material = Enum.Material.Ice },
		Rooms = {
			{ Kind = "Wave", Enemies = { "FrostWolf", "IceSoldier", "FrostSorcerer" }, Count = 7, Waves = 2 },
			{ Kind = "Elite", Enemies = { "FrostKnight", "Yeti" }, Count = 2, Waves = 1 },
			{ Kind = "Miniboss", Enemies = { "Yeti" }, Count = 1, HealthScale = 6, Waves = 1 },
			{ Kind = "Boss", Boss = "GlacierWyrm" },
		},
		Rewards = {
			Exp = 420000,
			Gold = 50000,
			Gems = 25,
			Drops = {
				{ Id = "SpinToken", Chance = 0.3, Min = 1, Max = 1 },
				{ Id = "FrostbiteDagger", Chance = 0.08, Min = 1, Max = 1 },
				{ Id = "FrostRing", Chance = 0.08, Min = 1, Max = 1 },
				{ Id = "AscensionSeal", Chance = 0.03, Min = 1, Max = 1 },
			},
		},
	},
	InfernalPit = {
		DisplayName = "Infernal Pit",
		LevelRequired = 120,
		BaseLevel = 135,
		TimeLimit = 900,
		Theme = { Floor = C(50, 25, 25), Wall = C(35, 15, 15), Accent = C(255, 90, 20), Material = Enum.Material.Basalt },
		Rooms = {
			{ Kind = "Wave", Enemies = { "Imp", "Hellhound", "VoidCultist" }, Count = 8, Waves = 2 },
			{ Kind = "Elite", Enemies = { "DemonWarrior" }, Count = 3, Waves = 1 },
			{ Kind = "Miniboss", Enemies = { "DemonGeneral" }, Count = 1, HealthScale = 4, Waves = 1 },
			{ Kind = "Boss", Boss = "InfernalArchfiend" },
		},
		Rewards = {
			Exp = 1800000,
			Gold = 150000,
			Gems = 35,
			Drops = {
				{ Id = "SpinToken", Chance = 0.35, Min = 1, Max = 2 },
				{ Id = "BossCore", Chance = 0.2, Min = 1, Max = 1 },
				{ Id = "VoidEarring", Chance = 0.05, Min = 1, Max = 1 },
				{ Id = "DemonHeart", Chance = 0.02, Min = 1, Max = 1 },
				{ Id = "VoidCrystal", Chance = 0.8, Min = 2, Max = 4 },
			},
		},
	},
}

return Dungeons
