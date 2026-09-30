--[[
	AssetIds (ModuleScript)
	Location: ReplicatedStorage.Modules.Assets.AssetIds

	ALL external asset references in one place. The game runs without any of them:
	- Animations: empty id -> a procedural fallback pose is played (AnimationLib)
	- Sounds / Music: empty id -> silent (a few built-in rbxasset:// sounds are used as defaults)

	HOW TO ADD YOUR OWN ASSETS
	1. Create/upload the animation (Animation Editor -> Publish) or sound (Creator Hub -> Audio).
	2. Copy the numeric id and paste it as "rbxassetid://123456789" below.
	Animations must be made for R15 (player characters are R15 by default).
]]
local AssetIds = {}

-- Name -> animation id. Fallback = procedural pose name used when the id is empty.
AssetIds.Animations = {
	-- M1 combo per weapon family (Blade = Katana/Greatsword/Dagger/DualBlades/Scythe/Spear/Staff)
	Blade_M1_1 = { Id = "", Fallback = "SwingRight" },
	Blade_M1_2 = { Id = "", Fallback = "SwingLeft" },
	Blade_M1_3 = { Id = "", Fallback = "SwingRight" },
	Blade_M1_4 = { Id = "", Fallback = "SwingOverhead" },
	Fist_M1_1 = { Id = "", Fallback = "PunchRight" },
	Fist_M1_2 = { Id = "", Fallback = "PunchLeft" },
	Fist_M1_3 = { Id = "", Fallback = "Kick" },
	Fist_M1_4 = { Id = "", Fallback = "PunchBoth" },
	Heavy = { Id = "", Fallback = "SwingOverhead" },
	Block = { Id = "", Fallback = "Guard" },
	Dash = { Id = "", Fallback = "Lean" },
	-- Skills (referenced by ctx:Anim("Name") in power/weapon modules)
	Power_Push = { Id = "", Fallback = "CastForward" },
	Power_Pull = { Id = "", Fallback = "CastForward" },
	Power_Cast = { Id = "", Fallback = "CastUp" },
	Power_Point = { Id = "", Fallback = "PointRight" },
	Power_Guard = { Id = "", Fallback = "Guard" },
	Power_Slash = { Id = "", Fallback = "SwingRight" },
	Power_Summon = { Id = "", Fallback = "CastUp" },
	Power_Teleport = { Id = "", Fallback = "Lean" },
	Power_Beam = { Id = "", Fallback = "CastForward" },
	Power_Combo = { Id = "", Fallback = "PunchBoth" },
	Power_Throw = { Id = "", Fallback = "PointRight" },
	Power_Spin = { Id = "", Fallback = "CastUp" },
	Power_Domain = { Id = "", Fallback = "CastUp" },
	Power_Ultimate = { Id = "", Fallback = "CastUp" },
	Stand_Barrage = { Id = "", Fallback = "PunchBoth" },
	Stand_Heavy = { Id = "", Fallback = "PunchRight" },
	Stand_TimeStop = { Id = "", Fallback = "CastUp" },
	Stand_Ultimate = { Id = "", Fallback = "PunchBoth" },
	Rubber_Pistol = { Id = "", Fallback = "PunchRight" },
	Rubber_Gatling = { Id = "", Fallback = "PunchBoth" },
	Rubber_Rocket = { Id = "", Fallback = "Lean" },
	Rubber_Ultimate = { Id = "", Fallback = "CastUp" },
	Jutsu_Fire = { Id = "", Fallback = "CastForward" },
	Jutsu_Eye = { Id = "", Fallback = "PointRight" },
	Weapon_Dash = { Id = "", Fallback = "SwingRight" },
	Weapon_Combo = { Id = "", Fallback = "SwingLeft" },
	Weapon_Heavy = { Id = "", Fallback = "SwingOverhead" },
	Weapon_Slam = { Id = "", Fallback = "SwingOverhead" },
	Weapon_Throw = { Id = "", Fallback = "PointRight" },
	Weapon_Spin = { Id = "", Fallback = "SwingLeft" },
	Weapon_Thrust = { Id = "", Fallback = "PunchRight" },
	Weapon_Punch = { Id = "", Fallback = "PunchRight" },
	Weapon_Uppercut = { Id = "", Fallback = "CastUp" },
	Weapon_Cast = { Id = "", Fallback = "CastForward" },
	Weapon_Ultimate = { Id = "", Fallback = "SwingOverhead" },
	Transform = { Id = "", Fallback = "CastUp" },
}

-- Locomotion for NPCs / enemies / bosses (played on the server, replicates to everyone).
-- Defaults are Roblox's standard R15 animations; replace with your own if you like.
AssetIds.NPCAnimations = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
}

-- Sound effects. Some classic built-in client sounds are used as defaults.
AssetIds.Sounds = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Slash_Heavy = "rbxasset://sounds/swordlunge.wav",
	Stab = "rbxasset://sounds/swordlunge.wav",
	Whoosh = "rbxasset://sounds/swordslash.wav",
	Punch = "",
	Punch_Heavy = "",
	Hit = "",
	HitHeavy = "",
	Block = "",
	PerfectBlock = "rbxasset://sounds/electronicpingshort.wav",
	GuardBreak = "",
	Dash = "",
	Jump = "",
	Explosion = "",
	Throw = "rbxasset://sounds/swordslash.wav",
	Teleport = "",
	LevelUp = "rbxasset://sounds/electronicpingshort.wav",
	UIClick = "rbxasset://sounds/electronicpingshort.wav",
	UIHover = "",
	SpinTick = "",
	SpinReveal = "rbxasset://sounds/electronicpingshort.wav",
	MythicReveal = "",
	SecretReveal = "",
	Drop = "",
	RareDrop = "",
	QuestComplete = "rbxasset://sounds/electronicpingshort.wav",
	-- Power sounds (Cast / Impact / Charge per power)
	Gravity_Cast = "",
	Gravity_Impact = "",
	Gravity_Pull = "",
	Gravity_Charge = "",
	Gravity_Ult_Charge = "",
	Stand_Summon = "",
	Stand_Charge = "",
	TimeStop = "",
	Blue_Cast = "",
	Red_Cast = "",
	Infinity = "",
	Domain_Expand = "",
	Shadow_Slash = "",
	Shadow_Summon = "",
	Shadow_Teleport = "",
	Arise = "",
	Ki_Charge = "",
	Ki_Beam = "",
	Ki_Ult_Charge = "",
	Ki_Ult = "",
	Stretch = "",
	Inflate = "",
	Fire_Cast = "",
	Genjutsu = "",
	Counter_Ready = "",
	Susanoo = "",
	Transform_Awakening = "",
	Transform_Shadow = "",
	Transform_Golden = "",
	Transform_Demon = "",
	Transform_Celestial = "",
	BossRoar = "",
	Thunder = "",
	Rain = "",
	Wind = "",
}

-- Music tracks (looped). Region music changes when entering a region.
AssetIds.Music = {
	Menu = "",
	Region_Greenwood = "",
	Region_Desert = "",
	Region_Sky = "",
	Region_Frozen = "",
	Region_Demon = "",
	Region_Celestial = "",
	Boss_Greenwood = "",
	Boss_Desert = "",
	Boss_Sky = "",
	Boss_Frozen = "",
	Boss_Demon = "",
	Boss_Celestial = "",
	Boss_Secret = "",
	Boss_World = "",
	Boss_Raid = "",
	Dungeon = "",
	Raid = "",
}

return AssetIds
