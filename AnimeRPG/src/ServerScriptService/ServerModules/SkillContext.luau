--[[
	SkillContext (ModuleScript)
	Location: ServerScriptService.ServerModules.SkillContext

	PHASE 5 - Power Framework core. Every skill's Execute(ctx) receives one of these.
	It exposes safe, server-validated building blocks (hitboxes, damage, motion, VFX...)
	so power/weapon/boss modules never touch health, remotes or physics directly.
]]
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Hitbox = require(ServerScriptService.ServerModules.Hitbox)
local Motion = require(ServerScriptService.ServerModules.Motion)

local SkillContext = {}
SkillContext.__index = SkillContext

export type Options = {
	Entity: any,
	Skill: any,
	Source: string, -- "Power" | "Weapon" | "Boss" | "Enemy"
	SourceId: string,
	Mastery: number?,
	Color: Color3?,
	Color2: Color3?,
	AimPosition: Vector3?,
	DamageType: string?, -- "Power" | "Weapon" | "Style" | "True"
	Scaling: string?, -- stat name
	SourceMultiplier: number?,
	OnHit: any?,
}

function SkillContext.new(options: Options)
	local entity = options.Entity
	local root = entity.Root
	local aim = options.AimPosition or (root.Position + root.CFrame.LookVector * 10)
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local direction = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
	local self = setmetatable({
		Entity = entity,
		Caster = entity.Model,
		Root = root,
		Humanoid = entity.Humanoid,
		Player = entity.Player,
		Skill = options.Skill,
		Source = options.Source,
		SourceId = options.SourceId,
		Mastery = options.Mastery or 0,
		Color = options.Color or Color3.new(1, 1, 1),
		Color2 = options.Color2 or Color3.new(1, 1, 1),
		AimPosition = aim,
		AimDirection = direction,
		DamageType = options.DamageType or "Power",
		Scaling = options.Scaling,
		SourceMultiplier = options.SourceMultiplier or 1,
		OnHit = options.OnHit,
		Transformed = entity.Model:GetAttribute("Transformed") == true,
		_cancelled = false,
	}, SkillContext)
	-- Face the aim direction when casting.
	if not entity.Player then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	return self
end

local function fxService()
	return Registry.Get("FXService")
end

-- STATE ----------------------------------------------------------------------------------------

function SkillContext:IsValid(): boolean
	if self._cancelled then
		return false
	end
	local entity = self.Entity
	if not EntityRegistry.IsAlive(entity) then
		return false
	end
	local now = os.clock()
	if now < entity.State.FrozenUntil then
		return false
	end
	if now < entity.State.StunnedUntil and now >= entity.State.SuperArmorUntil then
		return false
	end
	return true
end

function SkillContext:Cancel()
	self._cancelled = true
end

-- Waits and returns false if the caster died / got stunned (skill should stop).
function SkillContext:Wait(seconds: number): boolean
	task.wait(seconds)
	return self:IsValid()
end

function SkillContext:Lock(seconds: number)
	self.Entity.State.ActionLockUntil = math.max(self.Entity.State.ActionLockUntil, os.clock() + seconds)
end

function SkillContext:IFrames(seconds: number)
	self.Entity.State.IFramesUntil = math.max(self.Entity.State.IFramesUntil, os.clock() + seconds)
end

function SkillContext:SuperArmor(seconds: number)
	self.Entity.State.SuperArmorUntil = math.max(self.Entity.State.SuperArmorUntil, os.clock() + seconds)
end

function SkillContext:Forward(distance: number): Vector3
	return self.Root.Position + self.AimDirection * distance
end

-- VISUALS / AUDIO -------------------------------------------------------------------------------

function SkillContext:FX(effect: string, params: { [string]: any })
	local position = params.Position or (params.CFrame and params.CFrame.Position) or params.From or self.Root.Position
	fxService():Play(effect, params, position)
end

function SkillContext:Anim(name: string, speed: number?)
	fxService():Play("Anim", { Model = self.Caster, Name = name, Speed = speed }, self.Root.Position)
end

function SkillContext:Sound(name: string, position: Vector3?)
	local pos = position or self.Root.Position
	fxService():Play("Sound", { Name = name, Position = pos }, pos)
end

function SkillContext:Afterimage()
	self:FX("Afterimage", { Model = self.Caster, Color = self.Color })
end

function SkillContext:Aura(duration: number)
	self:FX("Aura", { Model = self.Caster, Color = self.Color, Duration = duration })
end

function SkillContext:Shake(position: Vector3, intensity: number, radius: number?)
	self:FX("CameraShake", { Position = position, Intensity = intensity, Radius = radius or 60 })
end

function SkillContext:Telegraph(position: Vector3, radius: number, duration: number, color: Color3?)
	local ground = Hitbox.Ground(position, { self.Caster })
	self:FX("Telegraph", { Position = ground, Radius = radius, Duration = duration, Color = color or Color3.fromRGB(255, 40, 40) })
