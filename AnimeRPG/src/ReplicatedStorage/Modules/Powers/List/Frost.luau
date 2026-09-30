--[[
	Frost (ModuleScript) - Rare ice power
	Location: ReplicatedStorage.Modules.Powers.List.Frost
	Skill 1 Ice Shard | 2 Frost Nova | 3 Glacier Spike | ULT Absolute Zero
]]
local ICE = Color3.fromRGB(150, 220, 255)

return {
	Id = "Frost",
	DisplayName = "Frost",
	Rarity = "Rare",
	Element = "Ice",
	Color = ICE,
	SecondaryColor = Color3.fromRGB(240, 250, 255),
	Description = "Freeze enemies solid and shatter them.",
	Passive = {
		Name = "Cold Blood",
		Description = "+6% damage reduction, +5% power damage.",
		Modifiers = { DamageReduction = 0.06, PowerDamage = 0.05 },
	},
	Skills = {
		{
			Name = "Ice Shard",
			Description = "Fire three ice shards.",
			Cooldown = 5,
			EnergyCost = 12,
			Damage = 14,
			Range = 50,
			Execute = function(ctx)
				ctx:Anim("Power_Throw")
				for i = -1, 1 do
					local dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(i * 8)) * ctx.AimDirection).Unit
					ctx:Projectile({
						Direction = dir,
						Speed = 120,
						Range = 50,
						Radius = 3,
						Visual = { Kind = "Shard", Color = ICE, Size = 2 },
						Spec = { Stun = 0.35 },
					})
				end
			end,
		},
		{
			Name = "Frost Nova",
			Description = "Freeze all nearby enemies for 1.5 seconds.",
			Cooldown = 12,
			EnergyCost = 22,
			Damage = 26,
			Range = 16,
			Execute = function(ctx)
				ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ICE, Size = 32 })
				ctx:FX("IceSpikes", { Position = ctx.Root.Position, Color = ICE, Size = 16 })
				for _, target in ipairs(ctx:HitRadius(ctx.Root.Position, 16, { Stun = 0.2 })) do
					ctx:Freeze(target, 1.5)
				end
			end,
		},
		{
			Name = "Glacier Spike",
			Description = "A line of ice spikes erupts forward.",
			Cooldown = 10,
			EnergyCost = 20,
			Damage = 34,
			Range = 40,
			Execute = function(ctx)
				for step = 1, 6 do
					local pos = ctx.Root.Position + ctx.AimDirection * (step * 6)
					ctx:FX("IceSpikes", { Position = pos, Color = ICE, Size = 6 })
					ctx:HitRadius(pos, 6, { Stun = 0.6, Up = 45, Launch = true })
					if not ctx:Wait(0.06) then
						return
					end
				end
			end,
		},
		{
			Name = "Absolute Zero",
			Description = "ULTIMATE: Flash-freeze the area, then shatter everything.",
			Cooldown = 40,
			EnergyCost = 60,
			Damage = 110,
			Range = 30,
			Execute = function(ctx)
				ctx:Cinematic(1.4, "Ultimate")
				ctx:FX("Domain", { Position = ctx.Root.Position, Color = ICE, Size = 60, Duration = 2.2, Style = "Ice" })
				local targets = ctx:Enemies(ctx.Root.Position, 30)
				for _, target in ipairs(targets) do
					ctx:Freeze(target, 2)
				end
				if not ctx:Wait(1.8) then
					return
				end
				ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
				ctx:FX("IceSpikes", { Position = ctx.Root.Position, Color = ICE, Size = 30 })
				ctx:HitRadius(ctx.Root.Position, 30, { Stun = 1, Knockback = 70, Up = 30, Ragdoll = 1.2 })
			end,
		},
	},
}
