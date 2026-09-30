--[[
	BossCatalog (ModuleScript)
	Location: ReplicatedStorage.Modules.Bosses.BossCatalog
	Bosses with phases. BossBrain switches phase by HP%:
		Phase 1 (100-70%): normal skills
		Phase 2 (70-30%): new skills, faster
		Enrage  (<30%)  : aura, much faster, Ultimate unlocked
	Drops: { Id, Chance, Min, Max }. Chance is per eligible player (personal loot).
	Title: granted on first kill. RespawnTime in seconds.
]]
local C = Color3.fromRGB

local bosses = {}

local function add(id: string, def)
	def.Id = id
	def.IsBoss = true
	def.Behaviour = "Boss"
	def.AttackSpeed = def.AttackSpeed or 0.85
	def.Range = def.Range or 9
	def.WalkSpeed = def.WalkSpeed or 18
	def.AggroRange = def.AggroRange or 80
	def.BlockChance = def.BlockChance or 0.35
	def.DodgeChance = def.DodgeChance or 0.15
	def.RespawnTime = def.RespawnTime or 180
	def.Scale = def.Scale or 2
	def.ArenaRadius = def.ArenaRadius or 90
	def.Phases = def.Phases
		or {
			{ Threshold = 1.0, Skills = { "Combo", "Shockwave" }, SpeedMultiplier = 1 },
			{ Threshold = 0.7, Skills = { "Combo", "Shockwave", "MeteorRain" }, SpeedMultiplier = 1.15 },
			{ Threshold = 0.3, Skills = { "Combo", "Shockwave", "MeteorRain", "Blink" }, SpeedMultiplier = 1.35, Enrage = true },
		}
	bosses[id] = def
end

add("BanditChief", {
	DisplayName = "Bandit Chief Garrok",
	Title = "Bandit_Bane",
	Level = 18,
	HealthMultiplier = 14,
	DamageMultiplier = 1.4,
	Scale = 1.6,
	WeaponClass = "Greatsword",
	Colors = { Body = C(150, 60, 40), Accent = C(230, 180, 60) },
	AttackColor = C(255, 170, 60),
	Minion = "Bandit",
	Music = "Boss_Greenwood",
	Phases = {
		{ Threshold = 1.0, Skills = { "Combo", "Shockwave" }, SpeedMultiplier = 1 },
		{ Threshold = 0.7, Skills = { "Combo", "Shockwave", "Summon", "WarCry" }, SpeedMultiplier = 1.1 },
		{ Threshold = 0.3, Skills = { "Combo", "Shockwave", "Blink", "WarCry" }, SpeedMultiplier = 1.3, Enrage = true },
	},
	Ultimate = "Nova",
	RespawnTime = 120,
	Drops = {
		{ Id = "ChiefSeal", Chance = 0.6, Min = 1, Max = 1 },
		{ Id = "BanditCleaver", Chance = 0.12, Min = 1, Max = 1 },
		{ Id = "Bandana", Chance = 0.2, Min = 1, Max = 1 },
		{ Id = "SpinToken", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "ExpScroll", Chance = 0.1, Min = 1, Max = 1 },
	},
	GemReward = 5,
})

add("MidnightWraith", {
	DisplayName = "Midnight Wraith",
	Title = "Night_Hunter",
	Level = 60,
	NightOnly = true,
	HealthMultiplier = 18,
	DamageMultiplier = 1.6,
	Scale = 1.8,
	WeaponClass = "Scythe",
	Colors = { Body = C(30, 20, 50), Accent = C(170, 70, 255) },
	AttackColor = C(170, 70, 255),
	Minion = "PortalWraith",
	Music = "Boss_Secret",
	Phases = {
		{ Threshold = 1.0, Skills = { "Blink", "Combo", "Pull" }, SpeedMultiplier = 1.1 },
		{ Threshold = 0.7, Skills = { "Blink", "Combo", "Pull", "Summon" }, SpeedMultiplier = 1.25 },
		{ Threshold = 0.3, Skills = { "Blink", "Combo", "Pull", "SweepBeam" }, SpeedMultiplier = 1.4, Enrage = true },
	},
	Ultimate = "Domain",
	RespawnTime = 300,
	Drops = {
		{ Id = "NightSlayer", Chance = 0.1, Min = 1, Max = 1 },
		{ Id = "WraithEssence", Chance = 0.5, Min = 1, Max = 1 },
		{ Id = "Moonpetal", Chance = 0.6, Min = 2, Max = 4 },
		{ Id = "ShadowCore", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "VoidAura", Chance = 0.02, Min = 1, Max = 1 },
	},
	GemReward = 25,
})

