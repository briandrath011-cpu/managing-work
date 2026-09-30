--[[
	EnemyCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.Enemies.EnemyCatalog
	Regular enemies. Health/damage scale with Level automatically (EnemyService).
	Behaviour: "Melee" | "Brute" | "Ranged" | "Caster" | "Assassin"
	Drops: { Id, Chance (0-1), Min, Max }. Luck modifiers raise Chance on the server.
]]
local C = Color3.fromRGB

local enemies = {}

local function add(id: string, def)
	def.Id = id
	def.Scale = def.Scale or 1
	def.HealthMultiplier = def.HealthMultiplier or 1
	def.DamageMultiplier = def.DamageMultiplier or 1
	def.AttackSpeed = def.AttackSpeed or 0.9
	def.Range = def.Range or 6
	def.WalkSpeed = def.WalkSpeed or 16
	def.AggroRange = def.AggroRange or 45
	def.BlockChance = def.BlockChance or 0.15
	def.DodgeChance = def.DodgeChance or 0.05
	def.Skills = def.Skills or {}
	def.Drops = def.Drops or {}
	enemies[id] = def
end

-- GREENWOOD (1-20)
add("ForestWolf", {
	DisplayName = "Forest Wolf",
	Level = 3,
	Behaviour = "Melee",
	WalkSpeed = 20,
	Colors = { Body = C(110, 100, 90), Accent = C(60, 50, 40) },
	Scale = 0.85,
	BlockChance = 0,
	DodgeChance = 0.1,
	Drops = { { Id = "WolfFang", Chance = 0.45, Min = 1, Max = 2 }, { Id = "GreenwoodHerb", Chance = 0.2, Min = 1, Max = 1 } },
})
add("Bandit", {
	DisplayName = "Bandit",
	Level = 8,
	Behaviour = "Melee",
	WeaponClass = "Dagger",
	Colors = { Body = C(120, 60, 50), Accent = C(40, 30, 30) },
	Skills = { "Lunge" },
	Drops = {
		{ Id = "BanditInsignia", Chance = 0.4, Min = 1, Max = 2 },
		{ Id = "RustyDagger", Chance = 0.02, Min = 1, Max = 1 },
		{ Id = "HealthPotion", Chance = 0.05, Min = 1, Max = 1 },
	},
})
add("BanditArcher", {
	DisplayName = "Bandit Archer",
	Level = 11,
	Behaviour = "Ranged",
	Colors = { Body = C(90, 110, 60), Accent = C(40, 50, 30) },
	Skills = { "Volley" },
	Drops = { { Id = "BanditInsignia", Chance = 0.4, Min = 1, Max = 2 } },
})
add("BanditBrute", {
	DisplayName = "Bandit Brute",
	Level = 15,
	Behaviour = "Brute",
	WeaponClass = "Greatsword",
	Scale = 1.25,
	HealthMultiplier = 1.8,
	DamageMultiplier = 1.3,
	AttackSpeed = 0.7,
	Range = 8,
	WalkSpeed = 14,
	Colors = { Body = C(140, 70, 50), Accent = C(60, 30, 20) },
	Skills = { "Slam" },
	BlockChance = 0.3,
	Drops = {
		{ Id = "BanditInsignia", Chance = 0.6, Min = 2, Max = 3 },
		{ Id = "IronGreatsword", Chance = 0.03, Min = 1, Max = 1 },
		{ Id = "LeatherVest", Chance = 0.03, Min = 1, Max = 1 },
	},
})

-- DESERT (20-45)
add("SandScorpion", {
	DisplayName = "Sand Scorpion",
	Level = 22,
	Behaviour = "Melee",
	Scale = 0.9,
	WalkSpeed = 18,
	Colors = { Body = C(200, 160, 90), Accent = C(90, 60, 30) },
	BlockChance = 0.05,
	Drops = { { Id = "ScarabShell", Chance = 0.45, Min = 1, Max = 2 } },
})
add("DesertRaider", {
	DisplayName = "Desert Raider",
	Level = 28,
	Behaviour = "Assassin",
	WeaponClass = "Katana",
	Colors = { Body = C(230, 210, 170), Accent = C(160, 50, 40) },
	Skills = { "Lunge", "Spin" },
	DodgeChance = 0.15,
	Drops = { { Id = "ScarabShell", Chance = 0.3, Min = 1, Max = 2 }, { Id = "SandstormScimitar", Chance = 0.02, Min = 1, Max = 1 } },
})
add("MummyGuard", {
	DisplayName = "Mummy Guard",
	Level = 35,
	Behaviour = "Brute",
	WeaponClass = "Spear",
	Scale = 1.1,
	HealthMultiplier = 1.4,
	Colors = { Body = C(220, 210, 180), Accent = C(120, 100, 70) },
	Skills = { "Lunge", "Slam" },
	BlockChance = 0.35,
	Drops = { { Id = "AncientRelic", Chance = 0.3, Min = 1, Max = 1 }, { Id = "SunShard", Chance = 0.12, Min = 1, Max = 1 } },
})
add("SandMage", {
	DisplayName = "Sand Mage",
	Level = 38,
	Behaviour = "Caster",
	WeaponClass = "Staff",
	Colors = { Body = C(60, 120, 160), Accent = C(240, 200, 80) },
	Skills = { "Fireball", "Beam", "Heal" },
	AttackColor = C(255, 200, 80),
	Drops = { { Id = "SunShard", Chance = 0.25, Min = 1, Max = 2 } },
})
add("SandGolem", {
	DisplayName = "Sand Golem",
	Level = 42,
	Behaviour = "Brute",
	Scale = 1.6,
	HealthMultiplier = 2.4,
	DamageMultiplier = 1.4,
	AttackSpeed = 0.6,
	Range = 9,
	WalkSpeed = 12,
	Colors = { Body = C(210, 180, 120), Accent = C(160, 130, 80) },
	Skills = { "Slam", "Leap" },
	BlockChance = 0.2,
	Drops = { { Id = "AncientRelic", Chance = 0.5, Min = 1, Max = 2 }, { Id = "SunShard", Chance = 0.3, Min = 1, Max = 2 } },
})

