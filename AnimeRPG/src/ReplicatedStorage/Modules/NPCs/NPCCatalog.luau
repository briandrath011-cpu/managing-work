--[[
	NPCCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.NPCs.NPCCatalog
	Every friendly NPC. Placement is in World.WorldConfig.NPCs.
	Roles: QuestGiver, Crafter, Merchant, StyleTrainer, WeaponTrainer, PowerTrainer,
	       SpinOracle, TraitMystic, DungeonKeeper, RaidHerald
	Shop entries: { Item, Price, Currency ("Gold"|"Gems"), LevelRequired? }
]]
local C = Color3.fromRGB

local npcs = {}

local function add(id: string, def)
	def.Id = id
	def.Roles = def.Roles or { "QuestGiver" }
	def.Quests = def.Quests or {}
	def.Colors = def.Colors or { Body = C(200, 180, 150), Accent = C(90, 70, 50) }
	npcs[id] = def
end

-- GREENWOOD
add(
	"ElderRowan",
	{
		DisplayName = "Elder Rowan",
		Region = "Greenwood",
		Colors = { Body = C(120, 160, 90), Accent = C(240, 240, 230) },
		Greeting = "Welcome to Greenwood, young one. Dark days are coming - we need heroes.",
		Quests = { "GW_Chief", "GW_Journey" },
	}
)
add(
	"GuardCaptainLyra",
	{
		DisplayName = "Captain Lyra",
		Region = "Greenwood",
		Colors = { Body = C(150, 150, 170), Accent = C(200, 50, 50) },
		Greeting = "Wolves in the forest, bandits on the road. Grab a blade and help us!",
		Quests = { "GW_Wolves", "GW_Bandits", "GW_Brutes", "GW_Scout" },
	}
)
add(
	"HerbalistMira",
	{
		DisplayName = "Herbalist Mira",
		Region = "Greenwood",
		Colors = { Body = C(120, 200, 130), Accent = C(240, 200, 220) },
		Greeting = "Herbs heal what swords cannot.",
		Quests = { "GW_Herbs" },
	}
)
add(
	"BlacksmithBrann",
	{
		DisplayName = "Blacksmith Brann",
		Region = "Greenwood",
		Roles = { "Crafter", "QuestGiver" },
		CraftStation = "Greenwood",
		Colors = { Body = C(110, 80, 60), Accent = C(60, 60, 60) },
		Greeting = "Bring me materials and I'll forge you something fine.",
	}
)
add(
	"CourierFinn",
	{
		DisplayName = "Courier Finn",
		Region = "Greenwood",
		Colors = { Body = C(200, 170, 90), Accent = C(90, 60, 30) },
		Greeting = "Got a delivery that needs fast legs!",
		Quests = { "GW_Delivery" },
	}
)
add("MerchantPip", {
	DisplayName = "Merchant Pip",
	Region = "Greenwood",
	Roles = { "Merchant" },
	Colors = { Body = C(230, 180, 60), Accent = C(120, 40, 120) },
	Greeting = "Potions! Scrolls! Weapons! Everything a hero needs!",
	Shop = {
		{ Item = "HealthPotion", Price = 60, Currency = "Gold" },
		{ Item = "EnergyElixir", Price = 80, Currency = "Gold" },
		{ Item = "IronGreatsword", Price = 800, Currency = "Gold" },
		{ Item = "FarmerScythe", Price = 800, Currency = "Gold" },
		{ Item = "GuardSpear", Price = 800, Currency = "Gold" },
		{ Item = "BrawlerGauntlets", Price = 800, Currency = "Gold" },
		{ Item = "ApprenticeStaff", Price = 800, Currency = "Gold" },
		{ Item = "TwinKnives", Price = 800, Currency = "Gold" },
		{ Item = "RustyDagger", Price = 500, Currency = "Gold" },
		{ Item = "LeatherVest", Price = 600, Currency = "Gold" },
		{ Item = "ExpScroll", Price = 40, Currency = "Gems" },
		{ Item = "SpinToken", Price = 50, Currency = "Gems" },
	},
})
add(
	"SpinOracle",
	{
		DisplayName = "Oracle of Fate",
		Region = "Greenwood",
		Roles = { "SpinOracle" },
		Colors = { Body = C(90, 40, 140), Accent = C(255, 210, 90) },
		Greeting = "Fate spins for all. Shall we see which power chooses you?",
	}
)
add(
	"TraitMystic",
	{
		DisplayName = "Trait Mystic",
		Region = "Greenwood",
		Roles = { "TraitMystic" },
		Colors = { Body = C(40, 90, 140), Accent = C(200, 240, 255) },
		Greeting = "Your soul holds a hidden trait. Let me draw it out.",
	}
)
add(
	"MasterKaito",
	{
		DisplayName = "Master Kaito",
		Region = "Greenwood",
		Roles = { "StyleTrainer" },
		Colors = { Body = C(240, 240, 240), Accent = C(200, 30, 30) },
		Greeting = "The body is the first weapon. I teach every style - if you are ready.",
	}
)
add(
	"WeaponMasterSora",
	{
		DisplayName = "Weapon Master Sora",
		Region = "Greenwood",
		Roles = { "WeaponTrainer" },
		Colors = { Body = C(60, 60, 80), Accent = C(180, 180, 200) },
		Greeting = "Pay for training and I'll sharpen your mastery of your weapon.",
	}
)
add(
	"PowerSageIris",
	{
		DisplayName = "Power Sage Iris",
		Region = "Greenwood",
		Roles = { "PowerTrainer" },
		Colors = { Body = C(90, 60, 170), Accent = C(160, 230, 255) },
		Greeting = "Power grows with understanding. Let me guide your mastery.",
	}
)
add(
	"DungeonKeeper",
	{
		DisplayName = "Dungeon Keeper Voss",
		Region = "Greenwood",
		Roles = { "DungeonKeeper", "QuestGiver" },
		Colors = { Body = C(50, 50, 60), Accent = C(170, 90, 255) },
		Greeting = "Gather up to 4 adventurers and step through the gate.",
		Quests = { "GW_Dungeon" },
	}
)
add(
	"WanderingHermit",
	{
		DisplayName = "Wandering Hermit",
		Region = "Greenwood",
		Hidden = true,
		Colors = { Body = C(100, 90, 80), Accent = C(60, 50, 40) },
		Greeting = "Few find this cave. Fewer survive what hunts under the moon...",
		Quests = { "SC_Wraith" },
	}
)
add("MoonMerchant", {
	DisplayName = "Moon Merchant",
	Region = "Greenwood",
	Roles = { "Merchant", "QuestGiver" },
	NightOnly = true,
	Colors = { Body = C(40, 40, 90), Accent = C(220, 220, 255) },
	Greeting = "I only trade beneath the moon. Rare goods for rare folk.",
	Quests = { "NT_Moonpetal" },
	Shop = {
		{ Item = "LuckPotion", Price = 60, Currency = "Gems" },
		{ Item = "TraitToken", Price = 80, Currency = "Gems" },
		{ Item = "SpinToken", Price = 45, Currency = "Gems" },
		{ Item = "AzureAura", Price = 400, Currency = "Gems" },
	},
})

