--[[
	Powers tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Powers
	Equipped power (passive, skills + mastery unlocks, mastery bar), Power Storage
	(equip / lock / delete), storage upgrade and pity counters. Opens the Spin menu.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent.Parent

local PowerRegistry = require(ReplicatedStorage.Modules.Powers.PowerRegistry)
local Progression = require(ReplicatedStorage.Modules.Config.Progression)
local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local Modifiers = require(ReplicatedStorage.Modules.Combat.Modifiers)
local TableUtil = require(ReplicatedStorage.Modules.Shared.TableUtil)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local PowersTab = {}
PowersTab.__index = PowersTab

local T = UIKit.Theme

local function action(name, uid)
	local ok, err = Net.Invoke("PowerAction", name, uid)
	if not ok and err then
		ClientRegistry.Get("HUD"):Toast(err, "Error")
	end
end

function PowersTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, PowersTab)
	self.Info = UIKit.Panel(frame, { Size = UDim2.new(0.5, -6, 1, 0) })
	UIKit.Padding(self.Info, 12)
	local right = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = frame }
	)
	self.StorageLabel = UIKit.Label(right, "", { Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Font = T.FontBlack })
	self.PityLabel = UIKit.Label(
		right,
		"",
		{ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = T.SubText, Font = T.Font }
	)
	UIKit.Button(
		right,
		"✦ Open Spins",
		{ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(0.5, -4, 0, 34), BackgroundColor3 = T.Accent2 },
		function()
			ClientRegistry.Get("Menu"):Close()
			ClientRegistry.Get("SpinMenu"):Open()
		end
	)
	UIKit.Button(
		right,
		"+Storage (" .. GameConfig.Spins.StorageUpgradeGemCost .. " Gems)",
		{ Position = UDim2.new(0.5, 4, 0, 46), Size = UDim2.new(0.5, -4, 0, 34), TextSize = 13 },
		function()
			action("UpgradeStorage")
		end
	)
	self.List = UIKit.Scroll(right, { Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 1, -88) })
	UIKit.List(self.List, nil, 6)
	return self
end

function PowersTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	-- Equipped power details
	UIKit.Clear(self.Info)
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Info })
	UIKit.List(list, nil, 5)
	local owned = data.Powers.Owned[data.Powers.EquippedUid]
	local power = owned and PowerRegistry.Get(owned.Id)
	if not power then
		UIKit.Label(list, "No power equipped.", { TextSize = 18 })
		UIKit.Label(
			list,
			"Use your Spins (Oracle of Fate in Greenwood, or the Spin button) to obtain a power.",
			{ TextSize = 13, Font = T.Font, Size = UDim2.new(1, 0, 0, 40) }
		)
	else
		local record = data.PowerMastery[power.Id] or { Level = 0, Exp = 0 }
		UIKit.Label(
			list,
			power.DisplayName,
			{ TextSize = 24, Font = T.FontBlack, TextColor3 = UIKit.RarityColor(power.Rarity), Size = UDim2.new(1, 0, 0, 30) }
		)
		UIKit.Label(list, power.Rarity .. " • " .. power.Element, { TextSize = 13, TextColor3 = T.SubText })
		UIKit.Label(list, power.Description, { TextSize = 13, Font = T.Font, Size = UDim2.new(1, 0, 0, 34) })
		local need = Progression.MasteryExpToNext(record.Level)
		local _, setBar = UIKit.Bar(list, T.Accent, { Size = UDim2.new(1, 0, 0, 18) })
		setBar(
			need == math.huge and 1 or record.Exp / need,
			need == math.huge and "MASTERY MAX" or string.format("Mastery %d  (%d / %d)", record.Level, record.Exp, need)
		)
		UIKit.Label(list, "Passive: " .. power.Passive.Name, { TextSize = 14, TextColor3 = T.Gold })
		for _, line in ipairs(Modifiers.Describe(power.Passive.Modifiers)) do
			UIKit.Label(list, "  " .. line, { TextSize = 12, TextColor3 = T.Good })
		end
		for slot, skill in ipairs(power.Skills) do
			local required = power.MasteryUnlocks[slot]
			local unlocked = record.Level >= required
			local keyName = slot == 4 and "ULT" or tostring(slot)
			UIKit.Label(
				list,
				string.format("[%s] %s  %s", keyName, skill.Name, unlocked and "" or ("(Mastery " .. required .. ")")),
				{ TextSize = 14, TextColor3 = unlocked and T.Text or T.SubText }
			)
			UIKit.Label(
				list,
				string.format("   %s  CD %ds • %d Energy", skill.Description, skill.Cooldown, skill.EnergyCost),
				{ TextSize = 11, Font = T.Font, TextColor3 = T.SubText, Size = UDim2.new(1, 0, 0, 28) }
			)
		end
	end
	-- Storage
	local count = TableUtil.Count(data.Powers.Owned)
	self.StorageLabel.Text = string.format("Power Storage  %d / %d", count, data.Powers.StorageSlots)
	local pityText = {}
	for _, rule in ipairs(RarityConfig.Pity) do
		table.insert(pityText, string.format("%s %d/%d", rule.Rarity, data.Pity[rule.Rarity] or 0, rule.Threshold))
	end
	self.PityLabel.Text = "Pity: " .. table.concat(pityText, "  •  ")
	UIKit.Clear(self.List)
	local entries = {}
	for uid, entry in pairs(data.Powers.Owned) do
		table.insert(entries, { Uid = uid, Entry = entry, Def = PowerRegistry.Get(entry.Id) })
	end
	table.sort(entries, function(a, b)
		local ra = a.Def and RarityConfig.Rank[a.Def.Rarity] or 0
		local rb = b.Def and RarityConfig.Rank[b.Def.Rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.Uid < b.Uid
	end)
	for index, item in ipairs(entries) do
		local def = item.Def
		if def then
			local row = UIKit.Panel(self.List, { Size = UDim2.new(1, -8, 0, 52), LayoutOrder = index })
			local stroke = row:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = UIKit.RarityColor(def.Rarity)
			end
			local equipped = data.Powers.EquippedUid == item.Uid
			UIKit.Label(
				row,
				(equipped and "▶ " or "") .. def.DisplayName .. (item.Entry.Locked and "  🔒" or ""),
				{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 22), TextColor3 = UIKit.RarityColor(def.Rarity) }
			)
			UIKit.Label(
				row,
				def.Rarity,
				{ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -250, 0, 18), TextSize = 12, TextColor3 = T.SubText }
			)
			UIKit.Button(row, equipped and "Equipped" or "Equip", {
				Position = UDim2.new(1, -236, 0, 9),
				Size = UDim2.fromOffset(76, 34),
				TextSize = 13,
				BackgroundColor3 = equipped and T.Good or T.Accent,
			}, function()
				action("Equip", item.Uid)
			end)
			UIKit.Button(
				row,
				item.Entry.Locked and "Unlock" or "Lock",
				{ Position = UDim2.new(1, -156, 0, 9), Size = UDim2.fromOffset(70, 34), TextSize = 13 },
				function()
					action("Lock", item.Uid)
				end
			)
			UIKit.Button(
				row,
				"Delete",
				{ Position = UDim2.new(1, -82, 0, 9), Size = UDim2.fromOffset(72, 34), TextSize = 13, BackgroundColor3 = T.Bad },
				function()
					action("Delete", item.Uid)
				end
			)
		end
	end
end

return PowersTab
