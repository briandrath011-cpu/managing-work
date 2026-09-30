--[[
	WorldConfig (ModuleScript)
	Location: ReplicatedStorage.Modules.World.WorldConfig

	PHASE 15/17 - The open world layout. WorldBuilder builds the greybox world from this data,
	EnemyService/BossService/NPCService spawn from it and the client map UI draws it.
	Replace the generated geometry with your own map later: keep the same positions
	(or edit them here) and set GameConfig.World.AutoBuild = false.

	Coordinates are absolute studs. Ground regions sit at Y = 0.
]]
local WorldConfig = {}

local V = Vector3.new

WorldConfig.Regions = {
	{
		Id = "Greenwood",
		DisplayName = "Greenwood Village",
		Center = V(0, 0, 0),
		Size = V(760, 500, 760),
		LevelRange = { 1, 20 },
		Music = "Region_Greenwood",
		Theme = {
			Ground = "Grass",
			Accent = "LeafyGrass",
			Color = Color3.fromRGB(90, 170, 80),
			Fog = Color3.fromRGB(190, 225, 200),
			FogEnd = 1400,
		},
		Weather = { Clear = 5, Rain = 2, Storm = 1, Fog = 1 },
	},
	{
		Id = "Desert",
		DisplayName = "Desert Kingdom",
		Center = V(900, 0, 0),
		Size = V(760, 500, 760),
		LevelRange = { 20, 45 },
		Music = "Region_Desert",
		Theme = {
			Ground = "Sand",
			Accent = "Sandstone",
			Color = Color3.fromRGB(230, 200, 130),
			Fog = Color3.fromRGB(245, 225, 180),
			FogEnd = 1500,
		},
		Weather = { Clear = 6, Fog = 1, Storm = 1 },
	},
	{
		Id = "SkyIslands",
		DisplayName = "Sky Islands",
		Center = V(900, 300, 900),
		Size = V(760, 400, 760),
		LevelRange = { 45, 75 },
		Music = "Region_Sky",
		Theme = {
			Ground = "Grass",
			Accent = "Rock",
			Color = Color3.fromRGB(150, 220, 150),
			Fog = Color3.fromRGB(210, 230, 255),
			FogEnd = 2000,
		},
		Weather = { Clear = 3, Storm = 3, Rain = 1 },
	},
	{
		Id = "Frozen",
		DisplayName = "Frozen Empire",
		Center = V(0, 0, 900),
		Size = V(760, 500, 760),
		LevelRange = { 75, 110 },
		Music = "Region_Frozen",
		Theme = {
			Ground = "Snow",
			Accent = "Glacier",
			Color = Color3.fromRGB(235, 245, 255),
			Fog = Color3.fromRGB(220, 235, 250),
			FogEnd = 900,
		},
		Weather = { Snow = 6, Fog = 2, Clear = 1 },
	},
	{
		Id = "Demon",
		DisplayName = "Demon Realm",
		Center = V(-900, 0, 900),
		Size = V(760, 500, 760),
		LevelRange = { 110, 160 },
		Music = "Region_Demon",
		Theme = {
			Ground = "Basalt",
			Accent = "CrackedLava",
			Color = Color3.fromRGB(60, 30, 30),
			Fog = Color3.fromRGB(90, 20, 20),
			FogEnd = 700,
		},
		Weather = { Clear = 3, Storm = 2, Fog = 2 },
	},
	{
		Id = "Celestial",
		DisplayName = "Celestial Realm",
		Center = V(-900, 400, 0),
		Size = V(760, 400, 760),
		LevelRange = { 160, 200 },
		Music = "Region_Celestial",
		Theme = {
			Ground = "Marble",
			Accent = "Pavement",
			Color = Color3.fromRGB(245, 240, 225),
			Fog = Color3.fromRGB(255, 245, 220),
			FogEnd = 2200,
		},
		Weather = { Clear = 6, Fog = 1 },
	},
}

