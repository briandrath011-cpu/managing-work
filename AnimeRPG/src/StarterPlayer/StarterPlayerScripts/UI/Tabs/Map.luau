--[[
	Map tab (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.UI.Tabs.Map
	PHASE 33 / 34 - World map: regions (undiscovered ones stay hidden), boss locations,
	dungeon gates, raid gate, fast travel waypoints (click to travel once discovered),
	quest areas for active kill quests and your own position.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayerScripts = script.Parent.Parent.Parent

local WorldConfig = require(ReplicatedStorage.Modules.World.WorldConfig)
local BossCatalog = require(ReplicatedStorage.Modules.Bosses.BossCatalog)
local Dungeons = require(ReplicatedStorage.Modules.World.Dungeons)
local QuestCatalog = require(ReplicatedStorage.Modules.Quests.QuestCatalog)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)

local MapTab = {}
MapTab.__index = MapTab

local T = UIKit.Theme
local WORLD_MIN = Vector2.new(-1300, -420)
local WORLD_MAX = Vector2.new(1300, 1300)

local function toMap(position: Vector3): UDim2
	local x = (position.X - WORLD_MIN.X) / (WORLD_MAX.X - WORLD_MIN.X)
	local y = (position.Z - WORLD_MIN.Y) / (WORLD_MAX.Y - WORLD_MIN.Y)
	return UDim2.fromScale(math.clamp(x, 0, 1), math.clamp(y, 0, 1))
end

function MapTab.new(frame: Frame)
	local self = setmetatable({ Frame = frame }, MapTab)
	self.Canvas = UIKit.New(
		"Frame",
		{ BackgroundColor3 = Color3.fromRGB(18, 40, 60), Size = UDim2.new(1, -220, 1, 0), ClipsDescendants = true, Parent = frame }
	)
	UIKit.Corner(self.Canvas, 12)
	UIKit.Stroke(self.Canvas, T.Accent, 1.5, 0.4)
	self.Legend = UIKit.Panel(frame, { Position = UDim2.new(1, -210, 0, 0), Size = UDim2.new(0, 210, 1, 0) })
	UIKit.Padding(self.Legend, 10)
	UIKit.List(self.Legend, nil, 6)
	UIKit.Label(self.Legend, "LEGEND", { Font = T.FontBlack, TextColor3 = T.Accent })
	UIKit.Label(self.Legend, "◆ Waypoint (click to travel)", { TextSize = 12, TextColor3 = Color3.fromRGB(90, 200, 255) })
	UIKit.Label(self.Legend, "☠ Boss", { TextSize = 12, TextColor3 = Color3.fromRGB(255, 90, 90) })
	UIKit.Label(self.Legend, "▣ Dungeon / Raid", { TextSize = 12, TextColor3 = Color3.fromRGB(190, 120, 255) })
	UIKit.Label(self.Legend, "◎ Quest area", { TextSize = 12, TextColor3 = Color3.fromRGB(255, 220, 90) })
	UIKit.Label(self.Legend, "▲ You", { TextSize = 12, TextColor3 = Color3.new(1, 1, 1) })
	self.Info = UIKit.Label(self.Legend, "", { TextSize = 12, Font = T.Font, TextColor3 = T.SubText, Size = UDim2.new(1, 0, 0, 120) })
	self.PlayerMarker = nil
	RunService.RenderStepped:Connect(function()
		if self.PlayerMarker and frame.Visible then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				self.PlayerMarker.Position = toMap(root.Position)
				local look = root.CFrame.LookVector
				self.PlayerMarker.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
		end
	end)
	return self
end

local function marker(parent: Instance, position: Vector3, text: string, color: Color3, size: number?): TextButton
	local button = UIKit.New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(position),
		Size = UDim2.fromOffset(size or 20, size or 20),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextSize = size or 18,
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		ZIndex = 5,
		Parent = parent,
	})
	return button
end

