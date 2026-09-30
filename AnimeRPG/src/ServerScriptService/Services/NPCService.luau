--[[
	NPCService (ModuleScript)
	Location: ServerScriptService.Services.NPCService
	Spawns friendly NPCs (WorldConfig.NPCs) with a ProximityPrompt. Talking opens a dialog
	built on the server for that player (quests with state, shop, crafting, trainers...).
	Night-only NPCs appear only during the night phase.
	Remote: DialogOpen (RemoteEvent, server -> client)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage.Modules
local NPCCatalog = require(Modules.NPCs.NPCCatalog)
local QuestCatalog = require(Modules.Quests.QuestCatalog)
local QuestLogic = require(Modules.Quests.QuestLogic)
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local NPCRig = require(ServerScriptService.ServerModules.NPCRig)
local NPCAnimator = require(ServerScriptService.ServerModules.NPCAnimator)

local NPCService = {}

local nightNpcs: { Model } = {}
local hiddenStorage = Instance.new("Folder")
hiddenStorage.Name = "HiddenNPCs"
hiddenStorage.Parent = ServerStorage

local function npcFolder(): Folder
	local folder = workspace:FindFirstChild("NPCs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NPCs"
		folder.Parent = workspace
	end
	return folder :: Folder
end

function NPCService:BuildDialog(player: Player, npcId: string)
	local def = NPCCatalog[npcId]
	local data = Registry.Get("PlayerDataService"):Get(player)
	if not def or not data then
		return nil
	end
	local night = workspace:GetAttribute("TimePhase") == "Night"
	local inventory = Registry.Get("InventoryService")
	local function countItem(itemId)
		return inventory:CountItem(player, itemId)
	end
	local quests = {}
	-- Quests offered by this NPC
	for _, questId in ipairs(def.Quests) do
		local quest = QuestCatalog.Get(questId)
		if quest then
			local active = data.Quests.Active[questId]
			local state
			if active then
				state = QuestLogic.IsComplete(quest, active.Progress, countItem) and (quest.TurnIn == npcId and "Ready" or "Active")
					or "Active"
			else
				local ok, reason = QuestLogic.IsAvailable(quest, data, night)
				state = ok and "Available" or ((reason == "Already completed") and "Done" or "Locked")
			end
			if state ~= "Done" and not (state == "Locked" and quest.Hidden) then
				table.insert(quests, { Id = questId, State = state })
			end
		end
	end
	-- Quests that are turned in here but given elsewhere (deliveries / journeys)
	for questId, active in pairs(data.Quests.Active) do
		local quest = QuestCatalog.Get(questId)
		if quest and quest.TurnIn == npcId and quest.Giver ~= npcId then
			local ready = QuestLogic.IsComplete(quest, active.Progress, countItem)
			table.insert(quests, { Id = questId, State = ready and "Ready" or "Active" })
		end
	end
	return {
		Id = npcId,
		Name = def.DisplayName,
		Greeting = def.Greeting,
		Roles = def.Roles,
		Quests = quests,
		CraftStation = def.CraftStation,
		HasShop = def.Shop ~= nil,
	}
end

local function onTalk(player: Player, npcId: string)
	-- Talk objectives first so the dialog shows the updated state.
	Registry.Get("QuestService"):OnEvent(player, { Kind = "Talk", Target = npcId })
	local payload = NPCService:BuildDialog(player, npcId)
	if payload then
		Net.Event("DialogOpen"):FireClient(player, npcId, payload)
	end
end

function NPCService:SpawnNpc(placement)
	local def = NPCCatalog[placement.Npc]
	if not def then
		warn("[NPCService] Unknown NPC " .. tostring(placement.Npc))
		return
	end
	local model = NPCRig.Create({ Id = def.Id, Body = def.Colors.Body, Accent = def.Colors.Accent })
	model.Name = def.DisplayName
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 0
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	-- Face the village center / spawn.
	local position = placement.Position + Vector3.new(0, 2, 0)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	model:SetAttribute("NpcId", def.Id)
	model:SetAttribute("Roles", table.concat(def.Roles, ","))
	NPCRig.AddOverhead(model, def.DisplayName, Color3.fromRGB(120, 230, 255), false)
	task.defer(function()
		if model.Parent then
			NPCAnimator.Update(humanoid, root) -- idle pose
		end
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = def.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		onTalk(player, def.Id)
	end)

	if def.NightOnly or placement.NightOnly then
		table.insert(nightNpcs, model)
		model.Parent = workspace:GetAttribute("TimePhase") == "Night" and npcFolder() or hiddenStorage
	else
		model.Parent = npcFolder()
	end
end

function NPCService:Init() end

function NPCService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	for _, placement in ipairs(WorldConfig.NPCs) do
		self:SpawnNpc(placement)
	end
	workspace:GetAttributeChangedSignal("TimePhase"):Connect(function()
		local night = workspace:GetAttribute("TimePhase") == "Night"
		for _, model in ipairs(nightNpcs) do
			model.Parent = night and npcFolder() or hiddenStorage
		end
		if night then
			Registry.Get("FXService"):Notify(nil, "Event", "🌙 Night falls... rare merchants and creatures appear.")
		end
	end)
end

return NPCService
