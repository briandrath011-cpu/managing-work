--[[
	HUD (ModuleScript) -> creates ScreenGui "HUD"
	Location: StarterPlayer.StarterPlayerScripts.UI.HUD

	PHASE 21 - Health, Energy, EXP, Level, Awakening, currencies, current Power + Weapon,
	ability slots (1-4 + Z/X/C) with cooldowns and platform-aware key glyphs
	(keyboard / controller), quest tracker, notifications, server messages, world event timer.
	Mobile: touch buttons for every combat action + tappable ability slots.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local Modules = ReplicatedStorage.Modules
local InputConfig = require(Modules.Config.InputConfig)
local Progression = require(Modules.Config.Progression)
local GameConfig = require(Modules.Config.GameConfig)
local QuestCatalog = require(Modules.Quests.QuestCatalog)
local QuestLogic = require(Modules.Quests.QuestLogic)
local ItemUtil = require(Modules.Items.ItemUtil)
local WorldEvents = require(Modules.World.WorldEvents)
local Format = require(Modules.Shared.Format)
local Net = require(Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local Platform = require(StarterPlayerScripts.ClientModules.Platform)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local HUD = {}

local T = UIKit.Theme
local player = Players.LocalPlayer
local screen: ScreenGui
local refs: { [string]: any } = {}
local slots: { any } = {}
local toastContainer: Frame
local mobileFrame: Frame

local SLOT_ACTIONS = {
	{ Source = "Power", Slot = 1, Action = "Skill1" },
	{ Source = "Power", Slot = 2, Action = "Skill2" },
	{ Source = "Power", Slot = 3, Action = "Skill3" },
	{ Source = "Power", Slot = 4, Action = "Skill4" },
	{ Source = "Weapon", Slot = 1, Action = "WeaponSkill1" },
	{ Source = "Weapon", Slot = 2, Action = "WeaponSkill2" },
	{ Source = "Weapon", Slot = 3, Action = "WeaponSkill3" },
}

local TOAST_COLORS = {
	Error = T.Bad,
	LevelUp = T.Gold,
	Drop = T.Text,
	Quest = Color3.fromRGB(120, 200, 255),
	QuestComplete = T.Good,
	Reward = T.Good,
	Unlock = Color3.fromRGB(200, 150, 255),
	Mastery = Color3.fromRGB(160, 200, 255),
	Achievement = T.Gold,
	Discover = Color3.fromRGB(150, 220, 255),
	Craft = T.Good,
	Event = Color3.fromRGB(255, 170, 90),
	Boss = Color3.fromRGB(255, 90, 90),
}

local function data()
	return ClientRegistry.Get("DataController"):Get()
end

local function keyLabel(action: string): string
	local platform = Platform.Get()
	if platform == "Console" then
		return InputConfig.GamepadLabel(action)
	elseif platform == "Mobile" then
		return ""
	end
	return InputConfig.KeyboardLabel(action)
end

-- NOTIFICATIONS -------------------------------------------------------------------------------------

function HUD:Toast(text: string, kind: string?, color: Color3?)
	if not toastContainer then
		return
	end
	local toast = UIKit.Panel(toastContainer, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 0.15 })
	local accent = color or TOAST_COLORS[kind or ""] or T.Text
	UIKit.Label(
		toast,
		text,
		{
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextColor3 = accent,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
		}
	)
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
	end
	toast.Position = UDim2.fromOffset(0, 20)
	local children = toastContainer:GetChildren()
	if #children > 7 then
		for _, child in ipairs(children) do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		if toast.Parent then
			UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
			for _, d in ipairs(toast:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.3, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.Tween(d, 0.3, { Transparency = 1 })
				end
			end
			task.delay(0.32, function()
				toast:Destroy()
			end)
		end
	end)
end

-- Big center banner (quest complete, new region...)
function HUD:Banner(title: string, subtitle: string?, color: Color3?)
	local frame = UIKit.New(
		"Frame",
		{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.28),
			Size = UDim2.fromOffset(700, 110),
			Parent = screen,
		}
	)
	local titleLabel = UIKit.Label(
		frame,
		title,
		{
			Size = UDim2.new(1, 0, 0, 56),
			Font = T.FontBlack,
			TextSize = 46,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color or T.Text,
			TextStrokeTransparency = 0.3,
			TextTransparency = 1,
		}
	)
	local sub = UIKit.Label(
		frame,
		subtitle or "",
		{
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
			TextTransparency = 1,
		}
	)
	local line = UIKit.New(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 56),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = color or T.Accent,
			BorderSizePixel = 0,
			Parent = frame,
		}
	)
	UIKit.Tween(titleLabel, 0.3, { TextTransparency = 0 })
	UIKit.Tween(sub, 0.5, { TextTransparency = 0 })
	UIKit.Tween(line, 0.5, { Size = UDim2.fromOffset(500, 2) })
	task.delay(3, function()
		UIKit.Tween(titleLabel, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		UIKit.Tween(sub, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		UIKit.Tween(line, 0.5, { Size = UDim2.fromOffset(0, 2) })
		task.delay(0.55, function()
			frame:Destroy()
		end)
	end)
end

function HUD:ServerMessage(text: string, color: Color3?)
	local bar = UIKit.Panel(
		screen,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -60),
			Size = UDim2.fromOffset(760, 46),
			BackgroundColor3 = Color3.fromRGB(30, 10, 20),
		}
	)
	UIKit.Gradient(bar, Color3.fromRGB(60, 10, 30), Color3.fromRGB(20, 10, 40), 0)
	UIKit.Label(
		bar,
		text,
		{
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 20,
			Font = T.FontBlack,
			TextColor3 = color or Color3.fromRGB(255, 210, 120),
		}
	)
	UIKit.Tween(bar, 0.4, { Position = UDim2.new(0.5, 0, 0, 60) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		UIKit.Tween(bar, 0.4, { Position = UDim2.new(0.5, 0, 0, -60) })
		task.delay(0.45, function()
			bar:Destroy()
		end)
	end)
end

-- BUILD ------------------------------------------------------------------------------------------------

local function buildPlayerPanel()
	local panel = UIKit.Panel(screen, { Name = "PlayerPanel", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(330, 146) })
	local badge = UIKit.New(
		"Frame",
		{ BackgroundColor3 = T.Accent, Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(10, 10), Parent = panel }
	)
	UIKit.Corner(badge, 29)
	UIKit.Gradient(badge, T.Accent, T.Accent2, 45)
	UIKit.Label(
		badge,
		"LV",
		{ Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 6), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center }
	)
	refs.Level = UIKit.Label(
		badge,
		"1",
		{
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 20),
			TextSize = 24,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
		}
	)
	refs.Name = UIKit.Label(
		panel,
		player.DisplayName,
		{ Position = UDim2.fromOffset(78, 8), Size = UDim2.new(1, -88, 0, 20), TextSize = 17, Font = T.FontBlack }
	)
	refs.Build = UIKit.Label(
		panel,
		"",
		{ Position = UDim2.fromOffset(78, 28), Size = UDim2.new(1, -88, 0, 16), TextSize = 12, TextColor3 = T.SubText, Font = T.Font }
	)
	local _, setHealth = UIKit.Bar(panel, T.Health, { Position = UDim2.fromOffset(78, 48), Size = UDim2.new(1, -88, 0, 18) })
	local _, setEnergy = UIKit.Bar(panel, T.Energy, { Position = UDim2.fromOffset(78, 70), Size = UDim2.new(1, -88, 0, 14) })
	local _, setExp = UIKit.Bar(panel, T.Exp, { Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 12) })
	local _, setAwaken, awakenLabel =
		UIKit.Bar(panel, T.Awakening, { Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 14) })
	refs.SetHealth, refs.SetEnergy, refs.SetExp, refs.SetAwaken, refs.AwakenLabel = setHealth, setEnergy, setExp, setAwaken, awakenLabel
	refs.StatHint = UIKit.Label(
		panel,
		"",
		{ Position = UDim2.fromOffset(10, 126), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = T.Gold, Font = T.FontBold }
	)