function MapTab:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	UIKit.Clear(self.Canvas)
	local discovered = data.Discovered
	for _, region in ipairs(WorldConfig.Regions) do
		local known = discovered.Regions[region.Id] == true
		local topLeft = toMap(region.Center - region.Size / 2)
		local bottomRight = toMap(region.Center + region.Size / 2)
		local box = UIKit.New("Frame", {
			Position = topLeft,
			Size = UDim2.fromScale(bottomRight.X.Scale - topLeft.X.Scale, bottomRight.Y.Scale - topLeft.Y.Scale),
			BackgroundColor3 = known and region.Theme.Color or Color3.fromRGB(40, 40, 50),
			BackgroundTransparency = known and 0.2 or 0.05,
			Parent = self.Canvas,
		})
		UIKit.Corner(box, 10)
		UIKit.Stroke(box, known and Color3.new(1, 1, 1) or T.SubText, 1, 0.6)
		UIKit.Label(
			box,
			known and string.format("%s\nLv. %d-%d", region.DisplayName, region.LevelRange[1], region.LevelRange[2]) or "???",
			{
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromOffset(0, 6),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 13,
				Font = T.FontBlack,
				TextStrokeTransparency = 0.3,
				ZIndex = 2,
			}
		)
	end
	local function regionKnown(position: Vector3): boolean
		local region = WorldConfig.RegionAt(position)
		return region ~= nil and discovered.Regions[region.Id] == true
	end
	for _, boss in ipairs(WorldConfig.Bosses) do
		if regionKnown(boss.Position) then
			local def = BossCatalog[boss.Boss]
			local m = marker(self.Canvas, boss.Position, "☠", Color3.fromRGB(255, 90, 90))
			m.MouseEnter:Connect(function()
				self.Info.Text = string.format("%s\nLevel %d%s", def.DisplayName, def.Level, def.NightOnly and "\nOnly at night" or "")
			end)
		end
	end
	for _, gate in ipairs(WorldConfig.DungeonGates) do
		if regionKnown(gate.Position) then
			local def = Dungeons.List[gate.Dungeon]
			local m = marker(self.Canvas, gate.Position, "▣", Color3.fromRGB(190, 120, 255))
			m.MouseEnter:Connect(function()
				self.Info.Text = string.format("Dungeon: %s\nRequires level %d", def.DisplayName, def.LevelRequired)
			end)
		end
	end
	if regionKnown(WorldConfig.RaidGate.Position) then
		marker(self.Canvas, WorldConfig.RaidGate.Position, "▣", Color3.fromRGB(255, 190, 60))
	end
	-- Quest areas: spawners of enemies needed by active kill quests
	for questId in pairs(data.Quests.Active) do
		local def = QuestCatalog.Get(questId)
		if def then
			for _, objective in ipairs(def.Objectives) do
				if objective.Kind == "Kill" and objective.Target ~= "Any" then
					for _, spawner in ipairs(WorldConfig.EnemySpawns) do
						if spawner.Enemy == objective.Target then
							marker(self.Canvas, spawner.Center, "◎", Color3.fromRGB(255, 220, 90), 22)
						end
					end
				end
			end
		end
	end
	for _, waypoint in ipairs(WorldConfig.Waypoints) do
		local known = discovered.Waypoints[waypoint.Id] == true
		if known or regionKnown(waypoint.Position) then
			local m =
				marker(self.Canvas, waypoint.Position, "◆", known and Color3.fromRGB(90, 200, 255) or Color3.fromRGB(90, 90, 110), 22)
			m.Selectable = true
			m.MouseEnter:Connect(function()
				self.Info.Text = waypoint.DisplayName .. (known and "\nClick to fast travel" or "\nNot discovered yet")
			end)
			m.Activated:Connect(function()
				if not known then
					ClientRegistry.Get("HUD"):Toast("Discover this waypoint first", "Error")
					return
				end
				local ok, err = Net.Invoke("FastTravel", waypoint.Id)
				if ok then
					ClientRegistry.Get("Menu"):Close()
				elseif err then
					ClientRegistry.Get("HUD"):Toast(err, "Error")
				end
			end)
		end
	end
	self.PlayerMarker = marker(self.Canvas, Vector3.zero, "▲", Color3.new(1, 1, 1), 18)
end

return MapTab
