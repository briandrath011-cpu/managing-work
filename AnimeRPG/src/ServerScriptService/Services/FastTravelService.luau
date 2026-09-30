--[[
	FastTravelService (ModuleScript)
	Location: ServerScriptService.Services.FastTravelService
	Travel between DISCOVERED waypoints only. Not allowed in combat / inside dungeons.
	Remote: FastTravel (RemoteFunction) (waypointId) -> ok, message
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local FastTravelService = {}

local limiter = RateLimiter.new(2, 0.2)

function FastTravelService:Travel(player: Player, waypointId: string): (boolean, string?)
	local data = Registry.Get("PlayerDataService"):Get(player)
	local waypoint = WorldConfig.GetWaypoint(waypointId)
	local entity = EntityRegistry.GetForPlayer(player)
	if not data or not waypoint or not entity or not EntityRegistry.IsAlive(entity) then
		return false, "Can't travel right now"
	end
	if not data.Discovered.Waypoints[waypointId] then
		return false, "Discover this waypoint first"
	end
	if os.clock() - entity.State.LastCombatTime < 8 then
		return false, "You can't fast travel during combat"
	end
	if entity.Model:GetAttribute("InInstance") then
		return false, "You can't fast travel from a dungeon or raid"
	end
	Registry.Get("FXService")
		:Play("Teleport", { Position = entity.Root.Position, Color = Color3.fromRGB(90, 200, 255) }, entity.Root.Position)
	Motion.Teleport(entity, Registry.Get("WorldBuilder"):GetWaypointCFrame(waypointId))
	data.Discovered.LastWaypoint = waypointId
	return true
end

function FastTravelService:Init()
	Net.Function("FastTravel").OnServerInvoke = function(player, waypointId)
		if not limiter:Check(player) then
			return false, "Please wait before traveling again"
		end
		if not Validate.String(waypointId, 40) then
			return false, "Invalid waypoint"
		end
		return FastTravelService:Travel(player, waypointId)
	end
end

return FastTravelService