end

local function buildCurrencies()
	local panel = UIKit.Panel(
		screen,
		{ Name = "Currencies", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(300, 40) }
	)
	UIKit.List(panel, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	UIKit.Padding(panel, 8)
	refs.Gold = UIKit.Label(panel, "0", { Size = UDim2.fromOffset(90, 24), TextColor3 = T.Gold, TextSize = 16 })
	refs.Gems = UIKit.Label(panel, "0", { Size = UDim2.fromOffset(80, 24), TextColor3 = T.Gem, TextSize = 16 })
	refs.Spins = UIKit.Label(panel, "0", { Size = UDim2.fromOffset(80, 24), TextColor3 = Color3.fromRGB(255, 150, 220), TextSize = 16 })
end

local function buildQuestTracker()
	local panel = UIKit.Panel(
		screen,
		{
			Name = "QuestTracker",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 64),
			Size = UDim2.fromOffset(300, 200),
			BackgroundTransparency = 0.3,
		}
	)
	UIKit.Label(
		panel,
		"QUESTS",
		{ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 14, Font = T.FontBlack, TextColor3 = T.Accent }
	)
	local list = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 1, -34), Parent = panel }
	)
	UIKit.List(list, nil, 4)
	refs.QuestList = list
	refs.QuestPanel = panel
