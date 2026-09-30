--[[
	Blaze (ModuleScript) - Common fire power. Good template for new powers.
	Location: ReplicatedStorage.Modules.Powers.List.Blaze
	Skill 1 Fire Fist | 2 Flame Wheel | 3 Ember Burst | ULT Inferno Pillar
]]
local FIRE = Color3.fromRGB(255, 110, 30)

return {
	Id = "Blaze",
	DisplayName = "Blaze",
	Rarity = "Common",
	Element = "Fire",
	Color = FIRE,
	SecondaryColor = Color3.fromRGB(255, 220, 90),
	Description = "Basic but reliable fire manipulation.",
	SpinWeight = 1,
	Passive = { Name = "Kindling", Description = "+5% power damage.", Modifiers = { PowerDamage = 0.05 } },
	Skills = {
		{
			Name = "Fire Fist",
			Description = "Throw a fireball.",
			Cooldown = 5,
			EnergyCost = 12,
			Damage = 26,
			Range = 45,
			Execute = function(ctx)
				ctx:Anim("Power_Throw")
				ctx:Sound("Fire_Cast")
				ctx:Projectile({
					Speed = 95,
					Range = 45,
					Radius = 4,
					Visual = { Kind = "Fireball", Color = FIRE, Size = 3 },
					Spec = { Stun = 0.5, Knockback = 25, Burn = true },
				})
			end,
		},
		{
			Name = "Flame Wheel",
			Description = "Spin in a ring of flame.",
			Cooldown = 9,
			EnergyCost = 16,
			Damage = 12,
			Range = 12,
			Execute = function(ctx)
				ctx:Anim("Power_Spin")
				for _ = 1, 4 do
					ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = FIRE, Size = 22 })
					ctx:HitRadius(ctx.Root.Position, 11, { Stun = 0.4, Burn = true })
					if not ctx:Wait(0.2) then
						return
					end
				end
			end,
		},
		{
			Name = "Ember Burst",
			Description = "Explode in a burst of embers that launches enemies.",
			Cooldown = 12,
			EnergyCost = 22,
			Damage = 38,
			Range = 14,
			Execute = function(ctx)
				ctx:Anim("Power_Cast")
				ctx:FX("Explosion", { Position = ctx.Root.Position, Color = FIRE, Size = 24 })
				ctx:HitRadius(ctx.Root.Position, 13, { Stun = 0.8, Up = 50, Launch = true, Knockback = 20 })
			end,
		},
		{
			Name = "Inferno Pillar",
			Description = "ULTIMATE: A towering pillar of fire erupts under the target.",
			Cooldown = 35,
			EnergyCost = 50,
			Damage = 30,
			Range = 45,
			Execute = function(ctx)
				ctx:Cinematic(1, "Ultimate")
				local pos = ctx.AimPosition
				ctx:Telegraph(pos, 14, 0.6)
				ctx:Wait(0.6)
				for _ = 1, 5 do
					ctx:FX("Pillar", { Position = pos, Color = FIRE, Size = 14, Height = 70 })
					ctx:HitRadius(pos, 14, { Stun = 0.5, Up = 15, Burn = true })
					if not ctx:Wait(0.25) then
						return
					end
				end
				ctx:HitRadius(pos, 14, { Damage = 2, Knockback = 70, Up = 40, Ragdoll = 1 })
			end,
		},
	},
}
