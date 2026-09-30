--[[
	ItemCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.Items.ItemCatalog
	Every non-weapon item. Weapons live in Weapons.WeaponCatalog. Use ItemUtil.Get(id) for both.
	Category: Armor | Head | Accessory | Material | Consumable | Cosmetic
	Stackable items (Materials/Consumables) share one inventory entry with Amount.
]]
local C = Color3.fromRGB

local items = {}

local function add(id: string, def)
	def.Id = id
	items[id] = def
end

-- ARMOR --------------------------------------------------------------------------------------
add(
	"LeatherVest",
	{
		DisplayName = "Leather Vest",
		Category = "Armor",
		Rarity = "Common",
		Defense = 8,
		LevelRequired = 1,
		Color = C(130, 90, 60),
		Description = "Basic protection.",
		Modifiers = { MaxHealth = 0.03 },
	}
)
add(
	"DesertRobes",
	{
		DisplayName = "Desert Robes",
		Category = "Armor",
		Rarity = "Rare",
		Defense = 22,
		LevelRequired = 20,
		Color = C(230, 200, 140),
		Description = "Light robes of the dune guard.",
		Modifiers = { MoveSpeed = 2, MaxHealth = 0.05 },
	}
)
add(
	"StormMail",
	{
		DisplayName = "Storm Mail",
		Category = "Armor",
		Rarity = "Epic",
		Defense = 45,
		LevelRequired = 45,
		Color = C(90, 120, 220),
		Description = "Crackles with static.",
		Modifiers = { MaxHealth = 0.08, CooldownReduction = 0.03 },
	}
)
add(
	"FrostPlate",
	{
		DisplayName = "Frost Plate",
		Category = "Armor",
		Rarity = "Epic",
		Defense = 75,
		LevelRequired = 75,
		Color = C(170, 220, 255),
		Description = "Frozen steel armor.",
		Modifiers = { DamageReduction = 0.06, MaxHealth = 0.1 },
	}
)
add(
	"DemonCloak",
	{
		DisplayName = "Demon Cloak",
		Category = "Armor",
		Rarity = "Legendary",
		Defense = 110,
		LevelRequired = 110,
		Color = C(90, 10, 30),
		Description = "Woven from demon shadows.",
		Modifiers = { DamageMult = 0.08, Lifesteal = 0.03, MaxHealth = 0.1 },
	}
)
add(
	"CelestialAegis",
	{
		DisplayName = "Celestial Aegis",
		Category = "Armor",
		Rarity = "Mythic",
		Defense = 160,
		LevelRequired = 160,
		Color = C(255, 245, 200),
		Description = "Armor of the heavens.",
		Modifiers = { DamageReduction = 0.1, MaxHealth = 0.18, DamageMult = 0.05 },
	}
)

-- HEAD ---------------------------------------------------------------------------------------
add(
	"Bandana",
	{
		DisplayName = "Bandana",
		Category = "Head",
		Rarity = "Common",
		Defense = 3,
		LevelRequired = 1,
		Color = C(200, 40, 40),
		Description = "Looks cool.",
		Modifiers = { StyleDamage = 0.03 },
	}
)
add(
	"PharaohMask",
	{
		DisplayName = "Pharaoh Mask",
		Category = "Head",
		Rarity = "Epic",
		Defense = 12,
		LevelRequired = 30,
		Color = C(240, 190, 50),
		Description = "Gilded death mask.",
		Modifiers = { PowerDamage = 0.06, MaxEnergy = 0.06 },
	}
)
add(
	"ThunderCrown",
	{
		DisplayName = "Thunder Crown",
		Category = "Head",
		Rarity = "Legendary",
		Defense = 20,
		LevelRequired = 60,
		Color = C(250, 240, 80),
		Description = "Crown of the storm king.",
		Modifiers = { CritChance = 0.04, MoveSpeed = 2 },
	}
)
add(
	"FrostHelm",
	{
		DisplayName = "Frost Helm",
		Category = "Head",
		Rarity = "Epic",
		Defense = 30,
		LevelRequired = 80,
		Color = C(200, 235, 255),
		Description = "Never melts.",
		Modifiers = { DamageReduction = 0.04 },
	}
)
add(
	"OniMask",
	{
		DisplayName = "Oni Mask",
		Category = "Head",
		Rarity = "Legendary",
		Defense = 38,
		LevelRequired = 115,
		Color = C(200, 30, 30),
		Description = "A demon's grin.",
		Modifiers = { DamageMult = 0.06, CritDamage = 0.15 },
	}
)
add(
	"Halo",
	{
		DisplayName = "Radiant Halo",
		Category = "Head",
		Rarity = "Mythic",
		Defense = 55,
		LevelRequired = 165,
		Color = C(255, 250, 180),
		Description = "Divine favor.",
		Modifiers = { DamageMult = 0.06, EnergyRegen = 0.25, Luck = 0.1 },
	}
)

