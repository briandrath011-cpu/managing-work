--[[
	UIKit (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.UIKit
	Small UI toolkit so every screen shares one modern anime-RPG style:
	dark glass panels, neon accents, rounded corners, animated buttons.
	Buttons are Selectable for gamepad navigation; all screens auto-scale for mobile.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RarityConfig = require(ReplicatedStorage.Modules.Config.RarityConfig)

local UIKit = {}

UIKit.Theme = {
	Background = Color3.fromRGB(12, 12, 20),
	Panel = Color3.fromRGB(22, 22, 36),
	PanelLight = Color3.fromRGB(34, 34, 54),
	PanelDark = Color3.fromRGB(14, 14, 24),
	Accent = Color3.fromRGB(120, 90, 255),
	Accent2 = Color3.fromRGB(255, 80, 140),
	Gold = Color3.fromRGB(255, 205, 80),
	Gem = Color3.fromRGB(90, 220, 255),
	Text = Color3.fromRGB(240, 240, 255),
	SubText = Color3.fromRGB(160, 160, 190),
	Good = Color3.fromRGB(90, 230, 130),
	Bad = Color3.fromRGB(255, 80, 90),
	Health = Color3.fromRGB(235, 60, 80),
	Energy = Color3.fromRGB(70, 170, 255),
	Exp = Color3.fromRGB(130, 255, 150),
	Awakening = Color3.fromRGB(255, 190, 60),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
	FontBlack = Enum.Font.GothamBlack,
}

local T = UIKit.Theme

function UIKit.RarityColor(rarity: string?): Color3
	return RarityConfig.GetColor(rarity or "Common")
end

-- Generic instance creator: UIKit.New("Frame", { Size = ..., Parent = ... }, { children })
function UIKit.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	return UIKit.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.New("UIStroke", {
		Color = color or T.Accent,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, px: number)
	return UIKit.New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.List(parent: Instance, direction: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return UIKit.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

function UIKit.Grid(parent: Instance, cell: UDim2, padding: number?): UIGridLayout
	return UIKit.New("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(padding or 8, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.Gradient(parent: Instance, a: Color3, b: Color3, rotation: number?): UIGradient
	return UIKit.New("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90, Parent = parent })
end

function UIKit.Tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween =
		TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.Panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(frame :: any)[key] = value
	end
	UIKit.Corner(frame, 12)
	UIKit.Stroke(frame, T.Accent, 1.2, 0.55)
	return frame
end

function UIKit.Label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UIKit.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = T.FontBold,
		TextColor3 = T.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(label :: any)[key] = value
	end
	return label
end

function UIKit.Button(parent: Instance, text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local color = (props and props.BackgroundColor3) or T.PanelLight
	local button = UIKit.New("TextButton", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = text,
		Font = T.FontBold,
		TextColor3 = T.Text,
		TextSize = 16,
		Size = UDim2.new(0, 140, 0, 38),
		Selectable = true,
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(button :: any)[key] = value
	end
	UIKit.Corner(button, 8)
	local stroke = UIKit.Stroke(button, T.Accent, 1.2, 0.5)
	local scale = UIKit.New("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.Tween(button, 0.12, { BackgroundColor3 = color:Lerp(T.Accent, 0.35) })
		UIKit.Tween(stroke, 0.12, { Transparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(button, 0.12, { BackgroundColor3 = color })
		UIKit.Tween(stroke, 0.12, { Transparency = 0.5 })
		UIKit.Tween(scale, 0.1, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		UIKit.Tween(stroke, 0.1, { Transparency = 0, Thickness = 2.5 })
	end)
	button.SelectionLost:Connect(function()
		UIKit.Tween(stroke, 0.1, { Transparency = 0.5, Thickness = 1.2 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.06, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1 })
	end)
	if onClick then
		button.Activated:Connect(function()
			UIKit.PlayClick()
			onClick()
		end)
	end
	return button
end

-- Set by SoundController so every button click can play a sound.
UIKit.ClickSound = nil :: (() -> ())?
function UIKit.PlayClick()
	if UIKit.ClickSound then
		UIKit.ClickSound()
	end
end

-- Progress bar. Returns frame + setter(ratio, text?)
function UIKit.Bar(parent: Instance, color: Color3, props: { [string]: any }?)
	local back = UIKit.New("Frame", {
		BackgroundColor3 = T.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 18),
		ClipsDescendants = true,
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(back :: any)[key] = value
	end
	UIKit.Corner(back, 6)
	UIKit.Stroke(back, color, 1, 0.6)
	local lag = UIKit.New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	})
	UIKit.Corner(lag, 6)
	local fill = UIKit.New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = back })
	UIKit.Corner(fill, 6)
	UIKit.Gradient(fill, color:Lerp(Color3.new(1, 1, 1), 0.25), color, 90)
	local label = UIKit.Label(back, "", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		ZIndex = 3,
		TextStrokeTransparency = 0.5,
	})
	local current = 1
	local function set(ratio: number, text: string?)
		ratio = math.clamp(ratio, 0, 1)
		if ratio < current then
			fill.Size = UDim2.fromScale(ratio, 1)
			UIKit.Tween(lag, 0.45, { Size = UDim2.fromScale(ratio, 1) })
		else
			UIKit.Tween(fill, 0.2, { Size = UDim2.fromScale(ratio, 1) })
			lag.Size = UDim2.fromScale(ratio, 1)
		end
		current = ratio
		if text then
			label.Text = text
		end
	end
	return back, set, label
end

function UIKit.Scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local scroll = UIKit.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = T.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(scroll :: any)[key] = value
	end
	return scroll
end

function UIKit.TextBox(parent: Instance, placeholder: string, props: { [string]: any }?): TextBox
	local box = UIKit.New("TextBox", {
		BackgroundColor3 = T.PanelDark,
		BorderSizePixel = 0,
		PlaceholderText = placeholder,
		PlaceholderColor3 = T.SubText,
		Text = "",
		Font = T.Font,
		TextSize = 15,
		TextColor3 = T.Text,
		ClearTextOnFocus = false,
		Size = UDim2.new(0, 200, 0, 32),
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(box :: any)[key] = value
	end
	UIKit.Corner(box, 8)
	UIKit.Stroke(box, T.Accent, 1, 0.6)
	UIKit.Padding(box, 6)
	return box
end

-- Full-screen ScreenGui with auto scaling (base 1280x720).
function UIKit.Screen(name: string, displayOrder: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local screen = UIKit.New("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 1,
		Parent = playerGui,
	})
	local uiScale = UIKit.New("UIScale", { Parent = screen })
	local function rescale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.35)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return screen
end

-- Centered window with title + close button. Returns window, content frame, close function, title label.
function UIKit.Window(screen: Instance, title: string, size: UDim2, onClose: (() -> ())?)
	local window = UIKit.Panel(screen, {
		Name = title .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
	})
	UIKit.Gradient(window, T.Panel, T.PanelDark, 90)
	local header =
		UIKit.New("Frame", { BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44), Parent = window })
	UIKit.Corner(header, 12)
	UIKit.Gradient(header, T.Accent, T.Accent2, 0)
	local titleLabel = UIKit.Label(
		header,
		title,
		{ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -70, 1, 0), TextSize = 20, Font = T.FontBlack }
	)
	local content = UIKit.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
		Parent = window,
	})
	local function close()
		window.Visible = false
		if onClose then
			onClose()
		end
	end
	UIKit.Button(header, "✕", { Size = UDim2.fromOffset(36, 32), Position = UDim2.new(1, -44, 0, 6), BackgroundColor3 = T.Bad }, close)
	return window, content, close, titleLabel
end

function UIKit.Open(window: GuiObject)
	window.Visible = true
	local scale = window:FindFirstChildOfClass("UIScale") or UIKit.New("UIScale", { Parent = window })
	scale.Scale = 0.85
	UIKit.Tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UIKit.Clear(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Slider 0-1. Returns frame, setter.
function UIKit.Slider(parent: Instance, label: string, value: number, onChanged: (number) -> ())
	local frame = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = parent })
	local text = UIKit.Label(frame, label, { Size = UDim2.new(1, 0, 0, 20) })
	local track = UIKit.New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.PanelDark,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -60, 0, 10),
		Parent = frame,
		Selectable = true,
	})
	UIKit.Corner(track, 5)
	local fill = UIKit.New("Frame", { BackgroundColor3 = T.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(value, 1), Parent = track })
	UIKit.Corner(fill, 5)
	local valueLabel = UIKit.Label(
		frame,
		string.format("%d%%", value * 100),
		{ Position = UDim2.new(1, -52, 0, 20), Size = UDim2.fromOffset(52, 20), TextXAlignment = Enum.TextXAlignment.Right }
	)
	local current = value
	local function set(v: number, fire: boolean?)
		current = math.clamp(math.floor(v * 20 + 0.5) / 20, 0, 1)
		fill.Size = UDim2.fromScale(current, 1)
		valueLabel.Text = string.format("%d%%", current * 100)
		if fire then
			onChanged(current)
		end
	end
	track.Activated:Connect(function(input)
		local x = input and input.Position and input.Position.X or 0
		local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		if not input or not input.Position then
			rel = current + 0.1
			if rel > 1.01 then
				rel = 0
			end
		end
		set(rel, true)
	end)
	text.Text = label
	return frame, set
end

function UIKit.Toggle(parent: Instance, label: string, value: boolean, onChanged: (boolean) -> ())
	local frame = UIKit.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = parent })
	UIKit.Label(frame, label, { Size = UDim2.new(1, -90, 1, 0) })
	local state = value
	local button
	button = UIKit.Button(
		frame,
		state and "ON" or "OFF",
		{ Position = UDim2.new(1, -80, 0, 2), Size = UDim2.fromOffset(80, 32), BackgroundColor3 = state and T.Good or T.PanelLight },
		function()
			state = not state
			button.Text = state and "ON" or "OFF"
			button.BackgroundColor3 = state and T.Good or T.PanelLight
			onChanged(state)
		end
	)
	return frame
end

return UIKit
