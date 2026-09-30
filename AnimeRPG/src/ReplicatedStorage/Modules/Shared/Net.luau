--[[
	Net (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.Net

	Central list of every RemoteEvent / RemoteFunction.
	The server creates them inside ReplicatedStorage.Remotes on boot (Net.Setup()).
	Clients wait for them. Never trust arguments coming from clients - every
	server handler validates types, ranges, cooldowns and rate limits.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- RemoteEvents
Net.EventNames = {
	-- Server -> Client
	"DataSync", -- ("Full", data) | ("Set", key, value)
	"Notify", -- (kind, text, extra)
	"FX", -- (effectName, params) visual/audio effects
	"ClientMotion", -- (kind, params) knockback/dash/pull on the local character
	"BossUI", -- (action, payload)
	"DialogOpen", -- (npcId, dialogPayload)
	"InstanceState", -- (kind, payload) dungeon/raid room + timer updates
	"SpinReveal", -- (results) extra reveal broadcast for Mythic/Secret
	-- Client -> Server
	"CombatAction", -- (action, payload)
	"UseSkill", -- (source, slot, aimPosition)
	"Transform", -- ()
	"MovementState", -- (state)
}

-- RemoteFunctions (Client -> Server request/response)
Net.FunctionNames = {
	"GetData",
	"RequestStart",
	"Spin",
	"PowerAction",
	"InventoryAction",
	"StatAction",
	"QuestAction",
	"CraftAction",
	"TraitAction",
	"ProfileAction",
	"FastTravel",
	"DungeonAction",
	"RaidAction",
	"ShopAction",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = "Remotes"
			existing.Parent = ReplicatedStorage
		end
		folder = existing :: any
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: any
	end
	return folder :: any
end

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup is server only")
	local root = getFolder()
	for _, name in ipairs(Net.EventNames) do
		if not root:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = root
		end
	end
	for _, name in ipairs(Net.FunctionNames) do
		if not root:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = root
		end
	end
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(Net.EventNames, name), "Unknown RemoteEvent " .. name)
	local root = getFolder()
	if RunService:IsServer() then
		local remote = root:FindFirstChild(name)
		if not remote then
			Net.Setup()
			remote = root:FindFirstChild(name)
		end
		return remote :: RemoteEvent
	end
	return root:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	assert(table.find(Net.FunctionNames, name), "Unknown RemoteFunction " .. name)
	local root = getFolder()
	if RunService:IsServer() then
		local remote = root:FindFirstChild(name)
		if not remote then
			Net.Setup()
			remote = root:FindFirstChild(name)
		end
		return remote :: RemoteFunction
	end
	return root:WaitForChild(name) :: RemoteFunction
end

-- Client helper: invoke a RemoteFunction safely (never errors, returns ok=false on failure).
function Net.Invoke(name: string, ...): (boolean, any)
	local remote = Net.Function(name)
	local results = table.pack(pcall(remote.InvokeServer, remote, ...))
	if not results[1] then
		warn("[Net] Invoke failed", name, results[2])
		return false, "Request failed"
	end
	return table.unpack(results, 2, results.n)
end

return Net