add("SandPharaoh", {
	DisplayName = "Sand Pharaoh Amunet",
	Title = "Sandwalker",
	Level = 44,
	HealthMultiplier = 16,
	DamageMultiplier = 1.45,
	Scale = 2,
	WeaponClass = "Staff",
	Colors = { Body = C(230, 190, 80), Accent = C(40, 160, 170) },
	AttackColor = C(255, 200, 80),
	Minion = "MummyGuard",
	Music = "Boss_Desert",
	Phases = {
		{ Threshold = 1.0, Skills = { "SweepBeam", "Pull", "Combo" }, SpeedMultiplier = 1 },
		{ Threshold = 0.7, Skills = { "SweepBeam", "Pull", "Summon", "MeteorRain" }, SpeedMultiplier = 1.15 },
		{ Threshold = 0.3, Skills = { "SweepBeam", "MeteorRain", "Pillars", "Blink" }, SpeedMultiplier = 1.35, Enrage = true },
	},
	Ultimate = "Cataclysm",
	Drops = {
		{ Id = "PharaohCore", Chance = 0.5, Min = 1, Max = 1 },
		{ Id = "PharaohStaff", Chance = 0.1, Min = 1, Max = 1 },
		{ Id = "PharaohMask", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "SunShard", Chance = 0.8, Min = 2, Max = 4 },
		{ Id = "SpinToken", Chance = 0.1, Min = 1, Max = 1 },
	},
	GemReward = 10,
})

add("ThunderTyrant", {
	DisplayName = "Thunder Tyrant Raijin",
	Title = "Stormcaller",
	Level = 74,
	HealthMultiplier = 18,
	DamageMultiplier = 1.5,
	Scale = 2.2,
	WeaponClass = "Spear",
	Colors = { Body = C(60, 70, 130), Accent = C(255, 245, 100) },
	AttackColor = C(255, 245, 120),
	Minion = "StormKnight",
	Music = "Boss_Sky",
	Phases = {
		{ Threshold = 1.0, Skills = { "ChainLightning", "Combo", "Blink" }, SpeedMultiplier = 1.1 },
		{ Threshold = 0.7, Skills = { "ChainLightning", "Pillars", "Blink", "Shockwave" }, SpeedMultiplier = 1.25 },
		{ Threshold = 0.3, Skills = { "ChainLightning", "Pillars", "Blink", "MeteorRain" }, SpeedMultiplier = 1.45, Enrage = true },
	},
	Ultimate = "Domain",
	Drops = {
		{ Id = "StormCore", Chance = 0.5, Min = 1, Max = 1 },
		{ Id = "ThunderSpear", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "ThunderCrown", Chance = 0.06, Min = 1, Max = 1 },
		{ Id = "AscensionSeal", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "SpinToken", Chance = 0.12, Min = 1, Max = 1 },
	},
	GemReward = 15,
})

add("FrostEmpress", {
	DisplayName = "Frost Empress Yukira",
	Title = "Frostborn",
	Level = 109,
	HealthMultiplier = 20,
	DamageMultiplier = 1.55,
	Scale = 2.1,
	WeaponClass = "Katana",
	Colors = { Body = C(200, 230, 255), Accent = C(90, 150, 230) },
	AttackColor = C(170, 230, 255),
	Minion = "IceSoldier",
	Music = "Boss_Frozen",
	Phases = {
		{ Threshold = 1.0, Skills = { "IcePrison", "Combo", "SweepBeam" }, SpeedMultiplier = 1.1 },
		{ Threshold = 0.7, Skills = { "IcePrison", "Combo", "MeteorRain", "Summon" }, SpeedMultiplier = 1.2 },
		{ Threshold = 0.3, Skills = { "IcePrison", "Blink", "MeteorRain", "CounterStance" }, SpeedMultiplier = 1.4, Enrage = true },
	},
	Ultimate = "Nova",
	Drops = {
		{ Id = "GlacialCore", Chance = 0.5, Min = 1, Max = 1 },
		{ Id = "MoonKatana", Chance = 0.05, Min = 1, Max = 1 },
		{ Id = "FrostPlate", Chance = 0.06, Min = 1, Max = 1 },
		{ Id = "FrostRing", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "SpinToken", Chance = 0.15, Min = 1, Max = 2 },
	},
	GemReward = 20,
})

