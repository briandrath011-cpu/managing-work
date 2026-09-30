--[[
	Time Stand (ModuleScript) - Legendary stand power
	Location: ReplicatedStorage.Modules.Powers.List.TimeStand
	Skill 1 Stand Barrage | 2 Heavy Impact | 3 Time Stop | ULT World Breaker
]]
local GOLD = Color3.fromRGB(255, 215, 90)

return {
	Id = "TimeStand",
	DisplayName = "Time Stand",
	Rarity = "Legendary",
	Element = "Time",
	Color = GOLD,
	SecondaryColor = Color3.fromRGB(80, 200, 120),
	Description = "A golden guardian spirit that can halt time.",
	Passive = {
		Name = "Guardian Spirit",
		Description = "+8% all damage, +5% crit chance.",
		Modifiers = { DamageMult = 0.08, CritChance = 0.05 },
	},
	Skills = {
		{
			Name = "Stand Barrage",
			Description = "Your stand unleashes a storm of punches.",
			Cooldown = 8,
			EnergyCost = 18,
			Damage = 7,
			Range = 10,
			Animation = "Stand_Barrage",
			Sounds = { Cast = "Stand_Summon", Impact = "Punch" },
			Execute = function(ctx)
				ctx:FX("Stand", { Model = ctx.Caster, Color = ctx.Color, Duration = 1.6, Pose = "Barrage" })
				ctx:Sound("Stand_Summon")
				for i = 1, 14 do
					local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 5, ctx.Root.Position + ctx.AimDirection * 10)
					ctx:HitBox(cf, Vector3.new(8, 8, 9), { Stun = 0.35, Knockback = i == 14 and 70 or 0, GuardDamage = 6 })
					if i % 3 == 0 then
						ctx:FX("HitSpark", { Position = cf.Position, Color = ctx.Color })
					end
					if not ctx:Wait(0.08) then
						return
					end
				end
			end,
		},
		{
			Name = "Heavy Impact",
			Description = "A single devastating stand punch that breaks guards.",
			Cooldown = 10,
			EnergyCost = 22,
			Damage = 60,
			Range = 10,
			Animation = "Stand_Heavy",
			Sounds = { Charge = "Stand_Charge", Impact = "Punch_Heavy" },
			Execute = function(ctx)
				ctx:FX("Stand", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.9, Pose = "Heavy" })
				ctx:Sound("Stand_Charge")
				if not ctx:Wait(0.35) then
					return
				end
				local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 5, ctx.Root.Position + ctx.AimDirection * 10)
				ctx:FX("Shockwave", { Position = cf.Position, Color = ctx.Color, Size = 16 })
				ctx:FX("ImpactFrame", { Position = cf.Position })
				ctx:HitBox(cf, Vector3.new(9, 9, 10), { Stun = 1, Knockback = 120, Up = 20, GuardBreak = true, Ragdoll = 1.2 })
			end,
		},
		{
			Name = "Time Stop",
			Description = "Freeze every nearby enemy in time for a few seconds.",
			Cooldown = 22,
			EnergyCost = 40,
			Damage = 10,
			Range = 35,
			Animation = "Stand_TimeStop",
			Sounds = { Cast = "TimeStop" },
			Execute = function(ctx)
				ctx:Sound("TimeStop")
				ctx:FX("TimeStop", { Position = ctx.Root.Position, Radius = 35, Duration = 3 })
				for _, target in ipairs(ctx:Enemies(ctx.Root.Position, 35)) do
					ctx:Freeze(target, 3)
					ctx:Damage(target, { Damage = 1 })
				end
			end,
		},
		{
			Name = "World Breaker",
			Description = "ULTIMATE: Stop time and unleash a massive combo on your target.",
			Cooldown = 45,
			EnergyCost = 70,
			Damage = 16,
			Range = 30,
			Animation = "Stand_Ultimate",
			Sounds = { Cast = "TimeStop", Impact = "Punch_Heavy" },
			Execute = function(ctx)
				ctx:Cinematic(1.2, "Ultimate")
				ctx:Sound("TimeStop")
				ctx:FX("TimeStop", { Position = ctx.Root.Position, Radius = 40, Duration = 3.2 })
				local targets = ctx:Enemies(ctx.Root.Position, 40)
				for _, target in ipairs(targets) do
					ctx:Freeze(target, 3.2)
				end
				local main = ctx:NearestEnemy(ctx.AimPosition, 30)
				if not main then
					return
				end
				ctx:Teleport(main.Root.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0))
				ctx:FX("Stand", { Model = ctx.Caster, Color = ctx.Color, Duration = 3, Pose = "Barrage" })
				for _ = 1, 20 do
					ctx:Damage(main, { Damage = 1, Stun = 0.2, NoAwakening = false })
					ctx:FX("HitSpark", { Position = main.Root.Position, Color = ctx.Color })
					if not ctx:Wait(0.08) then
						return
					end
				end
				ctx:FX("ImpactFrame", { Position = main.Root.Position })
				ctx:Damage(main, { Damage = 8, Stun = 1.5, GuardBreak = true })
				ctx:Knockback(main, ctx.Root.Position, 160, 30)
				ctx:Shake(main.Root.Position, 1.2, 80)
			end,
		},
	},
}
