--[[
	BossSkills (ModuleScript)
	Location: ReplicatedStorage.Modules.Bosses.BossSkills
	Big telegraphed boss attacks, shared by all bosses (colors come from the boss).
	Fields used by BossBrain: MinRange / Range (distance fit), Cooldown, Weight, Ultimate.
	Damage is in "boss M1 units x10" (scaled by boss level).
]]
local BossSkills = {}

BossSkills.Combo = {
	Name = "Relentless Combo",
	Cooldown = 7,
	Damage = 12,
	Range = 20,
	Weight = 3,
	Execute = function(ctx)
		ctx:Afterimage()
		ctx:Dash(ctx.AimDirection, math.min(16, (ctx.AimPosition - ctx.Root.Position).Magnitude - 4), 0.2)
		if not ctx:Wait(0.25) then
			return
		end
		for i = 1, 3 do
			local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 5, ctx.Root.Position + ctx.AimDirection * 10)
			ctx:FX("Slash", { CFrame = cf, Color = ctx.Color, Size = 14, Heavy = i == 3 })
			ctx:HitBox(cf, Vector3.new(12, 9, 11), { Stun = 0.45, Knockback = i == 3 and 60 or 0, GuardDamage = 25 })
			if not ctx:Wait(0.28) then
				return
			end
		end
	end,
}

BossSkills.Shockwave = {
	Name = "Shockwave",
	Cooldown = 9,
	Damage = 22,
	Range = 16,
	Weight = 2,
	Execute = function(ctx)
		ctx:Telegraph(ctx.Root.Position, 20, 0.9, ctx.Color)
		if not ctx:Wait(0.9) then
			return
		end
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 44 })
		ctx:FX("GroundCracks", { Position = ctx.Root.Position - Vector3.new(0, 3, 0), Size = 18 })
		ctx:Shake(ctx.Root.Position, 0.7, 80)
		ctx:HitRadius(ctx.Root.Position, 20, { Stun = 0.9, Knockback = 80, Up = 30, Ragdoll = 0.8 })
	end,
}

BossSkills.MeteorRain = {
	Name = "Meteor Rain",
	Cooldown = 14,
	Damage = 20,
	Range = 60,
	MinRange = 10,
	Weight = 2,
	Execute = function(ctx)
		local targets = ctx:Enemies(ctx.Root.Position, 70)
		for wave = 1, 3 do
			local spots = {}
			for _, target in ipairs(targets) do
				table.insert(spots, target.Root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
			end
			for _ = 1, 3 do
				table.insert(spots, ctx.Root.Position + Vector3.new(math.random(-35, 35), 0, math.random(-35, 35)))
			end
			for _, pos in ipairs(spots) do
				ctx:Telegraph(pos, 9, 0.9, ctx.Color)
			end
			if not ctx:Wait(0.9) then
				return
			end
			for _, pos in ipairs(spots) do
				ctx:FX("Meteor", { Position = pos, Color = ctx.Color, Size = 6 })
				ctx:HitRadius(pos, 9, { Stun = 0.6, Knockback = 40, Up = 20 })
			end
			if wave < 3 and not ctx:Wait(0.35) then
				return
			end
		end
	end,
}

BossSkills.SweepBeam = {
	Name = "Sweeping Beam",
	Cooldown = 13,
	Damage = 26,
	Range = 60,
	MinRange = 12,
	Weight = 2,
	Execute = function(ctx)
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 1 })
		ctx:SuperArmor(2.6)
		local origin = ctx.Root.Position
		ctx:FX(
			"Beam",
			{ From = origin, To = origin + ctx.AimDirection * 60, Color = Color3.fromRGB(255, 50, 50), Width = 0.5, Duration = 1 }
		)
		if not ctx:Wait(1) then
			return
		end
		local base = ctx.AimDirection
		for step = -3, 3 do
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(step * 12)) * base).Unit
			ctx:FX("Beam", { From = origin, To = origin + dir * 60, Color = ctx.Color, Width = 5, Duration = 0.18 })
			ctx:HitLine(origin, dir, 60, 7, { Damage = 0.5, Stun = 0.5, Knockback = 30 })
			if not ctx:Wait(0.12) then
				return
			end
		end
	end,
}