-- DESERT
add(
	"SultanAzim",
	{
		DisplayName = "Sultan Azim",
		Region = "Desert",
		Colors = { Body = C(240, 220, 170), Accent = C(160, 40, 60) },
		Greeting = "The sands swallow the careless. Prove yourself.",
		Quests = { "DS_Arrival", "DS_Scorpions", "DS_Raiders", "DS_Pharaoh", "DS_Journey" },
	}
)
add(
	"ArchaeologistNadia",
	{
		DisplayName = "Archaeologist Nadia",
		Region = "Desert",
		Colors = { Body = C(200, 160, 110), Accent = C(90, 70, 50) },
		Greeting = "The ruins hide the Sun King's secrets!",
		Quests = { "DS_Relics", "DS_Map", "DS_Pyramid", "DS_Dungeon" },
	}
)
add(
	"DesertCrafter",
	{
		DisplayName = "Glassmith Kara",
		Region = "Desert",
		Roles = { "Crafter" },
		CraftStation = "Desert",
		Colors = { Body = C(230, 200, 150), Accent = C(60, 180, 190) },
		Greeting = "Sun shards make beautiful things.",
	}
)
add("DesertMerchant", {
	DisplayName = "Trader Omar",
	Region = "Desert",
	Roles = { "Merchant" },
	Colors = { Body = C(170, 120, 60), Accent = C(240, 220, 170) },
	Greeting = "Water? Weapons? I have both!",
	Shop = {
		{ Item = "HealthPotion", Price = 60, Currency = "Gold" },
		{ Item = "EnergyElixir", Price = 80, Currency = "Gold" },
		{ Item = "SandstormScimitar", Price = 6000, Currency = "Gold", LevelRequired = 22 },
		{ Item = "DesertRobes", Price = 5000, Currency = "Gold", LevelRequired = 20 },
	},
})

