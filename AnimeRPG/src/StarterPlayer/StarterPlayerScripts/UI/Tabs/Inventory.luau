--[[
	Inventory tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Inventory
	PHASE 10 - Categories (Weapons, Armor, Accessories, Materials, Consumables, Cosmetics),
	search, sort (Rarity / Name / Newest / Amount), equip / unequip / use / lock / favorite / delete.
	All actions are server requests (InventoryAction).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local ItemUtil = require(ReplicatedStorage.Modules.Items.ItemUtil)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local Modifiers = require(ReplicatedStorage.Modules.Combat.Modifiers)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local InventoryTab = {}
InventoryTab.__index = InventoryTab

local T = UIKit.Theme
local FILTERS = {
	{ Name = "All", Categories = nil },
	{ Name = "Weapons", Categories = { Weapon = true } },
	{ Name = "Armor", Categories = { Armor = true, Head = true } },
	{ Name = "Accessories", Categories = { Accessory = true } },
	{ Name = "Materials", Categories = { Material = true } },
	{ Name = "Consumables", Categories = { Consumable = true } },
	{ Name = "Cosmetics", Categories = { Cosmetic = true } },
}
local SORTS = { "Rarity", "Name", "Newest", "Amount" }

local function toast(text, kind)
	ClientRegistry.Get("HUD"):Toast(text, kind or "Error")
end

local function request(action, a, b)
	local ok, err = Net.Invoke("InventoryAction", action, a, b)
	if not ok and err then
		toast(err)
	end
	return ok
end

function InventoryTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame, Filter = 1, Sort = 1, Search = "", Selected = nil }, InventoryTab)
	local top = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = frame })
	UIKit.List(top, Enum.FillDirection.Horizontal, 4)
	self.FilterButtons = {}
	for index, filter in ipairs(FILTERS) do
		self.FilterButtons[index] = UIKit.Button(
			top,
			filter.Name,
			{ Size = UDim2.fromOffset(92, 32), TextSize = 13, LayoutOrder = index },
			function()
				self.Filter = index
				self:Refresh()
			end
		)
	end
	local second = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 34), Parent = frame }
	)
	self.SearchBox = UIKit.TextBox(second, "Search items...", { Size = UDim2.fromOffset(240, 32) })
	self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.Search = string.lower(self.SearchBox.Text)
		self:Refresh()
	end)
	self.SortButton = UIKit.Button(
		second,
		"Sort: Rarity",
		{ Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(150, 32), TextSize = 13 },
		function()
			self.Sort = self.Sort % #SORTS + 1
			self:Refresh()
		end
	)
	self.CountLabel = UIKit.Label(
		second,
		"",
		{ Position = UDim2.fromOffset(410, 0), Size = UDim2.fromOffset(200, 32), TextSize = 13, TextColor3 = T.SubText }
	)
	self.Grid = UIKit.Scroll(frame, { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(0.64, 0, 1, -80) })
	UIKit.Grid(self.Grid, UDim2.fromOffset(104, 104), 8)
	UIKit.Padding(self.Grid, 4)
	self.Detail = UIKit.Panel(frame, { Position = UDim2.new(0.66, 0, 0, 80), Size = UDim2.new(0.34, 0, 1, -80) })
	UIKit.Padding(self.Detail, 12)
	return self
end