-- ACCESSORIES ------------------------------------------------------------------------------
add(
	"WolfToothCharm",
	{
		DisplayName = "Wolf Tooth Charm",
		Category = "Accessory",
		Rarity = "Common",
		LevelRequired = 1,
		Color = C(230, 230, 210),
		Description = "A hunter's lucky charm.",
		Modifiers = { CritChance = 0.02 },
	}
)
add(
	"SunAmulet",
	{
		DisplayName = "Sun Amulet",
		Category = "Accessory",
		Rarity = "Rare",
		LevelRequired = 25,
		Color = C(255, 200, 60),
		Description = "Warm to the touch.",
		Modifiers = { EnergyRegen = 0.12, PowerDamage = 0.04 },
	}
)
add(
	"StormRing",
	{
		DisplayName = "Storm Ring",
		Category = "Accessory",
		Rarity = "Epic",
		LevelRequired = 50,
		Color = C(120, 160, 255),
		Description = "Hums with lightning.",
		Modifiers = { CooldownReduction = 0.05, MoveSpeed = 1 },
	}
)
add(
	"FrostRing",
	{
		DisplayName = "Frost Ring",
		Category = "Accessory",
		Rarity = "Epic",
		LevelRequired = 80,
		Color = C(170, 230, 255),
		Description = "Cold as the north.",
		Modifiers = { DamageReduction = 0.05, GuardDamage = 0.1 },
	}
)
add(
	"MythicNecklace",
	{
		DisplayName = "Mythic Necklace",
		Category = "Accessory",
		Rarity = "Mythic",
		LevelRequired = 120,
		Color = C(255, 70, 110),
		Description = "Pulses with ancient power.",
		Modifiers = { DamageMult = 0.1, CritChance = 0.03, Luck = 0.08 },
	}
)
add(
	"VoidEarring",
	{
		DisplayName = "Void Earring",
		Category = "Accessory",
		Rarity = "Legendary",
		LevelRequired = 115,
		Color = C(120, 40, 220),
		Description = "Whispers from nowhere.",
		Modifiers = { PowerDamage = 0.12, MaxEnergy = 0.1 },
	}
)
add(
	"CelestialBand",
	{
		DisplayName = "Celestial Band",
		Category = "Accessory",
		Rarity = "Mythic",
		LevelRequired = 165,
		Color = C(200, 255, 255),
		Description = "A ring of pure starlight.",
		Modifiers = { DamageMult = 0.1, CooldownReduction = 0.06, AwakeningGain = 0.2 },
	}
)

-- MATERIALS --------------------------------------------------------------------------------
local function material(id, name, rarity, color, desc)
	add(id, { DisplayName = name, Category = "Material", Rarity = rarity, Stackable = true, Color = color, Description = desc })