-- Fast travel waypoints (must be discovered by touching them first).
WorldConfig.Waypoints = {
	{ Id = "GreenwoodVillage", Region = "Greenwood", DisplayName = "Greenwood Village", Position = V(0, 3, 30) },
	{ Id = "GreenwoodCamp", Region = "Greenwood", DisplayName = "Bandit Outskirts", Position = V(150, 3, -120) },
	{ Id = "DesertOasis", Region = "Desert", DisplayName = "Sunspire Oasis", Position = V(900, 3, 20) },
	{ Id = "DesertTemple", Region = "Desert", DisplayName = "Temple of the Sun", Position = V(1040, 3, 120) },
	{ Id = "SkyHub", Region = "SkyIslands", DisplayName = "Cloud Haven", Position = V(900, 306, 900) },
	{ Id = "FrozenGate", Region = "Frozen", DisplayName = "Frostgate", Position = V(0, 3, 700) },
	{ Id = "FrozenFortress", Region = "Frozen", DisplayName = "Glacier Fortress", Position = V(0, 3, 1010) },
	{ Id = "DemonGate", Region = "Demon", DisplayName = "Hellmouth", Position = V(-900, 3, 700) },
	{ Id = "CelestialHub", Region = "Celestial", DisplayName = "Starlight Sanctum", Position = V(-900, 406, 0) },
}

-- Sky Islands geometry (WorldBuilder builds terrain islands here; spawns must be on them).
WorldConfig.SkyIslands = {
	{ Id = "Hub", Center = V(900, 300, 900), Radius = 70 },
	{ Id = "North", Center = V(900, 310, 700), Radius = 55 },
	{ Id = "East", Center = V(1100, 305, 900), Radius = 55 },
	{ Id = "South", Center = V(900, 300, 1100), Radius = 55 },
	{ Id = "West", Center = V(700, 315, 900), Radius = 55 },
	{ Id = "Summit", Center = V(1080, 340, 1080), Radius = 60 },
}

WorldConfig.CelestialPlatforms = {
	{ Id = "Sanctum", Center = V(-900, 400, 0), Radius = 80 },
	{ Id = "GardenN", Center = V(-900, 410, -200), Radius = 60 },
	{ Id = "GardenE", Center = V(-700, 405, 0), Radius = 60 },
	{ Id = "GardenW", Center = V(-1100, 415, 0), Radius = 60 },
	{ Id = "Throne", Center = V(-900, 440, 220), Radius = 75 },
}

