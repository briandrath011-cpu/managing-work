--[[
	Shadow Monarch (ModuleScript) - Legendary summoner power
	Location: ReplicatedStorage.Modules.Powers.List.ShadowMonarch
	Skill 1 Shadow Slash | 2 Shadow Soldiers | 3 Shadow Exchange | ULT Arise
]]
local SHADOW = Color3.fromRGB(110, 60, 220)
local BLACK = Color3.fromRGB(15, 5, 30)

return {
	Id = "ShadowMonarch",
	DisplayName = "Shadow Monarch",
	Rarity = "Legendary",
	Element = "Shadow",
	Color = SHADOW,
	SecondaryColor = BLACK,
	Description = "Command an army of shadows that fight for you.",
	Passive = {
		Name = "Monarch's Domain",
		Description = "+10% power damage, +3% lifesteal.",
		Modifiers = { PowerDamage = 0.1, Lifesteal = 0.03 },
	},
	Skills = {
		{
			Name = "Shadow Slash",
			Description = "A dark energy blade that pierces enemies.",
			Cooldown = 6,
			EnergyCost = 15,
			Damage = 38,
			Range = 40,
			Animation = "Power_Slash",
			Sounds = { Cast = "Shadow_Slash" },
			Execute = function(ctx)
				ctx:Anim("Power_Slash")
				ctx:Sound("Shadow_Slash")
				ctx:Projectile({
					Speed = 110,
					Range = 40,
					Radius = 6,
					Pierce = true,
					Visual = { Kind = "Crescent", Color = SHADOW, Size = 10 },
					Spec = { Stun = 0.6, Knockback = 25 },
				})
			end,
		},
		{
			Name = "Shadow Soldiers",
			Description = "Summon 3 shadow soldiers that fight for 18 seconds.",
			Cooldown = 24,
			EnergyCost = 35,
			Damage = 14,
			Range = 10,
			Animation = "Power_Summon",
			Sounds = { Cast = "Shadow_Summon" },
			Execute = function(ctx)
				ctx:Anim("Power_Summon")
				ctx:Sound("Shadow_Summon")
				ctx:FX("Shockwave", { Position = ctx.Root.Position - Vector3.new(0, 2.5, 0), Color = BLACK, Size = 20 })
				ctx:Summon({
					Name = "Shadow Soldier",
					Count = 3,
					Duration = 18,
					Color = BLACK,
					Accent = SHADOW,
					DamageMultiplier = 1,
					HealthMultiplier = 0.6,
				})
			end,
		},
		{
			Name = "Shadow Exchange",
			Description = "Swap places with your nearest shadow (or teleport behind the target).",
			Cooldown = 9,
			EnergyCost = 15,
			Damage = 30,
			Range = 60,
			Animation = "Power_Teleport",
			Sounds = { Cast = "Shadow_Teleport" },
			Execute = function(ctx)
				ctx:Sound("Shadow_Teleport")
				local summon = ctx:NearestSummon(ctx.AimPosition)
				local from = ctx.Root.CFrame
				ctx:FX("Afterimage", { Model = ctx.Caster, Color = SHADOW })
				if summon then
					local summonCf = summon.Root.CFrame
					ctx:Teleport(summonCf)
					summon.Root.CFrame = from
				else
					local target = ctx:NearestEnemy(ctx.AimPosition, 20)
					if not target then
						return
					end
					ctx:Teleport(target.Root.CFrame * CFrame.new(0, 0, 4))
				end
				ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = SHADOW, Size = 14 })
				ctx:HitRadius(ctx.Root.Position, 9, { Stun = 0.8, Knockback = 40 })
			end,
		},
		{
			Name = "Arise",
			Description = "ULTIMATE: Raise a shadow army from the ground for a short time.",
			Cooldown = 55,
			EnergyCost = 75,
			Damage = 40,
			Range = 30,
			Animation = "Power_Ultimate",
			Sounds = { Cast = "Arise" },
			Execute = function(ctx)
				ctx:Cinematic(2, "Ultimate")
				ctx:Sound("Arise")
				ctx:Aura(4)
				ctx:FX("Domain", { Position = ctx.Root.Position, Color = BLACK, Size = 70, Duration = 2 })
				ctx:Wait(0.8)
				ctx:FX("ScreenFlash", { Color = SHADOW, Duration = 0.2, Position = ctx.Root.Position })
				ctx:HitRadius(ctx.Root.Position, 30, { Stun = 1, Up = 40, Launch = true })
				ctx:Summon({
					Name = "Shadow Knight",
					Count = 8,
					Duration = 12,
					Color = BLACK,
					Accent = SHADOW,
					DamageMultiplier = 1.6,
					HealthMultiplier = 1,
					Scale = 1.15,
				})
			end,
		},
	},
}
