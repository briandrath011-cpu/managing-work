--[[
	Rubber Power (ModuleScript) - Rare stretch power
	Location: ReplicatedStorage.Modules.Powers.List.RubberPower
	Skill 1 Pistol | 2 Gatling | 3 Rocket | ULT Giant Impact
]]
local SKIN = Color3.fromRGB(255, 200, 160)
local RED = Color3.fromRGB(230, 50, 50)

return {
	Id = "RubberPower",
	DisplayName = "Rubber Power",
	Rarity = "Rare",
	Element = "Rubber",
	Color = SKIN,
	SecondaryColor = RED,
	Description = "Your body stretches like rubber. Punches reach far.",
	Passive = {
		Name = "Rubber Body",
		Description = "+8% damage reduction, +6% fighting style damage.",
		Modifiers = { DamageReduction = 0.08, StyleDamage = 0.06 },
	},
	Skills = {
		{
			Name = "Pistol",
			Description = "A stretched long-range punch.",
			Cooldown = 5,
			EnergyCost = 10,
			Damage = 34,
			Range = 40,
			Animation = "Rubber_Pistol",
			Sounds = { Cast = "Stretch", Impact = "Punch" },
			Execute = function(ctx)
				ctx:Anim("Rubber_Pistol")
				ctx:Sound("Stretch")
				local origin = ctx.Root.Position
				ctx:FX("Stretch", { From = origin, To = origin + ctx.AimDirection * 40, Color = SKIN, Width = 1.2, Duration = 0.3 })
				ctx:HitLine(origin, ctx.AimDirection, 40, 4, { Stun = 0.6, Knockback = 60 })
			end,
		},
		{
			Name = "Gatling",
			Description = "A barrage of stretching punches.",
			Cooldown = 9,
			EnergyCost = 18,
			Damage = 8,
			Range = 16,
			Animation = "Rubber_Gatling",
			Sounds = { Cast = "Stretch", Impact = "Punch" },
			Execute = function(ctx)
				ctx:Anim("Rubber_Gatling")
				for i = 1, 12 do
					local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 8, ctx.Root.Position + ctx.AimDirection * 16)
					ctx:FX("Stretch", {
						From = ctx.Root.Position,
						To = cf.Position + Vector3.new(math.random(-3, 3), math.random(-2, 2), 0),
						Color = SKIN,
						Width = 0.8,
						Duration = 0.1,
					})
					ctx:HitBox(cf, Vector3.new(9, 8, 16), { Stun = 0.35, Knockback = i == 12 and 60 or 0 })
					if not ctx:Wait(0.08) then
						return
					end
				end
			end,
		},
		{
			Name = "Rocket",
			Description = "Launch yourself forward and crash into enemies.",
			Cooldown = 8,
			EnergyCost = 14,
			Damage = 36,
			Range = 40,
			Animation = "Rubber_Rocket",
			Sounds = { Cast = "Stretch" },
			Execute = function(ctx)
				ctx:Sound("Stretch")
				ctx:Dash(ctx.AimDirection + Vector3.new(0, 0.2, 0), 36, 0.35)
				ctx:Wait(0.35)
				ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = SKIN, Size = 16 })
				ctx:HitRadius(ctx.Root.Position, 9, { Stun = 0.7, Knockback = 80, Up = 20, Ragdoll = 1 })
			end,
		},
		{
			Name = "Giant Impact",
			Description = "ULTIMATE: Inflate your fist to titanic size and smash it down.",
			Cooldown = 40,
			EnergyCost = 60,
			Damage = 120,
			Range = 40,
			Animation = "Rubber_Ultimate",
			Sounds = { Charge = "Inflate", Impact = "Explosion" },
			Execute = function(ctx)
				ctx:Cinematic(1.4, "Ultimate")
				ctx:SuperArmor(2)
				ctx:Sound("Inflate")
				local center = ctx.AimPosition
				ctx:Telegraph(center, 20, 1)
				ctx:FX("GiantFist", { Position = center, Color = SKIN, Size = 18, Delay = 1 })
				if not ctx:Wait(1) then
					return
				end
				ctx:FX("ImpactFrame", { Position = center })
				ctx:FX("Crater", { Position = center, Size = 22 })
				ctx:FX("Debris", { Position = center, Count = 16, Color = Color3.fromRGB(110, 100, 90) })
				ctx:Shake(center, 1.2, 100)
				ctx:HitRadius(center, 20, { Stun = 1.4, Knockback = 100, Up = 40, Ragdoll = 1.8, GuardBreak = true })
			end,
		},
	},
}