BossSkills.Pillars = {
	Name = "Judgement Pillars",
	Cooldown = 12,
	Damage = 24,
	Range = 60,
	Weight = 2,
	Execute = function(ctx)
		local targets = ctx:Enemies(ctx.Root.Position, 70)
		for _, target in ipairs(targets) do
			ctx:Telegraph(target.Root.Position, 8, 1)
		end
		local positions = {}
		for _, target in ipairs(targets) do
			table.insert(positions, target.Root.Position)
		end
		if not ctx:Wait(1) then
			return
		end
		for _, pos in ipairs(positions) do
			ctx:FX("Pillar", { Position = pos, Color = ctx.Color, Size = 8, Height = 80 })
			ctx:HitRadius(pos, 8, { Stun = 1, Up = 50, Launch = true })
		end
	end,
}

BossSkills.Blink = {
	Name = "Blink Strike",
	Cooldown = 8,
	Damage = 20,
	Range = 50,
	MinRange = 6,
	Weight = 2,
	Execute = function(ctx)
		local target = ctx:NearestEnemy(ctx.AimPosition, 20)
		if not target then
			return
		end
		ctx:FX("Afterimage", { Model = ctx.Caster, Color = ctx.Color })
		ctx:Teleport(CFrame.lookAt((target.Root.CFrame * CFrame.new(0, 0, 5)).Position, target.Root.Position))
		if not ctx:Wait(0.3) then
			return
		end
		ctx:FX("Slash", { CFrame = target.Root.CFrame, Color = ctx.Color, Size = 16, Heavy = true })
		ctx:HitRadius(target.Root.Position, 8, { Stun = 0.8, Knockback = 70, Ragdoll = 0.8 })
	end,
}

BossSkills.Pull = {
	Name = "Vortex",
	Cooldown = 15,
	Damage = 10,
	Range = 40,
	Weight = 1,
	Execute = function(ctx)
		ctx:FX("Singularity", { Position = ctx.Root.Position + Vector3.new(0, 3, 0), Color = ctx.Color, Size = 8, Duration = 1.6 })
		for _ = 1, 5 do
			ctx:HitRadius(ctx.Root.Position, 35, { Damage = 0.3, Pull = ctx.Root.Position, Stun = 0.3 })
			if not ctx:Wait(0.3) then
				return
			end
		end
		ctx:FX("Explosion", { Position = ctx.Root.Position, Color = ctx.Color, Size = 30 })
		ctx:HitRadius(ctx.Root.Position, 14, { Damage = 2, Knockback = 90, Up = 30, Ragdoll = 1 })
	end,
}

BossSkills.ChainLightning = {
	Name = "Chain Lightning",
	Cooldown = 10,
	Damage = 18,
	Range = 55,
	Weight = 2,
	Execute = function(ctx)
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.6 })
		if not ctx:Wait(0.6) then
			return
		end
		local from = ctx.Root.Position + Vector3.new(0, 4, 0)
		for _, target in ipairs(ctx:Enemies(ctx.Root.Position, 55)) do
			ctx:FX("Lightning", { From = from, To = target.Root.Position, Color = ctx.Color })
			ctx:Damage(target, { Stun = 0.7 })
			from = target.Root.Position
		end
	end,
}

BossSkills.IcePrison = {
	Name = "Frozen Prison",
	Cooldown = 16,
	Damage = 16,
	Range = 50,
	Weight = 1,
	Execute = function(ctx)
		local targets = ctx:Enemies(ctx.Root.Position, 50)
		for _, target in ipairs(targets) do
			ctx:Telegraph(target.Root.Position, 6, 0.8, Color3.fromRGB(150, 220, 255))
		end
		if not ctx:Wait(0.8) then
			return
		end
		for _, target in ipairs(ctx:Enemies(ctx.Root.Position, 50)) do
			ctx:FX("IceSpikes", { Position = target.Root.Position, Color = ctx.Color, Size = 6 })
			for _, hit in ipairs(ctx:HitRadius(target.Root.Position, 6, {})) do
				ctx:Freeze(hit, 1.5)
			end
		end
	end,
}

BossSkills.Summon = {
	Name = "Call Minions",
	Cooldown = 25,
	Damage = 0,
	Range = 999,
	Weight = 1,
	Execute = function(ctx)
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 30 })
		local minion = ctx.Entity.Definition and ctx.Entity.Definition.Minion or "DungeonMinion"
		ctx:SpawnMinions(minion, 3)
	end,
}