function InventoryTab:ShowDetail(uid: string?)
	UIKit.Clear(self.Detail)
	local data = ClientRegistry.Get("DataController"):Get()
	local entry = uid and data and data.Inventory[uid]
	if not entry then
		UIKit.Label(self.Detail, "Select an item", { TextColor3 = T.SubText })
		return
	end
	local def = ItemUtil.Get(entry.Id)
	if not def then
		return
	end
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Detail })
	UIKit.List(list, nil, 6)
	UIKit.Label(
		list,
		def.DisplayName,
		{ TextSize = 20, Font = T.FontBlack, TextColor3 = UIKit.RarityColor(def.Rarity), Size = UDim2.new(1, 0, 0, 26) }
	)
	UIKit.Label(list, string.format("%s  •  %s", def.Rarity, def.Class or def.Category), { TextSize = 13, TextColor3 = T.SubText })
	UIKit.Label(list, def.Description or "", { TextSize = 13, Font = T.Font, Size = UDim2.new(1, 0, 0, 36) })
	if def.Damage then
		UIKit.Label(list, "Damage: " .. def.Damage, { TextSize = 14 })
	end
	if def.Defense then
		UIKit.Label(list, "Defense: " .. def.Defense, { TextSize = 14 })
	end
	if def.LevelRequired then
		UIKit.Label(
			list,
			"Requires level " .. def.LevelRequired,
			{ TextSize = 13, TextColor3 = data.Level >= def.LevelRequired and T.Good or T.Bad }
		)
	end
	for _, line in ipairs(Modifiers.Describe(def.Modifiers)) do
		UIKit.Label(list, line, { TextSize = 13, TextColor3 = T.Good })
	end
	if def.Passive then
		UIKit.Label(list, "Passive: " .. def.Passive.Name, { TextSize = 13, TextColor3 = T.Gold })
		UIKit.Label(list, def.Passive.Description, { TextSize = 12, Font = T.Font, Size = UDim2.new(1, 0, 0, 30) })
		for _, line in ipairs(Modifiers.Describe(def.Passive.Modifiers)) do
			UIKit.Label(list, line, { TextSize = 12, TextColor3 = T.Good })
		end
	end
	if entry.Amount > 1 then
		UIKit.Label(list, "Amount: " .. entry.Amount, { TextSize = 14 })
	end
	local buttons = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = list })
	UIKit.Grid(buttons, UDim2.new(0.5, -4, 0, 34), 6)
	local equipped = false
	for slot, value in pairs(data.Equipment) do
		if value == uid then
			equipped = slot
		end
	end
	local equipable = def.Category == "Weapon" or def.Category == "Armor" or def.Category == "Head" or def.Category == "Accessory"
	if equipable then
		if equipped then
			UIKit.Button(buttons, "Unequip", { BackgroundColor3 = T.PanelLight }, function()
				request("Unequip", equipped)
			end)
		else
			UIKit.Button(buttons, "Equip", { BackgroundColor3 = T.Accent }, function()
				request("Equip", uid)
			end)
		end
	elseif def.Category == "Consumable" then
		UIKit.Button(buttons, "Use", { BackgroundColor3 = T.Good }, function()
			request("Use", uid)
		end)
	elseif def.Category == "Cosmetic" then
		local active = data.Cosmetics.Aura == entry.Id
		UIKit.Button(buttons, active and "Remove Aura" or "Wear Aura", { BackgroundColor3 = T.Accent }, function()
			request("EquipCosmetic", active and "" or uid)
		end)
	end
	UIKit.Button(buttons, entry.Locked and "Unlock" or "Lock", {}, function()
		request("Lock", uid)
	end)
	UIKit.Button(buttons, entry.Favorite and "Unfavorite" or "Favorite", {}, function()
		request("Favorite", uid)
	end)
	UIKit.Button(buttons, "Delete", { BackgroundColor3 = T.Bad }, function()
		if request("Delete", uid, entry.Amount) then
			self.Selected = nil
		end
	end)
end

function InventoryTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	for index, button in ipairs(self.FilterButtons) do
		button.BackgroundColor3 = index == self.Filter and T.Accent or T.PanelLight
	end
	self.SortButton.Text = "Sort: " .. SORTS[self.Sort]
	local filter = FILTERS[self.Filter].Categories
	local items = {}
	local total = 0
	for uid, entry in pairs(data.Inventory) do
		total += 1
		local def = ItemUtil.Get(entry.Id)
		if
			def
			and (not filter or filter[def.Category])
			and (self.Search == "" or string.find(string.lower(def.DisplayName), self.Search, 1, true))
		then
			table.insert(items, { Uid = uid, Entry = entry, Def = def })
		end
	end
	local sort = SORTS[self.Sort]
	table.sort(items, function(a, b)
		if a.Entry.Favorite ~= b.Entry.Favorite then
			return a.Entry.Favorite == true
		end
		if sort == "Name" then
			return a.Def.DisplayName < b.Def.DisplayName
		elseif sort == "Newest" then
			return (a.Entry.Obtained or 0) > (b.Entry.Obtained or 0)
		elseif sort == "Amount" then
			return a.Entry.Amount > b.Entry.Amount
		end
		local ra, rb = RarityConfig.Rank[a.Def.Rarity] or 0, RarityConfig.Rank[b.Def.Rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.Def.DisplayName < b.Def.DisplayName
	end)
	self.CountLabel.Text = string.format("%d items", total)
	UIKit.Clear(self.Grid)
	local equippedSet = {}
	for _, value in pairs(data.Equipment) do
		equippedSet[value] = true
	end
	for index, item in ipairs(items) do
		local color = UIKit.RarityColor(item.Def.Rarity)
		local card = UIKit.Button(self.Grid, "", { LayoutOrder = index, BackgroundColor3 = T.PanelDark }, function()
			self.Selected = item.Uid
			self:ShowDetail(item.Uid)
		end)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
			stroke.Transparency = 0.1
			stroke.Thickness = self.Selected == item.Uid and 3 or 1.5
		end
		local swatch = UIKit.New("Frame", {
			BackgroundColor3 = item.Def.Color or color,
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.new(0.5, -18, 0, 8),
			Parent = card,
		})
		UIKit.Corner(swatch, 8)
		UIKit.Gradient(swatch, (item.Def.Color or color):Lerp(Color3.new(1, 1, 1), 0.3), item.Def.Color or color, 45)
		UIKit.Label(card, item.Def.DisplayName, {
			Position = UDim2.fromOffset(4, 48),
			Size = UDim2.new(1, -8, 0, 32),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
		})
		local badges = ""
		if equippedSet[item.Uid] then
			badges ..= "E "
		end
		if item.Entry.Locked then
			badges ..= "🔒"
		end
		if item.Entry.Favorite then
			badges ..= "★"
		end
		UIKit.Label(card, badges, { Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 14), TextSize = 11, TextColor3 = T.Gold })
		if item.Entry.Amount > 1 then
			UIKit.Label(card, "x" .. item.Entry.Amount, {
				Position = UDim2.new(0, 4, 1, -18),
				Size = UDim2.new(1, -8, 0, 14),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end
	self:ShowDetail(self.Selected)
end

return InventoryTab
