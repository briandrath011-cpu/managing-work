--[[
	PowerService (ModuleScript)
	Location: ServerScriptService.Services.PowerService

	PHASE 5 / 6 - Power framework + skill execution for BOTH powers and weapon skills.
	Remotes:
		UseSkill (RemoteEvent)        (source "Power"|"Weapon", slot, aimPosition)
		PowerAction (RemoteFunction)  ("Equip", uid) ("Unequip") ("Lock", uid) ("Delete", uid) ("UpgradeStorage")
	Server validates: ownership, mastery unlock, cooldown (incl. cooldown reduction), energy,
	stun/lock state and aim range (clamped) before the skill runs.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Progression = require(Modules.Config.Progression)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local SkillContext = require(ServerScriptService.ServerModules.SkillContext)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local PowerService = {}
PowerService.SkillUsed = Signal.new() -- (player, source, skillName, isUltimate)

local cooldowns: { [Player]: { [string]: number } } = {}
local skillLimiter = RateLimiter.new(10, 5)
local actionLimiter = RateLimiter.new(10, 4)
local dirtyMastery: { [Player]: boolean } = {}

local function dataService()
	return Registry.Get("PlayerDataService")
end

function PowerService:GetEquippedPower(player: Player)
	local data = dataService():Get(player)
	if not data then
		return nil
	end
	local owned = data.Powers.Owned[data.Powers.EquippedUid]
	if not owned then
		return nil
	end
	local def = PowerRegistry.Get(owned.Id)
	if not def then
		return nil
	end
	local record = data.PowerMastery[owned.Id]
	return def, record and record.Level or 0
end

function PowerService:AddMastery(player: Player, powerId: string, amount: number)
	local data = dataService():Get(player)
	local def = PowerRegistry.Get(powerId)
	if not data or not def then
		return
	end
	local record = data.PowerMastery[powerId]
	if not record then
		record = { Level = 0, Exp = 0 }
		data.PowerMastery[powerId] = record
	end
	local old = record.Level
	record.Level, record.Exp = Progression.ApplyMasteryExp(record.Level, record.Exp, amount)
	if record.Level > old then
		for slot, required in ipairs(def.MasteryUnlocks) do
			if old < required and record.Level >= required then
				Registry.Get("FXService")
					:Notify(
						player,
						"Unlock",
						string.format("%s Mastery %d: unlocked %s!", def.DisplayName, required, def.Skills[slot].Name)
					)
			end
		end
	end
	dirtyMastery[player] = true
end

-- Adds mastery to the currently equipped power (used by kills / quests).
function PowerService:AddEquippedMastery(player: Player, amount: number)
	local def = self:GetEquippedPower(player)
	if def then
		self:AddMastery(player, def.Id, amount)
	end
end

function PowerService:GetCooldownLeft(player: Player, key: string): number
	local list = cooldowns[player]
	return list and math.max(0, (list[key] or 0) - os.clock()) or 0
end

local function clampAim(root: BasePart, aim: Vector3, range: number): Vector3
	local offset = aim - root.Position
	local maxRange = range + GameConfig.Combat.MaxSkillRangeTolerance
	if offset.Magnitude > maxRange then
		return root.Position + offset.Unit * maxRange
	end
	return aim
end

-- Resolves + validates a skill. Returns skill, contextOptions, cooldownKey or nil, reason.
function PowerService:ResolveSkill(player: Player, source: string, slot: number)
	if source == "Power" then
		local def, mastery = self:GetEquippedPower(player)
		if not def then
			return nil, "No power equipped"
		end
		local skill = def.Skills[slot]
		if not skill then
			return nil, "Invalid slot"
		end
		if not PowerRegistry.IsSkillUnlocked(def, slot, mastery) then
			return nil, string.format("Requires %s mastery %d", def.DisplayName, def.MasteryUnlocks[slot])
		end
		return skill,
			{
				Source = "Power",
				SourceId = def.Id,
				Mastery = mastery,
				Color = def.Color,
				Color2 = def.SecondaryColor,
				DamageType = "Power",
				Scaling = "Energy",
				SourceMultiplier = def.DamageMultiplier,
			},
			"Power" .. slot
	elseif source == "Weapon" then
		local skill, info, required = Registry.Get("WeaponService"):GetSkill(player, slot)
		if not skill then
			return nil, "No weapon skill"
		end
		if info.Mastery < required then
			return nil, string.format("Requires %s mastery %d", info.Def.DisplayName, required)
		end
		-- Weapon skills scale with the weapon's damage (normalised so rare weapons matter but don't explode).
		local classMult = info.Class.DamageMultiplier * math.clamp(info.Def.Damage / 50, 0.4, 3.5)
		return skill,
			{
				Source = "Weapon",
				SourceId = info.Def.Id,
				Mastery = info.Mastery,
				Color = info.Def.Glow or info.Def.Accent or info.Def.Color,
				Color2 = info.Def.Color,
				DamageType = "Weapon",
				Scaling = info.Class.ScalesWithEnergy and "Energy" or "Weapon",
				SourceMultiplier = classMult,
				OnHit = info.Def.Passive and info.Def.Passive.OnHit or nil,
			},
			"Weapon" .. slot
	end
	return nil, "Invalid source"
end

function PowerService:UseSkill(player: Player, source: string, slot: number, aim: Vector3): (boolean, string?)
	local entity = EntityRegistry.GetForPlayer(player)
	if not entity or not EntityRegistry.CanAct(entity) then
		return false, "Can't act"
	end
	local skill, options, key = self:ResolveSkill(player, source, slot)
	if not skill then
		return false, options
	end
	local now = os.clock()
	cooldowns[player] = cooldowns[player] or {}
	if now < (cooldowns[player][key] or 0) - 0.15 then
		return false, "On cooldown"
	end
	local characterService = Registry.Get("CharacterService")
	local cost = skill.EnergyCost or 0
	if not characterService:SpendEnergy(player, cost) then
		Registry.Get("FXService"):Notify(player, "Error", "Not enough energy")
		return false, "Not enough energy"
	end
	local mods = entity.Modifiers
	local cooldown = (skill.Cooldown or 5) * (1 - (mods.CooldownReduction or 0))
	if entity.Model:GetAttribute("Transformed") then
		cooldown *= 0.85
	end
	cooldowns[player][key] = now + cooldown
	Registry.Get("FXService"):PlayFor(player, "SkillCooldown", { Key = key, Duration = cooldown })

	options.Entity = entity
	options.Skill = skill
	options.AimPosition = clampAim(entity.Root, aim, skill.Range or 30)
	local ctx = SkillContext.new(options)
	entity.State.ActionLockUntil = math.max(entity.State.ActionLockUntil, now + (skill.CastLock or 0.35))
	entity.State.Blocking = false
	entity.Model:SetAttribute("Blocking", false)

	task.spawn(function()
		local ok, err = pcall(skill.Execute, ctx)
		if not ok then
			warn(string.format("[PowerService] Skill %s errored: %s", tostring(skill.Name), tostring(err)))
		end
	end)

	if source == "Power" then
		self:AddMastery(player, options.SourceId, skill.Ultimate and 6 or 2)
	else
		Registry.Get("WeaponService"):AddMastery(player, options.SourceId, skill.Ultimate and 6 or 3)
	end
	self.SkillUsed:Fire(player, source, skill.Name, skill.Ultimate == true)
	return true
end

-- POWER INVENTORY ------------------------------------------------------------------------------

local function onPowerAction(player: Player, action: any, uid: any): (boolean, any)
	if not actionLimiter:Check(player) then
		return false, "Slow down"
	end
	local data = dataService():Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local powers = data.Powers
	if action == "Equip" then
		if not Validate.String(uid, 32) or not powers.Owned[uid] then
			return false, "Power not found"
		end
		powers.EquippedUid = uid
		cooldowns[player] = {}
	elseif action == "Unequip" then
		powers.EquippedUid = ""
	elseif action == "Lock" then
		local owned = Validate.String(uid, 32) and powers.Owned[uid]
		if not owned then
			return false, "Power not found"
		end
		owned.Locked = not owned.Locked
	elseif action == "Delete" then
		local owned = Validate.String(uid, 32) and powers.Owned[uid]
		if not owned then
			return false, "Power not found"
		end
		if owned.Locked then
			return false, "Power is locked"
		end
		if powers.EquippedUid == uid then
			return false, "Unequip it first"
		end
		powers.Owned[uid] = nil
		local def = PowerRegistry.Get(owned.Id)
		local refund = def and GameConfig.Spins.GoldConversion[def.Rarity] or 0
		if refund > 0 then
			dataService():AddCurrency(player, "Gold", refund)
		end
	elseif action == "UpgradeStorage" then
		local S = GameConfig.Spins
		if powers.StorageSlots >= S.MaxStorageSlots then
			return false, "Storage is maxed"
		end
		if not dataService():SpendCurrency(player, "Gems", S.StorageUpgradeGemCost) then
			return false, "Need " .. S.StorageUpgradeGemCost .. " Gems"
		end
		powers.StorageSlots = math.min(S.MaxStorageSlots, powers.StorageSlots + S.StorageUpgradeSlots)
	else
		return false, "Unknown action"
	end
	dataService():Replicate(player, "Powers")
	return true
end

function PowerService:Init()
	Net.Event("UseSkill").OnServerEvent:Connect(function(player, source, slot, aim)
		if not skillLimiter:Check(player) then
			return
		end
		if (source ~= "Power" and source ~= "Weapon") or not Validate.Integer(slot, 1, source == "Power" and 4 or 3) then
			return
		end
		if not Validate.Vector3(aim, 1e5) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				return
			end
			aim = root.Position + root.CFrame.LookVector * 20
		end
		PowerService:UseSkill(player, source, slot, aim)
	end)
	Net.Function("PowerAction").OnServerInvoke = onPowerAction
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		dirtyMastery[player] = nil
	end)
end

function PowerService:Start()
	while true do
		task.wait(1)
		for player in pairs(dirtyMastery) do
			dirtyMastery[player] = nil
			if player.Parent then
				dataService():Replicate(player, "PowerMastery")
			end
		end
	end
end

return PowerService