add("DemonLord", {
	DisplayName = "Demon Lord Vorgath",
	Title = "Demon_Slayer",
	Level = 158,
	HealthMultiplier = 24,
	DamageMultiplier = 1.6,
	Scale = 2.6,
	WeaponClass = "Scythe",
	Colors = { Body = C(70, 0, 10), Accent = C(255, 60, 20) },
	AttackColor = C(255, 60, 20),
	Minion = "Hellhound",
	Music = "Boss_Demon",
	Phases = {
		{ Threshold = 1.0, Skills = { "Combo", "MeteorRain", "Pull" }, SpeedMultiplier = 1.1 },
		{ Threshold = 0.7, Skills = { "Combo", "MeteorRain", "Summon", "SweepBeam", "WarCry" }, SpeedMultiplier = 1.25 },
		{
			Threshold = 0.3,
			Skills = { "Blink", "MeteorRain", "SweepBeam", "Pillars", "CounterStance" },
			SpeedMultiplier = 1.45,
			Enrage = true,
		},
	},
	Ultimate = "Cataclysm",
	Drops = {
		{ Id = "DemonCore", Chance = 0.5, Min = 1, Max = 1 },
		{ Id = "BossCore", Chance = 0.35, Min = 1, Max = 1 },
		{ Id = "DemonScythe", Chance = 0.05, Min = 1, Max = 1 },
		{ Id = "DemonHeart", Chance = 0.03, Min = 1, Max = 1 },
		{ Id = "DemonCloak", Chance = 0.05, Min = 1, Max = 1 },
		{ Id = "CrimsonAura", Chance = 0.04, Min = 1, Max = 1 },
	},
	GemReward = 30,
})

add("CelestialSovereign", {
	DisplayName = "Celestial Sovereign Aurelion",
	Title = "Celestial",
	Level = 200,
	HealthMultiplier = 30,
	DamageMultiplier = 1.7,
	Scale = 2.6,
	WeaponClass = "Greatsword",
	Colors = { Body = C(255, 250, 230), Accent = C(120, 220, 255) },
	AttackColor = C(255, 245, 190),
	Minion = "Seraph",
	Music = "Boss_Celestial",
	Phases = {
		{ Threshold = 1.0, Skills = { "Pillars", "Combo", "SweepBeam" }, SpeedMultiplier = 1.15 },
		{ Threshold = 0.7, Skills = { "Pillars", "Blink", "MeteorRain", "SweepBeam", "Summon" }, SpeedMultiplier = 1.3 },
		{
			Threshold = 0.3,
			Skills = { "Pillars", "Blink", "MeteorRain", "ChainLightning", "CounterStance" },
			SpeedMultiplier = 1.5,
			Enrage = true,
		},
	},
	Ultimate = "Nova",
	RespawnTime = 300,
	Drops = {
		{ Id = "CelestialCore", Chance = 0.45, Min = 1, Max = 1 },
		{ Id = "DivineFragment", Chance = 0.7, Min = 1, Max = 3 },
		{ Id = "VoidGreatsword", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "CelestialSigil", Chance = 0.02, Min = 1, Max = 1 },
		{ Id = "Halo", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "GoldenAura", Chance = 0.02, Min = 1, Max = 1 },
	},
	GemReward = 50,
})

-- World boss (World Event) - level set when spawned
add("RuinColossus", {
	DisplayName = "Ruin Colossus",
	Level = 0,
	HealthMultiplier = 60,
	DamageMultiplier = 1.5,
	Scale = 3.4,
	WalkSpeed = 14,
	Colors = { Body = C(80, 70, 60), Accent = C(255, 120, 40) },
	AttackColor = C(255, 120, 40),
	Minion = "MeteorElemental",
	Music = "Boss_World",
	Ultimate = "Cataclysm",
	RespawnTime = 0,
	ArenaRadius = 140,
	Drops = {
		{ Id = "MeteorFragment", Chance = 1, Min = 3, Max = 6 },
		{ Id = "BossCore", Chance = 0.4, Min = 1, Max = 1 },
		{ Id = "SpinToken", Chance = 0.5, Min = 1, Max = 2 },
		{ Id = "MythicNecklace", Chance = 0.01, Min = 1, Max = 1 },
		{ Id = "DragonFang", Chance = 0.04, Min = 1, Max = 1 },
	},
	GemReward = 40,
})