end
material("WolfFang", "Wolf Fang", "Common", C(240, 240, 230), "Dropped by forest wolves.")
material("BanditInsignia", "Bandit Insignia", "Common", C(180, 60, 50), "Proof of a defeated bandit.")
material("GreenwoodHerb", "Greenwood Herb", "Common", C(90, 200, 90), "A healing herb from Greenwood.")
material("ChiefSeal", "Chief's Seal", "Rare", C(210, 170, 70), "Seal of the Bandit Chief.")
material("ScarabShell", "Scarab Shell", "Common", C(60, 120, 110), "Shiny desert shell.")
material("SunShard", "Sun Shard", "Rare", C(255, 210, 90), "Crystallized sunlight.")
material("AncientRelic", "Ancient Relic", "Rare", C(190, 160, 110), "Found in desert ruins.")
material("PharaohCore", "Pharaoh Core", "Epic", C(255, 190, 40), "Heart of the Sand Pharaoh.")
material("CloudEssence", "Cloud Essence", "Rare", C(240, 250, 255), "Condensed sky mist.")
material("ThunderFeather", "Thunder Feather", "Rare", C(250, 240, 90), "Charged feather.")
material("StormCore", "Storm Core", "Epic", C(120, 150, 255), "Core of the Thunder Tyrant.")
material("FrostCrystal", "Frost Crystal", "Rare", C(170, 230, 255), "Never-melting ice.")
material("YetiHide", "Yeti Hide", "Rare", C(235, 235, 245), "Thick white fur.")
material("GlacialCore", "Glacial Core", "Epic", C(120, 210, 255), "Core of the Frost Empress.")
material("DemonHorn", "Demon Horn", "Epic", C(120, 20, 30), "Horn of a lesser demon.")
material("VoidCrystal", "Void Crystal", "Epic", C(110, 40, 200), "A shard of nothingness.")
material("HellfireEmber", "Hellfire Ember", "Epic", C(255, 90, 20), "Burns forever.")
material("BossCore", "Boss Core", "Legendary", C(255, 60, 90), "Pulsing core dropped by powerful bosses.")
material("DemonCore", "Demon Lord Core", "Legendary", C(200, 0, 40), "Core of the Demon Lord.")
material("Stardust", "Stardust", "Legendary", C(255, 250, 200), "Glittering celestial dust.")
material("DivineFragment", "Divine Fragment", "Legendary", C(255, 255, 255), "A piece of a fallen god.")
material("CelestialCore", "Celestial Core", "Mythic", C(180, 255, 255), "Core of the Celestial Sovereign.")
material("Moonpetal", "Moonpetal", "Epic", C(200, 200, 255), "Only blooms at night.")
material("WraithEssence", "Wraith Essence", "Legendary", C(90, 80, 160), "Dropped by the Midnight Wraith.")
material("MeteorFragment", "Meteor Fragment", "Epic", C(255, 130, 60), "Fell from the sky during a meteor shower.")
material("PortalShard", "Portal Shard", "Epic", C(150, 90, 255), "Remnant of a dimensional portal.")
material("BloodMoonEssence", "Blood Moon Essence", "Legendary", C(200, 20, 40), "Only obtainable during a Blood Moon.")
material("StormEssence", "Storm Essence", "Epic", C(160, 180, 255), "Gathered during thunder storms.")
material("EclipseShard", "Eclipse Shard", "Mythic", C(40, 20, 60), "Raid material.")

-- QUEST ITEMS (given by quests, removed on turn-in)
add(
	"SealedLetter",
	{
		DisplayName = "Sealed Letter",
		Category = "Material",
		Rarity = "Common",
		Stackable = true,
		QuestItem = true,
		Color = C(240, 230, 200),
		Description = "A letter for the blacksmith.",
	}
)
add(
	"RelicMap",
	{
		DisplayName = "Relic Map",
		Category = "Material",
		Rarity = "Rare",
		Stackable = true,
		QuestItem = true,
		Color = C(210, 180, 120),
		Description = "Deliver to the Sultan.",
	}
)
add(
	"FrostMissive",
	{
		DisplayName = "Frost Missive",
		Category = "Material",
		Rarity = "Rare",
		Stackable = true,
		QuestItem = true,
		Color = C(200, 230, 255),
		Description = "Urgent orders for the Demon Exile.",
	}
)

