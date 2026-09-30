--[[
	EnemySkills (ModuleScript)
	Location: ReplicatedStorage.Modules.Enemies.EnemySkills
	Skills used by normal/elite enemies (and summons). Same ctx API as powers.
	Damage here is in "M1 units x10" (the NPC's level scales it through SourceMultiplier).
	Every skill has a telegraph or wind-up so players can react (block/dash).
]]
local EnemySkills = {}

EnemySkills.Lunge = {
	Name = "Lunge",
	Cooldown = 6,
	Damage = 14,
	Range = 22,
	MinRange = 8,
	Execute = function(ctx)
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.35 })
		if not ctx:Wait(0.35) then
			return
		end
		local start = ctx.Root.Position
		ctx:Dash(ctx.AimDirection, 18, 0.2)
		ctx:Wait(0.2)
		ctx:HitLine(start, ctx.AimDirection, 20, 6, { Stun = 0.5, Knockback = 30 })
	end,
}

EnemySkills.Slam = {
	Name = "Ground Slam",
	Cooldown = 9,
	Damage = 22,
	Range = 10,
	Execute = function(ctx)
		ctx:Telegraph(ctx.Root.Position, 12, 0.7)
		if not ctx:Wait(0.7) then
			return
		end
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 24 })
		ctx:FX("GroundCracks", { Position = ctx.Root.Position - Vector3.new(0, 2.5, 0), Size = 10 })
		ctx:HitRadius(ctx.Root.Position, 12, { Stun = 0.8, Knockback = 50, Up = 25 })
	end,
}

EnemySkills.Spin = {
	Name = "Spin Attack",
	Cooldown = 8,
	Damage = 9,
	Range = 8,
	Execute = function(ctx)
		for _ = 1, 3 do
			ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = ctx.Color, Size = 16 })
			ctx:HitRadius(ctx.Root.Position, 8, { Stun = 0.4 })
			if not ctx:Wait(0.25) then
				return
			end
		end
	end,
}

EnemySkills.Fireball = {
	Name = "Fireball",
	Cooldown = 5,
	Damage = 14,
	Range = 45,
	MinRange = 6,
	Execute = function(ctx)
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.4 })
		if not ctx:Wait(0.4) then
			return
		end
		ctx:Projectile({
			Speed = 70,
			Range = 45,
			Radius = 3,
			Visual = { Kind = "Fireball", Color = ctx.Color, Size = 2.5 },
			Spec = { Stun = 0.4, Knockback = 20 },
		})
	end,
}

EnemySkills.Volley = {
	Name = "Volley",
	Cooldown = 7,
	Damage = 8,
	Range = 45,
	MinRange = 8,
	Execute = function(ctx)
		for i = -1, 1 do
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(i * 12)) * ctx.AimDirection).Unit
			ctx:Projectile({
				Direction = dir,
				Speed = 90,
				Range = 45,
				Radius = 2.5,
				Visual = { Kind = "Knife", Color = ctx.Color, Size = 1.5 },
				Spec = { Stun = 0.3 },
			})
		end
	end,
}

EnemySkills.Leap = {
	Name = "Leap Strike",
	Cooldown = 10,
	Damage = 20,
	Range = 35,
	MinRange = 12,
	Execute = function(ctx)
		local target = ctx.AimPosition
		ctx:Telegraph(target, 10, 0.8)
		ctx:Launch(55)
		if not ctx:Wait(0.4) then
			return
		end
		ctx:Teleport(CFrame.new(target + Vector3.new(0, 4, 0)))
		ctx:Wait(0.35)
		ctx:FX("Shockwave", { Position = target, Color = ctx.Color, Size = 20 })
		ctx:HitRadius(target, 10, { Stun = 0.8, Knockback = 45, Up = 20 })
	end,
}

EnemySkills.Beam = {
	Name = "Energy Beam",
	Cooldown = 10,
	Damage = 24,
	Range = 55,
	MinRange = 10,
	Execute = function(ctx)
		local origin = ctx.Root.Position
		local dir = ctx.AimDirection
		ctx:FX("Beam", { From = origin, To = origin + dir * 55, Color = Color3.fromRGB(255, 60, 60), Width = 0.4, Duration = 0.8 })
		if not ctx:Wait(0.8) then
			return
		end
		ctx:FX("Beam", { From = origin, To = origin + dir * 55, Color = ctx.Color, Width = 4, Duration = 0.4 })
		ctx:HitLine(origin, dir, 55, 6, { Stun = 0.6, Knockback = 40 })
	end,
}

EnemySkills.Freeze = {
	Name = "Frost Breath",
	Cooldown = 12,
	Damage = 12,
	Range = 18,
	Execute = function(ctx)
		ctx:FX("Charge", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.5 })
		if not ctx:Wait(0.5) then
			return
		end
		local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 9, ctx.Root.Position + ctx.AimDirection * 18)
		ctx:FX("IceSpikes", { Position = cf.Position, Color = ctx.Color, Size = 8 })
		for _, target in ipairs(ctx:HitBox(cf, Vector3.new(12, 8, 18), { Stun = 0.2 })) do
			ctx:Freeze(target, 1)
		end
	end,
}

EnemySkills.Heal = {
	Name = "Dark Mend",
	Cooldown = 18,
	Damage = 0,
	Range = 999,
	SelfCast = true,
	HealthBelow = 0.5,
	Execute = function(ctx)
		ctx:FX("Aura", { Model = ctx.Caster, Color = Color3.fromRGB(80, 255, 120), Duration = 1 })
		ctx:Heal(ctx.Entity, ctx.Humanoid.MaxHealth * 0.15)
	end,
}

return EnemySkills