-- Dungeon bosses (level set by the dungeon + difficulty)
add("HollowWarlord", {
	DisplayName = "Hollow Warlord",
	Level = 0,
	HealthMultiplier = 12,
	DamageMultiplier = 1.4,
	Scale = 1.8,
	WeaponClass = "Greatsword",
	Colors = { Body = C(60, 80, 50), Accent = C(200, 255, 120) },
	AttackColor = C(200, 255, 120),
	Minion = "DungeonMinion",
	Ultimate = "Nova",
	RespawnTime = 0,
	Drops = {},
})
add("TombGuardian", {
	DisplayName = "Tomb Guardian",
	Level = 0,
	HealthMultiplier = 14,
	DamageMultiplier = 1.45,
	Scale = 2.2,
	WeaponClass = "Spear",
	Colors = { Body = C(200, 180, 120), Accent = C(60, 200, 190) },
	AttackColor = C(255, 220, 120),
	Minion = "MummyGuard",
	Ultimate = "Cataclysm",
	RespawnTime = 0,
	Drops = {},
})
add("SkyWarden", {
	DisplayName = "Sky Warden",
	Level = 0,
	HealthMultiplier = 15,
	DamageMultiplier = 1.5,
	Scale = 2,
	WeaponClass = "Spear",
	Colors = { Body = C(220, 230, 255), Accent = C(255, 250, 120) },
	AttackColor = C(255, 250, 120),
	Minion = "Harpy",
	Ultimate = "Domain",
	RespawnTime = 0,
	Drops = {},
})
add("GlacierWyrm", {
	DisplayName = "Glacier Wyrm",
	Level = 0,
	HealthMultiplier = 16,
	DamageMultiplier = 1.5,
	Scale = 2.6,
	Colors = { Body = C(150, 200, 240), Accent = C(240, 250, 255) },
	AttackColor = C(170, 230, 255),
	Minion = "FrostWolf",
	Ultimate = "Nova",
	RespawnTime = 0,
	Drops = {},
})
add("InfernalArchfiend", {
	DisplayName = "Infernal Archfiend",
	Level = 0,
	HealthMultiplier = 18,
	DamageMultiplier = 1.55,
	Scale = 2.4,
	WeaponClass = "Scythe",
	Colors = { Body = C(90, 10, 10), Accent = C(255, 120, 20) },
	AttackColor = C(255, 90, 20),
	Minion = "Imp",
	Ultimate = "Cataclysm",
	RespawnTime = 0,
	Drops = {},
})

-- Raid boss
add("EclipseTyrant", {
	DisplayName = "Eclipse Tyrant Nyx",
	Title = "Raid_Legend",
	Level = 0,
	HealthMultiplier = 90,
	DamageMultiplier = 1.8,
	Scale = 3,
	WeaponClass = "Katana",
	Colors = { Body = C(20, 10, 30), Accent = C(255, 200, 80) },
	AttackColor = C(255, 200, 80),
	Minion = "PortalWraith",
	Music = "Boss_Raid",
	Phases = {
		{ Threshold = 1.0, Skills = { "Combo", "Pillars", "SweepBeam" }, SpeedMultiplier = 1.1 },
		{
			Threshold = 0.7,
			Skills = { "Blink", "Pillars", "MeteorRain", "Summon", "ChainLightning" },
			SpeedMultiplier = 1.25,
			Mechanic = "Shield",
		},
		{
			Threshold = 0.3,
			Skills = { "Blink", "Pillars", "MeteorRain", "SweepBeam", "IcePrison" },
			SpeedMultiplier = 1.5,
			Enrage = true,
			Mechanic = "Eclipse",
		},
	},
	Ultimate = "Domain",
	RespawnTime = 0,
	ArenaRadius = 120,
	Drops = {},
})

return bosses
