--[[
	WeightedRandom (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.WeightedRandom
	Pure weighted selection. Only the SERVER should roll anything that grants rewards.
]]
local WeightedRandom = {}

-- entries: { { Weight = number, ... } } or map { key = weight }
function WeightedRandom.PickEntry<T>(entries: { T }, rng: Random, weightKey: string?): T?
	local key = weightKey or "Weight"
	local total = 0
	for _, entry in ipairs(entries) do
		total += math.max(0, (entry :: any)[key] or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, entry in ipairs(entries) do
		cumulative += math.max(0, (entry :: any)[key] or 0)
		if roll < cumulative then
			return entry
		end
	end
	return entries[#entries]
end

function WeightedRandom.PickKey(weights: { [string]: number }, rng: Random, order: { string }?): string?
	-- An explicit order keeps rolls deterministic for a given seed (pairs() order is not stable).
	local keys = order or {}
	if not order then
		for k in pairs(weights) do
			table.insert(keys, k)
		end
		table.sort(keys)
	end
	local total = 0
	for _, k in ipairs(keys) do
		total += math.max(0, weights[k] or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, k in ipairs(keys) do
		cumulative += math.max(0, weights[k] or 0)
		if roll < cumulative then
			return k
		end
	end
	return keys[#keys]
end

return WeightedRandom
