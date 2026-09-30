--[[
	QuestCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.Quests.QuestCatalog

	PHASE 12 - Quest definitions.
	Type: Kill | Boss | Collect | Delivery | Exploration | Dungeon | Daily | Weekly | Secret
	Objective kinds:
		{ Kind = "Kill", Target = enemyId | "Any", Count }
		{ Kind = "Boss", Target = bossId | "Any", Count }
		{ Kind = "Collect", Item, Count }            -- items are removed on turn-in
		{ Kind = "Deliver", Item, Count, To = npcId } -- item is given on accept
		{ Kind = "Explore", Target = secretId | waypointId | regionId }
		{ Kind = "Dungeon", Target = dungeonId | "Any", Count }
		{ Kind = "Raid", Target = raidId | "Any", Count }
		{ Kind = "Talk", Target = npcId }
	Rewards: Exp, Gold, Gems, Spins, TraitRolls, Items = { id = amount }, Title, PowerMastery, Style
]]
local quests = {}

local function add(id: string, def)
	def.Id = id
	def.LevelRequired = def.LevelRequired or 1
	def.TurnIn = def.TurnIn or def.Giver
	quests[id] = def
end

-- GREENWOOD --------------------------------------------------------------------------------
add("GW_Wolves", {
	Name = "Wolf Trouble",
	Type = "Kill",
	Giver = "GuardCaptainLyra",
	Objectives = { { Kind = "Kill", Target = "ForestWolf", Count = 5 } },
	Rewards = { Exp = 180, Gold = 120 },
	Dialog = {
		Offer = "Wolves keep attacking travelers west of the village. Thin their numbers - 5 should do.",
		Complete = "Nicely done! You're a natural.",
	},
})
add("GW_Bandits", {
	Name = "Bandit Sweep",
	Type = "Kill",
	Giver = "GuardCaptainLyra",
	Prerequisite = "GW_Wolves",
	LevelRequired = 4,
	Objectives = { { Kind = "Kill", Target = "Bandit", Count = 8 } },
	Rewards = { Exp = 600, Gold = 300, Spins = 1 },
	Dialog = {
		Offer = "The bandit camp north-east grows bolder. Defeat 8 bandits.",
		Complete = "The roads are safer already. Here - take a spin, see what fate grants you.",
	},
})
add("GW_Herbs", {
	Name = "Healing Harvest",
	Type = "Collect",
	Giver = "HerbalistMira",
	LevelRequired = 2,
	Objectives = { { Kind = "Collect", Item = "GreenwoodHerb", Count = 5 } },
	Rewards = { Exp = 300, Gold = 150, Items = { HealthPotion = 3 } },
	Dialog = {
		Offer = "Wolves carry Greenwood Herbs in their fur, strange as it sounds. Bring me 5.",
		Complete = "Wonderful! Take these potions.",
	},
})
add("GW_Delivery", {
	Name = "Special Delivery",
	Type = "Delivery",
	Giver = "CourierFinn",
	TurnIn = "BlacksmithBrann",
	LevelRequired = 3,
	Objectives = { { Kind = "Deliver", Item = "SealedLetter", Count = 1, To = "BlacksmithBrann" } },
	Rewards = { Exp = 250, Gold = 200 },
	Dialog = {
		Offer = "Could you bring this letter to Blacksmith Brann? My legs are tired.",
		Complete = "A letter from Finn? Thanks, traveler!",
	},
})
add("GW_Scout", {
	Name = "The Old Watchtower",
	Type = "Exploration",
	Giver = "GuardCaptainLyra",
	Prerequisite = "GW_Bandits",
	LevelRequired = 8,
	Objectives = { { Kind = "Explore", Target = "WatchTower" } },
	Rewards = { Exp = 900, Gold = 400, Gems = 10 },
	Dialog = {
		Offer = "Climb the old watchtower south-east of the village and report what you see.",
		Complete = "A hidden stash up there? Keep it, you earned it.",
	},
})
add("GW_Brutes", {
	Name = "Breaking the Brutes",
	Type = "Kill",
	Giver = "GuardCaptainLyra",
	Prerequisite = "GW_Bandits",
	LevelRequired = 12,
	Objectives = { { Kind = "Kill", Target = "BanditBrute", Count = 3 }, { Kind = "Kill", Target = "BanditArcher", Count = 4 } },
	Rewards = { Exp = 2200, Gold = 800, Items = { ExpScroll = 1 } },
	Dialog = {
		Offer = "The chief's brutes and archers guard his camp. Take them out.",
		Complete = "Now the chief is exposed. Speak to the Elder.",
	},
})
add("GW_Chief", {
	Name = "The Bandit Chief",
	Type = "Boss",
	Giver = "ElderRowan",
	Prerequisite = "GW_Brutes",
	LevelRequired = 15,
	Objectives = { { Kind = "Boss", Target = "BanditChief", Count = 1 } },
	Rewards = { Exp = 5000, Gold = 2000, Gems = 25, Spins = 2 },
	Dialog = {
		Offer = "Garrok the Bandit Chief terrorises our village. End his reign.",
		Complete = "Greenwood is free! You are a true hero.",
	},
})
add("GW_Dungeon", {
	Name = "Into the Hollow",
	Type = "Dungeon",
	Giver = "DungeonKeeper",
	LevelRequired = 10,
	Objectives = { { Kind = "Dungeon", Target = "GoblinHollow", Count = 1 } },
	Rewards = { Exp = 3000, Gold = 1000, Gems = 15 },
	Dialog = { Offer = "Clear the Goblin Hollow dungeon. Bring friends if you can.", Complete = "You made it out! Impressive." },
})
add("GW_Journey", {
	Name = "Beyond the Dunes",
	Type = "Exploration",
	Giver = "ElderRowan",
	Prerequisite = "GW_Chief",
	LevelRequired = 18,
	Objectives = { { Kind = "Explore", Target = "Desert" }, { Kind = "Talk", Target = "SultanAzim" } },
	Rewards = { Exp = 3000, Gold = 1500 },
	Dialog = { Offer = "Head east to the Desert Kingdom. Sultan Azim needs help.", Complete = "Rowan sent you? Good. We need strength." },
	TurnIn = "SultanAzim",
})

