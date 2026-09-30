--[[
	SpinMenu (ModuleScript) -> ScreenGui "SpinMenu"
	Location: StarterPlayer.StarterPlayerScripts.UI.SpinMenu

	PHASE 7 - Power spin UI. The RESULT always comes from the server (Spin RemoteFunction);
	this module only animates it:
	- 1x spin: a reel of power cards that decelerates onto the result
	- 10x spin: cards flip one by one
	- Skip button / "Skip spin animation" setting
	- Rarity effects, special Mythic + Secret reveals (flash, shake, glow)
	Open with P, the HUD "Spin" button, the Powers tab, or the Oracle NPC.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayerScripts = script.Parent.Parent

local Modules = ReplicatedStorage.Modules
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local RarityConfig = require(Modules.Config.RarityConfig)
local GameConfig = require(Modules.Config.GameConfig)
local Net = require(Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)

local SpinMenu = {}

local T = UIKit.Theme
local screen: ScreenGui
local window: Frame
local stage: Frame
local infoLabel: TextLabel
local pityLabel: TextLabel
local skipButton: TextButton
local spinning = false
local skipRequested = false

local allPowers = {}
for _, def in pairs(PowerRegistry.All()) do
	table.insert(allPowers, def)
end
table.sort(allPowers, function(a, b)
	return a.Id < b.Id
end)

local function card(parent: Instance, def, size: Vector2): Frame
	local color = RarityConfig.GetColor(def.Rarity)
	local frame = UIKit.New("Frame", { BackgroundColor3 = T.PanelDark, Size = UDim2.fromOffset(size.X, size.Y), Parent = parent })
	UIKit.Corner(frame, 12)
	UIKit.Stroke(frame, color, 3, 0)
	UIKit.Gradient(frame, color:Lerp(Color3.new(0, 0, 0), 0.55), T.PanelDark, 90)
	local orb = UIKit.New(
		"Frame",
		{
			BackgroundColor3 = def.Color,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(size.X * 0.45, size.X * 0.45),
			Parent = frame,
		}
	)
	UIKit.Corner(orb, 999)
	UIKit.Gradient(orb, def.Color:Lerp(Color3.new(1, 1, 1), 0.4), def.SecondaryColor or def.Color, 45)
	UIKit.Label(
		frame,
		def.DisplayName,
		{
			Position = UDim2.new(0, 6, 1, -54),
			Size = UDim2.new(1, -12, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 15,
			Font = T.FontBlack,
			TextColor3 = color,
		}
	)
	UIKit.Label(
		frame,
		string.upper(def.Rarity),
		{
			Position = UDim2.new(0, 6, 1, -28),
			Size = UDim2.new(1, -12, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 12,
			TextColor3 = T.SubText,
		}
	)
	return frame
end

local function specialReveal(rarity: string, def)
	local style = RarityConfig.RevealStyle[rarity]
	local color = RarityConfig.GetColor(rarity)
	if style.Flash then
		VFXLib.ScreenFlashLocal(color, style.Duration * 0.4, 0.3)
	end
	if style.Shake > 0 then
		ClientRegistry.Get("CameraController"):Shake(style.Shake, style.Duration * 0.4)
	end
	if style.Special then
		SoundLib.Play(style.Special == "Secret" and "SecretReveal" or "MythicReveal")
		local banner = UIKit.Label(screen, style.Special == "Secret" and "✦ SECRET ✦" or "MYTHIC!", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(800, 110),
			TextSize = 90,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			TextStrokeTransparency = 0,
			ZIndex = 20,
		})
		local scale = UIKit.New("UIScale", { Scale = 3, Parent = banner })
		UIKit.Tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		if style.Special == "Secret" then
			-- Rainbow cycle for secrets
			local start = os.clock()
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local t = os.clock() - start
				if t > style.Duration or not banner.Parent then
					connection:Disconnect()
					return
				end
				banner.TextColor3 = Color3.fromHSV((t * 0.6) % 1, 0.7, 1)
			end)
		end
		task.delay(style.Duration, function()
			UIKit.Tween(banner, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(0.45, function()
				banner:Destroy()
			end)
		end)
	else
		SoundLib.Play("SpinReveal")
	end
	local _ = def
end

local function waitOrSkip(seconds: number)
	local start = os.clock()
	while os.clock() - start < seconds and not skipRequested do
		task.wait()
	end
end

-- Single spin reel animation.
local function animateSingle(result)
	UIKit.Clear(stage)
	local target = PowerRegistry.Get(result.PowerId)
	local reel = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), Parent = stage })
	local cardWidth, gap = 150, 14
	local count = 40
	local cards = {}
	for i = 1, count do
		local def = i == count - 3 and target or allPowers[math.random(1, #allPowers)]
		local c = card(reel, def, Vector2.new(cardWidth, 210))
		c.Position = UDim2.fromOffset((i - 1) * (cardWidth + gap), 20)
		cards[i] = c
	end
	local stageWidth = stage.AbsoluteSize.X > 0 and stage.AbsoluteSize.X or 900
	local finalX = -((count - 4) * (cardWidth + gap)) + stageWidth / 2 - cardWidth / 2
	local pointer = UIKit.New(
		"Frame",
		{
			BackgroundColor3 = T.Gold,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(0, 4, 1, -8),
			ZIndex = 10,
			Parent = stage,
		}
	)
	local _ = pointer
	local duration = 3.2
	local start = os.clock()
	local lastIndex = 0
	while os.clock() - start < duration and not skipRequested do
		local t = (os.clock() - start) / duration
		local eased = 1 - (1 - t) ^ 3
		local x = finalX * eased
		reel.Position = UDim2.fromOffset(x, 0)
		local index = math.floor(-x / (cardWidth + gap))
		if index ~= lastIndex then
			lastIndex = index
			SoundLib.Play("SpinTick", nil, 0.3, 1 + t * 0.5)
		end
		RunService.RenderStepped:Wait()
	end
	reel.Position = UDim2.fromOffset(finalX, 0)
	local winner = cards[count - 3]
	local scale = UIKit.New("UIScale", { Parent = winner })
	UIKit.Tween(scale, 0.35, { Scale = 1.15 }, Enum.EasingStyle.Back)
	specialReveal(result.Rarity, target)
end

local function animateMulti(results)
	UIKit.Clear(stage)
	local grid = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = stage })
	UIKit.Grid(grid, UDim2.fromOffset(150, 120), 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	UIKit.Padding(grid, 8)
	local best = results[1]
	for _, result in ipairs(results) do
		if (RarityConfig.Rank[result.Rarity] or 0) > (RarityConfig.Rank[best.Rarity] or 0) then
			best = result
		end
	end
	for index, result in ipairs(results) do
		local def = PowerRegistry.Get(result.PowerId)
		local c = card(grid, def, Vector2.new(150, 120))
		c.LayoutOrder = index
		local cover = UIKit.New("Frame", { BackgroundColor3 = T.PanelLight, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = c })
		UIKit.Corner(cover, 12)
		UIKit.Label(
			cover,
			"?",
			{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 40, Font = T.FontBlack, ZIndex = 6 }
		)
		if result.Converted then
			UIKit.Label(
				c,
				"→ Gold",
				{ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 16), TextSize = 11, TextColor3 = T.Gold, ZIndex = 4 }
			)
		end
		task.spawn(function()
			waitOrSkip(0.25 * index)
			UIKit.Tween(cover, 0.2, { BackgroundTransparency = 1 })
			for _, d in ipairs(cover:GetDescendants()) do
				if d:IsA("TextLabel") then
					d.TextTransparency = 1
				end
			end
			if not skipRequested then
				SoundLib.Play("SpinTick", nil, 0.4, 1 + index * 0.05)
			end
		end)
	end
	waitOrSkip(0.25 * #results + 0.3)
	specialReveal(best.Rarity, PowerRegistry.Get(best.PowerId))
end

function SpinMenu:Refresh()
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return
	end
	infoLabel.Text = string.format("Spins: %d     Gems: %d     Storage: %d slots", data.Spins, data.Gems, data.Powers.StorageSlots)
	local parts = {}
	for _, rule in ipairs(RarityConfig.Pity) do
		table.insert(parts, string.format("%s pity %d/%d", rule.Rarity, data.Pity[rule.Rarity] or 0, rule.Threshold))
	end
	pityLabel.Text = table.concat(parts, "   •   ")
end

function SpinMenu:Spin(count: number, withGems: boolean)
	if spinning then
		return
	end
	spinning = true
	skipRequested = ClientRegistry.Get("SettingsController").Settings.SkipSpinAnimation
	skipButton.Visible = true
	local ok, result = Net.Invoke("Spin", count, withGems)
	if not ok then
		ClientRegistry.Get("HUD"):Toast(result or "Spin failed", "Error")
		spinning = false
		skipButton.Visible = false
		return
	end
	if count == 1 then
		animateSingle(result.Results[1])
	else
		animateMulti(result.Results)
	end
	for _, entry in ipairs(result.Results) do
		local def = PowerRegistry.Get(entry.PowerId)
		ClientRegistry.Get("HUD"):Toast(
			string.format(
				"%s%s (%s)%s",
				entry.PityHit and "[PITY] " or "",
				def.DisplayName,
				entry.Rarity,
				entry.Converted and " → Gold" or ""
			),
			"Drop",
			RarityConfig.GetColor(entry.Rarity)
		)
	end
	skipButton.Visible = false
	spinning = false
	self:Refresh()
end

function SpinMenu:Open()
	UIKit.Open(window)
	ClientRegistry.Get("InputController").GameplayBlocked = true
	self:Refresh()
end

function SpinMenu:Close()
	window.Visible = false
	ClientRegistry.Get("InputController").GameplayBlocked = false
end

function SpinMenu:Init()
	screen = UIKit.Screen("SpinMenu", 25)
	local content
	window, content = UIKit.Window(screen, "POWER SPIN", UDim2.fromOffset(980, 560), function()
		SpinMenu:Close()
	end)
	infoLabel = UIKit.Label(content, "", { Size = UDim2.new(1, 0, 0, 24), TextSize = 16 })
	pityLabel = UIKit.Label(
		content,
		"",
		{ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 20), TextSize = 12, TextColor3 = T.SubText, Font = T.Font }
	)
	stage = UIKit.New(
		"Frame",
		{
			BackgroundColor3 = T.PanelDark,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 260),
			ClipsDescendants = true,
			Parent = content,
		}
	)
	UIKit.Corner(stage, 12)
	UIKit.Label(
		stage,
		"Spin to discover your power!",
		{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, TextColor3 = T.SubText }
	)
	local buttons = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 44), Parent = content }
	)
	UIKit.List(buttons, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	UIKit.Button(buttons, "SPIN x1", { Size = UDim2.fromOffset(160, 44), BackgroundColor3 = T.Accent, LayoutOrder = 1 }, function()
		task.spawn(SpinMenu.Spin, SpinMenu, 1, false)
	end)
	UIKit.Button(buttons, "SPIN x10", { Size = UDim2.fromOffset(160, 44), BackgroundColor3 = T.Accent2, LayoutOrder = 2 }, function()
		task.spawn(SpinMenu.Spin, SpinMenu, 10, false)
	end)
	UIKit.Button(
		buttons,
		"x1 (" .. GameConfig.Spins.SpinGemCost .. " Gems)",
		{ Size = UDim2.fromOffset(170, 44), LayoutOrder = 3 },
		function()
			task.spawn(SpinMenu.Spin, SpinMenu, 1, true)
		end
	)
	UIKit.Button(
		buttons,
		"x10 (" .. GameConfig.Spins.TenSpinGemCost .. " Gems)",
		{ Size = UDim2.fromOffset(180, 44), LayoutOrder = 4 },
		function()
			task.spawn(SpinMenu.Spin, SpinMenu, 10, true)
		end
	)
	skipButton = UIKit.Button(
		content,
		"SKIP ▶▶",
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 58),
			Size = UDim2.fromOffset(110, 34),
			BackgroundColor3 = T.Bad,
			Visible = false,
			ZIndex = 20,
		},
		function()
			skipRequested = true
		end
	)
	-- Chances
	local chances = UIKit.New(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 376), Size = UDim2.new(1, 0, 0, 90), Parent = content }
	)
	UIKit.List(chances, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	for index, rarity in ipairs(RarityConfig.Order) do
		local chip = UIKit.Panel(chances, { Size = UDim2.fromOffset(140, 74), LayoutOrder = index })
		local stroke = chip:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = RarityConfig.GetColor(rarity)
		end
		UIKit.Label(
			chip,
			rarity,
			{
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(1, 0, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = RarityConfig.GetColor(rarity),
			}
		)
		UIKit.Label(
			chip,
			RarityConfig.SpinChances[rarity] .. "%",
			{
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 18,
				Font = T.FontBlack,
			}
		)
		local names = {}
		for _, def in ipairs(PowerRegistry.ByRarity(rarity)) do
			table.insert(names, def.DisplayName)
		end
		UIKit.Label(
			chip,
			table.concat(names, ", "),
			{
				Position = UDim2.fromOffset(4, 48),
				Size = UDim2.new(1, -8, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 10,
				Font = T.Font,
				TextColor3 = T.SubText,
			}
		)
	end
	ClientRegistry.Get("InputController"):OnAction("Spin", function(began)
		if began then
			if window.Visible then
				SpinMenu:Close()
			else
				SpinMenu:Open()
			end
		end
	end)
	ClientRegistry.Get("DataController").Changed:Connect(function(key)
		if window.Visible and not spinning and (key == "Spins" or key == "Gems" or key == "Pity" or key == "Powers") then
			SpinMenu:Refresh()
		end
	end)
end

return SpinMenu
