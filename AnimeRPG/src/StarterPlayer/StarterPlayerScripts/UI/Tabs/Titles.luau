--[[
	Titles tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Titles
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local Titles = require(ReplicatedStorage.Modules.Progression.Titles)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local TitlesTab = {}
TitlesTab.__index = TitlesTab

local T = UIKit.Theme

function TitlesTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, TitlesTab)
	self.List = UIKit.Scroll(frame)
	UIKit.Grid(self.List, UDim2.new(0.5, -8, 0, 60), 8)
	return self
end

function TitlesTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	UIKit.Clear(self.List)
	local ids = {}
	for id in pairs(Titles.List) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ownedA, ownedB = data.Titles.Owned[a] == true, data.Titles.Owned[b] == true
		if ownedA ~= ownedB then
			return ownedA
		end
		return (RarityConfig.Rank[Titles.List[a].Rarity] or 0) > (RarityConfig.Rank[Titles.List[b].Rarity] or 0)
	end)
	for index, id in ipairs(ids) do
		local def = Titles.List[id]
		local owned = data.Titles.Owned[id] == true
		local equipped = data.Titles.Equipped == id
		local card = UIKit.Panel(self.List, { LayoutOrder = index })
		UIKit.Label(card, def.DisplayName, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -120, 0, 22),
			TextColor3 = owned and UIKit.RarityColor(def.Rarity) or T.SubText,
		})
		UIKit.Label(
			card,
			owned and def.Rarity or ("Locked: " .. def.Source),
			{ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -120, 0, 22), TextSize = 12, Font = T.Font, TextColor3 = T.SubText }
		)
		if owned then
			UIKit.Button(card, equipped and "Unequip" or "Equip", {
				Position = UDim2.new(1, -106, 0, 12),
				Size = UDim2.fromOffset(96, 34),
				BackgroundColor3 = equipped and T.Good or T.Accent,
			}, function()
				local ok, err = Net.Invoke("ProfileAction", "EquipTitle", equipped and "" or id)
				if not ok and err then
					ClientRegistry.Get("HUD"):Toast(err, "Error")
				end
			end)
		end
	end
end

return TitlesTab
