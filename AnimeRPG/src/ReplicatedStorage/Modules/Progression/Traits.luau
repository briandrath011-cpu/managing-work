--[[
	Traits (ModuleScript)
	Location: ReplicatedStorage.Modules.Progression.Traits
	Rolled with Trait Rolls (TraitService). Small build tweaks - no extreme pay-to-win values.
]]
local Traits = {}

Traits.List = {
	None = { Id = "None", DisplayName = "None", Rarity = "Common", Description = "No trait.", Modifiers = {} },
	Strong = {
		Id = "Strong",
		DisplayName = "Strong",
		Rarity = "Common",
		Description = "Hits a little harder.",
		Modifiers = { StyleDamage = 0.06, WeaponDamage = 0.03 },
	},
	Sturdy = { Id = "Sturdy", DisplayName = "Sturdy", Rarity = "Common", Description = "Tougher body.", Modifiers = { MaxHealth = 0.06 } },
	Swift = {
		Id = "Swift",
		DisplayName = "Swift",
		Rarity = "Rare",
		Description = "Moves and dashes faster.",
		Modifiers = { MoveSpeed = 3, DashCooldown = 0.08 },
	},
	Tank = {
		Id = "Tank",
		DisplayName = "Tank",
		Rarity = "Rare",
		Description = "Takes less damage.",
		Modifiers = { DamageReduction = 0.06, MaxHealth = 0.05 },
	},
	Focused = {
		Id = "Focused",
		DisplayName = "Focused",
		Rarity = "Rare",
		Description = "Skills recharge faster.",
		Modifiers = { CooldownReduction = 0.06 },
	},
	EnergyMaster = {
		Id = "EnergyMaster",
		DisplayName = "Energy Master",
		Rarity = "Epic",
		Description = "More energy and power damage.",
		Modifiers = { MaxEnergy = 0.15, EnergyRegen = 0.2, PowerDamage = 0.05 },
	},
	Bladesworn = {
		Id = "Bladesworn",
		DisplayName = "Bladesworn",
		Rarity = "Epic",
		Description = "Weapon specialist.",
		Modifiers = { WeaponDamage = 0.1, GuardDamage = 0.1 },
	},
	Lucky = {
		Id = "Lucky",
		DisplayName = "Lucky",
		Rarity = "Legendary",
		Description = "Better drops and more gold.",
		Modifiers = { Luck = 0.2, GoldBonus = 0.15 },
	},
	Berserker = {
		Id = "Berserker",
		DisplayName = "Berserker",
		Rarity = "Legendary",
		Description = "Crits more, heals on hit.",
		Modifiers = { CritChance = 0.05, Lifesteal = 0.03 },
	},
	Godspeed = {
		Id = "Godspeed",
		DisplayName = "Godspeed",
		Rarity = "Mythic",
		Description = "Blinding speed and fast recovery.",
		Modifiers = { MoveSpeed = 6, DashCooldown = 0.2, CooldownReduction = 0.05, CritChance = 0.03 },
	},
	Ascendant = {
		Id = "Ascendant",
		DisplayName = "Ascendant",
		Rarity = "Secret",
		Description = "Chosen by the heavens.",
		Modifiers = { DamageMult = 0.08, MaxHealth = 0.08, AwakeningGain = 0.25, ExpBonus = 0.1 },
	},
}

-- Order used by the roll (weights come from RarityConfig.TraitChances split across traits of a rarity).
Traits.Rollable =
	{ "Strong", "Sturdy", "Swift", "Tank", "Focused", "EnergyMaster", "Bladesworn", "Lucky", "Berserker", "Godspeed", "Ascendant" }

function Traits.Get(id: string?)
	if not id or id == "None" then
		return nil
	end
	return Traits.List[id]
end

return Traits