-- Enemy spawners: Enemy, Center, Count, Radius, RespawnTime
WorldConfig.EnemySpawns = {
	-- Greenwood
	{ Enemy = "ForestWolf", Center = V(-170, 3, -110), Count = 6, Radius = 45, RespawnTime = 12 },
	{ Enemy = "ForestWolf", Center = V(-220, 3, 60), Count = 5, Radius = 40, RespawnTime = 12 },
	{ Enemy = "Bandit", Center = V(170, 3, -170), Count = 6, Radius = 35, RespawnTime = 14 },
	{ Enemy = "BanditArcher", Center = V(215, 3, -140), Count = 3, Radius = 25, RespawnTime = 16 },
	{ Enemy = "BanditBrute", Center = V(230, 3, -210), Count = 3, Radius = 25, RespawnTime = 20 },
	-- Desert
	{ Enemy = "SandScorpion", Center = V(760, 3, 120), Count = 6, Radius = 45, RespawnTime = 12 },
	{ Enemy = "DesertRaider", Center = V(780, 3, -150), Count = 6, Radius = 40, RespawnTime = 14 },
	{ Enemy = "MummyGuard", Center = V(1020, 3, 200), Count = 5, Radius = 30, RespawnTime = 16 },
	{ Enemy = "SandMage", Center = V(1060, 3, -60), Count = 4, Radius = 30, RespawnTime = 16 },
	{ Enemy = "SandGolem", Center = V(1150, 3, -180), Count = 3, Radius = 30, RespawnTime = 22 },
	-- Sky Islands
	{ Enemy = "CloudSprite", Center = V(900, 318, 700), Count = 5, Radius = 30, RespawnTime = 12 },
	{ Enemy = "Harpy", Center = V(1100, 313, 900), Count = 5, Radius = 30, RespawnTime = 14 },
	{ Enemy = "StormKnight", Center = V(900, 308, 1100), Count = 5, Radius = 30, RespawnTime = 16 },
	{ Enemy = "ThunderBeast", Center = V(700, 323, 900), Count = 3, Radius = 25, RespawnTime = 22 },
	-- Frozen
	{ Enemy = "FrostWolf", Center = V(-150, 3, 780), Count = 6, Radius = 45, RespawnTime = 12 },
	{ Enemy = "Yeti", Center = V(160, 3, 800), Count = 4, Radius = 35, RespawnTime = 20 },
	{ Enemy = "IceSoldier", Center = V(-60, 3, 960), Count = 6, Radius = 35, RespawnTime = 14 },
	{ Enemy = "FrostSorcerer", Center = V(90, 3, 960), Count = 4, Radius = 30, RespawnTime = 16 },
	{ Enemy = "FrostKnight", Center = V(0, 3, 1060), Count = 3, Radius = 25, RespawnTime = 22 },
	-- Demon
	{ Enemy = "Imp", Center = V(-1050, 3, 780), Count = 6, Radius = 40, RespawnTime = 12 },
	{ Enemy = "Hellhound", Center = V(-760, 3, 820), Count = 6, Radius = 40, RespawnTime = 14 },
	{ Enemy = "DemonWarrior", Center = V(-1000, 3, 1000), Count = 5, Radius = 35, RespawnTime = 16 },
	{ Enemy = "VoidCultist", Center = V(-800, 3, 1020), Count = 4, Radius = 30, RespawnTime = 16 },
	{ Enemy = "DemonGeneral", Center = V(-900, 3, 1120), Count = 2, Radius = 25, RespawnTime = 30 },
	-- Celestial
	{ Enemy = "Seraph", Center = V(-900, 413, -200), Count = 5, Radius = 30, RespawnTime = 14 },
	{ Enemy = "CelestialGuardian", Center = V(-700, 408, 0), Count = 5, Radius = 30, RespawnTime = 16 },
	{ Enemy = "StarTitan", Center = V(-1100, 418, 0), Count = 3, Radius = 30, RespawnTime = 25 },
}

-- Boss arenas
WorldConfig.Bosses = {
	{ Boss = "BanditChief", Position = V(240, 3, -280), Region = "Greenwood" },
	{ Boss = "MidnightWraith", Position = V(-250, 3, 250), Region = "Greenwood" }, -- night only
	{ Boss = "SandPharaoh", Position = V(1100, 3, 200), Region = "Desert" },
	{ Boss = "ThunderTyrant", Position = V(1080, 346, 1080), Region = "SkyIslands" },
	{ Boss = "FrostEmpress", Position = V(0, 3, 1150), Region = "Frozen" },
	{ Boss = "DemonLord", Position = V(-900, 3, 1180), Region = "Demon" },
	{ Boss = "CelestialSovereign", Position = V(-900, 446, 220), Region = "Celestial" },
}

