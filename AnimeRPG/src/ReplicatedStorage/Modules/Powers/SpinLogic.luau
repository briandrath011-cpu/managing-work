--[[
	SpinLogic (ModuleScript)
	Location: ReplicatedStorage.Modules.Powers.SpinLogic
	Pure spin + pity math. Only SpinService (server) calls Roll with real rewards.
	Unit tested (tests/spec/SpinLogic.spec.luau).

	Pity: Pity[tier] counts spins since the player last got >= that tier.
	If the NEXT spin would reach the threshold, the result is raised to that tier.
]]
local RarityConfig = require(script.Parent.Parent.Config.RarityConfig)
local WeightedRandom = require(script.Parent.Parent.Shared.WeightedRandom)

local SpinLogic = {}

function SpinLogic.RollRarity(
	rng: Random,
	pity: { [string]: number },
	chances: { [string]: number }?,
	pityConfig: { any }?
): (string, boolean)
	local table_ = chances or RarityConfig.SpinChances
	local rarity = WeightedRandom.PickKey(table_, rng, RarityConfig.Order) :: string
	local pityHit = false
	for _, rule in ipairs(pityConfig or RarityConfig.Pity) do
		local count = pity[rule.Rarity] or 0
		if count + 1 >= rule.Threshold and not RarityConfig.IsAtLeast(rarity, rule.Rarity) then
			rarity = rule.Rarity
			pityHit = true
		end
	end
	return rarity, pityHit
end

-- Returns a NEW pity table after a spin resulted in `rarity`.
function SpinLogic.UpdatePity(pity: { [string]: number }, rarity: string, pityConfig: { any }?): { [string]: number }
	local out = table.clone(pity)
	for _, rule in ipairs(pityConfig or RarityConfig.Pity) do
		if RarityConfig.IsAtLeast(rarity, rule.Rarity) then
			out[rule.Rarity] = 0
		else
			out[rule.Rarity] = (out[rule.Rarity] or 0) + 1
		end
	end
	return out
end

-- Picks a power of the rarity (falls back to lower rarities if none exist).
-- powersByRarity: function(rarity) -> { powerDef }
function SpinLogic.PickPower(rng: Random, rarity: string, powersByRarity: (string) -> { any }): (any?, string)
	local rank = RarityConfig.Rank[rarity] or 1
	for r = rank, 1, -1 do
		local name = RarityConfig.Order[r]
		local list = powersByRarity(name)
		if #list > 0 then
			return WeightedRandom.PickEntry(list, rng, "SpinWeight"), name
		end
	end
	return nil, rarity
end

return SpinLogic
