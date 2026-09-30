--[[
	MainMenu (ModuleScript) -> ScreenGui "MainMenu"
	Location: StarterPlayer.StarterPlayerScripts.UI.MainMenu
	PHASE 31 - Loading Screen -> Title Screen -> Play (character summary) / Character / Settings
	-> Start Game (server spawns the character, HUD appears).
	The camera slowly orbits Greenwood Village behind the menu.
]]
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local ItemUtil = require(Modules.Items.ItemUtil)
local Traits = require(Modules.Progression.Traits)
local QualityConfig = require(Modules.Config.QualityConfig)
local Format = require(Modules.Shared.Format)
local Net = require(Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local Platform = require(StarterPlayerScripts.ClientModules.Platform)

local MainMenu = {}

local T = UIKit.Theme
local screen: ScreenGui
local loading: Frame
local title: Frame
local panel: Frame
local cameraConnection: RBXScriptConnection? = nil
local started = false

local function orbitCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	cameraConnection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) * 0.05
		local position = Vector3.new(math.cos(t) * 140, 70, math.sin(t) * 140)
		camera.CFrame = CFrame.lookAt(position, Vector3.new(0, 10, 20))
	end)
end

local function stopCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- LOADING --------------------------------------------------------------------------------------------

function MainMenu:ShowLoading()
	screen = UIKit.Screen("MainMenu", 100)
	loading = UIKit.New("Frame", { BackgroundColor3 = T.Background, Size = UDim2.fromScale(1, 1), Parent = screen })
	UIKit.Gradient(loading, Color3.fromRGB(30, 15, 60), T.Background, 90)
	UIKit.Label(loading, GameConfig.GameName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(900, 90),
		TextSize = 72,
		Font = T.FontBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Text,
	})
	local _, setBar, label = UIKit.Bar(
		loading,
		T.Accent,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(520, 20) }
	)
	self.SetLoading = setBar
	self.LoadingLabel = label
	setBar(0, "Loading...")
end

function MainMenu:SetProgress(ratio: number, text: string)
	if self.SetLoading then
		self.SetLoading(ratio, text)
	end
end

function MainMenu:Preload()
	local assets = {}
	for _, gui in ipairs(screen:GetDescendants()) do
		table.insert(assets, gui)
	end
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

-- TITLE ----------------------------------------------------------------------------------------------

local function clearPanel()
	UIKit.Clear(panel)
	panel.Visible = true
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = panel })
	UIKit.List(list, nil, 10)
	return list
end

function MainMenu:ShowCharacter(withStart: boolean)
	local list = clearPanel()
	local data = ClientRegistry.Get("DataController"):Get()
	UIKit.Label(
		list,
		withStart and "READY?" or "CHARACTER",
		{ TextSize = 26, Font = T.FontBlack, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 32) }
	)
	if data then
		local owned = data.Powers.Owned[data.Powers.EquippedUid]
		local power = owned and PowerRegistry.Get(owned.Id)
		local weaponEntry = data.Equipment.Weapon ~= "" and data.Inventory[data.Equipment.Weapon]
		local weapon = weaponEntry and ItemUtil.Get(weaponEntry.Id)
		local trait = Traits.Get(data.Trait)
		local lines = {
			{ "Level", tostring(data.Level) },
			{ "Power", power and power.DisplayName or "None" },
			{ "Weapon", weapon and weapon.DisplayName or "Fists" },
			{ "Fighting Style", data.FightingStyle },
			{ "Trait", trait and trait.DisplayName or "None" },
			{ "Gold / Gems", Format.Short(data.Gold) .. " / " .. Format.Short(data.Gems) },
			{ "Spins", tostring(data.Spins) },
		}
		for _, line in ipairs(lines) do
			local row = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = list })
			UIKit.Label(row, line[1], { Size = UDim2.new(0.45, 0, 1, 0), TextColor3 = T.SubText })
			UIKit.Label(row, line[2], { Position = UDim2.fromScale(0.45, 0), Size = UDim2.new(0.55, 0, 1, 0) })
		end
	else
		UIKit.Label(list, "Loading your data...", { TextColor3 = T.SubText })
	end
	if withStart then
		local startButton = UIKit.Button(
			list,
			"START GAME",
			{ Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.Accent2, TextSize = 22 },
			function()
				MainMenu:StartGame()
			end
		)
		if Platform.Get() == "Console" then
			GuiService.SelectedObject = startButton
		end
	end
end

