--[[
	Registry (ModuleScript)
	Location: ServerScriptService.ServerModules.Registry
	Holds every server service after Main.server boots. Services fetch each other lazily:
		local Registry = require(ServerScriptService.ServerModules.Registry)
		Registry.Get("PlayerDataService"):AddExp(player, 100)
	(Always call Get inside functions, never at module load - avoids circular requires.)
]]
local Registry = {}
Registry.Services = {} :: { [string]: any }
Registry.Started = false

function Registry.Add(name: string, service: any)
	Registry.Services[name] = service
end

function Registry.Get(name: string): any
	local service = Registry.Services[name]
	if not service then
		error("[Registry] Service not found: " .. tostring(name), 2)
	end
	return service
end

function Registry.Has(name: string): boolean
	return Registry.Services[name] ~= nil
end

return Registry