end

local function buildEventIndicator()
	local label = UIKit.Label(
		screen,
		"",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(420, 26),
			TextSize = 18,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(255, 180, 90),
			TextStrokeTransparency = 0.3,
		}
	)
	refs.EventLabel = label
	refs.ClockLabel = UIKit.Label(
		screen,
		"",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 38),
			Size = UDim2.fromOffset(300, 18),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.SubText,
			TextStrokeTransparency = 0.5,
		}
	)
end

local function buildAbilityBar()
	local bar = UIKit.New(
		"Frame",
		{
			Name = "AbilityBar",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(7 * 78 + 30, 110),
			Parent = screen,
		}
	)
	refs.PowerName = UIKit.Label(
		bar,
		"",
		{
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(4 * 78, 20),
			TextSize = 14,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
		}
	)
	refs.WeaponName = UIKit.Label(
		bar,
		"",
		{
			Position = UDim2.fromOffset(4 * 78 + 30, 0),
			Size = UDim2.fromOffset(3 * 78, 20),
			TextSize = 14,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
		}
	)
	for index, info in ipairs(SLOT_ACTIONS) do
		local x = (index - 1) * 78 + (info.Source == "Weapon" and 30 or 0)
		local slot = UIKit.New(
			"TextButton",
			{
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = T.Panel,
				Position = UDim2.fromOffset(x, 24),
				Size = UDim2.fromOffset(70, 70),
				Parent = bar,
				Selectable = false,
			}
		)
		UIKit.Corner(slot, 12)
		local stroke = UIKit.Stroke(slot, info.Slot == 4 and info.Source == "Power" and T.Gold or T.Accent, 1.5, 0.3)
		local name = UIKit.Label(
			slot,
			"",
			{
				Position = UDim2.fromOffset(4, 22),
				Size = UDim2.new(1, -8, 0, 30),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextWrapped = true,
			}
		)
		local key = UIKit.Label(
			slot,
			"",
			{ Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, 16), TextSize = 12, Font = T.FontBlack, TextColor3 = T.SubText }
		)
		local cooldown = UIKit.New(
			"Frame",
			{
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.35,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0),
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = slot,
			}
		)
		UIKit.Corner(cooldown, 12)
		local cdText = UIKit.Label(
			slot,
			"",
			{ Size = UDim2.fromScale(1, 1), TextSize = 20, Font = T.FontBlack, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 }
		)
		local lock = UIKit.Label(
			slot,
			"",
			{
				Position = UDim2.new(0, 0, 1, -18),
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 10,
				TextColor3 = T.Bad,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 4,
			}
		)
		slot.Activated:Connect(function()
			ClientRegistry.Get("AbilityController"):Use(info.Source, info.Slot)
		end)
		slots[index] =
			{ Info = info, Frame = slot, Name = name, Key = key, Cooldown = cooldown, CdText = cdText, Lock = lock, Stroke = stroke }
	end
end

local function buildMobileControls()
	mobileFrame = UIKit.New(
		"Frame",
		{
			Name = "MobileControls",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -150),
			Size = UDim2.fromOffset(300, 260),
			Parent = screen,
			Visible = false,
		}
	)
	local input = ClientRegistry.Get("InputController")
	local function touchButton(action: string, text: string, position: UDim2, size: number, color: Color3?, toggle: boolean?)
		local button = UIKit.New(
			"TextButton",
			{
				Text = text,
				Font = T.FontBlack,
				TextSize = size > 80 and 20 or 14,
				TextColor3 = T.Text,
				AutoButtonColor = false,
				BackgroundColor3 = color or T.Panel,
				BackgroundTransparency = 0.25,
				Position = position,
				Size = UDim2.fromOffset(size, size),
				Parent = mobileFrame,
			}
		)
		UIKit.Corner(button, size / 2)
		UIKit.Stroke(button, T.Accent, 2, 0.2)
		button.InputBegan:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.Touch then
				if toggle then
					input:Trigger(action, not input:IsHeld(action))
					button.BackgroundColor3 = input:IsHeld(action) and T.Accent or (color or T.Panel)
				else
					input:Trigger(action, true)
					button.BackgroundTransparency = 0
				end
			end
		end)
		button.InputEnded:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.Touch and not toggle then
				input:Trigger(action, false)
				button.BackgroundTransparency = 0.25
			end
		end)
		return button
	end
	touchButton("M1", "ATTACK", UDim2.fromOffset(190, 150), 100, T.Accent2)
	touchButton("Heavy", "HEAVY", UDim2.fromOffset(110, 180), 70)
	touchButton("Block", "BLOCK", UDim2.fromOffset(200, 70), 70)
	touchButton("Dash", "DASH", UDim2.fromOffset(120, 100), 70)
	touchButton("Sprint", "RUN", UDim2.fromOffset(40, 190), 60, nil, true)
	touchButton("Transform", "AWAKEN", UDim2.fromOffset(40, 120), 60, T.Awakening)
	touchButton("LockOn", "LOCK", UDim2.fromOffset(40, 50), 60)
