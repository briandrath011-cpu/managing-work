--[[
	DataController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.DataController
	Read-only local copy of the player's save (sent by PlayerDataService via "DataSync").
	The client NEVER writes data; UI only reads this and sends requests to the server.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

local DataController = {}
DataController.Data = nil :: { [string]: any }?
DataController.Changed = Signal.new() -- (key, value)
DataController.Loaded = Signal.new() -- (data)

function DataController:Get(key: string?): any
	if not self.Data then
		return nil
	end
	if key then
		return self.Data[key]
	end
	return self.Data
end

function DataController:WaitForData(): { [string]: any }
	while not self.Data do
		self.Loaded:Wait()
	end
	return self.Data :: { [string]: any }
end

function DataController:Init()
	Net.Event("DataSync").OnClientEvent:Connect(function(kind, a, b)
		if kind == "Full" then
			self.Data = a
			self.Loaded:Fire(a)
			for key, value in pairs(a) do
				self.Changed:Fire(key, value)
			end
		elseif kind == "Set" and self.Data then
			self.Data[a] = b
			self.Changed:Fire(a, b)
		end
	end)
	-- Fallback: ask for the full save if it did not arrive shortly after joining.
	task.delay(4, function()
		if not self.Data then
			local ok, data = Net.Invoke("GetData")
			if ok and type(data) == "table" and not self.Data then
				self.Data = data
				self.Loaded:Fire(data)
				for key, value in pairs(data) do
					self.Changed:Fire(key, value)
				end
			end
		end
	end)
end

return DataController
