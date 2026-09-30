--[[
	InstanceUI (ModuleScript) -> ScreenGui "DungeonUI"
	Location: StarterPlayer.StarterPlayerScripts.UI.InstanceUI
	PHASE 16 / 20 - Dungeon + raid gate window (difficulty, create / join party), lobby panel
	with countdown, room banners, run timer, raid mechanic warnings, victory / defeat.
	Remotes: InstanceState (server -> client), DungeonAction / RaidAction (requests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = script.Parent.Parent

local Dungeons = require(ReplicatedStorage.Modules.World.Dungeons)
local Raids = require(ReplicatedStorage.Modules.World.Raids)
local Format = require(ReplicatedStorage.Modules.Shared.Format)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)

local InstanceUI = {}

local T = UIKit.Theme
local screen: ScreenGui
local gateWindow: Frame
local gateBody: Frame
local lobbyPanel: Frame
local lobbyLabel: TextLabel
local lobbyButtons: Frame
local timerLabel: TextLabel
local lobbyType = "Dungeon"
local selectedDifficulty = "Normal"

local function remoteFor(kind: string): string
	return kind == "Raid" and "RaidAction" or "DungeonAction"
end

local function invoke(kind: string, ...)
	local ok, result = Net.Invoke(remoteFor(kind), ...)
	if not ok and result then
		ClientRegistry.Get("HUD"):Toast(result, "Error")
	end
	return ok, result
end

local function closeGate()
	gateWindow.Visible = false
	ClientRegistry.Get("InputController").GameplayBlocked = false
end

local function openGate(payload)
	UIKit.Clear(gateBody)
	local list = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gateBody })
	UIKit.List(list, nil, 8)
	local kind = payload.Type
	if kind == "Dungeon" then
		local def = Dungeons.List[payload.Dungeon]
		UIKit.Label(list, def.DisplayName, { TextSize = 24, Font = T.FontBlack, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 30) })
		UIKit.Label(
			list,
			string.format("Requires level %d  •  1-4 players  •  Time limit %s", def.LevelRequired, Format.Time(def.TimeLimit)),
			{ TextSize = 13, TextColor3 = T.SubText }
		)
		UIKit.Label(list, "Lobby → Wave room → Elite room → Miniboss → Boss → Reward chest", { TextSize = 13, Font = T.Font })
		local diffRow = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = list })
		UIKit.List(diffRow, Enum.FillDirection.Horizontal, 8)
		local buttons = {}
		for _, name in ipairs(Dungeons.DifficultyOrder) do
			local diff = Dungeons.Difficulties[name]
			buttons[name] = UIKit.Button(
				diffRow,
				string.format("%s (x%.1f)", name, diff.Rewards),
				{ Size = UDim2.fromOffset(170, 38), TextColor3 = diff.Color },
				function()
					selectedDifficulty = name
					for n, b in pairs(buttons) do
						b.BackgroundColor3 = n == name and T.Accent or T.PanelLight
					end
				end
			)
		end
		buttons[selectedDifficulty].BackgroundColor3 = T.Accent
		UIKit.Button(list, "Create Party", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Good }, function()
			if invoke("Dungeon", "Create", payload.Dungeon, selectedDifficulty) then
				closeGate()
			end
		end)
	else
		local def = Raids[payload.Raid]
		UIKit.Label(list, def.DisplayName, { TextSize = 24, Font = T.FontBlack, TextColor3 = T.Gold, Size = UDim2.new(1, 0, 0, 30) })
		UIKit.Label(
			list,
			string.format("Requires level %d  •  up to 8 players  •  Revive fallen allies (hold E)", def.LevelRequired),
			{ TextSize = 13, TextColor3 = T.SubText }
		)
		UIKit.Label(
			list,
			"Mechanics: destroy the Eclipse Crystals to break the shield, hide in the light during the Eclipse.",
			{ TextSize = 13, Font = T.Font, Size = UDim2.new(1, 0, 0, 36) }
		)
		UIKit.Button(list, "Create Raid Party", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Good }, function()
			if invoke("Raid", "Create") then
				closeGate()
			end
		end)
	end
	UIKit.Label(list, "OPEN PARTIES", { TextSize = 15, Font = T.FontBlack })
	if #payload.Lobbies == 0 then
		UIKit.Label(list, "None - create one!", { TextSize = 13, TextColor3 = T.SubText })
	end
	for _, lobby in ipairs(payload.Lobbies) do
		UIKit.Button(
			list,
			string.format(
				"Join %s's party  (%d players%s)  - %ds",
				lobby.Host,
				#lobby.Members,
				lobby.Difficulty and (", " .. lobby.Difficulty) or "",
				lobby.Countdown
			),
			{ Size = UDim2.new(1, 0, 0, 38) },
			function()
				if invoke(kind, "Join", lobby.LobbyId) then
					closeGate()
				end
			end
		)
	end
	UIKit.Open(gateWindow)
	ClientRegistry.Get("InputController").GameplayBlocked = true