function MainMenu:ShowSettings()
	local list = clearPanel()
	local settings = ClientRegistry.Get("SettingsController")
	UIKit.Label(list, "SETTINGS", { TextSize = 26, Font = T.FontBlack, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 32) })
	local qualityButton
	qualityButton = UIKit.Button(list, "Quality: " .. settings.Settings.Quality, { Size = UDim2.new(1, 0, 0, 40) }, function()
		local index = table.find(QualityConfig.Options, settings.Settings.Quality) or 1
		local nextQuality = QualityConfig.Options[index % #QualityConfig.Options + 1]
		settings:Set("Quality", nextQuality)
		qualityButton.Text = "Quality: " .. nextQuality
	end)
	UIKit.Slider(list, "Music Volume", settings.Settings.MusicVolume, function(v)
		settings:Set("MusicVolume", v)
	end)
	UIKit.Slider(list, "Effects Volume", settings.Settings.SfxVolume, function(v)
		settings:Set("SfxVolume", v)
	end)
	UIKit.Toggle(list, "Camera Shake", settings.Settings.CameraShake, function(v)
		settings:Set("CameraShake", v)
	end)
end

function MainMenu:ShowTitle()
	UIKit.Tween(loading, 0.6, { BackgroundTransparency = 1 })
	for _, d in ipairs(loading:GetDescendants()) do
		if d:IsA("TextLabel") then
			UIKit.Tween(d, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		elseif d:IsA("Frame") then
			UIKit.Tween(d, 0.4, { BackgroundTransparency = 1 })
		end
	end
	task.delay(0.65, function()
		loading:Destroy()
	end)
	orbitCamera()
	ClientRegistry.Get("AudioController"):SetOverride("Menu", "Menu")
	title = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })
	local shade = UIKit.New(
		"Frame",
		{ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.new(0.45, 0, 1, 0), Parent = title }
	)
	UIKit.Gradient(shade, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 0).Transparency = NumberSequence.new(0.1, 1)
	UIKit.Label(title, GameConfig.GameName, {
		Position = UDim2.new(0, 60, 0.16, 0),
		Size = UDim2.fromOffset(700, 80),
		TextSize = 64,
		Font = T.FontBlack,
		TextStrokeTransparency = 0.4,
	})
	UIKit.Label(
		title,
		"Anime Action RPG  •  v" .. GameConfig.Version,
		{ Position = UDim2.new(0, 64, 0.16, 84), Size = UDim2.fromOffset(600, 26), TextSize = 18, TextColor3 = T.Accent }
	)
	local buttons = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0.38, 0), Size = UDim2.fromOffset(300, 260), Parent = title }
	)
	UIKit.List(buttons, nil, 12)
	local play = UIKit.Button(buttons, "PLAY", { Size = UDim2.fromOffset(280, 58), TextSize = 24, BackgroundColor3 = T.Accent }, function()
		MainMenu:ShowCharacter(true)
	end)
	UIKit.Button(buttons, "CHARACTER", { Size = UDim2.fromOffset(280, 50), TextSize = 18 }, function()
		MainMenu:ShowCharacter(false)
	end)
	UIKit.Button(buttons, "SETTINGS", { Size = UDim2.fromOffset(280, 50), TextSize = 18 }, function()
		MainMenu:ShowSettings()
	end)
	panel = UIKit.Panel(
		title,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Size = UDim2.fromOffset(420, 460), Visible = false }
	)
	UIKit.Padding(panel, 18)
	local hint = Platform.Get() == "Mobile" and "Tap PLAY to begin"
		or (Platform.Get() == "Console" and "Press A to select" or "Click PLAY to begin")
	UIKit.Label(title, hint, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(500, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.SubText,
	})
	if Platform.Get() == "Console" then
		GuiService.SelectedObject = play
	end
end

function MainMenu:StartGame()
	if started then
		return
	end
	started = true
	local ok, err = Net.Invoke("RequestStart")
	if not ok then
		started = false
		ClientRegistry.Get("HUD"):Toast(err or "Could not start", "Error")
		return
	end
	stopCamera()
	GuiService.SelectedObject = nil
	ClientRegistry.Get("AudioController"):SetOverride("Menu", nil)
	UIKit.Tween(title, 0.4, { Position = UDim2.fromScale(-1, 0) })
	task.delay(0.45, function()
		screen:Destroy()
	end)
	ClientRegistry.Get("HUD"):SetVisible(true)
	ClientRegistry.Get("HUD"):Banner(GameConfig.GameName, "Welcome, " .. game:GetService("Players").LocalPlayer.DisplayName, T.Accent)
end

function MainMenu:IsStarted(): boolean
	return started
end

return MainMenu