-- DESERT -----------------------------------------------------------------------------------
add("DS_Arrival", {
	Name = "Sands of Trial",
	Type = "Kill",
	Giver = "SultanAzim",
	LevelRequired = 20,
	Objectives = { { Kind = "Kill", Target = "SandScorpion", Count = 10 } },
	Rewards = { Exp = 6000, Gold = 1500 },
	Dialog = { Offer = "Scorpions poison our wells. Kill 10.", Complete = "Our wells thank you." },
})
add("DS_Scorpions", {
	Name = "Raider Menace",
	Type = "Kill",
	Giver = "SultanAzim",
	Prerequisite = "DS_Arrival",
	LevelRequired = 25,
	Objectives = { { Kind = "Kill", Target = "DesertRaider", Count = 10 } },
	Rewards = { Exp = 11000, Gold = 2500, Spins = 1 },
	Dialog = { Offer = "Raiders ambush our caravans in the western dunes.", Complete = "The caravans move again." },
})
add("DS_Relics", {
	Name = "Lost Relics",
	Type = "Collect",
	Giver = "ArchaeologistNadia",
	LevelRequired = 30,
	Objectives = { { Kind = "Collect", Item = "AncientRelic", Count = 6 } },
	Rewards = { Exp = 14000, Gold = 3000, Items = { LuckPotion = 1 } },
	Dialog = { Offer = "Mummy guards and golems carry Ancient Relics. Bring me 6!", Complete = "Incredible specimens!" },
})
add("DS_Map", {
	Name = "The Relic Map",
	Type = "Delivery",
	Giver = "ArchaeologistNadia",
	TurnIn = "SultanAzim",
	Prerequisite = "DS_Relics",
	LevelRequired = 30,
	Objectives = { { Kind = "Deliver", Item = "RelicMap", Count = 1, To = "SultanAzim" } },
	Rewards = { Exp = 8000, Gold = 2000 },
	Dialog = {
		Offer = "Bring this map to the Sultan. It shows the way into the pyramid.",
		Complete = "So the pyramid peak hides a door...",
	},
})
add("DS_Pyramid", {
	Name = "Peak of the Pyramid",
	Type = "Exploration",
	Giver = "ArchaeologistNadia",
	Prerequisite = "DS_Map",
	LevelRequired = 32,
	Objectives = { { Kind = "Explore", Target = "PyramidTop" } },
	Rewards = { Exp = 12000, Gold = 3000, Gems = 15 },
	Dialog = { Offer = "Climb the great pyramid in the east!", Complete = "You found the peak! Remarkable." },
})
add("DS_Raiders", {
	Name = "Golem Breaker",
	Type = "Kill",
	Giver = "SultanAzim",
	Prerequisite = "DS_Scorpions",
	LevelRequired = 38,
	Objectives = { { Kind = "Kill", Target = "SandGolem", Count = 4 }, { Kind = "Kill", Target = "SandMage", Count = 5 } },
	Rewards = { Exp = 26000, Gold = 5000 },
	Dialog = { Offer = "The Pharaoh's golems and mages guard the temple. Break them.", Complete = "The temple lies open." },
})
add("DS_Pharaoh", {
	Name = "The Undying Pharaoh",
	Type = "Boss",
	Giver = "SultanAzim",
	Prerequisite = "DS_Raiders",
	LevelRequired = 40,
	Objectives = { { Kind = "Boss", Target = "SandPharaoh", Count = 1 } },
	Rewards = { Exp = 45000, Gold = 9000, Gems = 30, Spins = 2 },
	Dialog = { Offer = "Pharaoh Amunet has awoken. Put her back to rest.", Complete = "The kingdom is in your debt." },
})
add("DS_Dungeon", {
	Name = "The Sunken Tomb",
	Type = "Dungeon",
	Giver = "ArchaeologistNadia",
	LevelRequired = 30,
	Objectives = { { Kind = "Dungeon", Target = "SunkenTomb", Count = 1 } },
	Rewards = { Exp = 20000, Gold = 4000, Gems = 20 },
	Dialog = { Offer = "Clear the Sunken Tomb. Its treasures await!", Complete = "The tomb's secrets are ours!" },
})
add("DS_Journey", {
	Name = "Ride the Wind",
	Type = "Exploration",
	Giver = "SultanAzim",
	Prerequisite = "DS_Pharaoh",
	LevelRequired = 43,
	Objectives = { { Kind = "Explore", Target = "SkyIslands" }, { Kind = "Talk", Target = "SkySage" } },
	Rewards = { Exp = 30000, Gold = 6000 },
	TurnIn = "SkySage",
	Dialog = {
		Offer = "Use the Wind Pillar in the north-east to reach the Sky Islands.",
		Complete = "A ground-walker made it up here? Welcome.",
	},
})