end

function SkillContext:Cinematic(duration: number, style: string?)
	if self.Player then
		fxService():PlayFor(
			self.Player,
			"Cinematic",
			{ Model = self.Caster, Duration = duration, Style = style or "Ultimate", Color = self.Color }
		)
	end
	self:FX("UltimateBanner", { Model = self.Caster, Name = self.Skill.Name, Color = self.Color })
end

-- TARGETING -------------------------------------------------------------------------------------

function SkillContext:Enemies(position: Vector3, radius: number): { any }
	return Hitbox.Radius(self.Entity, position, radius)
end

function SkillContext:NearestEnemy(position: Vector3, radius: number): any?
	return Hitbox.Nearest(self.Entity, position, radius)
end

function SkillContext:NearestSummon(position: Vector3): any?
	if not Registry.Has("EnemyService") then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, summon in ipairs(Registry.Get("EnemyService"):GetSummons(self.Player or self.Entity.Owner)) do
		local dist = (summon.Root.Position - position).Magnitude
		if dist < bestDist then
			best, bestDist = summon, dist
		end
	end
	return best
end

function SkillContext:SetMark(target)
	self.Entity.State.Mark = target and target.Model or nil
end

function SkillContext:GetMark(): any?
	local mark = self.Entity.State.Mark
	local entity = mark and EntityRegistry.Get(mark)
	if EntityRegistry.IsAlive(entity) then
		return entity
	end
	return nil
end

-- DAMAGE ----------------------------------------------------------------------------------------

local SPEC_KEYS = {
	"Stun",
	"Knockback",
	"Up",
	"Pull",
	"GuardDamage",
	"GuardBreak",
	"Unblockable",
	"Ragdoll",
	"Launch",
	"Downslam",
	"Burn",
	"ForceCrit",
	"Heavy",
	"NoAwakening",
}

local function buildInfo(self, spec: { [string]: any })
	local skill = self.Skill
	local info = {
		Base = (skill.Damage or 10) * (spec.Damage or 1),
		Kind = skill.Ultimate and "Ultimate" or "Skill",
		DamageType = self.DamageType,
		Scaling = self.Scaling,
		SourceMultiplier = self.SourceMultiplier,
		Mastery = self.Mastery,
		Color = self.Color,
		SourcePosition = spec.SourcePosition or self.Root.Position,
		OnHit = self.OnHit,
		Heavy = skill.Ultimate or spec.Heavy,
	}
	for _, key in ipairs(SPEC_KEYS) do
		if spec[key] ~= nil then
			info[key] = spec[key]
		end
	end
	return info
end

function SkillContext:Damage(target, spec: { [string]: any }?): number
	local dealt = Registry.Get("DamageService"):Deal(self.Entity, target, buildInfo(self, spec or {}))
	return dealt
end

local function applyAll(self, targets: { any }, spec): { any }
	local hit = {}
	for _, target in ipairs(targets) do
		local dealt, result = Registry.Get("DamageService"):Deal(self.Entity, target, buildInfo(self, spec))
		if result ~= "Invalid" then
			target._lastDealt = dealt
			table.insert(hit, target)
		end
	end
	return hit
end

function SkillContext:HitRadius(position: Vector3, radius: number, spec: { [string]: any }?): { any }
	local s = table.clone(spec or {})
	s.SourcePosition = s.SourcePosition or position
	return applyAll(self, Hitbox.Radius(self.Entity, position, radius), s)
end

function SkillContext:HitBox(cframe: CFrame, size: Vector3, spec: { [string]: any }?): { any }
	return applyAll(self, Hitbox.Box(self.Entity, cframe, size), spec or {})
end

function SkillContext:HitLine(origin: Vector3, direction: Vector3, length: number, width: number, spec: { [string]: any }?): { any }
	return applyAll(self, Hitbox.Line(self.Entity, origin, direction, length, width), spec or {})
end

function SkillContext:Heal(entity, amount: number)
	Registry.Get("DamageService"):Heal(entity, amount)
end

function SkillContext:Stun(target, duration: number)
	Registry.Get("DamageService"):Stun(target, duration)
end

function SkillContext:Freeze(target, duration: number)
	if os.clock() < target.State.SuperArmorUntil and target.Definition and target.Definition.IsBoss then
		duration *= 0.35 -- bosses resist time/freeze effects
	end
	Motion.Freeze(target, duration)
end

-- MOTION ----------------------------------------------------------------------------------------

function SkillContext:Knockback(target, fromPosition: Vector3, force: number, up: number?)
	if os.clock() < target.State.SuperArmorUntil then
		return
	end
	Motion.Knockback(target, fromPosition, force, up)
end

function SkillContext:Pull(target, toPosition: Vector3, force: number)
	if os.clock() < target.State.SuperArmorUntil then
		return
	end
	Motion.Pull(target, toPosition, force)
