--[[
	WeaponCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.Weapons.WeaponCatalog
	Every weapon item. Category is always "Weapon". Skills = override of the class skills
	(nil entries fall back to the class skill for that slot).
	Passive.OnHit is applied by DamageService on weapon hits.
]]
local C = Color3.fromRGB

local weapons = {}

local function add(id: string, def)
	def.Id = id
	def.Category = "Weapon"
	weapons[id] = def
end

-- Starter / common --------------------------------------------------------------------------
add("WoodenKatana", {
	DisplayName = "Wooden Katana",
	Class = "Katana",
	Rarity = "Common",
	Damage = 10,
	LevelRequired = 1,
	Color = C(170, 120, 70),
	Accent = C(90, 60, 30),
	Description = "A training sword.",
})
add("RustyDagger", {
	DisplayName = "Rusty Dagger",
	Class = "Dagger",
	Rarity = "Common",
	Damage = 9,
	LevelRequired = 1,
	Color = C(150, 110, 90),
	Accent = C(80, 60, 40),
	Description = "Better than nothing.",
})
add("IronGreatsword", {
	DisplayName = "Iron Greatsword",
	Class = "Greatsword",
	Rarity = "Common",
	Damage = 12,
	LevelRequired = 5,
	Color = C(180, 180, 190),
	Accent = C(90, 90, 100),
	Description = "Heavy iron slab.",
})
add("FarmerScythe", {
	DisplayName = "Farmer's Scythe",
	Class = "Scythe",
	Rarity = "Common",
	Damage = 11,
	LevelRequired = 5,
	Color = C(160, 160, 150),
	Accent = C(110, 80, 50),
	Description = "Harvest season.",
})
add("GuardSpear", {
	DisplayName = "Guard Spear",
	Class = "Spear",
	Rarity = "Common",
	Damage = 11,
	LevelRequired = 5,
	Color = C(200, 200, 210),
	Accent = C(120, 40, 40),
	Description = "Standard issue spear.",
})
add("BrawlerGauntlets", {
	DisplayName = "Brawler Gauntlets",
	Class = "Gauntlets",
	Rarity = "Common",
	Damage = 11,
	LevelRequired = 5,
	Color = C(120, 120, 130),
	Accent = C(200, 60, 60),
	Description = "Knuckle guards.",
})
add("ApprenticeStaff", {
	DisplayName = "Apprentice Staff",
	Class = "Staff",
	Rarity = "Common",
	Damage = 10,
	LevelRequired = 5,
	Color = C(140, 100, 60),
	Accent = C(100, 180, 255),
	Description = "Hums faintly.",
})
add("TwinKnives", {
	DisplayName = "Twin Knives",
	Class = "DualBlades",
	Rarity = "Common",
	Damage = 10,
	LevelRequired = 5,
	Color = C(200, 200, 200),
	Accent = C(60, 60, 60),
	Description = "Quick and light.",
})

-- Region weapons --------------------------------------------------------------------------------
add("BanditCleaver", {
	DisplayName = "Bandit Cleaver",
	Class = "Greatsword",
	Rarity = "Rare",
	Damage = 20,
	LevelRequired = 12,
	Color = C(160, 70, 50),
	Accent = C(220, 180, 80),
	Description = "The Bandit Chief's favorite.",
	Passive = { Name = "Plunder", Description = "+10% gold from enemies.", Modifiers = { GoldBonus = 0.1 } },
})
add("SandstormScimitar", {
	DisplayName = "Sandstorm Scimitar",
	Class = "Katana",
	Rarity = "Rare",
	Damage = 30,
	LevelRequired = 22,
	Color = C(230, 200, 130),
	Accent = C(200, 140, 50),
	Description = "Carried by desert guards.",
	Passive = { Name = "Sandblast", Description = "Hits may blind (stun).", OnHit = { Chance = 0.12, Effect = "Stun", Duration = 0.4 } },
})
add("PharaohStaff", {
	DisplayName = "Pharaoh's Staff",
	Class = "Staff",
	Rarity = "Epic",
	Damage = 40,
	LevelRequired = 30,
	Color = C(250, 200, 60),
	Accent = C(60, 200, 200),
	Description = "Staff of the Sand Pharaoh.",
	Passive = { Name = "Sun God", Description = "+10% power damage.", Modifiers = { PowerDamage = 0.1 } },
})
add("SkyPiercer", {
	DisplayName = "Sky Piercer",
	Class = "Spear",
	Rarity = "Epic",
	Damage = 50,
	LevelRequired = 48,
	Color = C(220, 240, 255),
	Accent = C(120, 180, 255),
	Description = "Forged above the clouds.",
	Passive = { Name = "Updraft", Description = "Finishers launch higher.", Modifiers = { MoveSpeed = 2 } },
})
add("FrostbiteDagger", {
	DisplayName = "Frostbite",
	Class = "Dagger",
	Rarity = "Epic",
	Damage = 64,
	LevelRequired = 78,
	Color = C(170, 230, 255),
	Accent = C(240, 250, 255),
	Description = "Freezes the blood.",
	Passive = {
		Name = "Chill",
		Description = "Hits may freeze.",
		OnHit = { Chance = 0.1, Effect = "Freeze", Duration = 0.8, Color = C(170, 230, 255) },
	},
})
add("GlacierHammerFists", {
	DisplayName = "Glacier Fists",
	Class = "Gauntlets",
	Rarity = "Epic",
	Damage = 66,
	LevelRequired = 82,
	Color = C(200, 240, 255),
	Accent = C(90, 160, 220),
	Description = "Ice-forged knuckles.",
})

