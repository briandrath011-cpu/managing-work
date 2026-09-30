--[[
	InputController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.InputController
	One place that turns keyboard / mouse / gamepad / touch into named ACTIONS
	(bindings in Modules.Config.InputConfig). Other controllers listen with:
		InputController:OnAction("Dash", function(began) ... end)
	Mobile buttons call InputController:Trigger(action, began).
	Gamepad modifier (hold LB) switches face buttons to weapon skills.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(ReplicatedStorage.Modules.Config.InputConfig)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local InputController = {}
InputController.ActionSignals = {} :: { [string]: any }
InputController.Held = {} :: { [string]: boolean }
InputController.Blocked = false -- true while menus with text input are focused
InputController.GameplayBlocked = false -- true while a full-screen menu is open

local ALWAYS_ALLOWED = { Menu = true, Map = true, Spin = true }

function InputController:GetSignal(action: string)
	local signal = self.ActionSignals[action]
	if not signal then
		signal = Signal.new()
		self.ActionSignals[action] = signal
	end
	return signal
end

function InputController:OnAction(action: string, fn: (boolean) -> ())
	return self:GetSignal(action):Connect(fn)
end

function InputController:Trigger(action: string, began: boolean)
	if began and self.GameplayBlocked and not ALWAYS_ALLOWED[action] then
		return
	end
	if self.Held[action] == began then
		return
	end
	self.Held[action] = began
	self:GetSignal(action):Fire(began)
end

function InputController:IsHeld(action: string): boolean
	return self.Held[action] == true
end

local function matchesKey(def, input: InputObject): boolean
	for _, key in ipairs(def.Keys) do
		if input.KeyCode == key or input.UserInputType == key then
			return true
		end
	end
	return false
end

local function modifierHeld(): boolean
	return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1)
end

local function handle(input: InputObject, processed: boolean, began: boolean)
	if InputController.Blocked then
		return
	end
	local isGamepad = input.UserInputType.Name:find("Gamepad") ~= nil
	for action, def in pairs(InputConfig.Actions) do
		local match = false
		if isGamepad then
			if table.find(def.Gamepad, input.KeyCode) then
				if def.GamepadModifier then
					match = modifierHeld() or not began
				else
					-- Face buttons with a modifier variant only fire without the modifier.
					match = not (
						began
						and modifierHeld()
						and (
							input.KeyCode == Enum.KeyCode.ButtonX
							or input.KeyCode == Enum.KeyCode.ButtonY
							or input.KeyCode == Enum.KeyCode.ButtonB
							or input.KeyCode == Enum.KeyCode.ButtonR3
						)
					)
				end
			end
		elseif matchesKey(def, input) then
			-- Ignore keys typed into chat / text boxes, but mouse clicks on UI too.
			match = not processed or not began
		end
		if match then
			if def.Toggle and began then
				InputController:Trigger(action, not InputController.Held[action])
			elseif not def.Toggle then
				InputController:Trigger(action, began)
			end
		end
	end
end

function InputController:Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		handle(input, processed, true)
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		handle(input, processed, false)
	end)
	UserInputService.TextBoxFocused:Connect(function()
		self.Blocked = true
	end)
	UserInputService.TextBoxFocusReleased:Connect(function()
		self.Blocked = false
	end)
end

return InputController
