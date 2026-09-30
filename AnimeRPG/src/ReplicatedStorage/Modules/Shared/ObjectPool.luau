--[[
	ObjectPool (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.ObjectPool
	Reuses Instances (damage numbers, hit sparks, shockwave parts) instead of creating/destroying.
]]
local ObjectPool = {}
ObjectPool.__index = ObjectPool

local PARK_CFRAME = CFrame.new(0, -10000, 0)

function ObjectPool.new(factory: () -> Instance, maxSize: number?)
	return setmetatable({
		_factory = factory,
		_free = {},
		_max = maxSize or 64,
		_active = 0,
	}, ObjectPool)
end

function ObjectPool:Get(): Instance
	local item = table.remove(self._free)
	if item == nil then
		item = self._factory()
	end
	self._active += 1
	return item
end

function ObjectPool:Release(item: Instance)
	self._active = math.max(0, self._active - 1)
	if #self._free >= self._max then
		item:Destroy()
		return
	end
	if item:IsA("BasePart") then
		item.CFrame = PARK_CFRAME
	elseif item:IsA("GuiObject") or item:IsA("LayerCollector") then
		(item :: any).Enabled = false
	end
	table.insert(self._free, item)
end

function ObjectPool:ActiveCount(): number
	return self._active
end

return ObjectPool
