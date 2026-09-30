--[[
	Progression (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.Progression
	Pure math for levels, mastery and derived character stats. Unit tested.
]]
local GameConfig = require(script.Parent.GameConfig)

local Progression = {}

local P = GameConfig.Progression
local C = GameConfig.Character

function Progression.ExpToNext(level: number): number
	if level >= P.MaxLevel then
		return math.huge
	end
	return math.floor(80 * level ^ 1.6 + 60 * level + 40)
end

-- Adds exp and returns newLevel, newExp, levelsGained.
function Progression.ApplyExp(level: number, exp: number, gained: number): (number, number, number)
	local gainedLevels = 0
	exp += math.max(0, gained)
	while level < P.MaxLevel do
		local need = Progression.ExpToNext(level)
		if exp < need then
			break
		end
		exp -= need
		level += 1
		gainedLevels += 1
	end
	if level >= P.MaxLevel then
		exp = 0
	end
	return level, exp, gainedLevels
end

Progression.MaxMastery = 100

function Progression.MasteryExpToNext(mastery: number): number
	if mastery >= Progression.MaxMastery then
		return math.huge
	end
	return math.floor(30 + mastery * 10 + mastery ^ 1.45 * 3)
end

function Progression.ApplyMasteryExp(mastery: number, exp: number, gained: number): (number, number, number)
	local gainedLevels = 0
	exp += math.max(0, gained)
	while mastery < Progression.MaxMastery do
		local need = Progression.MasteryExpToNext(mastery)
		if exp < need then
			break
		end
		exp -= need
		mastery += 1
		gainedLevels += 1
	end
	if mastery >= Progression.MaxMastery then
		exp = 0
	end
	return mastery, exp, gainedLevels
end

function Progression.MaxHealth(level: number, defense: number, bonus: number?): number
	return math.floor((C.BaseHealth + C.HealthPerLevel * (level - 1) + C.HealthPerDefense * defense) * (1 + (bonus or 0)))
end

function Progression.MaxEnergy(energyStat: number, bonus: number?): number
	return math.floor((C.BaseEnergy + C.EnergyPerStat * energyStat) * (1 + (bonus or 0)))
end

function Progression.EnergyRegen(energyStat: number): number
	return C.EnergyRegenPerSecond + C.EnergyRegenPerStat * energyStat
end

function Progression.MoveSpeedBonus(agility: number): number
	return math.min(C.MaxBonusSpeed, agility * C.SpeedPerAgility)
end

function Progression.DashCooldown(agility: number): number
	local M = GameConfig.Movement
	return math.max(M.MinDashCooldown, M.DashCooldown - agility * M.DashCooldownPerAgility)
end

-- Total stat points a player should have at a level (used to validate/repair saves).
function Progression.TotalStatPoints(level: number): number
	return P.StartingStatPoints + (level - 1) * P.StatPointsPerLevel
end

-- Enemy/boss exp reward scaling.
function Progression.EnemyExp(enemyLevel: number, multiplier: number?): number
	return math.floor((25 + enemyLevel * 9 + enemyLevel ^ 1.35 * 2) * (multiplier or 1))
end

function Progression.EnemyGold(enemyLevel: number, multiplier: number?): number
	return math.floor((8 + enemyLevel * 3) * (multiplier or 1))
end

return Progression