-- NPC placements (definitions in NPCs.NPCCatalog)
WorldConfig.NPCs = {
	{ Npc = "ElderRowan", Position = V(0, 3, -10) },
	{ Npc = "GuardCaptainLyra", Position = V(30, 3, -30) },
	{ Npc = "HerbalistMira", Position = V(-35, 3, 15) },
	{ Npc = "BlacksmithBrann", Position = V(40, 3, 30) },
	{ Npc = "MerchantPip", Position = V(-20, 3, 45) },
	{ Npc = "SpinOracle", Position = V(15, 3, 55) },
	{ Npc = "TraitMystic", Position = V(-50, 3, -30) },
	{ Npc = "MasterKaito", Position = V(60, 3, -5) },
	{ Npc = "WeaponMasterSora", Position = V(-60, 3, 0) },
	{ Npc = "PowerSageIris", Position = V(-5, 3, 70) },
	{ Npc = "DungeonKeeper", Position = V(70, 3, 90) },
	{ Npc = "WanderingHermit", Position = V(-285, 3, 215), Hidden = true },
	{ Npc = "MoonMerchant", Position = V(-40, 3, 90), NightOnly = true },
	{ Npc = "CourierFinn", Position = V(120, 3, 40) },
	{ Npc = "SultanAzim", Position = V(900, 3, -15) },
	{ Npc = "DesertCrafter", Position = V(930, 3, 30) },
	{ Npc = "ArchaeologistNadia", Position = V(870, 3, 35) },
	{ Npc = "DesertMerchant", Position = V(880, 3, -30) },
	{ Npc = "SkySage", Position = V(915, 306, 915) },
	{ Npc = "SkyCrafter", Position = V(880, 306, 890) },
	{ Npc = "FrostCommander", Position = V(20, 3, 710) },
	{ Npc = "FrostCrafter", Position = V(-25, 3, 720) },
	{ Npc = "DemonExile", Position = V(-880, 3, 720) },
	{ Npc = "DemonCrafter", Position = V(-930, 3, 715) },
	{ Npc = "CelestialOracle", Position = V(-880, 406, 20) },
	{ Npc = "CelestialCrafter", Position = V(-930, 406, -20) },
	{ Npc = "RaidHerald", Position = V(-900, 406, 45) },
}

-- Treasure chests. Hidden ones are in caves / parkour tops.
WorldConfig.Chests = {
	{ Id = "GW_Village", Position = V(-80, 3, 80), Tier = 1 },
	{ Id = "GW_Cave", Position = V(-300, 3, 230), Tier = 2, Hidden = true },
	{ Id = "GW_Tower", Position = V(260, 83, 220), Tier = 2, Hidden = true },
	{ Id = "DS_Ruins", Position = V(760, 3, -230), Tier = 2 },
	{ Id = "DS_Pyramid", Position = V(1180, 63, 60), Tier = 3, Hidden = true },
	{ Id = "SK_Summit", Position = V(1080, 346, 1140), Tier = 3 },
	{ Id = "SK_Cloud", Position = V(700, 321, 850), Tier = 3, Hidden = true },
	{ Id = "FZ_Cave", Position = V(250, 3, 1050), Tier = 3, Hidden = true },
	{ Id = "FZ_Fortress", Position = V(-70, 3, 1130), Tier = 4 },
	{ Id = "DM_Lava", Position = V(-1120, 3, 1120), Tier = 4, Hidden = true },
	{ Id = "CL_Garden", Position = V(-1100, 421, -40), Tier = 5 },
	{ Id = "CL_Secret", Position = V(-900, 520, -200), Tier = 5, Hidden = true },
}

-- Region travel: launch pads / portals (LevelRequired checked on the server).
WorldConfig.Portals = {
	{
		Id = "ToSky",
		DisplayName = "Wind Pillar",
		Position = V(1000, 3, -250),
		Target = V(900, 310, 900),
		LevelRequired = 40,
		Color = Color3.fromRGB(180, 230, 255),
	},
	{
		Id = "SkyToGround",
		DisplayName = "Descent Stream",
		Position = V(930, 306, 950),
		Target = V(1000, 6, -230),
		LevelRequired = 1,
		Color = Color3.fromRGB(180, 230, 255),
	},
	{
		Id = "SkyToFrozen",
		DisplayName = "Glacial Draft",
		Position = V(900, 306, 1150),
		Target = V(0, 6, 720),
		LevelRequired = 70,
		Color = Color3.fromRGB(200, 240, 255),
	},
	{
		Id = "ToDemon",
		DisplayName = "Hellgate",
		Position = V(-300, 3, 900),
		Target = V(-900, 6, 720),
		LevelRequired = 110,
		Color = Color3.fromRGB(255, 50, 30),
	},
	{
		Id = "DemonBack",
		DisplayName = "Frozen Rift",
		Position = V(-900, 3, 660),
		Target = V(-280, 6, 900),
		LevelRequired = 1,
		Color = Color3.fromRGB(200, 240, 255),
	},
	{
		Id = "ToCelestial",
		DisplayName = "Stairway to Heaven",
		Position = V(-900, 3, 600),
		Target = V(-900, 410, 30),
		LevelRequired = 160,
		Color = Color3.fromRGB(255, 250, 200),
	},
	{
		Id = "CelestialBack",
		DisplayName = "Fall of Stars",
		Position = V(-940, 406, 60),
		Target = V(-900, 6, 620),
		LevelRequired = 1,
		Color = Color3.fromRGB(255, 120, 60),
	},
}

