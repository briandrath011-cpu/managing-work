--[[
	Sharingan (ModuleScript) - Epic eye power
	Location: ReplicatedStorage.Modules.Powers.List.Sharingan
	Skill 1 Flame Jutsu | 2 Genjutsu | 3 Copy Counter | ULT Susanoo Strike
]]
local RED = Color3.fromRGB(220, 20, 30)
local FLAME = Color3.fromRGB(255, 120, 30)
local SUSANOO = Color3.fromRGB(140, 60, 255)

return {
	Id = "Sharingan",
	DisplayName = "Sharingan",
	Rarity = "Epic",
	Element = "Eye",
	Color = RED,
	SecondaryColor = FLAME,
	Description = "Eyes that read, copy and deceive.",
	Passive = {
		Name = "Insight",
		Description = "+6% crit chance, +10% energy regen.",
		Modifiers = { CritChance = 0.06, EnergyRegen = 0.1 },
	},
	Skills = {
		{
			Name = "Flame Jutsu",
			Description = "Breathe a great fireball that explodes on impact.",
			Cooldown = 7,
			EnergyCost = 18,
			Damage = 44,
			Range = 50,
			Animation = "Jutsu_Fire",
			Sounds = { Cast = "Fire_Cast", Impact = "Explosion" },
			Execute = function(ctx)
				ctx:Anim("Jutsu_Fire")
				ctx:Sound("Fire_Cast")
				ctx:Projectile({
					Speed = 80,
					Range = 50,
					Radius = 5,
					Visual = { Kind = "Fireball", Color = FLAME, Size = 6 },
					Spec = { Stun = 0.4, Burn = true },
					OnEnd = function(c, pos)
						c:FX("Explosion", { Position = pos, Color = FLAME, Size = 22 })
						c:HitRadius(pos, 12, { Damage = 0.6, Knockback = 50, Up = 15, Burn = true })
					end,
				})
			end,
		},
		{
			Name = "Genjutsu",
			Description = "Trap enemies you look at in an illusion (stuns 2.5s).",
			Cooldown = 14,
			EnergyCost = 24,
			Damage = 18,
			Range = 30,
			Animation = "Jutsu_Eye",
			Sounds = { Cast = "Genjutsu" },
			Execute = function(ctx)
				ctx:Sound("Genjutsu")
				ctx:FX("EyeFlash", { Model = ctx.Caster, Color = RED })
				local targets = ctx:HitBox(
					CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 15, ctx.Root.Position + ctx.AimDirection * 30),
					Vector3.new(16, 12, 30),
					{ Stun = 2.5, Unblockable = true }
				)
				for _, target in ipairs(targets) do
					ctx:FX("Genjutsu", { Model = target.Model, Color = RED, Duration = 2.5 })
				end
			end,
		},
		{
			Name = "Copy Counter",
			Description = "Read the enemy's attack. If hit within 1.2s, copy it back with double force.",
			Cooldown = 12,
			EnergyCost = 20,
			Damage = 70,
			Range = 10,
			Animation = "Power_Guard",
			Sounds = { Cast = "Counter_Ready", Impact = "Counter" },
			Execute = function(ctx)
				ctx:Anim("Power_Guard")
				ctx:Sound("Counter_Ready")
				ctx:FX("EyeFlash", { Model = ctx.Caster, Color = RED })
				ctx:Counter(1.2, function(c, attacker)
					c:Teleport(CFrame.lookAt((attacker.Root.CFrame * CFrame.new(0, 0, 4)).Position, attacker.Root.Position))
					c:FX("Slash", { CFrame = attacker.Root.CFrame, Color = RED, Size = 12, Heavy = true })
					c:Damage(attacker, { Damage = 1, Stun = 1.2, Knockback = 60 })
				end)
			end,
		},
		{
			Name = "Susanoo Strike",
			Description = "ULTIMATE: Manifest a spectral giant that cleaves the battlefield.",
			Cooldown = 45,
			EnergyCost = 70,
			Damage = 140,
			Range = 40,
			Animation = "Power_Ultimate",
			Sounds = { Cast = "Susanoo", Impact = "Slash_Heavy" },
			Execute = function(ctx)
				ctx:Cinematic(1.6, "Ultimate")
				ctx:SuperArmor(3)
				ctx:Sound("Susanoo")
				ctx:FX("Susanoo", { Model = ctx.Caster, Color = SUSANOO, Duration = 3 })
				ctx:Buff(ctx.Entity, "Susanoo", { DamageReduction = 0.3 }, 3)
				if not ctx:Wait(1) then
					return
				end
				local cf = CFrame.lookAt(ctx.Root.Position + ctx.AimDirection * 18, ctx.Root.Position + ctx.AimDirection * 40)
				ctx:FX("Slash", { CFrame = cf, Color = SUSANOO, Size = 50, Heavy = true })
				ctx:FX("ImpactFrame", { Position = cf.Position })
				ctx:Shake(cf.Position, 1, 90)
				ctx:HitBox(cf, Vector3.new(40, 16, 36), { Stun = 1.4, Knockback = 110, Up = 25, Ragdoll = 1.5, GuardBreak = true })
			end,
		},
	},
}