-- SKY --------------------------------------------------------------------------------------
add(
	"SK_Sprites",
	{
		Name = "Cloud Cleanup",
		Type = "Kill",
		Giver = "SkySage",
		LevelRequired = 45,
		Objectives = { { Kind = "Kill", Target = "CloudSprite", Count = 12 } },
		Rewards = { Exp = 45000, Gold = 7000 },
		Dialog = { Offer = "Rogue cloud sprites everywhere. Clear 12.", Complete = "The skies are calmer." },
	}
)
add(
	"SK_Feathers",
	{
		Name = "Thunder Feathers",
		Type = "Collect",
		Giver = "SkySage",
		LevelRequired = 50,
		Objectives = { { Kind = "Collect", Item = "ThunderFeather", Count = 8 } },
		Rewards = { Exp = 60000, Gold = 9000, Spins = 1 },
		Dialog = { Offer = "Harpies carry thunder feathers. I need 8.", Complete = "These crackle nicely." },
	}
)
add(
	"SK_Knights",
	{
		Name = "Knights of the Storm",
		Type = "Kill",
		Giver = "SkySage",
		Prerequisite = "SK_Sprites",
		LevelRequired = 60,
		Objectives = { { Kind = "Kill", Target = "StormKnight", Count = 8 }, { Kind = "Kill", Target = "ThunderBeast", Count = 3 } },
		Rewards = { Exp = 110000, Gold = 14000 },
		Dialog = { Offer = "The Tyrant's knights and beasts must fall.", Complete = "His army is broken." },
	}
)
add(
	"SK_Tyrant",
	{
		Name = "Dethrone the Tyrant",
		Type = "Boss",
		Giver = "SkySage",
		Prerequisite = "SK_Knights",
		LevelRequired = 68,
		Objectives = { { Kind = "Boss", Target = "ThunderTyrant", Count = 1 } },
		Rewards = { Exp = 200000, Gold = 25000, Gems = 40, Spins = 3 },
		Dialog = { Offer = "Raijin waits on the summit. End the storm.", Complete = "Clear skies at last!" },
	}
)
add(
	"SK_Dungeon",
	{
		Name = "Cloud Citadel",
		Type = "Dungeon",
		Giver = "SkySage",
		LevelRequired = 55,
		Objectives = { { Kind = "Dungeon", Target = "CloudCitadel", Count = 1 } },
		Rewards = { Exp = 90000, Gold = 12000, Gems = 25 },
		Dialog = { Offer = "Clear the Cloud Citadel.", Complete = "The citadel is ours." },
	}
)

