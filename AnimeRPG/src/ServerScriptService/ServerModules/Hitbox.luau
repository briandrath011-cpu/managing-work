--[[
	Hitbox (ModuleScript)
	Location: ServerScriptService.ServerModules.Hitbox
	Server-side spatial queries. Hitboxes are ALWAYS computed on the server
	(anti-exploit: the client can't report fake hits).
	Only checks HumanoidRootParts of registered entities, which is much cheaper than
	GetPartBoundsInBox over the whole map.
]]
local ServerScriptService = game:GetService("ServerScriptService")

local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)

local Hitbox = {}

local ROOT_RADIUS = 2.2 -- approximate body radius added to all checks

-- Enemies of `attacker` within a sphere.
function Hitbox.Radius(attacker: any, position: Vector3, radius: number): { any }
	local out = {}
	for _, entity in pairs(EntityRegistry.All()) do
		if EntityRegistry.IsAlive(entity) and EntityRegistry.AreEnemies(attacker, entity) then
			if (entity.Root.Position - position).Magnitude <= radius + ROOT_RADIUS then
				table.insert(out, entity)
			end
		end
	end
	return out
end

-- Enemies inside an oriented box (cframe = box center).
function Hitbox.Box(attacker: any, cframe: CFrame, size: Vector3): { any }
	local out = {}
	local half = size / 2 + Vector3.new(ROOT_RADIUS, ROOT_RADIUS, ROOT_RADIUS)
	for _, entity in pairs(EntityRegistry.All()) do
		if EntityRegistry.IsAlive(entity) and EntityRegistry.AreEnemies(attacker, entity) then
			local localPos = cframe:PointToObjectSpace(entity.Root.Position)
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				table.insert(out, entity)
			end
		end
	end
	return out
end

-- Enemies along a capsule/line (beams, lunges).
function Hitbox.Line(attacker: any, origin: Vector3, direction: Vector3, length: number, width: number): { any }
	local out = {}
	local dir = direction.Magnitude > 0 and direction.Unit or Vector3.zAxis
	for _, entity in pairs(EntityRegistry.All()) do
		if EntityRegistry.IsAlive(entity) and EntityRegistry.AreEnemies(attacker, entity) then
			local rel = entity.Root.Position - origin
			local along = rel:Dot(dir)
			if along >= -2 and along <= length then
				local closest = origin + dir * along
				if (entity.Root.Position - closest).Magnitude <= width / 2 + ROOT_RADIUS then
					table.insert(out, entity)
				end
			end
		end
	end
	return out
end

function Hitbox.Nearest(attacker: any, position: Vector3, radius: number): any?
	local best, bestDist = nil, math.huge
	for _, entity in ipairs(Hitbox.Radius(attacker, position, radius)) do
		local dist = (entity.Root.Position - position).Magnitude
		if dist < bestDist then
			best, bestDist = entity, dist
		end
	end
	return best
end

-- Ground position under a point (for AoE placement).
function Hitbox.Ground(position: Vector3, ignore: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = ignore or {}
	for _, folderName in ipairs({ "Enemies", "Bosses", "Effects", "Drops" }) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			table.insert(filter, folder)
		end
	end
	params.FilterDescendantsInstances = filter
	local result = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0), params)
	return result and result.Position or position
end

return Hitbox
