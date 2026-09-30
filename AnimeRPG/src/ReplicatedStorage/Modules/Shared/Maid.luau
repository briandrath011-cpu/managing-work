--[[
	Maid (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.Maid
	Tracks connections/instances/functions and cleans them all at once (effect cleanup).
]]
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task_)
	table.insert(self._tasks, task_)
	return task_
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, item in ipairs(tasks) do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			task.spawn(item)
		elseif kind == "thread" then
			pcall(task.cancel, item)
		elseif type(item) == "table" then
			if item.Disconnect then
				item:Disconnect()
			elseif item.Destroy then
				item:Destroy()
			elseif item.Clean then
				item:Clean()
			end
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
