--[[
	CombatServer (ModuleScript)
	Location: ServerScriptService.Services.CombatServer

	PHASE 3 - M1 Combat + Block + Dash (server authority)
	Actions from clients (RemoteEvent "CombatAction"):
		"M1"         { Air: bool, Launcher: bool }   4-hit combo, finisher / launcher / downslam
		"Heavy"      {}                             guard-breaking heavy attack
		"BlockStart" / "BlockEnd"                   block + perfect block window
		"Counter"    {}                             block + heavy = counter stance
		"Dash"       { Direction: "Front"|"Side"|"Back"|"Air" }
	The same functions are used by enemy/boss AI, so NPCs fight with identical rules.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local FightingStyles = require(Modules.Combat.FightingStyles)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Hitbox = require(ServerScriptService.ServerModules.Hitbox)
local Motion = require(ServerScriptService.ServerModules.Motion)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local CombatServer = {}
CombatServer.AttackStarted = Signal.new() -- (attackerEntity, kind) - AI listens to block/dodge

local CB = GameConfig.Combat
local limiter = RateLimiter.new(30, 18)

-- Resolves what the entity attacks with: equipped weapon or fighting style (or NPC definition).
function CombatServer:GetAttackProfile(entity)
	if entity.Player then
		local weaponInfo = Registry.Get("WeaponService"):GetEquipped(entity.Player)
		if weaponInfo then
			return {
				Kind = "Weapon",
				Id = weaponInfo.Def.Id,
				Damage = weaponInfo.Def.Damage * weaponInfo.Class.DamageMultiplier,
				HeavyMultiplier = weaponInfo.Class.HeavyMultiplier,
				AttackSpeed = weaponInfo.Class.AttackSpeed,
				Range = weaponInfo.Class.Range,
				Scaling = "Weapon",
				DamageType = "Weapon",
				Mastery = weaponInfo.Mastery,
				Color = weaponInfo.Def.Glow or weaponInfo.Def.Accent or weaponInfo.Def.Color,
				OnHit = weaponInfo.Def.Passive and weaponInfo.Def.Passive.OnHit or nil,
				CritBonus = weaponInfo.Class.CritBonus,
				HeavyEffect = "GuardBreak",
				ClassName = weaponInfo.Def.Class,
			}
		end
		local data = Registry.Get("PlayerDataService"):Get(entity.Player)
		local style = FightingStyles[data and data.FightingStyle or "Brawler"] or FightingStyles.Brawler
		return {
			Kind = "Style",
			Id = style.Id,
			-- Styles grow with level so unarmed builds stay viable.
			Damage = style.Damage * (1 + entity.Level / 40),
			HeavyMultiplier = style.HeavyDamage / style.Damage,
			AttackSpeed = style.AttackSpeed,
			Range = style.Range,
			Scaling = "Strength",
			DamageType = "Style",
			Mastery = 0,
			Color = style.Color,
			HeavyEffect = style.HeavyEffect,
			ClassName = "Fist",
		}
	end
	local def = entity.Definition or {}
	return {
		Kind = "NPC",
		Id = def.Id or "NPC",
		Damage = def.Damage or 8,
		HeavyMultiplier = 2.2,
		AttackSpeed = def.AttackSpeed or 0.9,
		Range = def.Range or 6,
		Scaling = nil,
		DamageType = "True",
		Mastery = 0,
		Color = def.AttackColor or Color3.new(1, 1, 1),
		HeavyEffect = "Knockback",
		ClassName = def.WeaponClass or "Fist",
	}
end

local function swingFx(entity, profile, combo: number, heavy: boolean)
	Registry.Get("FXService"):Play("Swing", {
		Model = entity.Model,
		Combo = combo,
		Color = profile.Color,
		Class = profile.ClassName,
		Heavy = heavy,
	}, entity.Root.Position)
end

local function stopBlocking(entity)
	if entity.State.Blocking then
		entity.State.Blocking = false
		entity.Model:SetAttribute("Blocking", false)
	end
end

-- Returns true if the M1 was accepted.
function CombatServer:PerformM1(entity, payload: { [string]: any }?): boolean
	if not EntityRegistry.CanAct(entity) then
		return false
	end
	local state = entity.State
	local profile = self:GetAttackProfile(entity)
	local now = os.clock()
	local cooldown = CB.M1BaseCooldown / math.max(0.3, profile.AttackSpeed)
	local tolerance = entity.Player and 0.8 or 1
	if now - state.LastM1 < cooldown * tolerance then
		return false
	end
	if state.Combo >= CB.M1ComboLength and now - state.LastM1 < CB.M1FinisherEndLag * tolerance then
		return false
	end
	if now - state.LastM1 > CB.ComboResetTime or state.Combo >= CB.M1ComboLength then
		state.Combo = 0
	end
	state.Combo += 1
	state.LastM1 = now
	stopBlocking(entity)
	local combo = state.Combo
	local finisher = combo == CB.M1ComboLength
	self.AttackStarted:Fire(entity, "M1")
	swingFx(entity, profile, combo, false)

	local range = profile.Range
	local cf = entity.Root.CFrame * CFrame.new(0, 0, -range / 2)
	local targets = Hitbox.Box(entity, cf, Vector3.new(range * 0.9, 7, range))
	if #targets == 0 then
		return true
	end
	-- Only the closest target is hit by normal M1s (keeps combos readable); finisher hits all.
	if not finisher then
		table.sort(targets, function(a, b)
			return (a.Root.Position - entity.Root.Position).Magnitude < (b.Root.Position - entity.Root.Position).Magnitude
		end)
		targets = { targets[1] }
	end

	local p = payload or {}
	local airborne = entity.Humanoid.FloorMaterial == Enum.Material.Air
	for _, target in ipairs(targets) do
		local info = {
			Base = profile.Damage * (finisher and 1.6 or 1),
			Kind = "M1",
			DamageType = profile.DamageType,
			Scaling = profile.Scaling,
			Mastery = profile.Mastery,
			Color = profile.Color,
			OnHit = profile.OnHit,
			CritBonus = profile.CritBonus,
			Stun = finisher and 0.8 or 0.5,
			GuardDamage = finisher and 20 or 10,
		}
		if finisher then
			if p.Launcher == true and not airborne then
				info.Up = 60
				info.Launch = true
				if entity.Player then
					Motion.Launch(entity, 58)
				end
			elseif airborne or p.Air == true then
				info.Downslam = true
				info.Ragdoll = 0.8
			else
				info.Knockback = 45
				info.Up = 8
			end
		elseif airborne and target.Humanoid.FloorMaterial == Enum.Material.Air then
			-- Air combo: keep both juggled
			info.Up = 14
		end
		local dealt = Registry.Get("DamageService"):Deal(entity, target, info)
		if dealt > 0 and entity.Player and profile.Kind == "Weapon" then
			Registry.Get("WeaponService"):AddMastery(entity.Player, profile.Id, finisher and 2 or 1)
		end
	end
	return true
end

function CombatServer:PerformHeavy(entity): boolean
	if not EntityRegistry.CanAct(entity) then
		return false
	end
	local state = entity.State
	local now = os.clock()
	if now - state.LastHeavy < CB.HeavyCooldown * (entity.Player and 0.85 or 1) then
		return false
	end
	state.LastHeavy = now
	stopBlocking(entity)
	local profile = self:GetAttackProfile(entity)
	self.AttackStarted:Fire(entity, "Heavy")
	swingFx(entity, profile, 5, true)
	state.ActionLockUntil = now + 0.45
	task.wait(0.35) -- wind-up (can be interrupted by stun)
	if not EntityRegistry.IsAlive(entity) or EntityRegistry.IsStunned(entity) then
		return false
	end
	local range = profile.Range + 1
	local cf = entity.Root.CFrame * CFrame.new(0, 0, -range / 2)
	Registry.Get("FXService"):Play("Shockwave", { Position = cf.Position, Color = profile.Color, Size = 10 }, cf.Position)
	for _, target in ipairs(Hitbox.Box(entity, cf, Vector3.new(range, 7, range))) do
		local info = {
			Base = profile.Damage * profile.HeavyMultiplier,
			Kind = "Heavy",
			DamageType = profile.DamageType,
			Scaling = profile.Scaling,
			Mastery = profile.Mastery,
			Color = profile.Color,
			OnHit = profile.OnHit,
			Stun = 1,
			GuardDamage = 60,
			Knockback = 70,
			Up = 12,
			Heavy = true,
		}
		if profile.HeavyEffect == "GuardBreak" then
			info.GuardBreak = true
		elseif profile.HeavyEffect == "Launch" then
			info.Knockback = nil
			info.Up = 70
			info.Launch = true
		elseif profile.HeavyEffect == "Pull" then
			info.Knockback = nil
			info.Pull = entity.Root.Position + entity.Root.CFrame.LookVector * 3
		end
		local dealt = Registry.Get("DamageService"):Deal(entity, target, info)
		if dealt > 0 and entity.Player and profile.Kind == "Weapon" then
			Registry.Get("WeaponService"):AddMastery(entity.Player, profile.Id, 3)
		end
	end
	return true
end

function CombatServer:SetBlocking(entity, blocking: boolean)
	if blocking then
		if not EntityRegistry.CanAct(entity) or entity.State.Guard <= 5 then
			return
		end
		entity.State.Blocking = true
		entity.State.BlockStart = os.clock()
		entity.Model:SetAttribute("Blocking", true)
	else
		stopBlocking(entity)
	end
end

function CombatServer:PerformCounter(entity): boolean
	local state = entity.State
	local now = os.clock()
	if not EntityRegistry.CanAct(entity) or now - (state.Cooldowns.Counter or 0) < CB.CounterCooldown then
		return false
	end
	state.Cooldowns.Counter = now
	stopBlocking(entity)
	local profile = self:GetAttackProfile(entity)
	state.CounterUntil = now + 0.45
	Registry.Get("FXService"):Play("CounterReady", { Model = entity.Model, Color = profile.Color, Duration = 0.45 }, entity.Root.Position)
	state.CounterCallback = function(attacker)
		if not EntityRegistry.IsAlive(entity) or not EntityRegistry.IsAlive(attacker) then
			return
		end
		Motion.Teleport(entity, CFrame.lookAt((attacker.Root.CFrame * CFrame.new(0, 0, 4)).Position, attacker.Root.Position))
		Registry.Get("FXService")
			:Play("Slash", { CFrame = attacker.Root.CFrame, Color = profile.Color, Size = 10, Heavy = true }, attacker.Root.Position)
		Registry.Get("DamageService"):Deal(entity, attacker, {
			Base = profile.Damage * 2.5,
			Kind = "Heavy",
			DamageType = profile.DamageType,
			Scaling = profile.Scaling,
			Mastery = profile.Mastery,
			Color = profile.Color,
			Stun = 1.2,
			Knockback = 50,
			Unblockable = true,
			Heavy = true,
		})
	end
	return true
end

function CombatServer:PerformDash(entity, direction: string): boolean
	local state = entity.State
	local now = os.clock()
	local cooldown = entity.Model:GetAttribute("DashCooldown") or GameConfig.Movement.DashCooldown
	if not EntityRegistry.CanAct(entity) or now - state.LastDash < cooldown * 0.8 then
		return false
	end
	state.LastDash = now
	stopBlocking(entity)
	state.IFramesUntil = math.max(state.IFramesUntil, now + 0.12)
	if entity.Player then
		Registry.Get("MovementValidator")
			:GrantAllowance(entity.Player, GameConfig.Movement.DashSpeed, GameConfig.Movement.DashDuration + 0.6)
	end
	Registry.Get("FXService"):Play("DashFX", { Model = entity.Model, Direction = direction }, entity.Root.Position)
	return true
end

-- REMOTE -------------------------------------------------------------------------------------------

local ACTIONS = { "M1", "Heavy", "BlockStart", "BlockEnd", "Counter", "Dash" }
local DASH_DIRECTIONS = { "Front", "Side", "Back", "Air" }

local function onCombatAction(player: Player, action: any, payload: any)
	if not limiter:Check(player) then
		return
	end
	if not Validate.OneOf(action, ACTIONS) then
		return
	end
	local entity = EntityRegistry.GetForPlayer(player)
	if not entity or not EntityRegistry.IsAlive(entity) then
		return
	end
	local p = type(payload) == "table" and payload or {}
	if action == "M1" then
		CombatServer:PerformM1(entity, { Air = p.Air == true, Launcher = p.Launcher == true })
	elseif action == "Heavy" then
		CombatServer:PerformHeavy(entity)
	elseif action == "BlockStart" then
		CombatServer:SetBlocking(entity, true)
	elseif action == "BlockEnd" then
		CombatServer:SetBlocking(entity, false)
	elseif action == "Counter" then
		CombatServer:PerformCounter(entity)
	elseif action == "Dash" then
		local dir = Validate.OneOf(p.Direction, DASH_DIRECTIONS) and p.Direction or "Front"
		CombatServer:PerformDash(entity, dir)
	end
end

function CombatServer:Init()
	Net.Event("CombatAction").OnServerEvent:Connect(function(player, action, payload)
		task.spawn(onCombatAction, player, action, payload)
	end)
end

function CombatServer:Start()
	-- Shared state tick for every entity (players + NPCs). One loop, 10 Hz.
	local TICK = 0.1
	while true do
		task.wait(TICK)
		local now = os.clock()
		for model, entity in pairs(EntityRegistry.All()) do
			if model.Parent then
				local state = entity.State
				local stunned = now < state.StunnedUntil
				if model:GetAttribute("Stunned") ~= stunned then
					model:SetAttribute("Stunned", stunned)
				end
				if not state.Blocking and state.Guard < CB.MaxGuard then
					state.Guard = math.min(CB.MaxGuard, state.Guard + CB.GuardRegenPerSecond * TICK)
					model:SetAttribute("Guard", math.floor(state.Guard))
				end
				if state.Blocking and entity.Player then
					-- Blocking drains a little energy to stop infinite turtling.
					Registry.Get("CharacterService"):SpendEnergy(entity.Player, 0.2)
				end
			end
		end
	end
end

return CombatServer
