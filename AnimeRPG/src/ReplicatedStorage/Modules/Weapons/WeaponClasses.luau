--[[
	WeaponClasses (ModuleScript)
	Location: ReplicatedStorage.Modules.Weapons.WeaponClasses
	Base behaviour for the 8 weapon classes. Individual weapons (WeaponCatalog) scale these.
	Mastery unlocks: 0 = M1 combo, 20 = Skill 1 (Z), 50 = Skill 2 (X), 100 = Ultimate (C)
]]
local WeaponClasses = {}

WeaponClasses.MasteryUnlocks = { 20, 50, 100 }

WeaponClasses.List = {
	Katana = {
		DisplayName = "Katana",
		DamageMultiplier = 1.0,
		AttackSpeed = 1.15,
		Range = 8,
		HeavyMultiplier = 2.4,
		Skills = { "Katana_IaiSlash", "Katana_CrossCut", "Katana_ThousandCuts" },
		Grip = "RightHand",
		Model = { Kind = "Blade", Length = 4.2, Width = 0.25, Thickness = 0.12, Guard = true },
	},
	Greatsword = {
		DisplayName = "Greatsword",
		DamageMultiplier = 1.35,
		AttackSpeed = 0.75,
		Range = 10,
		HeavyMultiplier = 2.8,
		Skills = { "Greatsword_Cleave", "Greatsword_Earthsplitter", "Greatsword_Titanfall" },
		Grip = "RightHand",
		Model = { Kind = "Blade", Length = 6, Width = 0.9, Thickness = 0.25, Guard = true },
	},
	Dagger = {
		DisplayName = "Dagger",
		DamageMultiplier = 0.8,
		AttackSpeed = 1.5,
		Range = 6,
		HeavyMultiplier = 2.2,
		CritBonus = 0.08,
		Skills = { "Dagger_Backstab", "Dagger_FanOfKnives", "Dagger_Assassinate" },
		Grip = "RightHand",
		Model = { Kind = "Blade", Length = 1.8, Width = 0.25, Thickness = 0.1, Guard = false },
	},
	Scythe = {
		DisplayName = "Scythe",
		DamageMultiplier = 1.15,
		AttackSpeed = 0.9,
		Range = 10,
		HeavyMultiplier = 2.5,
		Skills = { "Scythe_Reap", "Scythe_SoulHarvest", "Scythe_DeathsDance" },
		Grip = "RightHand",
		Model = { Kind = "Scythe", Length = 6.5 },
	},
	Spear = {
		DisplayName = "Spear",
		DamageMultiplier = 1.05,
		AttackSpeed = 1.0,
		Range = 11,
		HeavyMultiplier = 2.4,
		Skills = { "Spear_Lunge", "Spear_Javelin", "Spear_SkyfallLance" },
		Grip = "RightHand",
		Model = { Kind = "Spear", Length = 7.5 },
	},
	Gauntlets = {
		DisplayName = "Gauntlets",
		DamageMultiplier = 0.95,
		AttackSpeed = 1.35,
		Range = 6,
		HeavyMultiplier = 2.6,
		Skills = { "Gauntlets_RocketPunch", "Gauntlets_Uppercut", "Gauntlets_MeteorFist" },
		Grip = "BothHands",
		Model = { Kind = "Gauntlets" },
	},
	Staff = {
		DisplayName = "Staff",
		DamageMultiplier = 0.9,
		AttackSpeed = 1.05,
		Range = 9,
		HeavyMultiplier = 2.3,
		ScalesWithEnergy = true,
		Skills = { "Staff_ArcaneBolt", "Staff_ManaNova", "Staff_Starfall" },
		Grip = "RightHand",
		Model = { Kind = "Staff", Length = 6 },
	},
	DualBlades = {
		DisplayName = "Dual Blades",
		DamageMultiplier = 0.85,
		AttackSpeed = 1.45,
		Range = 7,
		HeavyMultiplier = 2.3,
		Skills = { "Dual_Whirlwind", "Dual_XSlash", "Dual_BladeStorm" },
		Grip = "BothHands",
		Model = { Kind = "Blade", Length = 3, Width = 0.2, Thickness = 0.1, Guard = false, Dual = true },
	},
}

return WeaponClasses
