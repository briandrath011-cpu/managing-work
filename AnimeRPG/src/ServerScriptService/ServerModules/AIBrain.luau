--[[
	AIBrain (ModuleScript)
	Location: ServerScriptService.ServerModules.AIBrain

	PHASE 11 / 13 - Enemy + Boss AI. One brain per NPC, ticked by EnemyService's single loop
	(no per-NPC while-loops). States: Idle -> Chase -> Attack -> Retreat -> Return.
	Enemies: detect players, chase, M1 combos, block when attacked, use skills, back off.
	Bosses : keep distance, choose skills by distance + cooldown, dash, combos, AoE,
	         phases (70% / 30%), enrage aura + speed, ultimate unlock.
	Allies (summons): same logic but target enemies.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local EnemySkills = require(Modules.Enemies.EnemySkills)
local BossSkills = require(Modules.Bosses.BossSkills)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local SkillContext = require(ServerScriptService.ServerModules.SkillContext)
local Motion = require(ServerScriptService.ServerModules.Motion)
local NPCAnimator = require(ServerScriptService.ServerModules.NPCAnimator)

local AIBrain = {}
AIBrain.__index = AIBrain

local rng = Random.new()

function AIBrain.new(entity, def, options)
	local self = setmetatable({
		Entity = entity,
		Def = def,
		Home = options.Home or entity.Root.Position,
		LeashRange = options.LeashRange or (def.IsBoss and (def.ArenaRadius or 90) * 1.4 or 110),
		Target = nil,
		State = "Idle",
		NextWander = 0,
		NextMove = 0,
		LastMoveTarget = nil,
		SkillReady = {},
		NextSkillTime = os.clock() + rng:NextNumber(1, 3),
		RetreatUntil = 0,
		HasRetreated = false,
		StuckTimer = 0,
		LastPos = entity.Root.Position,
		Phase = 1,
		Enraged = false,
		UltimateReady = 0,
		Casting = false,
		BaseWalkSpeed = def.WalkSpeed or 16,
		Skills = def.IsBoss and BossSkills or EnemySkills,
		OnPhaseChange = options.OnPhaseChange,
		IsAlly = entity.Team == "Allies",
		Owner = options.Owner,
		DamageScale = options.DamageScale or 1,
	}, AIBrain)
	entity.Humanoid.WalkSpeed = self.BaseWalkSpeed
	return self
end

function AIBrain:SpeedMultiplier(): number
	if not self.Def.IsBoss then
		return 1
	end
	local phase = self.Def.Phases[self.Phase]
	return phase and phase.SpeedMultiplier or 1
end

function AIBrain:CurrentSkills(): { string }
	if self.Def.IsBoss then
		local phase = self.Def.Phases[self.Phase]
		return phase and phase.Skills or {}
	end
	return self.Def.Skills or {}
end

-- TARGETING -------------------------------------------------------------------------------------

function AIBrain:FindTarget(): any?
	local entity = self.Entity
	local best, bestDist = nil, self.Def.AggroRange or 45
	for _, other in pairs(EntityRegistry.All()) do
		if other ~= entity and EntityRegistry.IsAlive(other) and EntityRegistry.AreEnemies(entity, other) then
			local dist = (other.Root.Position - entity.Root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = other, dist
			end
		end
	end
	return best
end

function AIBrain:ValidTarget(target): boolean
	if not target or not EntityRegistry.IsAlive(target) then
		return false
	end
	if (target.Root.Position - self.Home).Magnitude > self.LeashRange then
		return false
	end
	return true
end

-- Called by EnemyService when this NPC gets hit (aggro on attacker).
function AIBrain:OnDamaged(attacker)
	if not self.Target or not self:ValidTarget(self.Target) or rng:NextNumber() < 0.3 then
		if EntityRegistry.IsAlive(attacker) then
			self.Target = attacker
		end
	end
end

-- Called when a nearby entity starts an attack: chance to block or dodge.
function AIBrain:OnThreat(attacker)
	local entity = self.Entity
	if self.Casting or not EntityRegistry.CanAct(entity) then
		return
	end
	local dist = (attacker.Root.Position - entity.Root.Position).Magnitude
	if dist > 14 then
		return
	end
	local roll = rng:NextNumber()
	local combat = Registry.Get("CombatServer")
	if roll < (self.Def.BlockChance or 0) then
		self:Face(attacker.Root.Position)
		combat:SetBlocking(entity, true)
		task.delay(rng:NextNumber(0.4, 0.9), function()
			if entity.Model.Parent then
				combat:SetBlocking(entity, false)
			end
		end)
	elseif roll < (self.Def.BlockChance or 0) + (self.Def.DodgeChance or 0) then
		local away = entity.Root.Position - attacker.Root.Position
		local side = entity.Root.CFrame.RightVector * (rng:NextNumber() < 0.5 and -1 or 1)
		local dir = (Vector3.new(away.X, 0, away.Z).Unit * 0.5 + side).Unit
		if combat:PerformDash(entity, "Side") then
			Motion.Dash(entity, dir, 14, 0.18)
		end
	end
end

-- MOVEMENT --------------------------------------------------------------------------------------

function AIBrain:Face(position: Vector3)
	local root = self.Entity.Root
	if root.Anchored then
		return
	end
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

function AIBrain:MoveTo(position: Vector3, now: number)
	if now < self.NextMove and self.LastMoveTarget and (self.LastMoveTarget - position).Magnitude < 3 then
		return
	end
	self.NextMove = now + 0.35
	self.LastMoveTarget = position
	self.Entity.Humanoid:MoveTo(position)
end

function AIBrain:Stop()
	local humanoid = self.Entity.Humanoid
	humanoid:MoveTo(self.Entity.Root.Position)
	self.LastMoveTarget = nil
end

-- SKILLS ----------------------------------------------------------------------------------------

function AIBrain:CastSkill(skillId: string, target, now: number): boolean
	local skill = self.Skills[skillId]
	if not skill then
		return false
	end
	local entity = self.Entity
	local def = self.Def
	self.SkillReady[skillId] = now + (skill.Cooldown or 8) / self:SpeedMultiplier()
	self.Casting = true
	self:Stop()
	local aim = target and target.Root.Position or (entity.Root.Position + entity.Root.CFrame.LookVector * 10)
	if target then
		self:Face(aim)
	end
	local level = entity.Level
	local ctx = SkillContext.new({
		Entity = entity,
		Skill = skill,
		Source = def.IsBoss and "Boss" or "Enemy",
		SourceId = def.Id,
		Color = def.AttackColor or (def.Colors and def.Colors.Accent) or Color3.new(1, 1, 1),
		AimPosition = aim,
		DamageType = "True",
		-- Level scaling: skill Damage 10 == one normal hit of this NPC.
		SourceMultiplier = ((5 + level * 1.6) / 10) * (def.DamageMultiplier or 1) * self.DamageScale,
	})
	task.spawn(function()
		local ok, err = pcall(skill.Execute, ctx)
		if not ok then
			warn("[AIBrain] skill error " .. skillId .. ": " .. tostring(err))
		end
		self.Casting = false
	end)
	-- Failsafe in case a skill yields for very long.
	task.delay(6, function()
		self.Casting = false
	end)
	return true
end

function AIBrain:PickSkill(distance: number, now: number): string?
	if now < self.NextSkillTime then
		return nil
	end
	local options = {}
	local totalWeight = 0
	local humanoid = self.Entity.Humanoid
	for _, skillId in ipairs(self:CurrentSkills()) do
		local skill = self.Skills[skillId]
		if skill and now >= (self.SkillReady[skillId] or 0) then
			local fits = distance <= (skill.Range or 20) + 4 and distance >= (skill.MinRange or 0)
			if skill.SelfCast then
				fits = humanoid.Health / humanoid.MaxHealth <= (skill.HealthBelow or 1)
			end
			if fits then
				local weight = skill.Weight or 1
				table.insert(options, { Id = skillId, Weight = weight })
				totalWeight += weight
			end
		end
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * totalWeight
	for _, option in ipairs(options) do
		roll -= option.Weight
		if roll <= 0 then
			return option.Id
		end
	end
	return options[#options].Id
end

-- BOSS PHASES -------------------------------------------------------------------------------------

function AIBrain:UpdatePhase(now: number)
	local def = self.Def
	if not def.IsBoss then
		return
	end
	local humanoid = self.Entity.Humanoid
	local ratio = humanoid.Health / math.max(1, humanoid.MaxHealth)
	local newPhase = 1
	for index, phase in ipairs(def.Phases) do
		if ratio <= phase.Threshold then
			newPhase = index
		end
	end
	if newPhase > self.Phase then
		self.Phase = newPhase
		local phase = def.Phases[newPhase]
		local entity = self.Entity
		entity.State.SuperArmorUntil = now + 2
		entity.State.IFramesUntil = now + 1
		entity.Humanoid.WalkSpeed = self.BaseWalkSpeed * (phase.SpeedMultiplier or 1)
		local fx = Registry.Get("FXService")
		fx:Play(
			"Shockwave",
			{ Position = entity.Root.Position, Color = def.AttackColor or Color3.new(1, 0, 0), Size = 50 },
			entity.Root.Position
		)
		fx:Play("CameraShake", { Position = entity.Root.Position, Intensity = 0.8, Radius = 120 }, entity.Root.Position)
		if phase.Enrage and not self.Enraged then
			self.Enraged = true
			entity.Model:SetAttribute("Enraged", true)
			fx:Play(
				"Aura",
				{ Model = entity.Model, Color = Color3.fromRGB(255, 40, 40), Duration = 9999, Intense = true },
				entity.Root.Position
			)
			self.UltimateReady = now + 1.5
		end
		if self.OnPhaseChange then
			task.spawn(self.OnPhaseChange, self, newPhase, phase)
		end
	end
end

-- MAIN TICK ---------------------------------------------------------------------------------------

function AIBrain:Tick(now: number)
	local entity = self.Entity
	if not EntityRegistry.IsAlive(entity) then
		return
	end
	NPCAnimator.Update(entity.Humanoid, entity.Root)
	self:UpdatePhase(now)
	if self.Casting or not EntityRegistry.CanAct(entity) then
		return
	end

	if not self:ValidTarget(self.Target) then
		self.Target = self:FindTarget()
	end
	local target = self.Target
	local root = entity.Root
	local distHome = (root.Position - self.Home).Magnitude

	if not target then
		-- Return home / wander
		if distHome > 12 then
			self.State = "Return"
			self:MoveTo(self.Home, now)
			if entity.Humanoid.Health < entity.Humanoid.MaxHealth then
				entity.Humanoid.Health = math.min(entity.Humanoid.MaxHealth, entity.Humanoid.Health + entity.Humanoid.MaxHealth * 0.05)
			end
		elseif now >= self.NextWander and not self.Def.IsBoss and not self.IsAlly then
			self.State = "Idle"
			self.NextWander = now + rng:NextNumber(4, 9)
			local offset = Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))
			self:MoveTo(self.Home + offset, now)
		elseif self.IsAlly and self.Owner and self.Owner.Character then
			local ownerRoot = self.Owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if ownerRoot and (ownerRoot.Position - root.Position).Magnitude > 10 then
				self:MoveTo(ownerRoot.Position, now)
			end
		end
		return
	end

	local toTarget = target.Root.Position - root.Position
	local distance = toTarget.Magnitude
	local def = self.Def
	local behaviour = def.Behaviour or "Melee"
	local humanoid = entity.Humanoid

	-- Boss ultimate when enraged
	if def.IsBoss and self.Enraged and def.Ultimate and now >= self.UltimateReady then
		self.UltimateReady = now + (self.Skills[def.Ultimate] and self.Skills[def.Ultimate].Cooldown or 40)
		self:CastSkill(def.Ultimate, target, now)
		return
	end

	-- Low health retreat (normal enemies, once)
	if not def.IsBoss and not self.HasRetreated and humanoid.Health / humanoid.MaxHealth < 0.25 and rng:NextNumber() < 0.5 then
		self.HasRetreated = true
		self.RetreatUntil = now + rng:NextNumber(1.5, 2.5)
	end
	if now < self.RetreatUntil then
		self.State = "Retreat"
		local away = root.Position - toTarget.Unit * 20
		self:MoveTo(away, now)
		return
	end

	-- Skills
	local skillId = self:PickSkill(distance, now)
	if skillId then
		self.NextSkillTime = now + rng:NextNumber(def.IsBoss and 0.8 or 2, def.IsBoss and 2 or 5) / self:SpeedMultiplier()
		self:CastSkill(skillId, target, now)
		return
	end

	-- Positioning
	local range = def.Range or 6
	if behaviour == "Ranged" or behaviour == "Caster" then
		if distance < 12 then
			self.State = "Retreat"
			self:MoveTo(root.Position - toTarget.Unit * 14, now)
		elseif distance > 32 then
			self.State = "Chase"
			self:MoveTo(target.Root.Position, now)
		else
			self:Stop()
			self:Face(target.Root.Position)
			if distance <= range + 2 then
				Registry.Get("CombatServer"):PerformM1(entity)
			end
		end
		return
	end

	if def.IsBoss and distance > 30 and rng:NextNumber() < 0.25 then
		-- Gap closer
		if Registry.Get("CombatServer"):PerformDash(entity, "Front") then
			Motion.Dash(entity, Vector3.new(toTarget.X, 0, toTarget.Z).Unit, math.min(26, distance - 6), 0.22)
			Registry.Get("FXService"):Play("Afterimage", { Model = entity.Model, Color = def.AttackColor }, root.Position)
			return
		end
	end

	if distance > range * 0.9 then
		self.State = "Chase"
		self:MoveTo(target.Root.Position - toTarget.Unit * (range * 0.6), now)
		-- Unstuck: jump if not moving
		if (root.Position - self.LastPos).Magnitude < 0.5 then
			self.StuckTimer += 1
			if self.StuckTimer > 6 then
				humanoid.Jump = true
				self.StuckTimer = 0
			end
		else
			self.StuckTimer = 0
		end
		self.LastPos = root.Position
	else
		self.State = "Attack"
		self:Stop()
		self:Face(target.Root.Position)
		local combat = Registry.Get("CombatServer")
		if behaviour == "Brute" and rng:NextNumber() < 0.08 then
			task.spawn(combat.PerformHeavy, combat, entity)
		else
			combat:PerformM1(entity)
		end
	end
end

return AIBrain
