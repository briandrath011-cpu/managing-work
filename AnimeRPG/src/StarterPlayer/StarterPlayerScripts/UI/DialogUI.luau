--[[
	DialogUI (ModuleScript) -> ScreenGui "QuestUI"
	Location: StarterPlayer.StarterPlayerScripts.UI.DialogUI

	PHASE 12 / 17 - NPC dialog: quest offers (accept / turn in), shop, crafting,
	style trainer, weapon/power trainers, spin oracle, trait mystic.
	Also draws the quest icons above NPCs: "!" = quest available, "?" = ready to turn in.
	Remotes: DialogOpen (server -> client), QuestAction / ShopAction / CraftAction (requests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local Modules = ReplicatedStorage.Modules
local QuestCatalog = require(Modules.Quests.QuestCatalog)
local QuestLogic = require(Modules.Quests.QuestLogic)
local NPCCatalog = require(Modules.NPCs.NPCCatalog)
local ItemUtil = require(Modules.Items.ItemUtil)
local Recipes = require(Modules.Items.Recipes)
local FightingStyles = require(Modules.Combat.FightingStyles)
local Format = require(Modules.Shared.Format)
local Net = require(Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local QuestsTab = require(script.Parent.Tabs.Quests)

local DialogUI = {}

local T = UIKit.Theme
local screen: ScreenGui
local window: Frame
local body: Frame
local titleLabel: TextLabel
local currentNpc: string? = nil
local currentPayload = nil

local function toast(text, kind)
	ClientRegistry.Get("HUD"):Toast(text, kind or "Error")
end

local function clearBody()
	UIKit.Clear(body)
	local scroll = UIKit.Scroll(body)
	UIKit.List(scroll, nil, 8)
	UIKit.Padding(scroll, 4)
	return scroll
end

function DialogUI:Close()
	window.Visible = false
	currentNpc = nil
	ClientRegistry.Get("InputController").GameplayBlocked = false
end

local function reopen()
	-- Re-request the dialog so quest states refresh after an action.
	if currentNpc and currentPayload then
		task.delay(0.2, function()
			if currentNpc then
				DialogUI:ShowMain()
			end
		end)
	end
end

function DialogUI:ShowQuest(questId: string, state: string)
	local def = QuestCatalog.Get(questId)
	if not def then
		return
	end
	local list = clearBody()
	UIKit.Label(list, def.Name, { TextSize = 22, Font = T.FontBlack, TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 28) })
	local text = state == "Ready" and (def.Dialog and def.Dialog.Complete) or (def.Dialog and def.Dialog.Offer) or ""
	UIKit.Label(list, '"' .. text .. '"', { TextSize = 16, Font = T.Font, Size = UDim2.new(1, 0, 0, 60) })
	for _, objective in ipairs(def.Objectives) do
		UIKit.Label(list, "• " .. QuestLogic.Describe(objective, 0, objective.Count or 1), { TextSize = 14, TextColor3 = T.SubText })
	end
	UIKit.Label(
		list,
		"Rewards: " .. QuestsTab.RewardText(def.Rewards),
		{ TextSize = 14, TextColor3 = T.Good, Size = UDim2.new(1, 0, 0, 40) }
	)
	local row = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = list })
	UIKit.List(row, Enum.FillDirection.Horizontal, 10)
	if state == "Available" then
		UIKit.Button(row, "Accept", { Size = UDim2.fromOffset(160, 40), BackgroundColor3 = T.Good }, function()
			local ok, err = Net.Invoke("QuestAction", "Accept", questId, currentNpc)
			if ok then
				DialogUI:Close()
			elseif err then
				toast(err)
			end
		end)
	elseif state == "Ready" then
		UIKit.Button(row, "Complete Quest", { Size = UDim2.fromOffset(180, 40), BackgroundColor3 = T.Gold }, function()
			local ok, err = Net.Invoke("QuestAction", "TurnIn", questId, currentNpc)
			if ok then
				reopen()
			elseif err then
				toast(err)
			end
		end)
	end
	UIKit.Button(row, "Back", { Size = UDim2.fromOffset(120, 40) }, function()
		DialogUI:ShowMain()
	end)
end

function DialogUI:ShowShop()
	local ok, entries = Net.Invoke("ShopAction", "GetShop", currentNpc)
	local list = clearBody()
	UIKit.Button(list, "← Back", { Size = UDim2.fromOffset(120, 34) }, function()
		DialogUI:ShowMain()
	end)
	if not ok then
		UIKit.Label(list, tostring(entries))
		return
	end
	for index, entry in ipairs(entries) do
		local def = ItemUtil.Get(entry.Item)
		if def then
			local row = UIKit.Panel(list, { Size = UDim2.new(1, -8, 0, 52), LayoutOrder = index + 1 })
			UIKit.Label(
				row,
				def.DisplayName,
				{ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -330, 0, 22), TextColor3 = UIKit.RarityColor(def.Rarity) }
			)
			UIKit.Label(
				row,
				def.Description or "",
				{
					Position = UDim2.fromOffset(12, 26),
					Size = UDim2.new(1, -330, 0, 20),
					TextSize = 12,
					Font = T.Font,
					TextColor3 = T.SubText,
				}
			)
			UIKit.Label(
				row,
				string.format("%s %s", Format.Commas(entry.Price), entry.Currency),
				{
					Position = UDim2.new(1, -318, 0, 14),
					Size = UDim2.fromOffset(120, 24),
					TextColor3 = entry.Currency == "Gems" and T.Gem or T.Gold,
					TextXAlignment = Enum.TextXAlignment.Right,
				}
			)
			for i, amount in ipairs(def.Stackable and { 1, 5 } or { 1 }) do
				UIKit.Button(
					row,
					"Buy x" .. amount,
					{
						Position = UDim2.new(1, -190 + (i - 1) * 90, 0, 9),
						Size = UDim2.fromOffset(84, 34),
						TextSize = 13,
						BackgroundColor3 = T.Accent,
					},
					function()
						local bought, err = Net.Invoke("ShopAction", "Buy", currentNpc, index, amount)
						if bought then
							toast("Bought " .. def.DisplayName .. " x" .. amount, "Reward")
						elseif err then
							toast(err)
						end
					end
				)
			end
		end
	end
