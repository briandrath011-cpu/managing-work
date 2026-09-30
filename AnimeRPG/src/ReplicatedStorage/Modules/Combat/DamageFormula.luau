--[[
	DamageFormula (ModuleScript)
	Location: ReplicatedStorage.Modules.Combat.DamageFormula
	Pure damage math, only ever called by the SERVER (DamageService). Unit tested.

	Damage = Base
	       x Stat Scaling      (1 + stat * StatScale)
	       x Weapon Scaling    (weapon/power multiplier incl. mastery)
	       x Buff              (1 + all damage bonuses)
	       x Critical Modifier (CritMultiplier + CritDamage on crit)
	       x Level Factor      (small bonus/penalty for level difference)
	       x Defense Factor    (100 / (100 + defense))  -- "minus defense" without going negative
	       x Block Factor
	       - nothing below 1
]]
local DamageFormula = {}

DamageFormula.StatScale = 0.011
DamageFormula.MasteryScale = 0.004
DamageFormula.DefenseConstant = 100
DamageFormula.LevelDiffPerLevel = 0.012
DamageFormula.MaxLevelFactor = 1.3
DamageFormula.MinLevelFactor = 0.6

export type Input = {
	Base: number,
	Stat: number?, -- value of the scaling stat (Strength/Energy/Weapon)
	SourceMultiplier: number?, -- weapon/power damage multiplier
	Mastery: number?,
	DamageBonus: number?, -- sum of all percentage bonuses (0.25 = +25%)
	FlatBonus: number?,
	CritChance: number?,
	CritMultiplier: number?,
	CritDamageBonus: number?,
	AttackerLevel: number?,
	TargetLevel: number?,
	Defense: number?,
	DamageReduction: number?, -- 0..1 from modifiers
	BlockMultiplier: number?, -- 1 = not blocked
	ForceCrit: boolean?,
}

function DamageFormula.StatMultiplier(stat: number): number
	return 1 + math.max(0, stat) * DamageFormula.StatScale
end

function DamageFormula.DefenseMultiplier(defense: number): number
	defense = math.max(0, defense)
	return DamageFormula.DefenseConstant / (DamageFormula.DefenseConstant + defense)
end

function DamageFormula.LevelFactor(attackerLevel: number, targetLevel: number): number
	local diff = attackerLevel - targetLevel
	local factor = 1 + diff * DamageFormula.LevelDiffPerLevel
	return math.clamp(factor, DamageFormula.MinLevelFactor, DamageFormula.MaxLevelFactor)
end

function DamageFormula.Compute(input: Input, rng: Random?): (number, boolean)
	local random = rng or Random.new()
	local damage = input.Base + (input.FlatBonus or 0)
	damage *= DamageFormula.StatMultiplier(input.Stat or 0)
	damage *= (input.SourceMultiplier or 1) * (1 + (input.Mastery or 0) * DamageFormula.MasteryScale)
	damage *= 1 + (input.DamageBonus or 0)

	local isCrit = input.ForceCrit == true or random:NextNumber() < (input.CritChance or 0)
	if isCrit then
		damage *= (input.CritMultiplier or 1.5) + (input.CritDamageBonus or 0)
	end

	if input.AttackerLevel and input.TargetLevel then
		damage *= DamageFormula.LevelFactor(input.AttackerLevel, input.TargetLevel)
	end
	damage *= DamageFormula.DefenseMultiplier(input.Defense or 0)
	damage *= 1 - math.clamp(input.DamageReduction or 0, 0, 0.9)
	damage *= input.BlockMultiplier or 1

	return math.max(1, math.floor(damage + 0.5)), isCrit
end

return DamageFormula