BossSkills.WarCry = {
	Name = "War Cry",
	Cooldown = 20,
	Damage = 0,
	Range = 999,
	Weight = 1,
	Execute = function(ctx)
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 36 })
		ctx:FX("Aura", { Model = ctx.Caster, Color = ctx.Color, Duration = 8 })
		ctx:Buff(ctx.Entity, "WarCry", { DamageMult = 0.25, DamageReduction = 0.1 }, 8)
		ctx:HitRadius(ctx.Root.Position, 14, { Damage = 0.01, Knockback = 60 })
	end,
}

BossSkills.CounterStance = {
	Name = "Counter Stance",
	Cooldown = 14,
	Damage = 30,
	Range = 12,
	Weight = 1,
	Execute = function(ctx)
		ctx:Counter(1.4, function(c, attacker)
			c:Teleport(CFrame.lookAt((attacker.Root.CFrame * CFrame.new(0, 0, 5)).Position, attacker.Root.Position))
			c:FX("Slash", { CFrame = attacker.Root.CFrame, Color = c.Color, Size = 16, Heavy = true })
			c:Damage(attacker, { Stun = 1.2, Knockback = 80, Unblockable = true })
		end)
	end,
}

-- ULTIMATES --------------------------------------------------------------------------------------

BossSkills.Nova = {
	Name = "Supernova",
	Cooldown = 40,
	Damage = 60,
	Range = 999,
	Ultimate = true,
	Execute = function(ctx)
		ctx:SuperArmor(3.5)
		ctx:IFrames(0.5)
		ctx:FX("UltimateBanner", { Model = ctx.Caster, Name = ctx.Skill.Name, Color = ctx.Color })
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 2.2 })
		ctx:Telegraph(ctx.Root.Position, 45, 2.4, ctx.Color)
		if not ctx:Wait(2.4) then
			return
		end
		ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
		ctx:FX("Explosion", { Position = ctx.Root.Position, Color = ctx.Color, Size = 90 })
		ctx:Shake(ctx.Root.Position, 1.3, 150)
		ctx:HitRadius(ctx.Root.Position, 45, { Stun = 1.4, Knockback = 130, Up = 50, Ragdoll = 1.8 })
	end,
}

BossSkills.Domain = {
	Name = "Domain of Ruin",
	Cooldown = 45,
	Damage = 14,
	Range = 999,
	Ultimate = true,
	Execute = function(ctx)
		ctx:SuperArmor(5)
		ctx:FX("UltimateBanner", { Model = ctx.Caster, Name = ctx.Skill.Name, Color = ctx.Color })
		ctx:FX("Domain", { Position = ctx.Root.Position, Color = ctx.Color, Size = 110, Duration = 4.5 })
		ctx:Wait(0.8)
		for _ = 1, 7 do
			for _, target in ipairs(ctx:Enemies(ctx.Root.Position, 55)) do
				ctx:Telegraph(target.Root.Position, 7, 0.45, ctx.Color)
			end
			if not ctx:Wait(0.45) then
				return
			end
			for _, target in ipairs(ctx:Enemies(ctx.Root.Position, 55)) do
				ctx:FX("Pillar", { Position = target.Root.Position, Color = ctx.Color, Size = 7, Height = 50 })
				ctx:HitRadius(target.Root.Position, 7, { Stun = 0.5 })
			end
		end
	end,
}

BossSkills.Cataclysm = {
	Name = "Cataclysm",
	Cooldown = 45,
	Damage = 30,
	Range = 999,
	Ultimate = true,
	Execute = function(ctx)
		ctx:SuperArmor(4)
		ctx:FX("UltimateBanner", { Model = ctx.Caster, Name = ctx.Skill.Name, Color = ctx.Color })
		ctx:Launch(60)
		ctx:Wait(0.6)
		for _ = 1, 10 do
			local pos = ctx.Root.Position + Vector3.new(math.random(-40, 40), -8, math.random(-40, 40))
			ctx:Telegraph(pos, 10, 0.6, ctx.Color)
			task.delay(0.6, function()
				ctx:FX("Meteor", { Position = pos, Color = ctx.Color, Size = 8 })
				ctx:HitRadius(pos, 10, { Stun = 0.7, Knockback = 50, Up = 20 })
			end)
			if not ctx:Wait(0.2) then
				return
			end
		end
		ctx:Wait(0.8)
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 80 })
		ctx:HitRadius(ctx.Root.Position, 40, { Damage = 1.5, Knockback = 100, Up = 30 })
	end,
}

return BossSkills
