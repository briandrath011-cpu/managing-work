--[[
	Platform (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.Platform
	Detects PC / Console / Mobile and follows the LAST used input type, so controller
	glyphs appear as soon as a gamepad is used and touch buttons on phones/tablets.
]]
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(game:GetService("ReplicatedStorage").Modules.Shared.Signal)

local Platform = {}
Platform.Changed = Signal.new() -- (platform)

local function detect(inputType: Enum.UserInputType?): string
	if GuiService:IsTenFootInterface() then
		return "Console"
	end
	local t = inputType or UserInputService:GetLastInputType()
	if t.Name:find("Gamepad") then
		return "Console"
	end
	if t == Enum.UserInputType.Touch then
		return "Mobile"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return "Mobile"
	end
	return "PC"
end

Platform.Current = detect(nil)

-- True for phones/tablets even when a controller was used last (for quality defaults).
function Platform.IsMobileDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Platform.Get(): string
	return Platform.Current
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Focus or inputType == Enum.UserInputType.None then
		return
	end
	local new = detect(inputType)
	if new ~= Platform.Current then
		Platform.Current = new
		Platform.Changed:Fire(new)
	end
end)

return Platform
