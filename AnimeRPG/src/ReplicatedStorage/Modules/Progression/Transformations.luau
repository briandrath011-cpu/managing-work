--[[
	Transformations (ModuleScript)
	Location: ReplicatedStorage.Modules.Progression.Transformations
	Activated when the Awakening bar is full (TransformationService).
	Unlock sources: level, bosses (drop "Unlock" item), quests.
]]
local Transformations = {}

Transformations.List = {
	Awakening = {
		Id = "Awakening",
		DisplayName = "Awakening",
		Description = "Unleash your hidden potential.",
		Rarity = "Rare",
		AuraColor = Color3.fromRGB(255, 255, 255),
		SecondaryColor = Color3.fromRGB(120, 200, 255),
		Duration = 25,
		UnlockLevel = 25,
		Modifiers = { DamageMult = 0.15, DamageReduction = 0.05, MoveSpeed = 3 },
		Sound = "Transform_Awakening",
	},
	ShadowForm = {
		Id = "ShadowForm",
		DisplayName = "Shadow Form",
		Description = "Become one with the dark. Grants lifesteal.",
		Rarity = "Epic",
		AuraColor = Color3.fromRGB(110, 40, 200),
		SecondaryColor = Color3.fromRGB(20, 0, 40),
		Duration = 28,
		UnlockItem = "ShadowCore",
		Modifiers = { DamageMult = 0.2, Lifesteal = 0.05, MoveSpeed = 4 },
		Sound = "Transform_Shadow",
	},
	GoldenAscension = {
		Id = "GoldenAscension",
		DisplayName = "Golden Ascension",
		Description = "Blazing golden aura. Huge power damage.",
		Rarity = "Legendary",
		AuraColor = Color3.fromRGB(255, 220, 60),
		SecondaryColor = Color3.fromRGB(255, 150, 0),
		Duration = 30,
		UnlockItem = "AscensionSeal",
		Modifiers = { DamageMult = 0.2, PowerDamage = 0.2, EnergyRegen = 0.5, MoveSpeed = 5 },
		Sound = "Transform_Golden",
	},
	DemonMode = {
		Id = "DemonMode",
		DisplayName = "Demon Mode",
		Description = "Crimson rage. Massive damage, lower defense.",
		Rarity = "Mythic",
		AuraColor = Color3.fromRGB(220, 20, 40),
		SecondaryColor = Color3.fromRGB(40, 0, 0),
		Duration = 30,
		UnlockItem = "DemonHeart",
		Modifiers = { DamageMult = 0.35, CritChance = 0.08, DamageReduction = -0.1, MoveSpeed = 6 },
		Sound = "Transform_Demon",
	},
	CelestialForm = {
		Id = "CelestialForm",
		DisplayName = "Celestial Form",
		Description = "The final ascension.",
		Rarity = "Secret",
		AuraColor = Color3.fromRGB(180, 255, 255),
		SecondaryColor = Color3.fromRGB(255, 240, 180),
		Duration = 35,
		UnlockItem = "CelestialSigil",
		Modifiers = { DamageMult = 0.35, DamageReduction = 0.15, CooldownReduction = 0.15, MoveSpeed = 8 },
		Sound = "Transform_Celestial",
	},
}

function Transformations.Get(id: string?)
	if not id or id == "" then
		return nil
	end
	return Transformations.List[id]
end

return Transformations