end

local function buildMenuButtons()
	local frame = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 170), Size = UDim2.fromOffset(330, 40), Parent = screen }
	)
	UIKit.List(frame, Enum.FillDirection.Horizontal, 6)
	refs.MenuButton = UIKit.Button(frame, "☰ Menu", { Size = UDim2.fromOffset(100, 36), TextSize = 14 }, function()
		ClientRegistry.Get("Menu"):Toggle()
	end)
	UIKit.Button(frame, "✦ Spin", { Size = UDim2.fromOffset(100, 36), TextSize = 14 }, function()
		ClientRegistry.Get("SpinMenu"):Open()
	end)
	UIKit.Button(frame, "🗺 Map", { Size = UDim2.fromOffset(100, 36), TextSize = 14 }, function()
		ClientRegistry.Get("Menu"):Open("Map")
	end)
end

local function buildToasts()
	toastContainer = UIKit.New(
		"Frame",
		{
			Name = "Toasts",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -140),
			Size = UDim2.fromOffset(520, 280),
			Parent = screen,
		}
	)
	local layout = UIKit.List(toastContainer, nil, 4, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

-- UPDATE ---------------------------------------------------------------------------------------------

function HUD:RefreshData()
	local d = data()
	if not d then
		return
	end
	refs.Level.Text = tostring(d.Level)
	local need = Progression.ExpToNext(d.Level)
	if need == math.huge then
		refs.SetExp(1, "MAX LEVEL")
	else
		refs.SetExp(d.Exp / need, string.format("EXP %s / %s", Format.Short(d.Exp), Format.Short(need)))
	end
	refs.Gold.Text = "● " .. Format.Short(d.Gold)
	refs.Gems.Text = "◆ " .. Format.Short(d.Gems)
	refs.Spins.Text = "✦ " .. tostring(d.Spins)
	refs.StatHint.Text = d.StatPoints > 0 and string.format("+%d stat points available (Menu > Stats)", d.StatPoints) or ""
	local ability = ClientRegistry.Get("AbilityController")
	local _, _, _, power = ability:GetSkillInfo("Power", 1)
	local _, _, _, weapon = ability:GetSkillInfo("Weapon", 1)
	refs.PowerName.Text = power and power.DisplayName or "No Power (visit the Oracle)"
	refs.PowerName.TextColor3 = power and UIKit.RarityColor(power.Rarity) or T.SubText
	refs.WeaponName.Text = weapon and weapon.DisplayName or "Fists"
	refs.WeaponName.TextColor3 = weapon and UIKit.RarityColor(weapon.Rarity) or T.SubText
	local titleParts = {}
	if d.Trait ~= "None" then
		table.insert(titleParts, d.Trait)
	end
	table.insert(titleParts, d.FightingStyle)
	refs.Build.Text = table.concat(titleParts, " • ")
	for _, slot in ipairs(slots) do
		local skill, unlocked, required = ability:GetSkillInfo(slot.Info.Source, slot.Info.Slot)
		slot.Name.Text = skill and skill.Name or "-"
		slot.Lock.Text = (skill and not unlocked) and ("M" .. required) or ""
		slot.Name.TextTransparency = (skill and unlocked) and 0 or 0.5
	end
	self:RefreshQuests()
end

function HUD:RefreshQuests()
	local d = data()
	if not d then
		return
	end
	UIKit.Clear(refs.QuestList)
	local count = 0
	local inventory = d.Inventory
	local function countItem(id)
		return ItemUtil.CountInInventory(inventory, id)
	end
	local ordered = {}
	for questId, active in pairs(d.Quests.Active) do
		table.insert(ordered, { Id = questId, Active = active })
	end
	table.sort(ordered, function(a, b)
		return (a.Active.Accepted or 0) > (b.Active.Accepted or 0)
	end)
	for _, entry in ipairs(ordered) do
		local def = QuestCatalog.Get(entry.Id)
		if def and count < 4 then
			count += 1
			local done = QuestLogic.IsComplete(def, entry.Active.Progress, countItem)
			UIKit.Label(
				refs.QuestList,
				(done and "✔ " or "• ") .. def.Name,
				{ Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = done and T.Good or T.Text }
			)
			for i, objective in ipairs(def.Objectives) do
				local have, need = QuestLogic.ObjectiveProgress(objective, entry.Active.Progress[i], countItem)
				UIKit.Label(
					refs.QuestList,
					"   " .. QuestLogic.Describe(objective, have, need),
					{ Size = UDim2.new(1, 0, 0, 14), TextSize = 11, Font = T.Font, TextColor3 = have >= need and T.Good or T.SubText }
				)
			end
		end
	end
	refs.QuestPanel.Visible = count > 0
end

local function updateKeyLabels()
	for _, slot in ipairs(slots) do
		slot.Key.Text = keyLabel(slot.Info.Action)
	end
	if mobileFrame then
		mobileFrame.Visible = Platform.Get() == "Mobile"
	end
end

function HUD:SetVisible(visible: boolean)
	if screen then
		screen.Enabled = visible
	end
end

function HUD:Init()
	screen = UIKit.Screen("HUD", 5)
	screen.Enabled = false
	buildPlayerPanel()
	buildCurrencies()
	buildQuestTracker()
	buildEventIndicator()
	buildAbilityBar()
	buildMobileControls()
	buildMenuButtons()
	buildToasts()
	updateKeyLabels()
	Platform.Changed:Connect(updateKeyLabels)

	local dataController = ClientRegistry.Get("DataController")
	dataController.Changed:Connect(function()
		self:RefreshData()
	end)

	Net.Event("Notify").OnClientEvent:Connect(function(kind, text, extra)
		if kind == "Server" then
			self:ServerMessage(text, extra and extra.Color)
			SoundLib.Play("SpinReveal", nil, 0.4)
		elseif kind == "LevelUp" then
			self:Banner("LEVEL UP!", "Level " .. tostring(extra and extra.Level or ""), T.Gold)
			self:Toast(text, kind)
		elseif kind == "Drop" and extra and extra.Rarity then
			self:Toast(text, kind, UIKit.RarityColor(extra.Rarity))
		else
			self:Toast(text, kind)
		end
	end)
end

function HUD:Start()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0 then
			refs.SetHealth(humanoid.Health / humanoid.MaxHealth, string.format("%d / %d", humanoid.Health, humanoid.MaxHealth))
			local energy = character:GetAttribute("Energy") or 0
			local maxEnergy = math.max(1, character:GetAttribute("MaxEnergy") or 100)
			refs.SetEnergy(energy / maxEnergy, string.format("%d / %d", energy, maxEnergy))
			local awakening = character:GetAttribute("Awakening") or 0
			if character:GetAttribute("Transformed") then
				refs.SetAwaken(1, "TRANSFORMED")
			else
				local full = awakening >= GameConfig.Transform.MaxAwakening
				refs.SetAwaken(
					awakening / GameConfig.Transform.MaxAwakening,
					full and ("AWAKENING READY - " .. keyLabel("Transform")) or "Awakening"
				)
			end
		end
		local ability = ClientRegistry.Get("AbilityController")
		for _, slot in ipairs(slots) do
			local remaining, total = ability:GetCooldown(slot.Info.Source .. slot.Info.Slot)
			if remaining > 0 then
				slot.Cooldown.Size = UDim2.fromScale(1, remaining / total)
				slot.CdText.Text = string.format(remaining < 10 and "%.1f" or "%d", remaining)
			else
				slot.Cooldown.Size = UDim2.fromScale(1, 0)
				slot.CdText.Text = ""
			end
		end
		-- World event + clock
		local eventId = Workspace:GetAttribute("WorldEvent")
		if eventId and WorldEvents[eventId] then
			local ends = Workspace:GetAttribute("WorldEventEnds") or 0
			refs.EventLabel.Text = string.format("⚠ %s  %s", WorldEvents[eventId].DisplayName, Format.Time(ends - os.time()))
		else
			refs.EventLabel.Text = ""
		end
		local phase = Workspace:GetAttribute("TimePhase") or ""
		local weather = Workspace:GetAttribute("Weather") or ""
		local region = character and character:GetAttribute("Region") or ""
		refs.ClockLabel.Text = string.format("%s  •  %s  •  %s", region, phase, weather)
	end)
end

return HUD
