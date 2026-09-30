--[[
	Achievements tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Achievements
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local Achievements = require(ReplicatedStorage.Modules.Progression.Achievements)
local PowerRegistry = require(ReplicatedStorage.Modules.Powers.PowerRegistry)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local TableUtil = require(ReplicatedStorage.Modules.Shared.TableUtil)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local AchievementsTab = {}
AchievementsTab.__index = AchievementsTab

local T = UIKit.Theme

local function progress(achievement, data): number
	if achievement.Kind == "Counter" then
		return data.Counters[achievement.Key] or 0
	elseif achievement.Kind == "Level" then
		return data.Level
	elseif achievement.Kind == "Boss" then
		return data.BossKills[achievement.Key] or 0
	elseif achievement.Kind == "Regions" then
		return TableUtil.Count(data.Discovered.Regions)
	elseif achievement.Kind == "PowerRarity" then
		for _, owned in pairs(data.Powers.Owned) do
			local def = PowerRegistry.Get(owned.Id)
			if def and RarityConfig.IsAtLeast(def.Rarity, achievement.Key) then
				return 1
			end
		end
	end
	return 0
end

function AchievementsTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, AchievementsTab)
	self.Header = UIKit.Label(frame, "", { Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Font = T.FontBlack, TextColor3 = T.Gold })
	self.List = UIKit.Scroll(frame, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30) })
	UIKit.Grid(self.List, UDim2.new(0.5, -8, 0, 74), 8)
	return self
end

function AchievementsTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	UIKit.Clear(self.List)
	local unlocked = 0
	for index, achievement in ipairs(Achievements) do
		local done = data.Achievements[achievement.Id] ~= nil
		if done then
			unlocked += 1
		end
		local card = UIKit.Panel(self.List, { LayoutOrder = done and index + 1000 or index })
		UIKit.Label(
			card,
			(done and "🏆 " or "") .. achievement.Name,
			{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextColor3 = done and T.Gold or T.Text }
		)
		UIKit.Label(
			card,
			achievement.Description,
			{ Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 18), TextSize = 12, Font = T.Font, TextColor3 = T.SubText }
		)
		local _, setBar =
			UIKit.Bar(card, done and T.Good or T.Accent, { Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 14) })
		local value = math.min(progress(achievement, data), achievement.Goal)
		setBar(value / achievement.Goal, string.format("%d / %d", value, achievement.Goal))
	end
	self.Header.Text = string.format("Achievements  %d / %d", unlocked, #Achievements)
end

return AchievementsTab
