--[[
	Quests tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Quests
	Active quests (story, side, secret, daily, weekly) with objectives, rewards and abandon.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local QuestCatalog = require(ReplicatedStorage.Modules.Quests.QuestCatalog)
local QuestLogic = require(ReplicatedStorage.Modules.Quests.QuestLogic)
local ItemUtil = require(ReplicatedStorage.Modules.Items.ItemUtil)
local NPCCatalog = require(ReplicatedStorage.Modules.NPCs.NPCCatalog)
local Format = require(ReplicatedStorage.Modules.Shared.Format)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local QuestsTab = {}
QuestsTab.__index = QuestsTab

local T = UIKit.Theme
local TYPE_COLORS = {
	Daily = Color3.fromRGB(120, 220, 255),
	Weekly = Color3.fromRGB(200, 150, 255),
	Secret = Color3.fromRGB(20, 255, 200),
	Boss = Color3.fromRGB(255, 110, 110),
}

function QuestsTab.RewardText(rewards): string
	local parts = {}
	if rewards.Exp then
		table.insert(parts, Format.Short(rewards.Exp) .. " EXP")
	end
	if rewards.ExpLevelMultiplier then
		table.insert(parts, "Bonus EXP")
	end
	if rewards.Gold then
		table.insert(parts, Format.Short(rewards.Gold) .. " Gold")
	end
	if rewards.Gems then
		table.insert(parts, rewards.Gems .. " Gems")
	end
	if rewards.Spins then
		table.insert(parts, rewards.Spins .. " Spins")
	end
	if rewards.TraitRolls then
		table.insert(parts, rewards.TraitRolls .. " Trait Roll")
	end
	for id, amount in pairs(rewards.Items or {}) do
		local def = ItemUtil.Get(id)
		table.insert(parts, string.format("%dx %s", amount, def and def.DisplayName or id))
	end
	return table.concat(parts, ", ")
end

function QuestsTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, QuestsTab)
	self.Header = UIKit.Label(frame, "", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = T.SubText, TextSize = 13 })
	self.List = UIKit.Scroll(frame, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28) })
	UIKit.List(self.List, nil, 8)
	return self
end

function QuestsTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	local completed = 0
	for _ in pairs(data.Quests.Completed) do
		completed += 1
	end
	local now = os.time()
	local dayLeft = 86400 - now % 86400
	self.Header.Text = string.format("Completed quests: %d   •   Daily reset in %s", completed, Format.Time(dayLeft))
	UIKit.Clear(self.List)
	local function countItem(id)
		return ItemUtil.CountInInventory(data.Inventory, id)
	end
	local index = 0
	for questId, active in pairs(data.Quests.Active) do
		local def = QuestCatalog.Get(questId)
		if def then
			index += 1
			local height = 70 + #def.Objectives * 18
			local card = UIKit.Panel(
				self.List,
				{
					Size = UDim2.new(1, -8, 0, height),
					LayoutOrder = def.Type == "Daily" and 100 + index or (def.Type == "Weekly" and 200 + index or index),
				}
			)
			local done = QuestLogic.IsComplete(def, active.Progress, countItem)
			UIKit.Label(
				card,
				def.Name,
				{
					Position = UDim2.fromOffset(12, 6),
					Size = UDim2.new(1, -140, 0, 22),
					TextSize = 17,
					Font = T.FontBlack,
					TextColor3 = done and T.Good or T.Text,
				}
			)
			UIKit.Label(
				card,
				def.Type,
				{
					Position = UDim2.new(1, -240, 0, 8),
					Size = UDim2.fromOffset(100, 18),
					TextSize = 12,
					TextColor3 = TYPE_COLORS[def.Type] or T.SubText,
					TextXAlignment = Enum.TextXAlignment.Right,
				}
			)
			for i, objective in ipairs(def.Objectives) do
				local have, need = QuestLogic.ObjectiveProgress(objective, active.Progress[i], countItem)
				UIKit.Label(
					card,
					"• " .. QuestLogic.Describe(objective, have, need),
					{
						Position = UDim2.fromOffset(16, 30 + (i - 1) * 18),
						Size = UDim2.new(1, -32, 0, 18),
						TextSize = 13,
						Font = T.Font,
						TextColor3 = have >= need and T.Good or T.Text,
					}
				)
			end
			local turnIn = def.TurnIn and NPCCatalog[def.TurnIn]
			local footer = "Rewards: " .. QuestsTab.RewardText(def.Rewards)
			if turnIn and def.Type ~= "Daily" and def.Type ~= "Weekly" then
				footer ..= "   •   Turn in: " .. turnIn.DisplayName
			end
			UIKit.Label(
				card,
				footer,
				{ Position = UDim2.fromOffset(12, height - 26), Size = UDim2.new(1, -140, 0, 20), TextSize = 12, TextColor3 = T.Gold }
			)
			if def.Type ~= "Daily" and def.Type ~= "Weekly" then
				UIKit.Button(
					card,
					"Abandon",
					{ Position = UDim2.new(1, -120, 0, 6), Size = UDim2.fromOffset(108, 30), TextSize = 13, BackgroundColor3 = T.Bad },
					function()
						local ok, err = Net.Invoke("QuestAction", "Abandon", questId)
						if not ok and err then
							ClientRegistry.Get("HUD"):Toast(err, "Error")
						end
					end
				)
			end
		end
	end
	if index == 0 then
		UIKit.Label(self.List, "No active quests. Talk to NPCs with a ! above their head.", { TextColor3 = T.SubText })
	end
end

return QuestsTab
