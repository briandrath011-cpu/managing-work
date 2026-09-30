--[[
	Rinnegan (ModuleScript) - Mythic gravity power
	Location: ReplicatedStorage.Modules.Powers.List.Rinnegan
	Skill 1 Almighty Push | 2 Universal Pull | 3 Planetary Devastation | ULT Six Paths Cataclysm
	Animations / Sounds reference names in Modules.Assets.AssetIds.
]]
local PURPLE = Color3.fromRGB(170, 120, 255)
local DARK = Color3.fromRGB(60, 30, 110)

return {
	Id = "Rinnegan",
	DisplayName = "Rinnegan",
	Rarity = "Mythic",
	Element = "Gravity",
	Color = PURPLE,
	SecondaryColor = DARK,
	Description = "Command gravity itself: repel, attract and crush.",
	Passive = {
		Name = "Deva Path",
		Description = "+10% power damage, +8% damage reduction.",
		Modifiers = { PowerDamage = 0.1, DamageReduction = 0.08 },
	},
	Skills = {
		{
			Name = "Almighty Push",
			Description = "A huge gravity shockwave that blasts every enemy away.",
			Cooldown = 7,
			EnergyCost = 20,
			Damage = 42,
			Range = 22,
			Animation = "Power_Push",
			Sounds = { Cast = "Gravity_Cast", Impact = "Gravity_Impact" },
			Execute = function(ctx)
				ctx:Anim("Power_Push")
				ctx:Sound("Gravity_Cast")
				local pos = ctx.Root.Position
				ctx:FX("Shockwave", { Position = pos, Color = ctx.Color, Size = 48 })
				ctx:FX("EnergyRing", { Position = pos, Color = Color3.new(1, 1, 1), Size = 40 })
				ctx:FX("Dust", { Position = pos - Vector3.new(0, 2.5, 0), Size = 22 })
				ctx:Shake(pos, 0.5, 60)
				ctx:HitRadius(pos, 22, { Stun = 0.7, Knockback = 110, Up = 25, Ragdoll = 1, GuardDamage = 40 })
			end,
		},
		{
			Name = "Universal Pull",
			Description = "Drag every enemy in front of you to your feet.",
			Cooldown = 9,
			EnergyCost = 22,
			Damage = 30,
			Range = 40,
			Animation = "Power_Pull",
			Sounds = { Cast = "Gravity_Pull" },
			Execute = function(ctx)
				ctx:Anim("Power_Pull")
				ctx:Sound("Gravity_Pull")
				local targets = ctx:HitBox(
					CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 20, ctx.Root.Position + ctx.AimDirection * 40),
					Vector3.new(18, 12, 40),
					{ Stun = 1.1 }
				)
				for _, target in ipairs(targets) do
					ctx:FX("Beam", { From = ctx.Root.Position, To = target.Root.Position, Color = ctx.Color, Width = 0.6, Duration = 0.35 })
					ctx:Pull(target, ctx.Root.Position + ctx.AimDirection * 4, 90)
				end
			end,
		},
		{
			Name = "Planetary Devastation",
			Description = "Launch a gravity core that sucks in enemies and debris, then collapses.",
			Cooldown = 14,
			EnergyCost = 35,
			Damage = 26,
			Range = 50,
			Animation = "Power_Cast",
			Sounds = { Charge = "Gravity_Charge", Impact = "Gravity_Impact" },
			Execute = function(ctx)
				ctx:Anim("Power_Cast")
				ctx:Sound("Gravity_Charge")
				local core = ctx.AimPosition + Vector3.new(0, 12, 0)
				ctx:FX("Singularity", { Position = core, Color = DARK, Size = 8, Duration = 2.6 })
				ctx:FX("Debris", { Position = ctx.AimPosition, Count = 14, Color = Color3.fromRGB(120, 110, 100), PullTo = core })
				for _ = 1, 8 do
					ctx:HitRadius(core, 26, { Damage = 0.35, Stun = 0.5, Pull = core })
					if not ctx:Wait(0.25) then
						return
					end
				end
				ctx:FX("Explosion", { Position = core, Color = ctx.Color, Size = 34 })
				ctx:Shake(core, 0.8, 80)
				ctx:HitRadius(core, 20, { Damage = 2.5, Knockback = 60, Ragdoll = 1.2 })
			end,
		},
		{
			Name = "Six Paths Cataclysm",
			Description = "ULTIMATE: Rise into the air and crush the battlefield under absolute gravity.",
			Cooldown = 45,
			EnergyCost = 70,
			Damage = 70,
			Range = 40,
			Animation = "Power_Ultimate",
			Sounds = { Charge = "Gravity_Ult_Charge", Cast = "Gravity_Ult", Impact = "Gravity_Impact" },
			Execute = function(ctx)
				ctx:Cinematic(1.8, "Ultimate")
				ctx:SuperArmor(3)
				ctx:Anim("Power_Ultimate")
				ctx:Sound("Gravity_Ult_Charge")
				ctx:Launch(40)
				ctx:Aura(3)
				local center = ctx.Root.Position
				ctx:FX("Domain", { Position = center, Color = DARK, Size = 90, Duration = 2.5 })
				ctx:Wait(0.6)
				for _ = 1, 5 do
					ctx:FX("Shockwave", { Position = center, Color = ctx.Color, Size = 80 })
					ctx:HitRadius(center, 40, { Damage = 0.4, Stun = 0.6, Pull = center })
					if not ctx:Wait(0.3) then
						return
					end
				end
				ctx:FX("ImpactFrame", { Position = center })
				ctx:FX("ScreenFlash", { Color = Color3.new(1, 1, 1), Duration = 0.2, Position = center })
				ctx:FX("Crater", { Position = center - Vector3.new(0, 3, 0), Size = 30 })
				ctx:Shake(center, 1.2, 120)
				ctx:HitRadius(center, 40, { Damage = 2.2, Knockback = 140, Up = 50, Ragdoll = 2, GuardBreak = true })
			end,
		},
	},
}