end

function SkillContext:Dash(direction: Vector3, distance: number, duration: number)
	Motion.Dash(self.Entity, direction, distance, duration)
end

function SkillContext:Launch(up: number)
	Motion.Launch(self.Entity, up)
end

function SkillContext:Teleport(cframe: CFrame)
	Motion.Teleport(self.Entity, cframe + Vector3.new(0, 0.5, 0))
end

-- BUFFS / COUNTERS / SUMMONS ----------------------------------------------------------------------

function SkillContext:Buff(entity, name: string, modifiers: { [string]: number }, duration: number)
	entity.State.Buffs[name] = { Modifiers = modifiers, Expires = os.clock() + duration }
	if modifiers.MoveSpeed then
		local function sync()
			local total = 0
			for _, buff in pairs(entity.State.Buffs) do
				if os.clock() < buff.Expires then
					total += buff.Modifiers.MoveSpeed or 0
				end
			end
			entity.Model:SetAttribute("BuffSpeed", total)
		end
		sync()
		task.delay(duration + 0.05, sync)
	end
end

function SkillContext:Counter(duration: number, onCounter: (any, any) -> ())
	local state = self.Entity.State
	state.CounterUntil = os.clock() + duration
	state.CounterCallback = function(attacker)
		if EntityRegistry.IsAlive(attacker) and self:IsValid() then
			onCounter(self, attacker)
		end
	end
	self:FX("CounterReady", { Model = self.Caster, Color = self.Color, Duration = duration })
end

function SkillContext:Summon(options: { [string]: any }): { any }
	if not Registry.Has("EnemyService") then
		return {}
	end
	return Registry.Get("EnemyService"):SpawnSummons(self.Entity, options)
end

-- Enemy/boss only: spawn hostile minions around the caster.
function SkillContext:SpawnMinions(enemyId: string, count: number)
	if not Registry.Has("EnemyService") then
		return {}
	end
	return Registry.Get("EnemyService"):SpawnMinions(self.Entity, enemyId, count)
end

-- PROJECTILES -----------------------------------------------------------------------------------

local projectileParams = RaycastParams.new()
projectileParams.FilterType = Enum.RaycastFilterType.Include

local function mapFilter(): { Instance }
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(list, map)
	end
	table.insert(list, workspace.Terrain)
	return list
end

--[[
	options: Origin, Direction, Speed, Range, Radius, Pierce, Homing,
	         Visual = { Kind, Color, Size }, Spec (hit spec),
	         OnHit(ctx, target, dealt), OnEnd(ctx, position)
]]
function SkillContext:Projectile(options: { [string]: any })
	local origin = options.Origin or (self.Root.Position + self.AimDirection * 3)
	local direction = (options.Direction or self.AimDirection).Unit
	local speed = options.Speed or 100
	local range = options.Range or 50
	local radius = options.Radius or 3
	local id = HttpService:GenerateGUID(false)
	local homingTarget = options.Homing and self:NearestEnemy(self.AimPosition, 25) or nil
	local visual = options.Visual or {}

	self:FX("Projectile", {
		Id = id,
		Origin = origin,
		Direction = direction,
		Speed = speed,
		Range = range,
		Kind = visual.Kind or "Orb",
		Color = visual.Color or self.Color,
		Size = visual.Size or 2,
		Target = homingTarget and homingTarget.Model or nil,
	})

	task.spawn(function()
		projectileParams.FilterDescendantsInstances = mapFilter()
		local position = origin
		local traveled = 0
		local alreadyHit = {}
		local spec = options.Spec or {}
		local ended = false
		while traveled < range and not ended do
			local dt = RunService.Heartbeat:Wait()
			if homingTarget and EntityRegistry.IsAlive(homingTarget) then
				local toTarget = homingTarget.Root.Position - position
				if toTarget.Magnitude > 1 then
					direction = direction:Lerp(toTarget.Unit, math.min(1, dt * 8)).Unit
				end
			end
			local step = direction * speed * dt
			local wallHit = workspace:Raycast(position, step, projectileParams)
			if wallHit then
				position = wallHit.Position
				ended = true
			else
				position += step
				traveled += step.Magnitude
			end
			for _, target in ipairs(Hitbox.Radius(self.Entity, position, radius)) do
				if not alreadyHit[target] then
					alreadyHit[target] = true
					local s = table.clone(spec)
					s.SourcePosition = position - direction * 3
					local hitList = applyAll(self, { target }, s)
					if hitList[1] and options.OnHit then
						task.spawn(options.OnHit, self, target, target._lastDealt or 0)
					end
					if not options.Pierce then
						ended = true
						break
					end
				end
			end
		end
		fxService():Play("ProjectileEnd", { Id = id, Position = position }, position)
		if options.OnEnd then
			options.OnEnd(self, position)
		end
	end)
end

return SkillContext
