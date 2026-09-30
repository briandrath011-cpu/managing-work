--[[
	QuestService (ModuleScript)
	Location: ServerScriptService.Services.QuestService

	PHASE 12 - Quest System (server authority)
	Remote: QuestAction (RemoteFunction) ("Accept", questId, npcId) ("Abandon", questId) ("TurnIn", questId, npcId)
	Progress events: Kill / Boss (DropService), Explore (ExplorationService), Talk (NPCService),
	Dungeon (DungeonService), Raid (RaidService). Collect/Deliver progress is read live from the inventory.
	Daily (3) and Weekly (2) quests rotate automatically (UTC) and auto-complete.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local QuestCatalog = require(Modules.Quests.QuestCatalog)
local QuestLogic = require(Modules.Quests.QuestLogic)
local WorldConfig = require(Modules.World.WorldConfig)
local TableUtil = require(Modules.Shared.TableUtil)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local QuestService = {}
QuestService.QuestCompleted = Signal.new() -- (player, questId)

local limiter = RateLimiter.new(10, 4)
local rng = Random.new()
local NPC_RANGE = 25

local function dataService()
	return Registry.Get("PlayerDataService")
end

local function isNight(): boolean
	return workspace:GetAttribute("TimePhase") == "Night"
end

local function npcPosition(npcId: string): Vector3?
	for _, placement in ipairs(WorldConfig.NPCs) do
		if placement.Npc == npcId then
			return placement.Position
		end
	end
	return nil
end

local function isNearNpc(player: Player, npcId: string): boolean
	local position = npcPosition(npcId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return position ~= nil and root ~= nil and (root.Position - position).Magnitude <= NPC_RANGE
end

local function countItem(player: Player)
	return function(itemId: string): number
		return Registry.Get("InventoryService"):CountItem(player, itemId)
	end
end

function QuestService:Accept(player: Player, questId: string, _npcId: string?): (boolean, string?)
	local data = dataService():Get(player)
	local def = QuestCatalog.Get(questId)
	if not data or not def then
		return false, "Unknown quest"
	end
	local ok, reason = QuestLogic.IsAvailable(def, data, isNight())
	if not ok then
		return false, reason
	end
	if def.Giver and not isNearNpc(player, def.Giver) then
		return false, "Too far from the quest giver"
	end
	if TableUtil.Count(data.Quests.Active) >= 15 then
		return false, "Too many active quests"
	end
	data.Quests.Active[questId] = { Progress = QuestLogic.NewProgress(def), Accepted = os.time() }
	for _, objective in ipairs(def.Objectives) do
		if objective.Kind == "Deliver" then
			Registry.Get("InventoryService"):AddItem(player, objective.Item, objective.Count or 1)
		end
	end
	dataService():Replicate(player, "Quests")
	Registry.Get("FXService"):Notify(player, "Quest", "Quest accepted: " .. def.Name)
	-- Objectives that may already be satisfied (e.g. region already discovered).
	for _, objective in ipairs(def.Objectives) do
		if objective.Kind == "Explore" then
			local discovered = data.Discovered
			if discovered.Regions[objective.Target] or discovered.Secrets[objective.Target] or discovered.Waypoints[objective.Target] then
				self:OnEvent(player, { Kind = "Explore", Target = objective.Target })
			end
		end
	end
	return true
end

function QuestService:Abandon(player: Player, questId: string): (boolean, string?)
	local data = dataService():Get(player)
	local def = QuestCatalog.Get(questId)
	if not data or not def or not data.Quests.Active[questId] then
		return false, "Quest not active"
	end
	if def.Type == "Daily" or def.Type == "Weekly" then
		return false, "Board quests can't be abandoned"
	end
	data.Quests.Active[questId] = nil
	for _, objective in ipairs(def.Objectives) do
		if objective.Kind == "Deliver" then
			Registry.Get("InventoryService"):RemoveItem(
				player,
				objective.Item,
				math.min(objective.Count or 1, Registry.Get("InventoryService"):CountItem(player, objective.Item))
			)
		end
	end
	dataService():Replicate(player, "Quests")
	return true
end

function QuestService:Complete(player: Player, questId: string): (boolean, string?)
	local data = dataService():Get(player)
	local def = QuestCatalog.Get(questId)
	local active = data and data.Quests.Active[questId]
	if not def or not active then
		return false, "Quest not active"
	end
	if not QuestLogic.IsComplete(def, active.Progress, countItem(player)) then
		return false, "Objectives not complete"
	end
	-- Consume collected / delivered items.
	local inventory = Registry.Get("InventoryService")
	for _, objective in ipairs(def.Objectives) do
		if objective.Kind == "Collect" or objective.Kind == "Deliver" then
			if not inventory:RemoveItem(player, objective.Item, objective.Count or 1) then
				return false, "Missing items"
			end
		end
	end
	data.Quests.Active[questId] = nil
	data.Quests.Completed[questId] = (data.Quests.Completed[questId] or 0) + 1
	dataService():Replicate(player, "Quests")
	dataService():AddCounter(player, "QuestsCompleted", 1)
	Registry.Get("DropService"):GrantRewards(player, def.Rewards, nil)
	Registry.Get("FXService"):Notify(player, "QuestComplete", "Quest complete: " .. def.Name)
	Registry.Get("FXService"):PlayFor(player, "QuestComplete", { Name = def.Name })
	self.QuestCompleted:Fire(player, questId)
	return true
end

function QuestService:TurnIn(player: Player, questId: string, npcId: string?): (boolean, string?)
	local def = QuestCatalog.Get(questId)
	if not def then
		return false, "Unknown quest"
	end
	local turnIn = def.TurnIn
	if turnIn and (npcId ~= turnIn or not isNearNpc(player, turnIn)) then
		return false, "Return to the quest NPC"
	end
	return self:Complete(player, questId)
end

-- Progress events from other services.
function QuestService:OnEvent(player: Player, event)
	local data = dataService():Get(player)
	if not data then
		return
	end
	local changed = false
	local autoComplete = {}
	for questId, active in pairs(data.Quests.Active) do
		local def = QuestCatalog.Get(questId)
		if def and QuestLogic.ApplyEvent(def, active.Progress, event) then
			changed = true
			if QuestLogic.IsComplete(def, active.Progress, countItem(player)) then
				if def.Type == "Daily" or def.Type == "Weekly" then
					table.insert(autoComplete, questId)
				else
					Registry.Get("FXService")
						:Notify(
							player,
							"Quest",
							def.Name .. " - objectives complete! Return to " .. tostring(def.TurnIn or "the quest giver")
						)
				end
			end
		end
	end
	if changed then
		dataService():Replicate(player, "Quests")
	end
	for _, questId in ipairs(autoComplete) do
		self:Complete(player, questId)
	end
end

-- Daily / weekly rotation.
local function pick(pool: { string }, count: number): { string }
	local copy = table.clone(pool)
	TableUtil.Shuffle(copy, rng)
	local out = {}
	for i = 1, math.min(count, #copy) do
		out[i] = copy[i]
	end
	return out
end

function QuestService:RefreshBoards(player: Player)
	local data = dataService():Get(player)
	if not data then
		return
	end
	local quests = data.Quests
	local now = os.time()
	local changed = false
	local day = QuestLogic.DayKey(now)
	if quests.DailyReset ~= day then
		for _, id in ipairs(quests.DailyPool) do
			quests.Active[id] = nil
		end
		quests.DailyPool = pick(QuestCatalog.DailyPool, QuestCatalog.DailyCount)
		for _, id in ipairs(quests.DailyPool) do
			quests.Active[id] = { Progress = QuestLogic.NewProgress(QuestCatalog.Get(id)), Accepted = now }
		end
		quests.DailyReset = day
		changed = true
	end
	local week = QuestLogic.WeekKey(now)
	if quests.WeeklyReset ~= week then
		for _, id in ipairs(quests.WeeklyPool) do
			quests.Active[id] = nil
		end
		quests.WeeklyPool = pick(QuestCatalog.WeeklyPool, QuestCatalog.WeeklyCount)
		for _, id in ipairs(quests.WeeklyPool) do
			quests.Active[id] = { Progress = QuestLogic.NewProgress(QuestCatalog.Get(id)), Accepted = now }
		end
		quests.WeeklyReset = week
		changed = true
	end
	if changed then
		dataService():Replicate(player, "Quests")
	end
end

function QuestService:Init()
	Net.Function("QuestAction").OnServerInvoke = function(player, action, questId, npcId)
		if not limiter:Check(player) then
			return false, "Slow down"
		end
		if not Validate.String(questId, 40) then
			return false, "Invalid quest"
		end
		if npcId ~= nil and not Validate.String(npcId, 40) then
			return false, "Invalid npc"
		end
		if action == "Accept" then
			return QuestService:Accept(player, questId, npcId)
		elseif action == "Abandon" then
			return QuestService:Abandon(player, questId)
		elseif action == "TurnIn" then
			return QuestService:TurnIn(player, questId, npcId)
		end
		return false, "Unknown action"
	end
	dataService().ProfileLoaded:Connect(function(player)
		QuestService:RefreshBoards(player)
	end)
	-- Collect quests react to new items.
	Registry.Get("InventoryService").ItemAdded:Connect(function(player, itemId)
		local data = dataService():Get(player)
		if not data then
			return
		end
		for questId, active in pairs(data.Quests.Active) do
			local def = QuestCatalog.Get(questId)
			if def then
				for _, objective in ipairs(def.Objectives) do
					if
						objective.Kind == "Collect"
						and objective.Item == itemId
						and QuestLogic.IsComplete(def, active.Progress, countItem(player))
					then
						Registry.Get("FXService"):Notify(player, "Quest", def.Name .. " - objectives complete! Return to the quest giver.")
					end
				end
			end
		end
	end)
end

function QuestService:Start()
	while true do
		task.wait(300)
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			QuestService:RefreshBoards(player)
		end
	end
end

return QuestService
