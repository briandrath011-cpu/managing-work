--[[
	Gale (ModuleScript) - Common wind power
	Location: ReplicatedStorage.Modules.Powers.List.Gale
	Skill 1 Wind Blade | 2 Cyclone | 3 Tailwind | ULT Tempest
]]
local WIND = Color3.fromRGB(170, 255, 210)

return {
	Id = "Gale",
	DisplayName = "Gale",
	Rarity = "Common",
	Element = "Wind",
	Color = WIND,
	SecondaryColor = Color3.fromRGB(240, 255, 250),
	Description = "Slice and push with sharp winds.",
	Passive = { Name = "Light Feet", Description = "+2 move speed.", Modifiers = { MoveSpeed = 2 } },
	Skills = {
		{
			Name = "Wind Blade",
			Description = "A fast cutting gust.",
			Cooldown = 5,
			EnergyCost = 10,
			Damage = 24,
			Range = 45,
			Execute = function(ctx)
				ctx:Anim("Power_Slash")
				ctx:Projectile({
					Speed = 130,
					Range = 45,
					Radius = 5,
					Pierce = true,
					Visual = { Kind = "Crescent", Color = WIND, Size = 7 },
					Spec = { Stun = 0.4, Knockback = 20 },
				})
			end,
		},
		{
			Name = "Cyclone",
			Description = "Create a small tornado that pulls enemies in.",
			Cooldown = 10,
			EnergyCost = 18,
			Damage = 10,
			Range = 30,
			Execute = function(ctx)
				local pos = ctx.Root.Position + ctx.AimDirection * 14
				for _ = 1, 6 do
					ctx:FX("Tornado", { Position = pos, Color = WIND, Size = 10 })
					ctx:HitRadius(pos, 11, { Stun = 0.4, Pull = pos, Up = 8 })
					if not ctx:Wait(0.25) then
						return
					end
				end
			end,
		},
		{
			Name = "Tailwind",
			Description = "Dash forward and gain speed for 6 seconds.",
			Cooldown = 12,
			EnergyCost = 14,
			Damage = 18,
			Range = 30,
			Execute = function(ctx)
				ctx:Afterimage()
				ctx:Dash(ctx.AimDirection, 26, 0.2)
				ctx:Buff(ctx.Entity, "Tailwind", { MoveSpeed = 8 }, 6)
				ctx:HitLine(ctx.Root.Position, ctx.AimDirection, 26, 6, { Stun = 0.4, Knockback = 30 })
			end,
		},
		{
			Name = "Tempest",
			Description = "ULTIMATE: A roaring storm of blades around you.",
			Cooldown = 35,
			EnergyCost = 50,
			Damage = 14,
			Range = 22,
			Execute = function(ctx)
				ctx:Cinematic(1, "Ultimate")
				ctx:SuperArmor(2.4)
				for _ = 1, 10 do
					ctx:FX("Tornado", { Position = ctx.Root.Position, Color = WIND, Size = 22 })
					ctx:HitRadius(ctx.Root.Position, 22, { Stun = 0.35, Pull = ctx.Root.Position })
					if not ctx:Wait(0.2) then
						return
					end
				end
				ctx:HitRadius(ctx.Root.Position, 22, { Damage = 3, Knockback = 100, Up = 50, Ragdoll = 1.2 })
			end,
		},
	},
}
