--[[
	Modifiers (ModuleScript)
	Location: ReplicatedStorage.Modules.Combat.Modifiers
	A "modifier table" is a dictionary of bonus values. Traits, power passives, armor,
	accessories, transformations and temporary buffs all use the same keys.
	Aggregate() sums them. Pure - unit tested.
]]
local Modifiers = {}

-- Every supported key with its neutral value and a human readable label for UI.
Modifiers.Keys = {
	DamageMult = { Default = 0, Label = "All Damage", Percent = true },
	PowerDamage = { Default = 0, Label = "Power Damage", Percent = true },
	WeaponDamage = { Default = 0, Label = "Weapon Damage", Percent = true },
	StyleDamage = { Default = 0, Label = "Fighting Style Damage", Percent = true },
	DamageReduction = { Default = 0, Label = "Damage Reduction", Percent = true },
	MaxHealth = { Default = 0, Label = "Max Health", Percent = true },
	MaxEnergy = { Default = 0, Label = "Max Energy", Percent = true },
	EnergyRegen = { Default = 0, Label = "Energy Regen", Percent = true },
	MoveSpeed = { Default = 0, Label = "Move Speed", Percent = false },
	CritChance = { Default = 0, Label = "Crit Chance", Percent = true },
	CritDamage = { Default = 0, Label = "Crit Damage", Percent = true },
	Lifesteal = { Default = 0, Label = "Lifesteal", Percent = true },
	CooldownReduction = { Default = 0, Label = "Cooldown Reduction", Percent = true },
	Luck = { Default = 0, Label = "Drop Luck", Percent = true },
	ExpBonus = { Default = 0, Label = "EXP Bonus", Percent = true },
	GoldBonus = { Default = 0, Label = "Gold Bonus", Percent = true },
	DashCooldown = { Default = 0, Label = "Dash Cooldown", Percent = true },
	GuardDamage = { Default = 0, Label = "Guard Damage", Percent = true },
	AwakeningGain = { Default = 0, Label = "Awakening Gain", Percent = true },
	FlatDefense = { Default = 0, Label = "Defense", Percent = false },
	FlatDamage = { Default = 0, Label = "Bonus Damage", Percent = false },
}

-- Hard caps so stacking cannot break the game.
Modifiers.Caps = {
	DamageReduction = 0.6,
	CritChance = 0.5,
	CooldownReduction = 0.4,
	Lifesteal = 0.25,
	DashCooldown = 0.5,
}

function Modifiers.Empty(): { [string]: number }
	local out = {}
	for key, info in pairs(Modifiers.Keys) do
		out[key] = info.Default
	end
	return out
end

function Modifiers.Aggregate(list: { { [string]: number }? }): { [string]: number }
	local out = Modifiers.Empty()
	for _, mods in ipairs(list) do
		if mods then
			for key, value in pairs(mods) do
				if out[key] ~= nil and type(value) == "number" then
					out[key] += value
				end
			end
		end
	end
	for key, cap in pairs(Modifiers.Caps) do
		out[key] = math.min(out[key], cap)
	end
	return out
end

function Modifiers.Describe(mods: { [string]: number }?): { string }
	local lines = {}
	if not mods then
		return lines
	end
	local keys = {}
	for key in pairs(mods) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local info = Modifiers.Keys[key]
		local value = mods[key]
		if info and value ~= 0 then
			local sign = value > 0 and "+" or ""
			if info.Percent then
				table.insert(lines, string.format("%s%d%% %s", sign, math.floor(value * 100 + 0.5), info.Label))
			else
				table.insert(lines, string.format("%s%s %s", sign, tostring(value), info.Label))
			end
		end
	end
	return lines
end

return Modifiers
