--[[
	Limitless (ModuleScript) - Mythic spatial power
	Location: ReplicatedStorage.Modules.Powers.List.Limitless
	Skill 1 Attraction | 2 Repulsion | 3 Infinity Counter | ULT Void Domain
]]
local BLUE = Color3.fromRGB(70, 150, 255)
local RED = Color3.fromRGB(255, 60, 60)
local VOID = Color3.fromRGB(160, 120, 255)

return {
	Id = "Limitless",
	DisplayName = "Limitless",
	Rarity = "Mythic",
	Element = "Space",
	Color = BLUE,
	SecondaryColor = RED,
	Description = "Manipulate infinity: attract, repel and nullify.",
	Passive = {
		Name = "Infinity",
		Description = "+12% damage reduction, +10% cooldown reduction.",
		Modifiers = { DamageReduction = 0.12, CooldownReduction = 0.1 },
	},
	Skills = {
		{
			Name = "Attraction",
			Description = "Create a blue point that drags enemies into it.",
			Cooldown = 8,
			EnergyCost = 20,
			Damage = 14,
			Range = 45,
			Animation = "Power_Point",
			Sounds = { Cast = "Blue_Cast" },
			Execute = function(ctx)
				ctx:Anim("Power_Point")
				ctx:Sound("Blue_Cast")
				local point = ctx.AimPosition + Vector3.new(0, 4, 0)
				ctx:FX("Singularity", { Position = point, Color = BLUE, Size = 6, Duration = 1.8 })
				for _ = 1, 6 do
					ctx:HitRadius(point, 20, { Damage = 1, Stun = 0.5, Pull = point })
					if not ctx:Wait(0.3) then
						return
					end
				end
			end,
		},
		{
			Name = "Repulsion",
			Description = "Fire a red orb that detonates in an explosive shockwave.",
			Cooldown = 10,
			EnergyCost = 26,
			Damage = 55,
			Range = 55,
			Animation = "Power_Point",
			Sounds = { Cast = "Red_Cast", Impact = "Explosion" },
			Execute = function(ctx)
				ctx:Anim("Power_Point")
				ctx:Sound("Red_Cast")
				ctx:Projectile({
					Speed = 130,
					Range = 55,
					Radius = 4,
					Visual = { Kind = "Orb", Color = RED, Size = 3 },
					Spec = { Damage = 0.4, Stun = 0.3 },
					OnEnd = function(c, pos)
						c:FX("Explosion", { Position = pos, Color = RED, Size = 26 })
						c:FX("Shockwave", { Position = pos, Color = RED, Size = 36 })
						c:Shake(pos, 0.7, 60)
						c:HitRadius(pos, 16, { Damage = 1, Knockback = 130, Up = 25, Ragdoll = 1.2 })
					end,
				})
			end,
		},
		{
			Name = "Infinity Counter",
			Description = "For 1.5s, attacks can't reach you. Attackers are repelled and damaged.",
			Cooldown = 14,
			EnergyCost = 25,
			Damage = 60,
			Range = 10,
			Animation = "Power_Guard",
			Sounds = { Cast = "Infinity" },
			Execute = function(ctx)
				ctx:Anim("Power_Guard")
				ctx:Sound("Infinity")
				ctx:FX("Aura", { Model = ctx.Caster, Color = Color3.fromRGB(200, 230, 255), Duration = 1.5 })
				ctx:Counter(1.5, function(c, attacker)
					c:FX("Shockwave", { Position = c.Root.Position, Color = BLUE, Size = 20 })
					c:Damage(attacker, { Damage = 1, Stun = 1.2 })
					c:Knockback(attacker, c.Root.Position, 110, 20)
				end)
			end,
		},
		{
			Name = "Void Domain",
			Description = "ULTIMATE: Expand a domain of infinite information. Everyone inside is paralysed.",
			Cooldown = 50,
			EnergyCost = 80,
			Damage = 30,
			Range = 40,
			Animation = "Power_Domain",
			Sounds = { Cast = "Domain_Expand", Impact = "Domain_Hit" },
			Execute = function(ctx)
				ctx:Cinematic(2, "Domain")
				ctx:SuperArmor(5)
				ctx:Sound("Domain_Expand")
				local center = ctx.Root.Position
				ctx:FX("Domain", { Position = center, Color = VOID, Size = 100, Duration = 5, Style = "Void" })
				ctx:Wait(0.8)
				for _ = 1, 8 do
					for _, target in ipairs(ctx:Enemies(center, 45)) do
						ctx:Freeze(target, 0.6)
						ctx:Damage(target, { Damage = 1 })
						ctx:FX("HitSpark", { Position = target.Root.Position, Color = VOID })
					end
					if not ctx:Wait(0.5) then
						return
					end
				end
				ctx:FX("ImpactFrame", { Position = center })
				ctx:HitRadius(center, 45, { Damage = 3, Knockback = 90, Ragdoll = 1.5 })
			end,
		},
	},
}
