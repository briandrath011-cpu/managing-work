--[[
	DataTemplate (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.DataTemplate
	Default save file for a new player. Anything added here automatically appears
	in old saves (TableUtil.Reconcile on load).
]]
local GameConfig = require(script.Parent.GameConfig)

local P = GameConfig.Progression

return {
	SchemaVersion = GameConfig.Data.SchemaVersion,

	-- PHASE 1: core progression
	Level = 1,
	Exp = 0,
	Gold = P.StartingGold,
	Gems = P.StartingGems,
	StatPoints = P.StartingStatPoints,
	Stats = { Strength = 0, Defense = 0, Energy = 0, Weapon = 0, Agility = 0 },

	-- PHASE 5-7: powers + spins
	Spins = P.StartingSpins,
	Pity = { Legendary = 0, Mythic = 0, Secret = 0 },
	Powers = {
		EquippedUid = "",
		StorageSlots = GameConfig.Spins.DefaultStorageSlots,
		Owned = {}, -- [uid] = { Id = "Rinnegan", Locked = false, Obtained = os.time() }
	},
	PowerMastery = {}, -- [powerId] = { Level = 0, Exp = 0 }

	-- PHASE 8-10: weapons, inventory, equipment
	Inventory = {}, -- [uid] = { Id = itemId, Amount = 1, Locked = false, Favorite = false }
	Equipment = { Weapon = "", Armor = "", Head = "", Accessory1 = "", Accessory2 = "" },
	WeaponMastery = {}, -- [weaponId] = { Level = 0, Exp = 0 }
	FightingStyle = "Brawler",
	FightingStyles = { Brawler = true },

	-- Build extras
	Trait = "None",
	TraitRolls = P.StartingTraitRolls,
	Transformations = { Equipped = "", Unlocked = {} },

	-- PHASE 12: quests
	Quests = {
		Active = {}, -- [questId] = { Progress = { [objectiveIndex] = n }, Accepted = os.time() }
		Completed = {}, -- [questId] = timesCompleted
		DailyReset = 0,
		WeeklyReset = 0,
		DailyPool = {},
		WeeklyPool = {},
	},

	-- PHASE 13-14: bosses and drops
	BossKills = {}, -- [bossId] = count
	BossDrops = {}, -- [itemId] = count (collection log)

	-- Meta progression
	Counters = {
		EnemiesDefeated = 0,
		BossesDefeated = 0,
		SpinsUsed = 0,
		DungeonsCleared = 0,
		RaidsCleared = 0,
		ItemsCrafted = 0,
		ChestsOpened = 0,
		QuestsCompleted = 0,
		EventsCompleted = 0,
		Deaths = 0,
		DamageDealt = 0,
		PlayTime = 0,
	},
	Achievements = {}, -- [achievementId] = unlockedTimestamp
	Titles = { Equipped = "", Owned = {} },
	Cosmetics = { Aura = "", Owned = {} },

	-- Exploration
	Discovered = { Regions = {}, Waypoints = {}, Chests = {}, Secrets = {}, LastWaypoint = "GreenwoodVillage" },
	Unlocks = { DoubleJump = true, AirDash = true, WallRun = true, WallJump = true, Flight = false },

	Settings = {
		Quality = "Auto",
		MusicVolume = 0.5,
		SfxVolume = 0.8,
		CameraShake = true,
		DamageNumbers = true,
		AutoDeleteCommon = false,
		AutoDeleteRare = false,
		SkipSpinAnimation = false,
	},

	LastLogin = 0,
	FirstJoin = 0,
}