end

function DialogUI:ShowCraft(station: string)
	local data = ClientRegistry.Get("DataController"):Get()
	local list = clearBody()
	UIKit.Button(list, "← Back", { Size = UDim2.fromOffset(120, 34) }, function()
		DialogUI:ShowMain()
	end)
	for index, recipe in ipairs(Recipes) do
		if recipe.Station == station or recipe.Station == "Any" then
			local result = ItemUtil.Get(recipe.Result)
			local row = UIKit.Panel(list, { Size = UDim2.new(1, -8, 0, 74), LayoutOrder = index + 1 })
			UIKit.Label(
				row,
				string.format("%s x%d", result and result.DisplayName or recipe.Result, recipe.Amount),
				{
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.new(1, -150, 0, 22),
					TextColor3 = UIKit.RarityColor(result and result.Rarity),
				}
			)
			local parts = {}
			local canCraft = data and data.Gold >= recipe.Gold
			for itemId, amount in pairs(recipe.Materials) do
				local have = data and ItemUtil.CountInInventory(data.Inventory, itemId) or 0
				local def = ItemUtil.Get(itemId)
				table.insert(parts, string.format("%s %d/%d", def and def.DisplayName or itemId, have, amount))
				if have < amount then
					canCraft = false
				end
			end
			table.insert(parts, Format.Commas(recipe.Gold) .. " Gold")
			UIKit.Label(
				row,
				table.concat(parts, "  •  "),
				{
					Position = UDim2.fromOffset(12, 28),
					Size = UDim2.new(1, -150, 0, 40),
					TextSize = 12,
					Font = T.Font,
					TextColor3 = canCraft and T.Good or T.SubText,
				}
			)
			UIKit.Button(
				row,
				"Craft",
				{
					Position = UDim2.new(1, -130, 0, 18),
					Size = UDim2.fromOffset(118, 38),
					BackgroundColor3 = canCraft and T.Good or T.PanelLight,
				},
				function()
					local ok, err = Net.Invoke("CraftAction", "Craft", recipe.Id, currentNpc)
					if ok then
						DialogUI:ShowCraft(station)
					elseif err then
						toast(err)
					end
				end
			)
		end
	end
end