-- SKY ISLANDS (45-75)
add("CloudSprite", {
	DisplayName = "Cloud Sprite",
	Level = 48,
	Behaviour = "Caster",
	Scale = 0.8,
	Colors = { Body = C(240, 250, 255), Accent = C(150, 200, 255) },
	Skills = { "Fireball" },
	AttackColor = C(180, 220, 255),
	Drops = { { Id = "CloudEssence", Chance = 0.4, Min = 1, Max = 2 } },
})
add("Harpy", {
	DisplayName = "Harpy",
	Level = 55,
	Behaviour = "Assassin",
	WalkSpeed = 22,
	Colors = { Body = C(180, 150, 220), Accent = C(90, 70, 130) },
	Skills = { "Lunge", "Leap" },
	DodgeChance = 0.2,
	Drops = { { Id = "ThunderFeather", Chance = 0.35, Min = 1, Max = 2 } },
})
add("StormKnight", {
	DisplayName = "Storm Knight",
	Level = 65,
	Behaviour = "Melee",
	WeaponClass = "Spear",
	Scale = 1.1,
	HealthMultiplier = 1.5,
	Colors = { Body = C(80, 90, 140), Accent = C(250, 240, 90) },
	Skills = { "Lunge", "Beam" },
	BlockChance = 0.35,
	AttackColor = C(250, 240, 90),
	Drops = {
		{ Id = "ThunderFeather", Chance = 0.35, Min = 1, Max = 2 },
		{ Id = "CloudEssence", Chance = 0.3, Min = 1, Max = 2 },
		{ Id = "SkyPiercer", Chance = 0.01, Min = 1, Max = 1 },
	},
})
add("ThunderBeast", {
	DisplayName = "Thunder Beast",
	Level = 70,
	Behaviour = "Brute",
	Scale = 1.5,
	HealthMultiplier = 2.2,
	DamageMultiplier = 1.3,
	WalkSpeed = 18,
	Colors = { Body = C(60, 60, 90), Accent = C(250, 250, 120) },
	Skills = { "Slam", "Leap" },
	AttackColor = C(250, 250, 120),
	Drops = { { Id = "ThunderFeather", Chance = 0.5, Min = 2, Max = 3 }, { Id = "StormRing", Chance = 0.01, Min = 1, Max = 1 } },
})

