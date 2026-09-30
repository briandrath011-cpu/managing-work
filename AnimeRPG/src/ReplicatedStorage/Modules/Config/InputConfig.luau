--[[
	InputConfig (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.InputConfig
	One binding table for PC, console and mobile. InputController reads this.
	Each action: Keys (keyboard/mouse), Gamepad (buttons), Touch (show mobile button), Label, GamepadModifier.
]]
local InputConfig = {}

InputConfig.Actions = {
	M1 = { Keys = { Enum.UserInputType.MouseButton1 }, Gamepad = { Enum.KeyCode.ButtonR2 }, Touch = true, Label = "Attack" },
	Heavy = { Keys = { Enum.KeyCode.R }, Gamepad = { Enum.KeyCode.ButtonR1 }, Touch = true, Label = "Heavy" },
	Block = { Keys = { Enum.KeyCode.F }, Gamepad = { Enum.KeyCode.ButtonL2 }, Touch = true, Label = "Block" },
	Dash = { Keys = { Enum.KeyCode.Q }, Gamepad = { Enum.KeyCode.ButtonB }, Touch = true, Label = "Dash" },
	Sprint = { Keys = { Enum.KeyCode.LeftShift }, Gamepad = { Enum.KeyCode.ButtonL3 }, Touch = true, Label = "Sprint", Toggle = true },
	Skill1 = { Keys = { Enum.KeyCode.One }, Gamepad = { Enum.KeyCode.DPadUp }, Touch = true, Label = "1" },
	Skill2 = { Keys = { Enum.KeyCode.Two }, Gamepad = { Enum.KeyCode.DPadRight }, Touch = true, Label = "2" },
	Skill3 = { Keys = { Enum.KeyCode.Three }, Gamepad = { Enum.KeyCode.DPadDown }, Touch = true, Label = "3" },
	Skill4 = { Keys = { Enum.KeyCode.Four }, Gamepad = { Enum.KeyCode.DPadLeft }, Touch = true, Label = "4" },
	-- Weapon skills: keyboard Z/X/C, gamepad hold L1 + X/Y/B
	WeaponSkill1 = {
		Keys = { Enum.KeyCode.Z },
		Gamepad = { Enum.KeyCode.ButtonX },
		GamepadModifier = Enum.KeyCode.ButtonL1,
		Touch = true,
		Label = "Z",
	},
	WeaponSkill2 = {
		Keys = { Enum.KeyCode.X },
		Gamepad = { Enum.KeyCode.ButtonY },
		GamepadModifier = Enum.KeyCode.ButtonL1,
		Touch = true,
		Label = "X",
	},
	WeaponSkill3 = {
		Keys = { Enum.KeyCode.C },
		Gamepad = { Enum.KeyCode.ButtonB },
		GamepadModifier = Enum.KeyCode.ButtonL1,
		Touch = true,
		Label = "C",
	},
	Transform = {
		Keys = { Enum.KeyCode.G },
		Gamepad = { Enum.KeyCode.ButtonR3 },
		GamepadModifier = Enum.KeyCode.ButtonL1,
		Touch = true,
		Label = "Awaken",
	},
	Flight = { Keys = { Enum.KeyCode.H }, Gamepad = { Enum.KeyCode.ButtonY }, Touch = false, Label = "Fly" },
	Menu = { Keys = { Enum.KeyCode.M }, Gamepad = { Enum.KeyCode.ButtonSelect }, Touch = true, Label = "Menu" },
	Map = { Keys = { Enum.KeyCode.N }, Gamepad = {}, Touch = false, Label = "Map" },
	Spin = { Keys = { Enum.KeyCode.P }, Gamepad = {}, Touch = false, Label = "Spin" },
	LockOn = { Keys = { Enum.KeyCode.T }, Gamepad = { Enum.KeyCode.ButtonR3 }, Touch = true, Label = "Lock" },
}

-- Text shown in ability slots per platform.
InputConfig.GamepadGlyphs = {
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.ButtonL2] = "LT",
	[Enum.KeyCode.ButtonR2] = "RT",
	[Enum.KeyCode.ButtonL3] = "LS",
	[Enum.KeyCode.ButtonR3] = "RS",
	[Enum.KeyCode.DPadUp] = "D↑",
	[Enum.KeyCode.DPadDown] = "D↓",
	[Enum.KeyCode.DPadLeft] = "D←",
	[Enum.KeyCode.DPadRight] = "D→",
	[Enum.KeyCode.ButtonSelect] = "View",
	[Enum.KeyCode.ButtonStart] = "Menu",
}

function InputConfig.KeyboardLabel(action: string): string
	local def = InputConfig.Actions[action]
	if not def or not def.Keys[1] then
		return ""
	end
	local key = def.Keys[1]
	if key == Enum.UserInputType.MouseButton1 then
		return "LMB"
	end
	local name = key.Name
	local digits = { One = "1", Two = "2", Three = "3", Four = "4" }
	return digits[name] or (name == "LeftShift" and "Shift" or name)
end

function InputConfig.GamepadLabel(action: string): string
	local def = InputConfig.Actions[action]
	if not def or not def.Gamepad[1] then
		return ""
	end
	local glyph = InputConfig.GamepadGlyphs[def.Gamepad[1]] or def.Gamepad[1].Name
	if def.GamepadModifier then
		return (InputConfig.GamepadGlyphs[def.GamepadModifier] or "") .. "+" .. glyph
	end
	return glyph
end

return InputConfig
