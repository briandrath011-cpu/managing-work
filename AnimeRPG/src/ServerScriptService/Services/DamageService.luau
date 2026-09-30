--[[
	DamageService (ModuleScript)
	Location: ServerScriptService.Services.DamageService

	PHASE 4 - Damage. The ONLY place that lowers health in combat.
	Handles: counters, block / perfect block / guard break, crits, defense, lifesteal,
	stun, knockback, launch, pull, ragdoll, burn, weapon on-hit passives, awakening charge,
	damage numbers + hit feedback (spark, hitstop, camera shake).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local DamageFormula = require(Modules.Combat.DamageFormula)
local Modifiers = require(Modules.Combat.Modifiers)
local Signal = require(Modules.Shared.Signal)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)

local DamageService = {}
DamageService.Damaged = Signal.new() -- (attacker, target, amount, info, result)
DamageService.Killed = Signal.new() -- (attacker, target)

local CB = GameConfig.Combat
local rng = Random.new()

local TYPE_BONUS = {
	Power = "PowerDamage",
	Weapon = "WeaponDamage",
	Style = "StyleDamage",
}

local function fx(effect: string, params, position: Vector3?)
	Registry.Get("FXService"):Play(effect, params, position)
end

local function effectiveMods(entity): { [string]: number }
	local list = { entity.Modifiers }
	for _, mods in ipairs(EntityRegistry.BuffModifiers(entity)) do
		table.insert(list, mods)
	end
	if entity.Player and workspace:GetAttribute("TimePhase") == "Night" then
		local weaponService = Registry.Has("WeaponService") and Registry.Get("WeaponService")
		local night = weaponService and weaponService:GetNightModifiers(entity.Player)
		if night then
			table.insert(list, night)
		end
	end
	return Modifiers.Aggregate(list)
end

DamageService.EffectiveModifiers = effectiveMods

local function isInFront(target, attackerPosition: Vector3): boolean
	local toAttacker = attackerPosition - target.Root.Position
	local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if flat.Magnitude < 0.1 then
		return true
	end
	return target.Root.CFrame.LookVector:Dot(flat.Unit) > -0.15
end

local function addAwakening(entity, amount: number)
	if entity.Player and Registry.Has("TransformationService") then
		Registry.Get("TransformationService"):AddAwakening(entity.Player, amount)
	end
end

function DamageService:Stun(target, duration: number)
	if duration <= 0 or not EntityRegistry.IsAlive(target) then
		return
	end
	if os.clock() < target.State.SuperArmorUntil then
		return
	end
	target.State.StunnedUntil = math.max(target.State.StunnedUntil, os.clock() + duration)
	target.State.Blocking = false
	target.Model:SetAttribute("Blocking", false)
	target.Model:SetAttribute("Stunned", true)
end

function DamageService:Heal(entity, amount: number)
	if not EntityRegistry.IsAlive(entity) or amount <= 0 then
		return
	end
	local humanoid = entity.Humanoid
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	fx("DamageNumber", { Position = entity.Root.Position, Amount = math.floor(amount), Heal = true }, entity.Root.Position)
end

local function applyBurn(attacker, target, perTick: number)
	task.spawn(function()
		for _ = 1, 3 do
			task.wait(0.6)
			if not EntityRegistry.IsAlive(target) then
				return
			end
			target.Humanoid.Health -= perTick
			fx(
				"DamageNumber",
				{ Position = target.Root.Position, Amount = perTick, Color = Color3.fromRGB(255, 140, 40) },
				target.Root.Position
			)
			if target.Humanoid.Health <= 0 then
				DamageService.Killed:Fire(attacker, target)
			end
		end
	end)
end

-- info: see header of file / SkillContext for fields
function DamageService:Deal(attacker, target, info): (number, string)
	if not EntityRegistry.IsAlive(attacker) and not info.AllowDeadAttacker then
		return 0, "Invalid"
	end
	if not EntityRegistry.IsAlive(target) then
		return 0, "Invalid"
	end
	local now = os.clock()
	local tState = target.State
	local hitPosition = info.Position or target.Root.Position

	attacker.State.LastCombatTime = now
	tState.LastCombatTime = now

	if now < tState.IFramesUntil then
		fx("DamageNumber", { Position = hitPosition, Text = "IMMUNE", Color = Color3.fromRGB(200, 200, 200) }, hitPosition)
		return 0, "Immune"
	end

	-- Counter windows (Infinity Counter, Copy Counter, boss counters)
	if now < tState.CounterUntil and tState.CounterCallback then
		local callback = tState.CounterCallback
		tState.CounterUntil = 0
		tState.CounterCallback = nil
		fx("DamageNumber", { Position = hitPosition, Text = "COUNTER!", Color = Color3.fromRGB(120, 200, 255) }, hitPosition)
		task.spawn(callback, attacker)
		return 0, "Countered"
	end

	-- Blocking
	local blockMultiplier = 1
	local attackerMods = effectiveMods(attacker)
	if tState.Blocking and not info.Unblockable and isInFront(target, attacker.Root.Position) then
		if now - tState.BlockStart <= CB.PerfectBlockWindow and not info.GuardBreak then
			DamageService:Stun(attacker, CB.PerfectBlockStun)
			fx("PerfectBlock", { Position = hitPosition, Model = target.Model }, hitPosition)
			addAwakening(target, 6)
			if target.Player then
				Registry.Get("CharacterService"):RestoreEnergy(target.Player, 10)
			end
			self.Damaged:Fire(attacker, target, 0, info, "PerfectBlock")
			return 0, "PerfectBlock"
		end
		local guardDamage = (info.GuardDamage or 12) * (1 + (attackerMods.GuardDamage or 0))
		if info.GuardBreak then
			guardDamage = math.huge
		end
		tState.Guard = math.max(0, tState.Guard - guardDamage)
		target.Model:SetAttribute("Guard", math.floor(tState.Guard))
		if tState.Guard <= 0 then
			tState.Blocking = false
			target.Model:SetAttribute("Blocking", false)
			tState.SuperArmorUntil = 0
			DamageService:Stun(target, CB.GuardBreakStun)
			fx("GuardBreak", { Position = hitPosition, Model = target.Model }, hitPosition)
		else
			blockMultiplier = 1 - CB.BlockDamageReduction
			fx("BlockHit", { Position = hitPosition }, hitPosition)
		end
	end

	-- Damage formula
	local targetMods = effectiveMods(target)
	local bonus = attackerMods.DamageMult
	local typeKey = TYPE_BONUS[info.DamageType or ""]
	if typeKey then
		bonus += attackerMods[typeKey] or 0
	end
	local agility = attacker.Stats.Agility or 0
	local critChance =
		math.min(CB.MaxCritChance, CB.BaseCritChance + agility * CB.CritPerAgility + attackerMods.CritChance + (info.CritBonus or 0))
	local amount, isCrit = DamageFormula.Compute({
		Base = info.Base,
		Stat = info.Scaling and attacker.Stats[info.Scaling] or 0,
		SourceMultiplier = info.SourceMultiplier or 1,
		Mastery = info.Mastery or 0,
		DamageBonus = bonus,
		FlatBonus = attackerMods.FlatDamage,
		CritChance = attacker.IsNPC and 0.02 or critChance,
		CritMultiplier = CB.CritMultiplier,
		CritDamageBonus = attackerMods.CritDamage,
		ForceCrit = info.ForceCrit,
		AttackerLevel = attacker.Level,
		TargetLevel = target.Level,
		Defense = target.Defense,
		DamageReduction = targetMods.DamageReduction,
		BlockMultiplier = blockMultiplier,
	}, rng)

	-- Weapon on-hit passive
	local onHit = info.OnHit
	if onHit and blockMultiplier == 1 and rng:NextNumber() < (onHit.Chance or 0) then
		if onHit.BonusDamage then
			amount += math.floor(amount * onHit.BonusDamage)
		end
		if onHit.Effect == "Stun" then
			DamageService:Stun(target, onHit.Duration or 0.4)
		elseif onHit.Effect == "Freeze" then
			Motion.Freeze(target, onHit.Duration or 0.8)
		elseif onHit.Effect == "Burn" then
			applyBurn(attacker, target, math.max(1, math.floor(amount * 0.08)))
		end
		fx("ElementProc", { Position = hitPosition, Color = onHit.Color or Color3.new(1, 1, 1), Effect = onHit.Effect }, hitPosition)
	end

	-- Apply
	local humanoid = target.Humanoid
	local before = humanoid.Health
	local newHealth = math.max(0, before - amount)
	if newHealth <= 0 and target.Player and target.Model:GetAttribute("CanBeDowned") and Registry.Has("RaidService") then
		-- Raids: lethal damage downs the player instead (teammates can revive).
		humanoid.Health = 1
		Registry.Get("RaidService"):Down(target)
	else
		humanoid.Health = newHealth
	end
	local dealt = before - humanoid.Health

	-- Contribution for rewards (summons credit their owner)
	local creditPlayer = attacker.Player or attacker.Owner
	if creditPlayer and target.IsNPC then
		target.DamageContrib[creditPlayer] = (target.DamageContrib[creditPlayer] or 0) + dealt
	end

	if attackerMods.Lifesteal > 0 and dealt > 0 then
		DamageService:Heal(attacker, dealt * attackerMods.Lifesteal)
	end

	-- Crowd control (not while blocking successfully)
	if blockMultiplier == 1 then
		local superArmor = now < tState.SuperArmorUntil
		if info.Stun and not superArmor then
			DamageService:Stun(target, info.Stun)
		end
		if not superArmor and humanoid.Health > 0 then
			local origin = info.SourcePosition or attacker.Root.Position
			if info.Pull then
				Motion.Pull(target, info.Pull, 80)
			elseif info.Knockback and info.Knockback > 0 then
				Motion.Knockback(target, origin, info.Knockback, info.Up or 0)
			elseif info.Downslam then
				Motion.Velocity(target, Vector3.new(0, -120, 0), 0.2)
			elseif info.Up and info.Up > 0 then
				Motion.Launch(target, info.Up)
			elseif info.Launch then
				Motion.Launch(target, 50)
			end
			if info.Ragdoll and info.Ragdoll > 0 then
				Motion.Ragdoll(target, info.Ragdoll)
			end
		end
		if info.Burn then
			applyBurn(attacker, target, math.max(1, math.floor(amount * 0.06)))
		end
	end

	-- Feedback
	local color = info.Color or Color3.new(1, 1, 1)
	local heavy = info.Heavy or info.Kind == "Heavy" or info.Kind == "Ultimate" or isCrit
	if not info.NoFX then
		fx("HitSpark", { Position = hitPosition, Color = color, Heavy = heavy, Blocked = blockMultiplier < 1 }, hitPosition)
	end
	fx("DamageNumber", { Position = hitPosition, Amount = math.floor(dealt), Crit = isCrit, Blocked = blockMultiplier < 1 }, hitPosition)
	if attacker.Player then
		Registry.Get("FXService"):PlayFor(attacker.Player, "Hitstop", { Duration = heavy and 0.08 or 0.04, Shake = heavy and 0.35 or 0.12 })
	end
	if target.Player then
		Registry.Get("FXService"):PlayFor(target.Player, "Hurt", { Amount = dealt, MaxHealth = humanoid.MaxHealth })
	end

	-- Awakening
	if not info.NoAwakening then
		local maxHp = math.max(1, humanoid.MaxHealth)
		addAwakening(attacker, (dealt / maxHp) * 100 * CB.AwakeningPerDamageDealt * 10 + CB.AwakeningPerComboHit)
		addAwakening(target, (dealt / maxHp) * 100 * CB.AwakeningPerDamageTaken * 3)
	end

	self.Damaged:Fire(attacker, target, dealt, info, blockMultiplier < 1 and "Blocked" or "Hit")
	if humanoid.Health <= 0 and before > 0 then
		self.Killed:Fire(attacker, target)
	end
	return dealt, blockMultiplier < 1 and "Blocked" or "Hit"
end

function DamageService:Init() end

return DamageService
