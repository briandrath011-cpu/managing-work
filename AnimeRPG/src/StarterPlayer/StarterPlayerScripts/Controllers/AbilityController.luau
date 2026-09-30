--[[
	AbilityController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.AbilityController

	PHASE 5-9 - Client side of skills. Keys 1-4 = power skills (4 = Ultimate),
	Z/X/C = weapon skills (C = weapon ultimate). Gamepad: D-Pad / LB + X,Y,B. Mobile: HUD buttons.
	Aiming: lock-on target > mouse position (PC) > auto-aim at the nearest enemy in front
	(console / mobile) > straight ahead. The server clamps range and validates everything.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local PowerRegistry = require(ReplicatedStorage.Modules.Powers.PowerRegistry)
local ItemUtil = require(ReplicatedStorage.Modules.Items.ItemUtil)
local WeaponSkills = require(ReplicatedStorage.Modules.Weapons.WeaponSkills)
local WeaponClasses = require(ReplicatedStorage.Modules.Weapons.WeaponClasses)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local Platform = require(StarterPlayerScripts.ClientModules.Platform)

local AbilityController = {}
AbilityController.CooldownStarted = Signal.new() -- (key, duration)

local player = Players.LocalPlayer
local cooldowns: { [string]: { Ends: number, Duration: number } } = {}
local skillRemote: RemoteEvent

function AbilityController:GetCooldown(key: string): (number, number)
	local entry = cooldowns[key]
	if not entry then
		return 0, 1
	end
	return math.max(0, entry.Ends - os.clock()), entry.Duration
end

function AbilityController:SetCooldown(key: string, duration: number)
	cooldowns[key] = { Ends = os.clock() + duration, Duration = duration }
	self.CooldownStarted:Fire(key, duration)
end

-- Returns (skillDef, unlocked, requiredMastery) for HUD + input validation.
function AbilityController:GetSkillInfo(source: string, slot: number)
	local data = ClientRegistry.Get("DataController"):Get()
	if not data then
		return nil, false, 0
	end
	if source == "Power" then
		local owned = data.Powers.Owned[data.Powers.EquippedUid]
		local power = owned and PowerRegistry.Get(owned.Id)
		if not power then
			return nil, false, 0
		end
		local mastery = data.PowerMastery[power.Id] and data.PowerMastery[power.Id].Level or 0
		local required = power.MasteryUnlocks[slot]
		return power.Skills[slot], mastery >= required, required, power
	end
	local uid = data.Equipment.Weapon
	local entry = uid ~= "" and data.Inventory[uid]
	if not entry then
		return nil, false, 0
	end
	local skillId = ItemUtil.GetWeaponSkills(entry.Id)[slot]
	local mastery = data.WeaponMastery[entry.Id] and data.WeaponMastery[entry.Id].Level or 0
	local required = WeaponClasses.MasteryUnlocks[slot]
	return skillId and WeaponSkills[skillId], mastery >= required, required, ItemUtil.Get(entry.Id)
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function AbilityController:GetAimPosition(range: number): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Vector3.zero
	end
	local cameraController = ClientRegistry.Get("CameraController")
	local lock = cameraController.LockTarget
	if lock and lock:FindFirstChild("HumanoidRootPart") then
		return (lock.HumanoidRootPart :: BasePart).Position
	end
	local camera = Workspace.CurrentCamera
	if Platform.Get() == "PC" and camera then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		aimParams.FilterDescendantsInstances = { character :: Model, Workspace:FindFirstChild("Effects") or character :: Model }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, aimParams)
		local point = hit and hit.Position or (ray.Origin + ray.Direction * 400)
		if (point - root.Position).Magnitude > range then
			point = root.Position + (point - root.Position).Unit * range
		end
		return point
	end
	-- Console / mobile: auto-aim at the nearest enemy in front
	local target = cameraController:FindNearestEnemy(math.max(range, 20), true)
	if target then
		return (target:FindFirstChild("HumanoidRootPart") :: BasePart).Position
	end
	local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or root.CFrame.LookVector
	return root.Position + flat * math.min(range, 30)
end

function AbilityController:Use(source: string, slot: number)
	local character = player.Character
	if not character or character:GetAttribute("Stunned") or character:GetAttribute("Frozen") or character:GetAttribute("Downed") then
		return
	end
	local skill, unlocked, required = self:GetSkillInfo(source, slot)
	local hud = ClientRegistry.Get("HUD")
	if not skill then
		hud:Toast(source == "Power" and "No power equipped - spin at the Oracle!" or "Equip a weapon first", "Error")
		return
	end
	if not unlocked then
		hud:Toast(string.format("%s unlocks at mastery %d", skill.Name, required), "Error")
		return
	end
	local key = source .. slot
	local remaining = self:GetCooldown(key)
	if remaining > 0.1 then
		return
	end
	local energy = character:GetAttribute("Energy") or 0
	if energy < (skill.EnergyCost or 0) then
		hud:Toast("Not enough energy", "Error")
		return
	end
	-- Optimistic cooldown; the server sends the exact value (SkillCooldown FX).
	self:SetCooldown(key, skill.Cooldown or 5)
	skillRemote:FireServer(source, slot, self:GetAimPosition(skill.Range or 30))
end

function AbilityController:Init()
	skillRemote = Net.Event("UseSkill")
	local input = ClientRegistry.Get("InputController")
	for slot = 1, 4 do
		input:OnAction("Skill" .. slot, function(began)
			if began then
				self:Use("Power", slot)
			end
		end)
	end
	for slot = 1, 3 do
		input:OnAction("WeaponSkill" .. slot, function(began)
			if began then
				self:Use("Weapon", slot)
			end
		end)
	end
end

return AbilityController