-- Boss / rare weapons ------------------------------------------------------------------------------
add("NightSlayer", {
	DisplayName = "Night Slayer",
	Class = "Katana",
	Rarity = "Legendary",
	Damage = 58,
	LevelRequired = 50,
	Color = C(40, 20, 60),
	Accent = C(170, 70, 255),
	Glow = C(170, 70, 255),
	Description = "A dark katana crackling with purple energy.",
	Passive = {
		Name = "Shadow Damage",
		Description = "Hits deal +25% bonus shadow damage (20% chance).",
		OnHit = { Chance = 0.2, BonusDamage = 0.25, Effect = "Shadow", Color = C(170, 70, 255) },
	},
	Skills = { nil, "NightSlayer_ShadowCrescent", "NightSlayer_Nightfall" },
})
add("DragonFang", {
	DisplayName = "Dragon Fang",
	Class = "DualBlades",
	Rarity = "Legendary",
	Damage = 62,
	LevelRequired = 60,
	Color = C(60, 200, 120),
	Accent = C(230, 255, 200),
	Glow = C(80, 255, 140),
	Description = "Twin fangs of an ancient wyrm.",
	Passive = {
		Name = "Dragon Blood",
		Description = "+4% crit chance, burning hits.",
		Modifiers = { CritChance = 0.04 },
		OnHit = { Chance = 0.15, BonusDamage = 0.2, Effect = "Burn", Color = C(80, 255, 140) },
	},
	Skills = { nil, "DragonFang_DragonRush", "DragonFang_Wyrmstorm" },
})
add("ThunderSpear", {
	DisplayName = "Thunder Spear",
	Class = "Spear",
	Rarity = "Legendary",
	Damage = 64,
	LevelRequired = 55,
	Color = C(255, 240, 90),
	Accent = C(90, 140, 255),
	Glow = C(255, 250, 150),
	Description = "Dropped by the Thunder Tyrant.",
	Passive = {
		Name = "Static",
		Description = "Hits may shock nearby enemies.",
		OnHit = { Chance = 0.18, BonusDamage = 0.3, Effect = "Shock", Color = C(255, 250, 120) },
	},
	Skills = { nil, "ThunderSpear_BoltThrow", "ThunderSpear_Judgement" },
})
add("MoonKatana", {
	DisplayName = "Moon Katana",
	Class = "Katana",
	Rarity = "Legendary",
	Damage = 80,
	LevelRequired = 90,
	Color = C(210, 220, 255),
	Accent = C(120, 130, 200),
	Glow = C(220, 230, 255),
	Description = "Silver blade that shines brightest at night.",
	Passive = { Name = "Moonlit", Description = "+15% damage at night.", NightModifiers = { DamageMult = 0.15 } },
	Skills = { nil, "MoonKatana_LunarArc", "MoonKatana_Eclipse" },
})
add("DemonScythe", {
	DisplayName = "Demon Scythe",
	Class = "Scythe",
	Rarity = "Mythic",
	Damage = 105,
	LevelRequired = 115,
	Color = C(140, 10, 20),
	Accent = C(30, 0, 0),
	Glow = C(255, 60, 30),
	Description = "Reaps souls to fuel the wielder.",
	Passive = {
		Name = "Soul Eater",
		Description = "+6% lifesteal.",
		Modifiers = { Lifesteal = 0.06 },
		OnHit = { Chance = 0.15, BonusDamage = 0.25, Effect = "Burn", Color = C(255, 80, 30) },
	},
	Skills = { nil, "DemonScythe_Hellreap", "DemonScythe_Apocalypse" },
})
add("VoidKatana", {
	DisplayName = "Void Katana",
	Class = "Katana",
	Rarity = "Mythic",
	Damage = 110,
	LevelRequired = 120,
	Color = C(30, 10, 50),
	Accent = C(140, 60, 255),
	Glow = C(140, 60, 255),
	Description = "Crafted from demon horns and void crystals.",
	Passive = {
		Name = "Rift",
		Description = "+10% power damage, void hits.",
		Modifiers = { PowerDamage = 0.1 },
		OnHit = { Chance = 0.15, BonusDamage = 0.3, Effect = "Shadow", Color = C(140, 60, 255) },
	},
	Skills = { nil, "Void_Rend", "Void_Oblivion" },
})
add("VoidGreatsword", {
	DisplayName = "Void Greatsword",
	Class = "Greatsword",
	Rarity = "Mythic",
	Damage = 130,
	LevelRequired = 140,
	Color = C(20, 0, 35),
	Accent = C(180, 90, 255),
	Glow = C(180, 90, 255),
	Description = "A slab of solidified void.",
	Passive = {
		Name = "Event Horizon",
		Description = "+15% guard damage, +8% damage.",
		Modifiers = { GuardDamage = 0.15, WeaponDamage = 0.08 },
	},
	Skills = { nil, "Void_Rend", "Void_Oblivion" },
})
add("CelestialBlade", {
	DisplayName = "Celestial Blade",
	Class = "Greatsword",
	Rarity = "Secret",
	Damage = 175,
	LevelRequired = 170,
	Color = C(255, 250, 220),
	Accent = C(120, 220, 255),
	Glow = C(255, 250, 200),
	Description = "Forged from the core of a star.",
	Passive = { Name = "Divinity", Description = "+15% all damage, +5% crit.", Modifiers = { DamageMult = 0.15, CritChance = 0.05 } },
	Skills = { nil, "Celestial_Judgement", "Celestial_Genesis" },
})

return weapons