-- FROZEN -----------------------------------------------------------------------------------
add(
	"FZ_Wolves",
	{
		Name = "Howling Winds",
		Type = "Kill",
		Giver = "FrostCommander",
		LevelRequired = 75,
		Objectives = { { Kind = "Kill", Target = "FrostWolf", Count = 12 } },
		Rewards = { Exp = 220000, Gold = 20000 },
		Dialog = { Offer = "Frost wolves stalk the pass. Cull 12.", Complete = "The pass is open." },
	}
)
add(
	"FZ_Yetis",
	{
		Name = "Yeti Hunt",
		Type = "Collect",
		Giver = "FrostCommander",
		LevelRequired = 82,
		Objectives = { { Kind = "Collect", Item = "YetiHide", Count = 6 } },
		Rewards = { Exp = 300000, Gold = 26000, Spins = 1 },
		Dialog = { Offer = "Our soldiers freeze. Bring 6 yeti hides.", Complete = "Warm coats for all!" },
	}
)
add(
	"FZ_Soldiers",
	{
		Name = "Siege of the Fortress",
		Type = "Kill",
		Giver = "FrostCommander",
		Prerequisite = "FZ_Wolves",
		LevelRequired = 92,
		Objectives = { { Kind = "Kill", Target = "IceSoldier", Count = 10 }, { Kind = "Kill", Target = "FrostKnight", Count = 3 } },
		Rewards = { Exp = 480000, Gold = 36000 },
		Dialog = { Offer = "Storm the fortress gate.", Complete = "The gate has fallen!" },
	}
)
add(
	"FZ_Empress",
	{
		Name = "The Frozen Heart",
		Type = "Boss",
		Giver = "FrostCommander",
		Prerequisite = "FZ_Soldiers",
		LevelRequired = 100,
		Objectives = { { Kind = "Boss", Target = "FrostEmpress", Count = 1 } },
		Rewards = { Exp = 900000, Gold = 60000, Gems = 50, Spins = 3 },
		Dialog = { Offer = "Face the Empress in her throne room.", Complete = "Spring may come again." },
	}
)
add(
	"FZ_Dungeon",
	{
		Name = "Glacier Depths",
		Type = "Dungeon",
		Giver = "FrostCommander",
		LevelRequired = 85,
		Objectives = { { Kind = "Dungeon", Target = "GlacierDepths", Count = 1 } },
		Rewards = { Exp = 400000, Gold = 30000, Gems = 30 },
		Dialog = { Offer = "Something massive sleeps in the glacier.", Complete = "A wyrm?! You're mad - and alive." },
	}
)
add(
	"FZ_Missive",
	{
		Name = "Orders for the Exile",
		Type = "Delivery",
		Giver = "FrostCommander",
		TurnIn = "DemonExile",
		Prerequisite = "FZ_Empress",
		LevelRequired = 108,
		Objectives = { { Kind = "Deliver", Item = "FrostMissive", Count = 1, To = "DemonExile" } },
		Rewards = { Exp = 500000, Gold = 40000 },
		Dialog = {
			Offer = "Take this missive through the Hellgate to Kael, the exiled demon.",
			Complete = "So the humans will fight with me. Good.",
		},
	}
)

