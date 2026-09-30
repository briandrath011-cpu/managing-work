--[[
	TableUtil (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.TableUtil
	Pure helpers (no Roblox APIs) - unit tested in tests/.
]]
local TableUtil = {}

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value :: any) do
		copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(inner)
	end
	return (copy :: any) :: T
end

-- Adds every key that exists in template but is missing in target (recursively).
-- Used when loading saves so new data fields appear for old players.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any })
	for key, templateValue in pairs(template) do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.DeepCopy(templateValue)
		elseif type(templateValue) == "table" and type(current) == "table" then
			-- Only recurse into "record" tables (string keys). Arrays/maps with dynamic keys
			-- are left alone so we don't inject template sample entries.
			local isRecord = next(templateValue) ~= nil
			for k in pairs(templateValue) do
				if type(k) ~= "string" then
					isRecord = false
					break
				end
			end
			if isRecord then
				TableUtil.Reconcile(current, templateValue)
			end
		end
	end
	return target
end

function TableUtil.Count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function TableUtil.Keys(t: { [any]: any }): { any }
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

function TableUtil.Map<T, U>(list: { T }, fn: (T, number) -> U): { U }
	local out = {}
	for i, v in ipairs(list) do
		out[i] = fn(v, i)
	end
	return out
end

function TableUtil.Filter<T>(list: { T }, fn: (T) -> boolean): { T }
	local out = {}
	for _, v in ipairs(list) do
		if fn(v) then
			table.insert(out, v)
		end
	end
	return out
end

function TableUtil.Shuffle<T>(list: { T }, rng: Random?): { T }
	local random = rng or Random.new()
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return TableUtil