-- FROZEN EMPIRE (75-110)
add("FrostWolf", {
	DisplayName = "Frost Wolf",
	Level = 78,
	Behaviour = "Melee",
	Scale = 0.95,
	WalkSpeed = 22,
	Colors = { Body = C(220, 235, 250), Accent = C(120, 170, 220) },
	DodgeChance = 0.1,
	BlockChance = 0,
	Drops = { { Id = "FrostCrystal", Chance = 0.35, Min = 1, Max = 2 } },
})
add("Yeti", {
	DisplayName = "Yeti",
	Level = 88,
	Behaviour = "Brute",
	Scale = 1.7,
	HealthMultiplier = 2.5,
	DamageMultiplier = 1.4,
	AttackSpeed = 0.7,
	Range = 9,
	WalkSpeed = 15,
	Colors = { Body = C(240, 240, 245), Accent = C(150, 170, 190) },
	Skills = { "Slam", "Leap" },
	Drops = { { Id = "YetiHide", Chance = 0.45, Min = 1, Max = 2 } },
})
add("IceSoldier", {
	DisplayName = "Ice Soldier",
	Level = 95,
	Behaviour = "Melee",
	WeaponClass = "Katana",
	Colors = { Body = C(140, 180, 220), Accent = C(230, 245, 255) },
	Skills = { "Lunge", "Freeze" },
	BlockChance = 0.35,
	AttackColor = C(170, 230, 255),
	Drops = { { Id = "FrostCrystal", Chance = 0.4, Min = 1, Max = 2 }, { Id = "FrostbiteDagger", Chance = 0.01, Min = 1, Max = 1 } },
})
add("FrostSorcerer", {
	DisplayName = "Frost Sorcerer",
	Level = 100,
	Behaviour = "Caster",
	WeaponClass = "Staff",
	Colors = { Body = C(90, 120, 200), Accent = C(220, 240, 255) },
	Skills = { "Freeze", "Beam", "Heal" },
	AttackColor = C(170, 230, 255),
	Drops = { { Id = "FrostCrystal", Chance = 0.5, Min = 1, Max = 3 }, { Id = "FrostHelm", Chance = 0.01, Min = 1, Max = 1 } },
})
add("FrostKnight", {
	DisplayName = "Frost Knight",
	Level = 105,
	Behaviour = "Brute",
	WeaponClass = "Greatsword",
	Scale = 1.3,
	HealthMultiplier = 2,
	DamageMultiplier = 1.25,
	Colors = { Body = C(180, 210, 240), Accent = C(60, 100, 160) },
	Skills = { "Slam", "Lunge", "Freeze" },
	BlockChance = 0.4,
	AttackColor = C(170, 230, 255),
	Drops = { { Id = "YetiHide", Chance = 0.3, Min = 1, Max = 2 }, { Id = "GlacierHammerFists", Chance = 0.01, Min = 1, Max = 1 } },
})

-- DEMON REALM (110-160)
add("Imp", {
	DisplayName = "Imp",
	Level = 112,
	Behaviour = "Caster",
	Scale = 0.75,
	WalkSpeed = 20,
	Colors = { Body = C(170, 40, 40), Accent = C(40, 0, 0) },
	Skills = { "Fireball" },
	AttackColor = C(255, 100, 30),
	Drops = { { Id = "HellfireEmber", Chance = 0.35, Min = 1, Max = 2 } },
})
add("Hellhound", {
	DisplayName = "Hellhound",
	Level = 122,
	Behaviour = "Melee",
	Scale = 1.05,
	WalkSpeed = 24,
	Colors = { Body = C(40, 20, 20), Accent = C(255, 90, 20) },
	Skills = { "Lunge" },
	DodgeChance = 0.15,
	AttackColor = C(255, 90, 20),
	Drops = { { Id = "HellfireEmber", Chance = 0.4, Min = 1, Max = 2 }, { Id = "DemonHorn", Chance = 0.1, Min = 1, Max = 1 } },
})
add("DemonWarrior", {
	DisplayName = "Demon Warrior",
	Level = 135,
	Behaviour = "Brute",
	WeaponClass = "Scythe",
	Scale = 1.35,
	HealthMultiplier = 2,
	DamageMultiplier = 1.3,
	Colors = { Body = C(90, 10, 20), Accent = C(20, 0, 0) },
	Skills = { "Spin", "Slam", "Lunge" },
	BlockChance = 0.35,
	AttackColor = C(255, 40, 40),
	Drops = { { Id = "DemonHorn", Chance = 0.35, Min = 1, Max = 2 }, { Id = "VoidCrystal", Chance = 0.12, Min = 1, Max = 1 } },
})
add("VoidCultist", {
	DisplayName = "Void Cultist",
	Level = 142,
	Behaviour = "Caster",
	WeaponClass = "Staff",
	Colors = { Body = C(40, 10, 60), Accent = C(160, 70, 255) },
	Skills = { "Beam", "Fireball", "Heal" },
	AttackColor = C(160, 70, 255),
	Drops = { { Id = "VoidCrystal", Chance = 0.35, Min = 1, Max = 2 } },
})
add("DemonGeneral", {
	DisplayName = "Demon General",
	Level = 150,
	Behaviour = "Brute",
	WeaponClass = "Greatsword",
	Scale = 1.6,
	HealthMultiplier = 3,
	DamageMultiplier = 1.4,
	Colors = { Body = C(60, 0, 10), Accent = C(255, 60, 30) },
	Skills = { "Slam", "Leap", "Beam" },
	BlockChance = 0.45,
	AttackColor = C(255, 60, 30),
	Drops = {
		{ Id = "DemonHorn", Chance = 0.5, Min = 2, Max = 3 },
		{ Id = "BossCore", Chance = 0.02, Min = 1, Max = 1 },
		{ Id = "OniMask", Chance = 0.01, Min = 1, Max = 1 },
	},
})