-- SKY
add(
	"SkySage",
	{
		DisplayName = "Sky Sage Aeris",
		Region = "SkyIslands",
		Colors = { Body = C(230, 240, 255), Accent = C(120, 180, 255) },
		Greeting = "Above the clouds, the storm king waits.",
		Quests = { "SK_Sprites", "SK_Feathers", "SK_Knights", "SK_Tyrant", "SK_Dungeon" },
	}
)
add(
	"SkyCrafter",
	{
		DisplayName = "Windwright Tobi",
		Region = "SkyIslands",
		Roles = { "Crafter" },
		CraftStation = "Sky",
		Colors = { Body = C(200, 220, 255), Accent = C(250, 240, 120) },
		Greeting = "Feathers and clouds - the best materials there are.",
	}
)

-- FROZEN
add(
	"FrostCommander",
	{
		DisplayName = "Commander Hilde",
		Region = "Frozen",
		Colors = { Body = C(170, 200, 230), Accent = C(40, 60, 100) },
		Greeting = "The Empress has gone mad. Help us take the fortress.",
		Quests = { "FZ_Wolves", "FZ_Yetis", "FZ_Soldiers", "FZ_Empress", "FZ_Dungeon", "FZ_Missive" },
	}
)
add(
	"FrostCrafter",
	{
		DisplayName = "Icesmith Bjorn",
		Region = "Frozen",
		Roles = { "Crafter" },
		CraftStation = "Frozen",
		Colors = { Body = C(200, 220, 240), Accent = C(90, 130, 170) },
		Greeting = "Ice-forged steel never dulls.",
	}
)

-- DEMON
add(
	"DemonExile",
	{
		DisplayName = "Exiled Demon Kael",
		Region = "Demon",
		Colors = { Body = C(90, 30, 40), Accent = C(255, 150, 60) },
		Greeting = "I betrayed the Demon Lord. Help me end him.",
		Quests = { "DM_Imps", "DM_Warriors", "DM_Horns", "DM_Lord", "DM_Dungeon" },
	}
)
add(
	"DemonCrafter",
	{
		DisplayName = "Hellforger Ash",
		Region = "Demon",
		Roles = { "Crafter" },
		CraftStation = "Demon",
		Colors = { Body = C(60, 20, 20), Accent = C(255, 100, 30) },
		Greeting = "Demon horns, void crystals... I can make legends.",
	}
)

-- CELESTIAL
add(
	"CelestialOracle",
	{
		DisplayName = "Oracle Seren",
		Region = "Celestial",
		Colors = { Body = C(255, 250, 230), Accent = C(150, 220, 255) },
		Greeting = "You have climbed farther than any mortal.",
		Quests = { "CL_Seraphs", "CL_Guardians", "CL_Titans", "CL_Sovereign" },
	}
)
add(
	"CelestialCrafter",
	{
		DisplayName = "Starsmith Lumi",
		Region = "Celestial",
		Roles = { "Crafter" },
		CraftStation = "Celestial",
		Colors = { Body = C(250, 245, 220), Accent = C(255, 210, 120) },
		Greeting = "Starlight bends to skilled hands.",
	}
)
add(
	"RaidHerald",
	{
		DisplayName = "Raid Herald",
		Region = "Celestial",
		Roles = { "RaidHerald", "QuestGiver" },
		Colors = { Body = C(30, 20, 40), Accent = C(255, 200, 80) },
		Greeting = "The Eclipse Tyrant stirs. Gather your strongest allies.",
		Quests = { "CL_Raid" },
	}
)

return npcs