function DialogUI:ShowStyles()
	local data = ClientRegistry.Get("DataController"):Get()
	local list = clearBody()
	UIKit.Button(list, "← Back", { Size = UDim2.fromOffset(120, 34) }, function()
		DialogUI:ShowMain()
	end)
	local ids = {}
	for id in pairs(FightingStyles) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return FightingStyles[a].LevelRequired < FightingStyles[b].LevelRequired
	end)
	for index, id in ipairs(ids) do
		local style = FightingStyles[id]
		local learned = data and data.FightingStyles[id]
		local row = UIKit.Panel(list, { Size = UDim2.new(1, -8, 0, 60), LayoutOrder = index + 1 })
		UIKit.Label(
			row,
			style.DisplayName,
			{ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -180, 0, 22), TextColor3 = style.Color }
		)
		UIKit.Label(
			row,
			string.format("%s  (Lv. %d, %s Gold)", style.Description, style.LevelRequired, Format.Commas(style.Cost)),
			{ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -180, 0, 28), TextSize = 12, Font = T.Font, TextColor3 = T.SubText }
		)
		UIKit.Button(
			row,
			learned and "Equip" or "Learn",
			{
				Position = UDim2.new(1, -160, 0, 12),
				Size = UDim2.fromOffset(148, 36),
				BackgroundColor3 = learned and T.PanelLight or T.Accent,
			},
			function()
				local ok, err
				if learned then
					ok, err = Net.Invoke("ShopAction", "EquipStyle", id)
				else
					ok, err = Net.Invoke("ShopAction", "BuyStyle", currentNpc, id)
				end
				if ok then
					DialogUI:ShowStyles()
				elseif err then
					toast(err)
				end
			end
		)
	end
end

function DialogUI:ShowMain()
	local payload = currentPayload
	if not payload then
		return
	end
	titleLabel.Text = payload.Name
	local list = clearBody()
	UIKit.Label(list, '"' .. (payload.Greeting or "...") .. '"', { TextSize = 17, Font = T.Font, Size = UDim2.new(1, 0, 0, 50) })
	local data = ClientRegistry.Get("DataController"):Get()
	local function countItem(id)
		return data and ItemUtil.CountInInventory(data.Inventory, id) or 0
	end
	for _, quest in ipairs(payload.Quests or {}) do
		local def = QuestCatalog.Get(quest.Id)
		if def then
			-- Recompute state locally so the list is fresh after actions.
			local state = quest.State
			if data then
				local active = data.Quests.Active[quest.Id]
				if active then
					state = QuestLogic.IsComplete(def, active.Progress, countItem) and (def.TurnIn == currentNpc and "Ready" or "Active")
						or "Active"
				elseif data.Quests.Completed[quest.Id] and not def.Repeatable then
					state = "Done"
				end
			end
			if state ~= "Done" then
				local prefix = ({ Available = "[!] ", Ready = "[?] ", Active = "[...] ", Locked = "[🔒] " })[state] or ""
				local color = ({ Available = T.Gold, Ready = T.Good, Active = T.SubText, Locked = T.SubText })[state] or T.Text
				UIKit.Button(
					list,
					prefix .. def.Name .. (state == "Locked" and ("  (Lv. " .. def.LevelRequired .. ")") or ""),
					{ Size = UDim2.new(1, -8, 0, 40), TextColor3 = color },
					function()
						if state == "Locked" then
							toast("Requires level " .. def.LevelRequired .. (def.Prerequisite and " and an earlier quest" or ""))
							return
						end
						DialogUI:ShowQuest(quest.Id, state)
					end
				)
			end
		end
	end
	local roles = payload.Roles or {}
	local function has(role)
		return table.find(roles, role) ~= nil
	end
	if payload.HasShop then
		UIKit.Button(list, "🛒 Shop", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent }, function()
			DialogUI:ShowShop()
		end)
	end
	if has("Crafter") and payload.CraftStation then
		UIKit.Button(list, "⚒ Crafting", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent }, function()
			DialogUI:ShowCraft(payload.CraftStation)
		end)
	end
	if has("StyleTrainer") then
		UIKit.Button(list, "🥋 Learn Fighting Styles", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent }, function()
			DialogUI:ShowStyles()
		end)
	end
	for _, trainer in ipairs({ { Role = "WeaponTrainer", Kind = "Weapon" }, { Role = "PowerTrainer", Kind = "Power" } }) do
		if has(trainer.Role) then
			UIKit.Button(
				list,
				"📈 Train " .. trainer.Kind .. " Mastery (+60)",
				{ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent },
				function()
					local ok, result = Net.Invoke("ShopAction", "Train", currentNpc, trainer.Kind)
					if ok then
						toast(string.format("Training complete! (-%s Gold)", Format.Commas(result)), "Reward")
					elseif result then
						toast(result)
					end
				end
			)
		end
	end
	if has("SpinOracle") then
		UIKit.Button(list, "✦ Spin for Powers", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent2 }, function()
			DialogUI:Close()
			ClientRegistry.Get("SpinMenu"):Open()
		end)
	end
	if has("TraitMystic") then
		UIKit.Button(list, "🔮 Roll Traits", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = T.Accent2 }, function()
			DialogUI:Close()
			ClientRegistry.Get("Menu"):Open("Character")
		end)
	end
	if has("DungeonKeeper") then
		UIKit.Label(
			list,
			"Dungeon gates are marked on your map (▣). Stand at a gate and interact to form a party.",
			{ TextSize = 13, TextColor3 = T.SubText, Size = UDim2.new(1, 0, 0, 40) }
		)
	end
	if has("RaidHerald") then
		UIKit.Label(
			list,
			"The raid gate is right behind me. Up to 8 players can join a raid.",
			{ TextSize = 13, TextColor3 = T.SubText, Size = UDim2.new(1, 0, 0, 40) }
		)
	end
	UIKit.Button(list, "Goodbye", { Size = UDim2.new(1, -8, 0, 38) }, function()
		DialogUI:Close()
	end)
