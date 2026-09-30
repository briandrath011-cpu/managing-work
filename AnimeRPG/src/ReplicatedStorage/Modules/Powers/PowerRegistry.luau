--[[
	PowerRegistry (ModuleScript)
	Location: ReplicatedStorage.Modules.Powers.PowerRegistry

	Auto-loads every ModuleScript inside Powers.List. To add a new power:
	  1. Copy any file in Powers/List (e.g. Blaze.luau), rename it and change Id/DisplayName/Rarity.
	  2. Write its 4 skills. Nothing else has to be registered - spins pick it up automatically.
]]
local RarityConfig = require(script.Parent.Parent.Config.RarityConfig)

local PowerRegistry = {}

PowerRegistry.MasteryUnlocks = { 0, 15, 35, 75 } -- skill 1, 2, 3, ultimate

-- Damage multiplier by rarity so rarer powers hit harder at equal mastery.
PowerRegistry.RarityMultiplier = {
	Common = 1.0,
	Rare = 1.1,
	Epic = 1.2,
	Legendary = 1.32,
	Mythic = 1.45,
	Secret = 1.6,
}

local powers: { [string]: any } = {}
local byRarity: { [string]: { any } } = {}

for _, rarity in ipairs(RarityConfig.Order) do
	byRarity[rarity] = {}
end

for _, moduleScript in ipairs(script.Parent.List:GetChildren()) do
	if moduleScript:IsA("ModuleScript") then
		local ok, def = pcall(require, moduleScript)
		if ok and type(def) == "table" and def.Id then
			assert(#def.Skills == 4, "Power " .. def.Id .. " must have 4 skills (3 + ultimate)")
			def.SpinWeight = def.SpinWeight or 1
			def.MasteryUnlocks = def.MasteryUnlocks or PowerRegistry.MasteryUnlocks
			def.DamageMultiplier = def.DamageMultiplier or PowerRegistry.RarityMultiplier[def.Rarity] or 1
			def.Skills[4].Ultimate = true
			powers[def.Id] = def
			table.insert(byRarity[def.Rarity], def)
		else
			warn("[PowerRegistry] Failed to load power module " .. moduleScript.Name .. ": " .. tostring(def))
		end
	end
end

for _, list in pairs(byRarity) do
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
end

function PowerRegistry.Get(id: string?)
	if not id then
		return nil
	end
	return powers[id]
end

function PowerRegistry.All()
	return powers
end

function PowerRegistry.ByRarity(rarity: string): { any }
	return byRarity[rarity] or {}
end

-- Which skill slots (1-4) are unlocked at a mastery level.
function PowerRegistry.IsSkillUnlocked(power, slot: number, mastery: number): boolean
	local required = power.Skills[slot] and (power.Skills[slot].MasteryRequired or power.MasteryUnlocks[slot]) or math.huge
	return mastery >= required
end

return PowerRegistry
