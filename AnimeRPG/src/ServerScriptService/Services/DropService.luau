--[[
	DropService (ModuleScript)
	Location: ServerScriptService.Services.DropService

	PHASE 14 - Drops + kill rewards (server only: the client never decides drops).
	- Personal loot: every eligible damage contributor rolls separately
	- Luck modifier increases drop chances
	- EXP / Gold (with bonuses), power mastery, counters, quest progress, boss log, titles
	- Rare drops trigger a special drop effect; Mythic+ drops are announced server-wide
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Progression = require(Modules.Config.Progression)
local RarityConfig = require(Modules.Config.RarityConfig)
local ItemUtil = require(Modules.Items.ItemUtil)
local Titles = require(Modules.Progression.Titles)
local Signal = require(Modules.Shared.Signal)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Modifiers = require(Modules.Combat.Modifiers)

local DropService = {}
DropService.ItemDropped = Signal.new() -- (player, itemId, amount, sourceId)

local rng = Random.new()

-- Global multipliers set by world events (Blood Moon etc.)
DropService.GlobalLuck = 0
DropService.GlobalExp = 0

local function playerMods(player: Player): { [string]: number }
	local entity = EntityRegistry.GetForPlayer(player)
	if not entity then
		return Registry.Get("CharacterService"):GetModifiers(player)
	end
	local list = { entity.Modifiers }
	for _, mods in ipairs(EntityRegistry.BuffModifiers(entity)) do
		table.insert(list, mods)
	end
	return Modifiers.Aggregate(list)
end

-- Pure-ish roll (exposed for tests / other services)
function DropService:RollTable(dropTable: { any }, luck: number, random: Random?): { { Id: string, Amount: number } }
	local r = random or rng
	local results = {}
	for _, entry in ipairs(dropTable or {}) do
		local chance = math.min(1, (entry.Chance or 0) * (1 + math.max(0, luck)))
		if r:NextNumber() < chance then
			table.insert(results, { Id = entry.Id, Amount = r:NextInteger(entry.Min or 1, entry.Max or entry.Min or 1) })
		end
	end
	return results
end

function DropService:GiveItem(player: Player, itemId: string, amount: number, sourceId: string?, position: Vector3?)
	local def = ItemUtil.Get(itemId)
	if not def then
		return
	end
	local uid = Registry.Get("InventoryService"):AddItem(player, itemId, amount)
	local fx = Registry.Get("FXService")
	if not uid then
		fx:Notify(player, "Error", "Inventory full! Lost drop: " .. def.DisplayName)
		return
	end
	local rarity = def.Rarity or "Common"
	fx:Notify(player, "Drop", string.format("+%d %s", amount, def.DisplayName), { Rarity = rarity, Item = itemId })
	if RarityConfig.IsAtLeast(rarity, "Epic") and position then
		fx:Play(
			"RareDrop",
			{ Position = position, Rarity = rarity, Color = RarityConfig.GetColor(rarity), Target = player.Character },
			position
		)
	end
	if sourceId then
		local data = Registry.Get("PlayerDataService"):Get(player)
		if data and RarityConfig.IsAtLeast(rarity, "Rare") then
			data.BossDrops[itemId] = (data.BossDrops[itemId] or 0) + amount
		end
	end
	if RarityConfig.IsAtLeast(rarity, "Mythic") then
		fx:Notify(
			nil,
			"Server",
			string.format("✦ %s obtained %s %s! ✦", player.DisplayName, string.upper(rarity), def.DisplayName),
			{ Color = RarityConfig.GetColor(rarity) }
		)
	end
	self.ItemDropped:Fire(player, itemId, amount, sourceId)
end

function DropService:GrantRewards(player: Player, rewards, sourceName: string?)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	if not data or not rewards then
		return
	end
	local mods = playerMods(player)
	if rewards.Exp or rewards.ExpLevelMultiplier then
		local exp = rewards.Exp or 0
		if rewards.ExpLevelMultiplier then
			exp += Progression.ExpToNext(data.Level) * 0.25 * rewards.ExpLevelMultiplier
		end
		dataService:AddExp(player, math.floor(exp * (1 + mods.ExpBonus + DropService.GlobalExp)))
	end
	if rewards.Gold then
		dataService:AddCurrency(player, "Gold", math.floor(rewards.Gold * (1 + mods.GoldBonus)))
	end
	if rewards.Gems then
		dataService:AddCurrency(player, "Gems", rewards.Gems)
	end
	if rewards.Spins then
		dataService:AddCurrency(player, "Spins", rewards.Spins)
	end
	if rewards.TraitRolls then
		dataService:AddCurrency(player, "TraitRolls", rewards.TraitRolls)
	end
	if rewards.Items then
		for itemId, amount in pairs(rewards.Items) do
			self:GiveItem(player, itemId, amount, nil, nil)
		end
	end
	if rewards.Title then
		self:GrantTitle(player, rewards.Title)
	end
	if rewards.PowerMastery then
		Registry.Get("PowerService"):AddEquippedMastery(player, rewards.PowerMastery)
	end
	if sourceName then
		Registry.Get("FXService"):Notify(player, "Reward", sourceName)
	end
end

function DropService:GrantTitle(player: Player, titleId: string)
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	local def = Titles.Get(titleId)
	if not data or not def or data.Titles.Owned[titleId] then
		return
	end
	data.Titles.Owned[titleId] = true
	dataService:Replicate(player, "Titles")
	Registry.Get("FXService"):Notify(player, "Unlock", "New title unlocked: " .. def.DisplayName)
end

-- Called by EnemyService when an enemy/boss dies.
function DropService:HandleKill(entity, def)
	local maxHealth = math.max(1, entity.Humanoid.MaxHealth)
	local isBoss = def.IsBoss == true
	local threshold = isBoss and 0.03 or 0.1
	local eligible = {}
	local topPlayer, topDamage = nil, 0
	for player, damage in pairs(entity.DamageContrib) do
		if player.Parent then
			if damage / maxHealth >= threshold then
				table.insert(eligible, player)
			end
			if damage > topDamage then
				topPlayer, topDamage = player, damage
			end
		end
	end
	if #eligible == 0 and topPlayer then
		table.insert(eligible, topPlayer)
	end
	local level = entity.Level
	local position = entity.Root.Position
	local dataService = Registry.Get("PlayerDataService")
	local expMult = isBoss and 14 or 1
	local goldMult = isBoss and 12 or 1
	for _, player in ipairs(eligible) do
		local data = dataService:Get(player)
		if data then
			local mods = playerMods(player)
			-- Reduced rewards when heavily out-levelling the enemy (anti-farming low zones).
			local levelGap = data.Level - level
			local gapFactor = levelGap > 15 and math.max(0.1, 1 - (levelGap - 15) * 0.05) or 1
			local exp = Progression.EnemyExp(level, expMult) * gapFactor * (1 + mods.ExpBonus + DropService.GlobalExp)
			dataService:AddExp(player, math.floor(exp))
			dataService:AddCurrency(player, "Gold", math.floor(Progression.EnemyGold(level, goldMult) * (1 + mods.GoldBonus)))
			Registry.Get("PowerService"):AddEquippedMastery(player, isBoss and 25 or 3)
			local weapon = Registry.Get("WeaponService"):GetEquipped(player)
			if weapon then
				Registry.Get("WeaponService"):AddMastery(player, weapon.Def.Id, isBoss and 20 or 2)
			end
			if isBoss then
				dataService:AddCounter(player, "BossesDefeated", 1)
				data.BossKills[def.Id] = (data.BossKills[def.Id] or 0) + 1
				dataService:Replicate(player, "BossKills")
				if def.GemReward then
					dataService:AddCurrency(player, "Gems", def.GemReward)
				end
				if def.Title then
					self:GrantTitle(player, def.Title)
				end
			else
				dataService:AddCounter(player, "EnemiesDefeated", 1)
			end
			local luck = mods.Luck + DropService.GlobalLuck
			for _, drop in ipairs(self:RollTable(def.Drops, luck)) do
				self:GiveItem(player, drop.Id, drop.Amount, isBoss and def.Id or nil, position)
			end
			Registry.Get("QuestService"):OnEvent(player, { Kind = isBoss and "Boss" or "Kill", Target = def.Id, Amount = 1 })
		end
	end
end

function DropService:Init() end

return DropService