-- DEMON ------------------------------------------------------------------------------------
add(
	"DM_Imps",
	{
		Name = "Imp Infestation",
		Type = "Kill",
		Giver = "DemonExile",
		LevelRequired = 110,
		Objectives = { { Kind = "Kill", Target = "Imp", Count = 15 } },
		Rewards = { Exp = 1000000, Gold = 60000 },
		Dialog = { Offer = "Imps everywhere. Burn them out.", Complete = "Fewer eyes watching us." },
	}
)
add(
	"DM_Warriors",
	{
		Name = "Demon Legion",
		Type = "Kill",
		Giver = "DemonExile",
		Prerequisite = "DM_Imps",
		LevelRequired = 125,
		Objectives = { { Kind = "Kill", Target = "DemonWarrior", Count = 10 }, { Kind = "Kill", Target = "VoidCultist", Count = 6 } },
		Rewards = { Exp = 1800000, Gold = 90000, Spins = 2 },
		Dialog = { Offer = "Break his legion.", Complete = "The legion trembles." },
	}
)
add(
	"DM_Horns",
	{
		Name = "Horns of Power",
		Type = "Collect",
		Giver = "DemonExile",
		LevelRequired = 120,
		Objectives = { { Kind = "Collect", Item = "DemonHorn", Count = 8 } },
		Rewards = { Exp = 1400000, Gold = 70000, Items = { SpinToken = 1 } },
		Dialog = { Offer = "Demon horns hold power. Bring 8.", Complete = "Strong horns. Good." },
	}
)
add(
	"DM_Lord",
	{
		Name = "Fall of Vorgath",
		Type = "Boss",
		Giver = "DemonExile",
		Prerequisite = "DM_Warriors",
		LevelRequired = 150,
		Objectives = { { Kind = "Kill", Target = "DemonGeneral", Count = 2 }, { Kind = "Boss", Target = "DemonLord", Count = 1 } },
		Rewards = { Exp = 4000000, Gold = 200000, Gems = 80, Spins = 5 },
		Dialog = { Offer = "Kill his generals, then Vorgath himself.", Complete = "The realm is free... thank you." },
	}
)
add(
	"DM_Dungeon",
	{
		Name = "The Infernal Pit",
		Type = "Dungeon",
		Giver = "DemonExile",
		LevelRequired = 120,
		Objectives = { { Kind = "Dungeon", Target = "InfernalPit", Count = 1 } },
		Rewards = { Exp = 1600000, Gold = 80000, Gems = 40 },
		Dialog = { Offer = "Descend into the Infernal Pit.", Complete = "You returned from the pit. Few do." },
	}
)

-- CELESTIAL --------------------------------------------------------------------------------
add(
	"CL_Seraphs",
	{
		Name = "Fallen Seraphs",
		Type = "Kill",
		Giver = "CelestialOracle",
		LevelRequired = 160,
		Objectives = { { Kind = "Kill", Target = "Seraph", Count = 15 } },
		Rewards = { Exp = 5000000, Gold = 250000 },
		Dialog = { Offer = "The seraphs have been corrupted.", Complete = "Their light returns." },
	}
)
add(
	"CL_Guardians",
	{
		Name = "Guardians' Test",
		Type = "Kill",
		Giver = "CelestialOracle",
		Prerequisite = "CL_Seraphs",
		LevelRequired = 170,
		Objectives = { { Kind = "Kill", Target = "CelestialGuardian", Count = 10 } },
		Rewards = { Exp = 7000000, Gold = 300000, Spins = 2 },
		Dialog = { Offer = "Prove yourself against the guardians.", Complete = "They accept you." },
	}
)
add(
	"CL_Titans",
	{
		Name = "Titan Fall",
		Type = "Kill",
		Giver = "CelestialOracle",
		Prerequisite = "CL_Guardians",
		LevelRequired = 185,
		Objectives = { { Kind = "Kill", Target = "StarTitan", Count = 5 } },
		Rewards = { Exp = 10000000, Gold = 400000, Items = { SpinToken = 2 } },
		Dialog = { Offer = "Topple the Star Titans.", Complete = "The heavens shook." },
	}
)
add(
	"CL_Sovereign",
	{
		Name = "Throne of Heaven",
		Type = "Boss",
		Giver = "CelestialOracle",
		Prerequisite = "CL_Titans",
		LevelRequired = 195,
		Objectives = { { Kind = "Boss", Target = "CelestialSovereign", Count = 1 } },
		Rewards = { Exp = 20000000, Gold = 1000000, Gems = 200, Spins = 10 },
		Dialog = { Offer = "Face Aurelion on the Throne of Heaven.", Complete = "You stand above the gods themselves." },
	}
)
add(
	"CL_Raid",
	{
		Name = "Eclipse",
		Type = "Dungeon",
		Giver = "RaidHerald",
		LevelRequired = 170,
		Objectives = { { Kind = "Raid", Target = "EclipseRaid", Count = 1 } },
		Rewards = { Exp = 15000000, Gold = 800000, Gems = 150 },
		Dialog = { Offer = "Defeat the Eclipse Tyrant with your allies.", Complete = "Legends will speak of this day." },
	}
)