end

-- QUEST ICONS ABOVE NPCs ------------------------------------------------------------------------------

local icons: { [Model]: TextLabel } = {}

local function npcState(npcId: string): string?
	local data = ClientRegistry.Get("DataController"):Get()
	local def = NPCCatalog[npcId]
	if not data or not def then
		return nil
	end
	local night = Workspace:GetAttribute("TimePhase") == "Night"
	local function countItem(id)
		return ItemUtil.CountInInventory(data.Inventory, id)
	end
	for questId, active in pairs(data.Quests.Active) do
		local quest = QuestCatalog.Get(questId)
		if quest and quest.TurnIn == npcId and QuestLogic.IsComplete(quest, active.Progress, countItem) then
			return "Ready"
		end
	end
	for _, questId in ipairs(def.Quests) do
		local quest = QuestCatalog.Get(questId)
		if quest and QuestLogic.IsAvailable(quest, data, night) then
			return "Available"
		end
	end
	return nil
end

local function refreshIcons()
	local folder = Workspace:FindFirstChild("NPCs")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		local npcId = model:GetAttribute("NpcId")
		local head = model:FindFirstChild("Head") :: BasePart?
		if npcId and head then
			local label = icons[model]
			if not label then
				local gui = Instance.new("BillboardGui")
				gui.Name = "QuestIcon"
				gui.Size = UDim2.fromOffset(40, 40)
				gui.StudsOffset = Vector3.new(0, 4.4, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 120
				gui.Parent = head
				local newLabel = Instance.new("TextLabel")
				newLabel.BackgroundTransparency = 1
				newLabel.Size = UDim2.fromScale(1, 1)
				newLabel.Font = Enum.Font.GothamBlack
				newLabel.TextScaled = true
				newLabel.TextStrokeTransparency = 0
				newLabel.Parent = gui
				icons[model] = newLabel
				label = newLabel
				model.Destroying:Once(function()
					icons[model] = nil
				end)
			end
			local state = npcState(npcId)
			local roles = model:GetAttribute("Roles") or ""
			if state == "Ready" then
				label.Text = "?"
				label.TextColor3 = T.Gold
			elseif state == "Available" then
				label.Text = "!"
				label.TextColor3 = T.Gold
			elseif string.find(roles, "Merchant") then
				label.Text = "$"
				label.TextColor3 = T.Good
			elseif string.find(roles, "Crafter") then
				label.Text = "⚒"
				label.TextColor3 = Color3.fromRGB(200, 200, 220)
			else
				label.Text = ""
			end
		end
	end
end

function DialogUI:Init()
	screen = UIKit.Screen("QuestUI", 22)
	local content, _close, title
	window, content, _close, title = UIKit.Window(screen, "NPC", UDim2.fromOffset(640, 520), function()
		DialogUI:Close()
	end)
	titleLabel = title
	body = content
	Net.Event("DialogOpen").OnClientEvent:Connect(function(npcId, payload)
		currentNpc = npcId
		currentPayload = payload
		UIKit.Open(window)
		ClientRegistry.Get("InputController").GameplayBlocked = true
		DialogUI:ShowMain()
	end)
	ClientRegistry.Get("DataController").Changed:Connect(function(key)
		if key == "Quests" or key == "Inventory" or key == "Level" then
			refreshIcons()
		end
	end)
end

function DialogUI:Start()
	while true do
		refreshIcons()
		task.wait(3)
	end
end

return DialogUI
