--[[
	Saiyan Power (ModuleScript) - Epic ki power
	Location: ReplicatedStorage.Modules.Powers.List.SaiyanPower
	Skill 1 Energy Wave | 2 Meteor Combo | 3 Instant Strike | ULT Limit Break
]]
local KI = Color3.fromRGB(90, 190, 255)
local GOLD = Color3.fromRGB(255, 225, 80)

return {
	Id = "SaiyanPower",
	DisplayName = "Saiyan Power",
	Rarity = "Epic",
	Element = "Ki",
	Color = KI,
	SecondaryColor = GOLD,
	Description = "Warrior ki that grows stronger in battle.",
	Passive = {
		Name = "Battle Blood",
		Description = "+30% awakening gain, +6% damage.",
		Modifiers = { AwakeningGain = 0.3, DamageMult = 0.06 },
	},
	Skills = {
		{
			Name = "Energy Wave",
			Description = "Charge and fire a piercing energy beam.",
			Cooldown = 8,
			EnergyCost = 22,
			Damage = 46,
			Range = 70,
			Animation = "Power_Beam",
			Sounds = { Charge = "Ki_Charge", Cast = "Ki_Beam" },
			Execute = function(ctx)
				ctx:Anim("Power_Beam")
				ctx:Sound("Ki_Charge")
				ctx:FX("Charge", { Model = ctx.Caster, Color = KI, Duration = 0.45 })
				if not ctx:Wait(0.45) then
					return
				end
				ctx:Sound("Ki_Beam")
				local origin = ctx.Root.Position + ctx.AimDirection * 2
				ctx:FX("Beam", { From = origin, To = origin + ctx.AimDirection * 70, Color = KI, Width = 4, Duration = 0.6 })
				ctx:HitLine(origin, ctx.AimDirection, 70, 7, { Stun = 0.7, Knockback = 60 })
			end,
		},
		{
			Name = "Meteor Combo",
			Description = "Rush the enemy, launch them skyward and spike them down.",
			Cooldown = 11,
			EnergyCost = 26,
			Damage = 20,
			Range = 30,
			Animation = "Power_Combo",
			Sounds = { Impact = "Punch_Heavy" },
			Execute = function(ctx)
				local target = ctx:NearestEnemy(ctx.AimPosition, 18)
				if not target then
					return
				end
				ctx:Afterimage()
				ctx:Teleport(target.Root.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0))
				for _ = 1, 4 do
					ctx:Damage(target, { Stun = 0.4 })
					ctx:FX("HitSpark", { Position = target.Root.Position, Color = KI })
					if not ctx:Wait(0.1) then
						return
					end
				end
				ctx:Damage(target, { Damage = 1.5, Stun = 1.2, Up = 70, Launch = true })
				ctx:Wait(0.35)
				ctx:Teleport(target.Root.CFrame * CFrame.new(0, 5, 0))
				ctx:FX("ImpactFrame", { Position = target.Root.Position })
				ctx:Damage(target, { Damage = 2.5, Stun = 1, Ragdoll = 1.2, Downslam = true })
				ctx:FX("Crater", { Position = target.Root.Position - Vector3.new(0, 5, 0), Size = 10 })
			end,
		},
		{
			Name = "Instant Strike",
			Description = "Vanish and reappear behind the enemy with a crushing blow.",
			Cooldown = 8,
			EnergyCost = 16,
			Damage = 45,
			Range = 35,
			Animation = "Power_Teleport",
			Sounds = { Cast = "Teleport", Impact = "Punch_Heavy" },
			Execute = function(ctx)
				local target = ctx:NearestEnemy(ctx.AimPosition, 20)
				if not target then
					return
				end
				ctx:Sound("Teleport")
				ctx:FX("Afterimage", { Model = ctx.Caster, Color = KI })
				ctx:Teleport(CFrame.lookAt((target.Root.CFrame * CFrame.new(0, 0, 4)).Position, target.Root.Position))
				ctx:Wait(0.05)
				ctx:FX("Shockwave", { Position = target.Root.Position, Color = KI, Size = 12 })
				ctx:Damage(target, { Stun = 0.8, Knockback = 90, Up = 20, Ragdoll = 1 })
			end,
		},
		{
			Name = "Limit Break",
			Description = "ULTIMATE: Explode with golden ki and fire an enormous wave.",
			Cooldown = 45,
			EnergyCost = 75,
			Damage = 150,
			Range = 90,
			Animation = "Power_Ultimate",
			Sounds = { Charge = "Ki_Ult_Charge", Cast = "Ki_Ult" },
			Execute = function(ctx)
				ctx:Cinematic(1.8, "Ultimate")
				ctx:SuperArmor(2.5)
				ctx:Sound("Ki_Ult_Charge")
				ctx:FX("Aura", { Model = ctx.Caster, Color = GOLD, Duration = 6, Intense = true })
				ctx:Buff(ctx.Entity, "LimitBreak", { DamageMult = 0.2, MoveSpeed = 6 }, 12)
				ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = GOLD, Size = 40 })
				if not ctx:Wait(1.1) then
					return
				end
				ctx:Sound("Ki_Ult")
				local origin = ctx.Root.Position + ctx.AimDirection * 2
				ctx:FX("Beam", { From = origin, To = origin + ctx.AimDirection * 90, Color = GOLD, Width = 12, Duration = 1.2 })
				ctx:FX("ImpactFrame", { Position = origin })
				ctx:Shake(origin, 1.1, 100)
				ctx:HitLine(origin, ctx.AimDirection, 90, 16, { Stun = 1.4, Knockback = 130, Up = 20, Ragdoll = 1.8, GuardBreak = true })
			end,
		},
	},
}