-- SECRET / NIGHT ---------------------------------------------------------------------------
add("SC_Wraith", {
	Name = "Hunter of the Night",
	Type = "Secret",
	Giver = "WanderingHermit",
	LevelRequired = 45,
	Hidden = true,
	Objectives = { { Kind = "Boss", Target = "MidnightWraith", Count = 1 } },
	Rewards = { Exp = 60000, Gold = 20000, Gems = 50, TraitRolls = 1, Items = { ShadowCore = 1 } },
	Dialog = {
		Offer = "At night, a wraith rises in the old graveyard. Destroy it and I'll share a secret power.",
		Complete = "You... actually did it. Take this Shadow Core.",
	},
})
add("NT_Moonpetal", {
	Name = "Moonlight Harvest",
	Type = "Collect",
	Giver = "MoonMerchant",
	LevelRequired = 25,
	NightOnly = true,
	Repeatable = true,
	Objectives = { { Kind = "Collect", Item = "Moonpetal", Count = 5 } },
	Rewards = { Exp = 15000, Gems = 20 },
	Dialog = { Offer = "Moonpetals bloom only at night. Bring me 5.", Complete = "Beautiful. Come back any night." },
})

-- DAILY / WEEKLY POOLS ---------------------------------------------------------------------
add(
	"DY_Slayer",
	{
		Name = "Daily: Slayer",
		Type = "Daily",
		Objectives = { { Kind = "Kill", Target = "Any", Count = 40 } },
		Rewards = { ExpLevelMultiplier = 1.5, Gold = 2000, Gems = 10 },
	}
)
add(
	"DY_Boss",
	{
		Name = "Daily: Boss Hunter",
		Type = "Daily",
		Objectives = { { Kind = "Boss", Target = "Any", Count = 1 } },
		Rewards = { ExpLevelMultiplier = 2, Gems = 15, Spins = 1 },
	}
)
add(
	"DY_Dungeon",
	{
		Name = "Daily: Delver",
		Type = "Daily",
		Objectives = { { Kind = "Dungeon", Target = "Any", Count = 1 } },
		Rewards = { ExpLevelMultiplier = 2, Gems = 15 },
	}
)
add(
	"DY_Explorer",
	{
		Name = "Daily: Wanderer",
		Type = "Daily",
		Objectives = { { Kind = "Kill", Target = "Any", Count = 20 }, { Kind = "Boss", Target = "Any", Count = 1 } },
		Rewards = { ExpLevelMultiplier = 2, Gold = 3000, Items = { LuckPotion = 1 } },
	}
)
add(
	"WK_Legend",
	{
		Name = "Weekly: Legend",
		Type = "Weekly",
		Objectives = { { Kind = "Kill", Target = "Any", Count = 400 } },
		Rewards = { ExpLevelMultiplier = 8, Gems = 80, Spins = 3 },
	}
)
add(
	"WK_Bosses",
	{
		Name = "Weekly: Tyrant Slayer",
		Type = "Weekly",
		Objectives = { { Kind = "Boss", Target = "Any", Count = 10 } },
		Rewards = { ExpLevelMultiplier = 8, Gems = 100, TraitRolls = 1 },
	}
)
add(
	"WK_Dungeons",
	{
		Name = "Weekly: Dungeon Crawler",
		Type = "Weekly",
		Objectives = { { Kind = "Dungeon", Target = "Any", Count = 5 } },
		Rewards = { ExpLevelMultiplier = 8, Gems = 100, Spins = 2 },
	}
)

return {
	List = quests,
	DailyPool = { "DY_Slayer", "DY_Boss", "DY_Dungeon", "DY_Explorer" },
	WeeklyPool = { "WK_Legend", "WK_Bosses", "WK_Dungeons" },
	DailyCount = 3,
	WeeklyCount = 2,
	Get = function(id: string?)
		return id and quests[id] or nil
	end,
}
