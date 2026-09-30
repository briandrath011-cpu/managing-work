--[[
	ClientMain (LocalScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientMain
	Boots the client: loading screen -> controllers + UI (Init, then Start) -> title screen.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ClientRegistry = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("ClientRegistry"))

-- Our own HUD replaces the default health bar / backpack.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local MainMenu = require(script.Parent:WaitForChild("UI"):WaitForChild("MainMenu"))
MainMenu:ShowLoading()
MainMenu:SetProgress(0.1, "Connecting...")

ReplicatedStorage:WaitForChild("Remotes")
ReplicatedStorage:WaitForChild("Modules")

local ORDER = {
	{ "Controllers", "DataController" },
	{ "Controllers", "InputController" },
	{ "Controllers", "SettingsController" },
	{ "Controllers", "CameraController" },
	{ "Controllers", "AudioController" },
	{ "UI", "HUD" },
	{ "Controllers", "MovementController" },
	{ "Controllers", "CombatController" },
	{ "Controllers", "AbilityController" },
	{ "Controllers", "VFXController" },
	{ "Controllers", "WeatherController" },
	{ "UI", "Menu" },
	{ "UI", "SpinMenu" },
	{ "UI", "BossUI" },
	{ "UI", "DialogUI" },
	{ "UI", "InstanceUI" },
}

ClientRegistry.Add("MainMenu", MainMenu)
for index, entry in ipairs(ORDER) do
	local moduleScript = script.Parent:WaitForChild(entry[1]):WaitForChild(entry[2])
	local ok, result = pcall(require, moduleScript)
	if ok then
		ClientRegistry.Add(entry[2], result)
	else
		warn("[ClientMain] Failed to load " .. entry[2] .. ": " .. tostring(result))
	end
	MainMenu:SetProgress(0.1 + 0.4 * index / #ORDER, "Loading " .. entry[2])
end

for _, entry in ipairs(ORDER) do
	local controller = ClientRegistry.Controllers[entry[2]]
	if controller and controller.Init then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			warn("[ClientMain] Init failed for " .. entry[2] .. ": " .. tostring(err))
		end
	end
end

for _, entry in ipairs(ORDER) do
	local controller = ClientRegistry.Controllers[entry[2]]
	if controller and controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn("[ClientMain] Start failed for " .. entry[2] .. ": " .. tostring(err))
			end
		end)
	end
end

MainMenu:SetProgress(0.6, "Loading your save...")
local dataController = ClientRegistry.Get("DataController")
local waited = 0
while not dataController.Data and waited < 30 do
	task.wait(0.1)
	waited += 0.1
end
MainMenu:SetProgress(0.85, "Preparing the world...")
MainMenu:Preload()
MainMenu:SetProgress(1, "Ready!")
task.wait(0.3)
MainMenu:ShowTitle()
