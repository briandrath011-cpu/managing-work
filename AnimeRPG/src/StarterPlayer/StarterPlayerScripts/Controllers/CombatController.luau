--[[
	CombatController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.CombatController

	PHASE 3 - Client side of M1 combat. Input -> instant local feedback (animation, weapon trail,
	small lunge) -> request to the server (CombatAction). The SERVER decides hits and damage.
	M1 (hold for auto-combo), Heavy, Block (hold), Counter (Block + Heavy), Transform.
	Launcher: hold Jump on the 4th hit. Downslam: 4th hit while airborne.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayerScripts = script.Parent.Parent

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local WeaponClasses = require(ReplicatedStorage.Modules.Weapons.WeaponClasses)
local FightingStyles = require(ReplicatedStorage.Modules.Combat.FightingStyles)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local AnimationLib = require(StarterPlayerScripts.ClientModules.AnimationLib)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local CombatController = {}

local CB = GameConfig.Combat
local player = Players.LocalPlayer
local combatRemote: RemoteEvent

local combo = 0
local lastM1 = 0
local lastHeavy = 0
local blocking = false

local function character(): Model?
	return player.Character
end

local function canAct(): boolean
	local char = character()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return not char:GetAttribute("Stunned")
		and not char:GetAttribute("Frozen")
		and not char:GetAttribute("Downed")
		and not char:GetAttribute("Ragdolled")
end

local function attackProfile()
	local char = character()
	local className = char and char:GetAttribute("WeaponClass")
	if className and WeaponClasses.List[className] then
		return WeaponClasses.List[className].AttackSpeed, "Blade", char:GetAttribute("WeaponColor")
	end
	local data = ClientRegistry.Get("DataController"):Get()
	local style = FightingStyles[data and data.FightingStyle or "Brawler"] or FightingStyles.Brawler
	return style.AttackSpeed, "Fist", style.Color
end

function CombatController:M1()
	if not canAct() or blocking then
		return
	end
	local speed, family, color = attackProfile()
	local now = os.clock()
	local cooldown = CB.M1BaseCooldown / speed
	if combo >= CB.M1ComboLength then
		cooldown = CB.M1FinisherEndLag
	end
	if now - lastM1 < cooldown then
		return
	end
	if now - lastM1 > CB.ComboResetTime or combo >= CB.M1ComboLength then
		combo = 0
	end
	combo += 1
	lastM1 = now
	local char = character() :: Model
	local humanoid = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	local launcher = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	combatRemote:FireServer("M1", { Air = airborne, Launcher = launcher and combo == CB.M1ComboLength })
	AnimationLib.Play(char, family .. "_M1_" .. combo, speed)
	VFXLib.WeaponTrail(char, color, 0.2)
	SoundLib.Play(family == "Blade" and "Slash" or "Punch", nil, 0.5)
	-- Small forward step for weight (not on the finisher of an air combo)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and not airborne then
		ClientRegistry.Get("MovementController"):ApplyVelocity(root.CFrame.LookVector * 14, 0.08)
	end
end

function CombatController:Heavy()
	if not canAct() then
		return
	end
	local now = os.clock()
	if blocking then
		-- Block + Heavy = Counter stance
		combatRemote:FireServer("Counter", {})
		VFXLib.Play("CounterReady", { Model = character(), Color = Color3.fromRGB(150, 220, 255), Duration = 0.45 })
		return
	end
	if now - lastHeavy < CB.HeavyCooldown then
		return
	end
	lastHeavy = now
	local _, _, color = attackProfile()
	combatRemote:FireServer("Heavy", {})
	local char = character() :: Model
	AnimationLib.Play(char, "Heavy", 1, 0.3)
	VFXLib.Play("Charge", { Model = char, Color = color or Color3.new(1, 1, 1), Duration = 0.35 })
	task.delay(0.3, function()
		VFXLib.WeaponTrail(char, color, 0.25)
		SoundLib.Play("Slash_Heavy", nil, 0.7)
	end)
	ClientRegistry.Get("AbilityController"):SetCooldown("Heavy", CB.HeavyCooldown)
end

function CombatController:SetBlocking(value: boolean)
	if value and not canAct() then
		return
	end
	if blocking == value then
		return
	end
	blocking = value
	combatRemote:FireServer(value and "BlockStart" or "BlockEnd", {})
	local char = character()
	if value and char then
		AnimationLib.Play(char, "Block", 1, 5)
	elseif char then
		AnimationLib.Reset(char)
	end
end

-- Hitstop: freeze our own animations for a few frames (feels like impact).
function CombatController:Hitstop(duration: number, shake: number?)
	local char = character()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local tracks = animator:GetPlayingAnimationTracks()
		for _, track in ipairs(tracks) do
			track:AdjustSpeed(0.05)
		end
		task.delay(duration, function()
			for _, track in ipairs(tracks) do
				track:AdjustSpeed(1)
			end
		end)
	end
	if shake then
		ClientRegistry.Get("CameraController"):Shake(shake, 0.12)
	end
end

function CombatController:Init()
	combatRemote = Net.Event("CombatAction")
	local input = ClientRegistry.Get("InputController")
	input:OnAction("M1", function(began)
		if began then
			self:M1()
		end
	end)
	input:OnAction("Heavy", function(began)
		if began then
			self:Heavy()
		end
	end)
	input:OnAction("Block", function(began)
		self:SetBlocking(began)
	end)
	input:OnAction("Transform", function(began)
		if began then
			local char = character()
			if char and (char:GetAttribute("Awakening") or 0) >= GameConfig.Transform.MaxAwakening then
				Net.Event("Transform"):FireServer()
			else
				ClientRegistry.Get("HUD"):Toast("Awakening bar is not full yet", "Error")
			end
		end
	end)
end

function CombatController:Start()
	-- Holding M1 keeps the combo going (great for mobile + controller).
	RunService.Heartbeat:Connect(function()
		local input = ClientRegistry.Get("InputController")
		if input:IsHeld("M1") then
			self:M1()
		end
		if blocking and not input:IsHeld("Block") then
			self:SetBlocking(false)
		end
	end)
	player.CharacterAdded:Connect(function()
		combo = 0
		blocking = false
	end)
end

return CombatController
