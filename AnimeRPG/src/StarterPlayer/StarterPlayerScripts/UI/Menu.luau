--[[
	Menu (ModuleScript) -> ScreenGui "Menu"
	Location: StarterPlayer.StarterPlayerScripts.UI.Menu
	PHASE 21 / 32 - In-game menu. PC: M | Controller: View button | Mobile: HUD "Menu" button.
	Tabs live in UI/Tabs (one ModuleScript each): Character, Inventory, Powers, Weapons, Stats,
	Quests, Achievements, Titles, Settings, Map.
	Controller navigation: every button is Selectable; the first tab is auto-selected.
]]
local GuiService = game:GetService("GuiService")
local StarterPlayerScripts = script.Parent.Parent

local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local Platform = require(StarterPlayerScripts.ClientModules.Platform)

local Menu = {}

local T = UIKit.Theme
local TAB_ORDER = { "Character", "Inventory", "Powers", "Weapons", "Stats", "Quests", "Achievements", "Titles", "Map", "Settings" }

local screen: ScreenGui
local window: Frame
local content: Frame
local tabButtons: { [string]: TextButton } = {}
local tabs: { [string]: any } = {}
local tabFrames: { [string]: Frame } = {}
local currentTab = "Character"
local isOpen = false

function Menu:IsOpen(): boolean
	return isOpen
end

function Menu:ShowTab(name: string)
	currentTab = name
	for tabName, frame in pairs(tabFrames) do
		frame.Visible = tabName == name
	end
	for tabName, button in pairs(tabButtons) do
		button.BackgroundColor3 = tabName == name and T.Accent or T.PanelLight
	end
	local tab = tabs[name]
	if tab and tab.Refresh then
		task.spawn(tab.Refresh, tab)
	end
end

function Menu:Open(tabName: string?)
	isOpen = true
	UIKit.Open(window)
	ClientRegistry.Get("InputController").GameplayBlocked = true
	self:ShowTab(tabName or currentTab)
	if Platform.Get() == "Console" then
		GuiService.SelectedObject = tabButtons[tabName or currentTab]
	end
end

function Menu:Close()
	isOpen = false
	window.Visible = false
	ClientRegistry.Get("InputController").GameplayBlocked = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then
		GuiService.SelectedObject = nil
	end
end

function Menu:Toggle(tabName: string?)
	if isOpen then
		self:Close()
	else
		self:Open(tabName)
	end
end

function Menu:Refresh()
	local tab = tabs[currentTab]
	if isOpen and tab and tab.Refresh then
		tab:Refresh()
	end
end

function Menu:Init()
	screen = UIKit.Screen("Menu", 20)
	window, content = UIKit.Window(screen, "MENU", UDim2.fromOffset(1060, 620), function()
		Menu:Close()
	end)
	local sidebar = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), Parent = content })
	UIKit.List(sidebar, nil, 5)
	local body = UIKit.New(
		"Frame",
		{
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(162, 0),
			Size = UDim2.new(1, -162, 1, 0),
			Parent = content,
		}
	)
	for index, name in ipairs(TAB_ORDER) do
		local button = UIKit.Button(sidebar, name, { Size = UDim2.new(1, 0, 0, 46), LayoutOrder = index, TextSize = 15 }, function()
			Menu:ShowTab(name)
		end)
		tabButtons[name] = button
		local frame =
			UIKit.New("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = body })
		tabFrames[name] = frame
		local moduleScript = script.Parent.Tabs:FindFirstChild(name)
		if moduleScript then
			local ok, tabModule = pcall(require, moduleScript)
			if ok then
				local instance = tabModule.new(frame)
				tabs[name] = instance
			else
				warn("[Menu] Tab " .. name .. " failed: " .. tostring(tabModule))
			end
		end
	end
	local input = ClientRegistry.Get("InputController")
	input:OnAction("Menu", function(began)
		if began then
			Menu:Toggle()
		end
	end)
	input:OnAction("Map", function(began)
		if began then
			if isOpen and currentTab == "Map" then
				Menu:Close()
			else
				Menu:Open("Map")
			end
		end
	end)
	ClientRegistry.Get("DataController").Changed:Connect(function()
		Menu:Refresh()
	end)
end

return Menu
