--[[
	BossUI (ModuleScript) -> ScreenGui "BossUI"
	Location: StarterPlayer.StarterPlayerScripts.UI.BossUI
	PHASE 13 - Boss intro card + camera pan, big boss health bar with phase pips,
	enrage indicator, "DEFEATED" screen. Also switches to boss music.
	Remote: BossUI (server -> client) "Intro" | "Update" | "Phase" | "Hide" | "Defeated"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local Format = require(ReplicatedStorage.Modules.Shared.Format)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local UIKit = require(StarterPlayerScripts.ClientModules.UIKit)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)

local BossUI = {}

local T = UIKit.Theme
local screen: ScreenGui
local barFrame: Frame
local nameLabel: TextLabel
local setBar: (number, string?) -> ()
local phaseLabel: TextLabel
local currentModel: Model? = nil

local function showBar(visible: boolean)
	if barFrame.Visible == visible then
		return
	end
	barFrame.Visible = visible
	if visible then
		barFrame.Position = UDim2.new(0.5, 0, 0, -80)
		UIKit.Tween(barFrame, 0.4, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	end
end

local function intro(payload)
	local model: Model? = payload.Model
	local card = UIKit.New(
		"Frame",
		{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromOffset(900, 150),
			Parent = screen,
		}
	)
	local strip = UIKit.New(
		"Frame",
		{
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.25,
			Size = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			BorderSizePixel = 0,
			Parent = card,
		}
	)
	UIKit.Gradient(strip, payload.Color or T.Bad, Color3.new(0, 0, 0), 0)
	local title = UIKit.Label(
		card,
		string.upper(payload.Name),
		{
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 70),
			TextSize = 56,
			Font = T.FontBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			TextTransparency = 1,
		}
	)
	local sub = UIKit.Label(
		card,
		"LEVEL " .. tostring(payload.Level) .. "  •  BOSS",
		{
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = payload.Color or T.Bad,
			TextTransparency = 1,
		}
	)
	UIKit.Tween(strip, 0.35, { Size = UDim2.new(1, 0, 1, 0) })
	task.delay(0.2, function()
		UIKit.Tween(title, 0.3, { TextTransparency = 0 })
		UIKit.Tween(sub, 0.4, { TextTransparency = 0 })
	end)
	-- Short camera pan toward the boss
	local camera = Workspace.CurrentCamera
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if camera and root then
		local original = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		local start = camera.CFrame
		local focus = root.Position + Vector3.new(0, 4, 0)
		local goal = CFrame.lookAt(focus + root.CFrame.LookVector * 22 + Vector3.new(0, 6, 0), focus)
		local tween = TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
		tween:Play()
		task.delay(2.2, function()
			local back = TweenService:Create(camera, TweenInfo.new(0.4), { CFrame = start })
			back:Play()
			back.Completed:Wait()
			camera.CameraType = original == Enum.CameraType.Scriptable and Enum.CameraType.Custom or original
		end)
	end
	VFXLib.ScreenFlashLocal(payload.Color or T.Bad, 0.4, 0.5)
	ClientRegistry.Get("CameraController"):Shake(0.6, 0.6)
	task.delay(2.6, function()
		UIKit.Tween(title, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		UIKit.Tween(sub, 0.3, { TextTransparency = 1 })
		UIKit.Tween(strip, 0.3, { BackgroundTransparency = 1 })
		task.delay(0.35, function()
			card:Destroy()
		end)
	end)
end

function BossUI:Init()
	screen = UIKit.Screen("BossUI", 8)
	barFrame = UIKit.Panel(
		screen,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(640, 64), Visible = false }
	)
	nameLabel = UIKit.Label(
		barFrame,
		"",
		{ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -140, 0, 24), TextSize = 18, Font = T.FontBlack }
	)
	phaseLabel = UIKit.Label(
		barFrame,
		"",
		{
			Position = UDim2.new(1, -130, 0, 4),
			Size = UDim2.fromOffset(118, 24),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = T.SubText,
		}
	)
	local _, setter = UIKit.Bar(barFrame, T.Health, { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 22) })
	setBar = setter
	local remote = Net.Event("BossUI")
	local audio = function()
		return ClientRegistry.Get("AudioController")
	end
	remote.OnClientEvent:Connect(function(action, payload)
		if action == "Intro" then
			intro(payload)
			audio():SetOverride("Boss", payload.Music or "Boss_World")
		elseif action == "Update" then
			currentModel = payload.Model
			showBar(true)
			nameLabel.Text = string.format("%s  [Lv. %d]", payload.Name, payload.Level or 0)
			setBar(
				payload.Health / math.max(1, payload.MaxHealth),
				string.format("%s / %s", Format.Short(payload.Health), Format.Short(payload.MaxHealth))
			)
			phaseLabel.Text = payload.Enraged and "ENRAGED" or ("Phase " .. tostring(payload.Phase))
			phaseLabel.TextColor3 = payload.Enraged and T.Bad or T.SubText
			if payload.Music then
				audio():SetOverride("Boss", payload.Music)
			end
		elseif action == "Phase" then
			ClientRegistry.Get("HUD")
				:Banner(payload.Enraged and "ENRAGED!" or ("PHASE " .. payload.Phase), nil, payload.Enraged and T.Bad or T.Gold)
		elseif action == "Hide" then
			if payload.Model == currentModel then
				showBar(false)
				audio():SetOverride("Boss", nil)
			end
		elseif action == "Defeated" then
			showBar(false)
			audio():SetOverride("Boss", nil)
			ClientRegistry.Get("HUD"):Banner("BOSS DEFEATED", payload.Name, T.Gold)
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		showBar(false)
		audio():SetOverride("Boss", nil)
	end)
end

return BossUI
