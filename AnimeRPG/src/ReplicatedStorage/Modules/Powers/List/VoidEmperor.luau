--[[
	Void Emperor (ModuleScript) - SECRET power (1% chance)
	Location: ReplicatedStorage.Modules.Powers.List.VoidEmperor
	Skill 1 Void Lance | 2 Event Horizon | 3 Dimension Shift | ULT Oblivion Throne
]]
local VOID = Color3.fromRGB(20, 255, 200)
local DARK = Color3.fromRGB(10, 0, 20)

return {
	Id = "VoidEmperor",
	DisplayName = "Void Emperor",
	Rarity = "Secret",
	Element = "Void",
	Color = VOID,
	SecondaryColor = DARK,
	Description = "Rule over the space between worlds.",
	Passive = {
		Name = "Sovereign",
		Description = "+12% all damage, +10% max health, +10% cooldown reduction.",
		Modifiers = { DamageMult = 0.12, MaxHealth = 0.1, CooldownReduction = 0.1 },
	},
	Skills = {
		{
			Name = "Void Lance",
			Description = "Three void lances that pierce everything.",
			Cooldown = 6,
			EnergyCost = 18,
			Damage = 34,
			Range = 70,
			Execute = function(ctx)
				ctx:Anim("Power_Throw")
				for i = 1, 3 do
					ctx:Projectile({
						Speed = 160,
						Range = 70,
						Radius = 4,
						Pierce = true,
						Visual = { Kind = "Spear", Color = VOID, Size = 6 },
						Spec = { Stun = 0.4, Knockback = 20 },
					})
					if i < 3 and not ctx:Wait(0.12) then
						return
					end
				end
			end,
		},
		{
			Name = "Event Horizon",
			Description = "A black hole that drags enemies in and tears them apart.",
			Cooldown = 14,
			EnergyCost = 30,
			Damage = 14,
			Range = 50,
			Execute = function(ctx)
				local pos = ctx.AimPosition + Vector3.new(0, 6, 0)
				ctx:FX("Singularity", { Position = pos, Color = DARK, Size = 10, Duration = 2.5 })
				for _ = 1, 10 do
					ctx:HitRadius(pos, 24, { Stun = 0.4, Pull = pos })
					if not ctx:Wait(0.25) then
						return
					end
				end
				ctx:FX("Explosion", { Position = pos, Color = VOID, Size = 40 })
				ctx:HitRadius(pos, 20, { Damage = 5, Knockback = 100, Ragdoll = 1.5 })
			end,
		},
		{
			Name = "Dimension Shift",
			Description = "Blink to the target location, damaging enemies at both ends.",
			Cooldown = 8,
			EnergyCost = 16,
			Damage = 40,
			Range = 50,
			Execute = function(ctx)
				local from = ctx.Root.Position
				ctx:FX("Explosion", { Position = from, Color = VOID, Size = 14 })
				ctx:HitRadius(from, 10, { Stun = 0.6, Knockback = 40 })
				local to = ctx.AimPosition + Vector3.new(0, 3, 0)
				ctx:Teleport(CFrame.lookAt(to, to + ctx.AimDirection))
				ctx:FX("Explosion", { Position = to, Color = VOID, Size = 14 })
				ctx:HitRadius(to, 10, { Stun = 0.6, Knockback = 40 })
			end,
		},
		{
			Name = "Oblivion Throne",
			Description = "ULTIMATE: Summon the throne of the void. Reality collapses around you.",
			Cooldown = 55,
			EnergyCost = 90,
			Damage = 60,
			Range = 50,
			Execute = function(ctx)
				ctx:Cinematic(2.2, "Domain")
				ctx:SuperArmor(5)
				ctx:IFrames(1.5)
				local center = ctx.Root.Position
				ctx:FX("Domain", { Position = center, Color = DARK, Size = 120, Duration = 4.5, Style = "Void" })
				ctx:Wait(1)
				for _ = 1, 6 do
					for _, target in ipairs(ctx:Enemies(center, 50)) do
						ctx:FX("Lightning", { From = center + Vector3.new(0, 40, 0), To = target.Root.Position, Color = VOID })
						ctx:Freeze(target, 0.5)
						ctx:Damage(target, { Damage = 0.6 })
					end
					if not ctx:Wait(0.4) then
						return
					end
				end
				ctx:FX("ImpactFrame", { Position = center })
				ctx:FX("ScreenFlash", { Color = VOID, Duration = 0.3, Position = center })
				ctx:HitRadius(center, 50, { Damage = 4, Knockback = 150, Up = 60, Ragdoll = 2, GuardBreak = true })
			end,
		},
	},
}
