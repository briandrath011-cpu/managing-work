--[[
	Raids (ModuleScript)
	Location: ReplicatedStorage.Modules.World.Raids
	PHASE 20 - Endgame raids (up to 8 players). Mechanics are implemented in RaidService:
	  Shield  : boss becomes immune until all Eclipse Crystals are destroyed
	  Eclipse : darkness falls; only the light circles are safe - everyone outside takes massive damage
	Revive: downed players can be revived by teammates (hold E) before the timer runs out.
]]
return {
	EclipseRaid = {
		DisplayName = "Eclipse Raid",
		LevelRequired = 170,
		Level = 205,
		Boss = "EclipseTyrant",
		MinPlayers = 1,
		TimeLimit = 1200,
		Theme = { Floor = Color3.fromRGB(30, 20, 40), Accent = Color3.fromRGB(255, 200, 80) },
		Rewards = {
			Exp = 25000000,
			Gold = 2000000,
			Gems = 150,
			Title = "Raid_Legend",
			Drops = {
				{ Id = "EclipseShard", Chance = 1, Min = 1, Max = 3 },
				{ Id = "CelestialSigil", Chance = 0.05, Min = 1, Max = 1 },
				{ Id = "CelestialBlade", Chance = 0.02, Min = 1, Max = 1 },
				{ Id = "EclipseAura", Chance = 0.03, Min = 1, Max = 1 },
				{ Id = "MythicNecklace", Chance = 0.08, Min = 1, Max = 1 },
				{ Id = "SpinToken", Chance = 0.8, Min = 2, Max = 4 },
			},
		},
	},
}