end

local function showLobby(payload)
	lobbyType = payload.Type
	lobbyPanel.Visible = true
	lobbyLabel.Text = string.format(
		"%s%s\nParty (%d): %s\nStarting in %ds",
		payload.Name,
		payload.Difficulty and (" - " .. payload.Difficulty) or "",
		#payload.Members,
		table.concat(payload.Members, ", "),
		payload.Countdown
	)
end

function InstanceUI:Init()
	screen = UIKit.Screen("DungeonUI", 15)
	local content
	gateWindow, content = UIKit.Window(screen, "GATE", UDim2.fromOffset(640, 500), closeGate)
	gateBody = content
	lobbyPanel = UIKit.Panel(
		screen,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 40), Size = UDim2.fromOffset(330, 150), Visible = false }
	)
	lobbyLabel = UIKit.Label(
		lobbyPanel,
		"",
		{ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 80), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top }
	)
	lobbyButtons = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 38), Parent = lobbyPanel }
	)
	UIKit.List(lobbyButtons, Enum.FillDirection.Horizontal, 8)
	UIKit.Button(lobbyButtons, "Start Now", { Size = UDim2.fromOffset(145, 36), BackgroundColor3 = T.Good }, function()
		invoke(lobbyType, "Start")
	end)
	UIKit.Button(lobbyButtons, "Leave", { Size = UDim2.fromOffset(145, 36), BackgroundColor3 = T.Bad }, function()
		invoke(lobbyType, "Leave")
		lobbyPanel.Visible = false
	end)
	timerLabel = UIKit.Label(screen, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(300, 30),
		TextSize = 22,
		Font = T.FontBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
	})

	local hud = function()
		return ClientRegistry.Get("HUD")
	end
	Net.Event("InstanceState").OnClientEvent:Connect(function(kind, payload)
		if kind == "OpenGate" then
			openGate(payload)
		elseif kind == "Lobby" then
			showLobby(payload)
		elseif kind == "LobbyClosed" then
			lobbyPanel.Visible = false
		elseif kind == "Start" then
			lobbyPanel.Visible = false
			hud():Banner(string.upper(payload.Name), payload.Difficulty or "RAID", T.Accent)
		elseif kind == "Room" then
			hud():Banner(payload.Text or "", payload.Kind or "", payload.Kind == "Boss" and T.Bad or T.Gold)
		elseif kind == "Timer" then
			timerLabel.Text = "⏱ " .. Format.Time(payload.Remaining)
			timerLabel.TextColor3 = payload.Remaining < 60 and T.Bad or T.Text
		elseif kind == "Mechanic" then
			hud():Banner("⚠ " .. payload.Text, nil, payload.Color or T.Bad)
			if payload.Darkness then
				VFXLib.ColorCorrection({ Brightness = -0.35, Contrast = 0.3, Saturation = -0.5 }, payload.Darkness, 0.5)
			end
		elseif kind == "End" then
			timerLabel.Text = ""
			hud():Banner(payload.Success and "VICTORY!" or "DEFEAT", payload.Name, payload.Success and T.Gold or T.Bad)
		end
	end)
end

return InstanceUI
