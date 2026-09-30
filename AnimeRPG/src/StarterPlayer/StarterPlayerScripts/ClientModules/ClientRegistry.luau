--[[
	ClientRegistry (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.ClientRegistry
	Holds all client controllers / UI modules after ClientMain boots them.
]]
local ClientRegistry = {}
ClientRegistry.Controllers = {} :: { [string]: any }

function ClientRegistry.Add(name: string, controller: any)
	ClientRegistry.Controllers[name] = controller
end

function ClientRegistry.Get(name: string): any
	local controller = ClientRegistry.Controllers[name]
	if not controller then
		error("[ClientRegistry] Controller not found: " .. tostring(name), 2)
	end
	return controller
end

function ClientRegistry.Has(name: string): boolean
	return ClientRegistry.Controllers[name] ~= nil
end

return ClientRegistry