-- CELESTIAL REALM (160-200)
add("Seraph", {
	DisplayName = "Seraph",
	Level = 162,
	Behaviour = "Caster",
	Colors = { Body = C(255, 250, 230), Accent = C(255, 220, 120) },
	Skills = { "Beam", "Fireball", "Heal" },
	AttackColor = C(255, 240, 160),
	Drops = { { Id = "Stardust", Chance = 0.3, Min = 1, Max = 2 } },
})
add("CelestialGuardian", {
	DisplayName = "Celestial Guardian",
	Level = 175,
	Behaviour = "Melee",
	WeaponClass = "Spear",
	Scale = 1.3,
	HealthMultiplier = 2,
	Colors = { Body = C(230, 240, 255), Accent = C(120, 220, 255) },
	Skills = { "Lunge", "Leap", "Beam" },
	BlockChance = 0.45,
	AttackColor = C(160, 240, 255),
	Drops = { { Id = "Stardust", Chance = 0.4, Min = 1, Max = 2 }, { Id = "DivineFragment", Chance = 0.1, Min = 1, Max = 1 } },
})
add("StarTitan", {
	DisplayName = "Star Titan",
	Level = 190,
	Behaviour = "Brute",
	Scale = 2,
	HealthMultiplier = 3.5,
	DamageMultiplier = 1.5,
	AttackSpeed = 0.6,
	Range = 10,
	WalkSpeed = 14,
	Colors = { Body = C(40, 40, 80), Accent = C(255, 250, 200) },
	Skills = { "Slam", "Leap", "Beam" },
	AttackColor = C(255, 250, 200),
	Drops = { { Id = "DivineFragment", Chance = 0.3, Min = 1, Max = 2 }, { Id = "Stardust", Chance = 0.5, Min = 2, Max = 3 } },
})

-- EVENT / DUNGEON ENEMIES
add("MeteorElemental", {
	DisplayName = "Meteor Elemental",
	Level = 0,
	Behaviour = "Brute",
	Scale = 1.3,
	HealthMultiplier = 1.6,
	Colors = { Body = C(90, 40, 30), Accent = C(255, 120, 40) },
	Skills = { "Slam", "Fireball" },
	AttackColor = C(255, 120, 40),
	Drops = { { Id = "MeteorFragment", Chance = 0.5, Min = 1, Max = 2 } },
})
add("InvadingDemon", {
	DisplayName = "Invading Demon",
	Level = 0,
	Behaviour = "Melee",
	WeaponClass = "Scythe",
	Colors = { Body = C(110, 20, 30), Accent = C(20, 0, 0) },
	Skills = { "Lunge", "Spin" },
	AttackColor = C(255, 40, 40),
	Drops = { { Id = "DemonHorn", Chance = 0.15, Min = 1, Max = 1 }, { Id = "SpinToken", Chance = 0.02, Min = 1, Max = 1 } },
})
add("PortalWraith", {
	DisplayName = "Portal Wraith",
	Level = 0,
	Behaviour = "Assassin",
	Colors = { Body = C(60, 30, 90), Accent = C(170, 90, 255) },
	Skills = { "Lunge", "Beam" },
	AttackColor = C(170, 90, 255),
	Drops = { { Id = "PortalShard", Chance = 0.35, Min = 1, Max = 1 } },
})
add("BloodGhoul", {
	DisplayName = "Blood Ghoul",
	Level = 0,
	Behaviour = "Melee",
	Colors = { Body = C(120, 20, 30), Accent = C(40, 0, 0) },
	Skills = { "Lunge" },
	AttackColor = C(255, 30, 40),
	Drops = { { Id = "BloodMoonEssence", Chance = 0.08, Min = 1, Max = 1 } },
})
add("DungeonMinion", {
	DisplayName = "Dungeon Minion",
	Level = 0,
	Behaviour = "Melee",
	WeaponClass = "Dagger",
	Colors = { Body = C(70, 70, 80), Accent = C(160, 60, 200) },
	Skills = { "Lunge" },
	Drops = {},
})
add("DungeonCaster", {
	DisplayName = "Dungeon Caster",
	Level = 0,
	Behaviour = "Caster",
	WeaponClass = "Staff",
	Colors = { Body = C(60, 40, 90), Accent = C(200, 120, 255) },
	Skills = { "Fireball", "Beam" },
	AttackColor = C(200, 120, 255),
	Drops = {},
})
add("DungeonElite", {
	DisplayName = "Dungeon Elite",
	Level = 0,
	Behaviour = "Brute",
	WeaponClass = "Greatsword",
	Scale = 1.4,
	HealthMultiplier = 3,
	DamageMultiplier = 1.3,
	Colors = { Body = C(40, 40, 50), Accent = C(255, 180, 40) },
	Skills = { "Slam", "Lunge", "Leap" },
	BlockChance = 0.4,
	AttackColor = C(255, 180, 40),
	Drops = {},
})

return enemies