-- Secret exploration spots
WorldConfig.Secrets = {
	{
		Id = "HermitCave",
		DisplayName = "Hermit's Cave",
		Position = V(-290, 3, 220),
		Radius = 25,
		Reward = { Gems = 15, Items = { SpinToken = 1 } },
	},
	{ Id = "WatchTower", DisplayName = "Old Watchtower", Position = V(260, 83, 220), Radius = 12, Reward = { Gems = 10 } },
	{
		Id = "PyramidTop",
		DisplayName = "Pyramid Peak",
		Position = V(1180, 63, 60),
		Radius = 12,
		Reward = { Gems = 20, Items = { LuckPotion = 1 } },
	},
	{ Id = "CloudNest", DisplayName = "Cloud Nest", Position = V(700, 321, 850), Radius = 15, Reward = { Gems = 25 } },
	{
		Id = "IceGrotto",
		DisplayName = "Ice Grotto",
		Position = V(250, 3, 1050),
		Radius = 20,
		Reward = { Gems = 30, Items = { TraitToken = 1 } },
	},
	{ Id = "LavaSanctum", DisplayName = "Lava Sanctum", Position = V(-1120, 3, 1120), Radius = 20, Reward = { Gems = 40 } },
	{
		Id = "StarPeak",
		DisplayName = "Star Peak",
		Position = V(-900, 520, -200),
		Radius = 15,
		Reward = { Gems = 60, Items = { SpinToken = 2 } },
	},
}

-- Night-only resource nodes
WorldConfig.NightNodes = {
	{ Item = "Moonpetal", Position = V(-120, 3, 150) },
	{ Item = "Moonpetal", Position = V(-200, 3, 190) },
	{ Item = "Moonpetal", Position = V(820, 3, 160) },
	{ Item = "Moonpetal", Position = V(80, 3, 860) },
	{ Item = "Moonpetal", Position = V(-1000, 3, 860) },
}

WorldConfig.DungeonGates = {
	{ Dungeon = "GoblinHollow", Position = V(80, 3, 110) },
	{ Dungeon = "SunkenTomb", Position = V(1000, 3, 70) },
	{ Dungeon = "CloudCitadel", Position = V(900, 306, 820) },
	{ Dungeon = "GlacierDepths", Position = V(-40, 3, 740) },
	{ Dungeon = "InfernalPit", Position = V(-960, 3, 760) },
}

WorldConfig.RaidGate = { Raid = "EclipseRaid", Position = V(-860, 406, 60) }

WorldConfig.WorldBossSpots = {
	V(-120, 3, -260),
	V(850, 3, 250),
	V(0, 3, 820),
}

WorldConfig.KillY = -200

function WorldConfig.GetRegion(id: string)
	for _, region in ipairs(WorldConfig.Regions) do
		if region.Id == id then
			return region
		end
	end
	return nil
end

-- Which region contains a position (nil = wilderness between regions).
function WorldConfig.RegionAt(position: Vector3)
	for _, region in ipairs(WorldConfig.Regions) do
		local offset = position - region.Center
		local half = region.Size / 2
		if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y >= -80 and offset.Y <= half.Y then
			return region
		end
	end
	return nil
end

function WorldConfig.GetWaypoint(id: string)
	for _, waypoint in ipairs(WorldConfig.Waypoints) do
		if waypoint.Id == id then
			return waypoint
		end
	end
	return nil
end

return WorldConfig