-- CONSUMABLES --------------------------------------------------------------------------------
local function consumable(id, def)
	def.Category = "Consumable"
	def.Stackable = true
	add(id, def)
end
consumable(
	"HealthPotion",
	{ DisplayName = "Health Potion", Rarity = "Common", Color = C(230, 60, 70), Description = "Restores 40% health.", Use = { Heal = 0.4 } }
)
consumable(
	"EnergyElixir",
	{
		DisplayName = "Energy Elixir",
		Rarity = "Common",
		Color = C(80, 170, 255),
		Description = "Restores 60% energy.",
		Use = { Energy = 0.6 },
	}
)
consumable(
	"ExpScroll",
	{
		DisplayName = "EXP Scroll",
		Rarity = "Rare",
		Color = C(120, 255, 120),
		Description = "+50% EXP for 15 minutes.",
		Use = { Buff = "ExpBoost", Modifiers = { ExpBonus = 0.5 }, Duration = 900 },
	}
)
consumable(
	"LuckPotion",
	{
		DisplayName = "Luck Potion",
		Rarity = "Epic",
		Color = C(90, 255, 160),
		Description = "+30% drop luck for 15 minutes.",
		Use = { Buff = "LuckBoost", Modifiers = { Luck = 0.3 }, Duration = 900 },
	}
)
consumable(
	"SpinToken",
	{ DisplayName = "Spin Token", Rarity = "Rare", Color = C(255, 200, 80), Description = "Grants 1 power spin.", Use = { Spins = 1 } }
)
consumable(
	"TraitToken",
	{
		DisplayName = "Trait Token",
		Rarity = "Rare",
		Color = C(200, 120, 255),
		Description = "Grants 1 trait roll.",
		Use = { TraitRolls = 1 },
	}
)
consumable(
	"ShadowCore",
	{
		DisplayName = "Shadow Core",
		Rarity = "Epic",
		Color = C(90, 30, 160),
		Description = "Use to unlock the Shadow Form transformation.",
		Use = { UnlockTransformation = "ShadowForm" },
	}
)
consumable(
	"AscensionSeal",
	{
		DisplayName = "Ascension Seal",
		Rarity = "Legendary",
		Color = C(255, 220, 60),
		Description = "Use to unlock Golden Ascension.",
		Use = { UnlockTransformation = "GoldenAscension" },
	}
)
consumable(
	"DemonHeart",
	{
		DisplayName = "Demon Heart",
		Rarity = "Mythic",
		Color = C(220, 20, 40),
		Description = "Use to unlock Demon Mode.",
		Use = { UnlockTransformation = "DemonMode" },
	}
)
consumable(
	"CelestialSigil",
	{
		DisplayName = "Celestial Sigil",
		Rarity = "Secret",
		Color = C(180, 255, 255),
		Description = "Use to unlock Celestial Form.",
		Use = { UnlockTransformation = "CelestialForm" },
	}
)
consumable(
	"WingsOfFreedom",
	{
		DisplayName = "Wings of Freedom",
		Rarity = "Legendary",
		Color = C(240, 250, 255),
		Description = "Use to unlock Flight (requires level 110).",
		Use = { UnlockFlight = true },
	}
)

-- COSMETICS ----------------------------------------------------------------------------------
local function cosmetic(id, name, rarity, color, desc)
	add(id, { DisplayName = name, Category = "Cosmetic", Rarity = rarity, Color = color, Description = desc, AuraColor = color })
end
cosmetic("CrimsonAura", "Crimson Aura", "Epic", C(255, 40, 60), "A burning red aura.")
cosmetic("AzureAura", "Azure Aura", "Epic", C(60, 160, 255), "A calm blue aura.")
cosmetic("VoidAura", "Void Aura", "Legendary", C(120, 30, 220), "Swirling darkness.")
cosmetic("GoldenAura", "Golden Aura", "Mythic", C(255, 215, 60), "Shines like the sun.")
cosmetic("EclipseAura", "Eclipse Aura", "Secret", C(30, 10, 40), "The raid champion's aura.")

return items
