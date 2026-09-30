--[[
	WeaponSkills (ModuleScript)
	Location: ReplicatedStorage.Modules.Weapons.WeaponSkills

	Library of weapon skills. Each skill's Execute(ctx) runs ONLY on the server
	(SkillContext in ServerScriptService.ServerModules). The client only reads
	Name/Description/Cooldown for UI.

	Skill fields:
		Name, Description, Cooldown, EnergyCost, Damage (base), Range (aim range),
		Ultimate (bool), Execute(ctx)
	Hit spec fields (ctx:HitRadius/HitBox/HitLine): Damage (multiplier), Stun, Knockback,
		Up, Pull, GuardDamage, GuardBreak, Ragdoll, Launch, Unblockable
]]
local WeaponSkills = {}

-- Shared helpers -------------------------------------------------------------------------------

local function frontCFrame(ctx, distance: number): CFrame
	local pos = ctx.Root.Position + ctx.AimDirection * distance
	return CFrame.lookAt(pos, pos + ctx.AimDirection)
end

local function slash(ctx, distance: number, size: Vector3, spec, fxSize: number?)
	local cf = frontCFrame(ctx, distance)
	ctx:FX("Slash", { CFrame = cf, Color = ctx.Color, Size = fxSize or size.X, Heavy = spec.Heavy })
	return ctx:HitBox(cf, size, spec)
end

local function dashStrike(ctx, distance: number, width: number, spec)
	local start = ctx.Root.Position
	ctx:Afterimage()
	ctx:Dash(ctx.AimDirection, distance, 0.2)
	ctx:Wait(0.2)
	ctx:FX(
		"Slash",
		{
			CFrame = CFrame.lookAt(start + ctx.AimDirection * distance / 2, start + ctx.AimDirection * distance),
			Color = ctx.Color,
			Size = distance,
			Heavy = true,
		}
	)
	return ctx:HitLine(start, ctx.AimDirection, distance + 4, width, spec)
end

local function groundSlam(ctx, radius: number, spec)
	local pos = ctx.Root.Position - Vector3.new(0, 2.5, 0)
	ctx:FX("Shockwave", { Position = pos, Color = ctx.Color, Size = radius * 2 })
	ctx:FX("GroundCracks", { Position = pos, Size = radius })
	ctx:FX("Debris", { Position = pos, Count = 8, Color = ctx.Color })
	ctx:Shake(pos, 0.6, 60)
	return ctx:HitRadius(pos, radius, spec)
end

-- KATANA ---------------------------------------------------------------------------------------
WeaponSkills.Katana_IaiSlash = {
	Name = "Iai Slash",
	Description = "Dash through enemies with a lightning-fast draw cut.",
	Cooldown = 6,
	EnergyCost = 10,
	Damage = 32,
	Range = 26,
	Execute = function(ctx)
		ctx:Anim("Weapon_Dash")
		ctx:Sound("Slash_Heavy")
		dashStrike(ctx, 24, 7, { Stun = 0.6, Knockback = 20 })
	end,
}

WeaponSkills.Katana_CrossCut = {
	Name = "Cross Cut",
	Description = "Two crossing slashes that break guards.",
	Cooldown = 9,
	EnergyCost = 16,
	Damage = 26,
	Range = 10,
	Execute = function(ctx)
		ctx:Anim("Weapon_Combo")
		for i = 1, 2 do
			ctx:Sound("Slash")
			slash(ctx, 5, Vector3.new(10, 7, 10), { Stun = 0.5, GuardDamage = 45, Knockback = i == 2 and 40 or 0 })
			if not ctx:Wait(0.2) then
				return
			end
		end
	end,
}

WeaponSkills.Katana_ThousandCuts = {
	Name = "Thousand Cuts",
	Description = "ULTIMATE: Vanish and strike every enemy around you in a blur of slashes.",
	Cooldown = 32,
	EnergyCost = 40,
	Damage = 22,
	Range = 20,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		ctx:IFrames(1.4)
		ctx:Anim("Weapon_Ultimate")
		ctx:FX("ScreenFlash", { Color = ctx.Color, Duration = 0.15, Position = ctx.Root.Position })
		for _ = 1, 8 do
			local targets = ctx:HitRadius(ctx.Root.Position, 20, { Damage = 1, Stun = 0.4 })
			for _, target in ipairs(targets) do
				ctx:FX(
					"Slash",
					{ CFrame = target.Root.CFrame * CFrame.Angles(0, 0, math.random() * math.pi), Color = ctx.Color, Size = 12 }
				)
			end
			ctx:Sound("Slash")
			if not ctx:Wait(0.12) then
				return
			end
		end
		groundSlam(ctx, 20, { Damage = 2.5, Knockback = 70, Up = 30, Ragdoll = 1 })
	end,
}

-- GREATSWORD -----------------------------------------------------------------------------------
WeaponSkills.Greatsword_Cleave = {
	Name = "Cleave",
	Description = "A huge horizontal swing with super armor.",
	Cooldown = 7,
	EnergyCost = 12,
	Damage = 40,
	Range = 12,
	Execute = function(ctx)
		ctx:SuperArmor(0.6)
		ctx:Anim("Weapon_Heavy")
		ctx:Wait(0.25)
		ctx:Sound("Slash_Heavy")
		slash(ctx, 6, Vector3.new(16, 8, 12), { Stun = 0.7, Knockback = 55, GuardDamage = 50, Heavy = true }, 18)
	end,
}

WeaponSkills.Greatsword_Earthsplitter = {
	Name = "Earthsplitter",
	Description = "Slam the ground and send a fissure forward.",
	Cooldown = 11,
	EnergyCost = 20,
	Damage = 34,
	Range = 30,
	Execute = function(ctx)
		ctx:Anim("Weapon_Slam")
		ctx:Wait(0.3)
		for step = 1, 5 do
			local pos = ctx.Root.Position + ctx.AimDirection * (step * 6) - Vector3.new(0, 2.5, 0)
			ctx:FX("GroundCracks", { Position = pos, Size = 6 })
			ctx:FX("Debris", { Position = pos, Count = 4, Color = ctx.Color })
			ctx:HitRadius(pos, 7, { Stun = 0.6, Up = 40, Launch = true })
			if not ctx:Wait(0.07) then
				return
			end
		end
		ctx:Shake(ctx.Root.Position, 0.5, 50)
	end,
}

WeaponSkills.Greatsword_Titanfall = {
	Name = "Titanfall",
	Description = "ULTIMATE: Leap high and crash down with a devastating shockwave.",
	Cooldown = 34,
	EnergyCost = 45,
	Damage = 110,
	Range = 30,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1)
		ctx:SuperArmor(1.6)
		ctx:Anim("Weapon_Ultimate")
		ctx:Launch(90)
		ctx:Wait(0.55)
		ctx:Dash(Vector3.new(0, -1, 0) + ctx.AimDirection * 0.4, 40, 0.25)
		ctx:Wait(0.25)
		ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
		groundSlam(ctx, 26, { Damage = 1, Stun = 1.2, Knockback = 90, Up = 40, Ragdoll = 1.5, GuardBreak = true })
	end,
}

-- DAGGER ---------------------------------------------------------------------------------------
WeaponSkills.Dagger_Backstab = {
	Name = "Shadowstep",
	Description = "Teleport behind your target and stab.",
	Cooldown = 7,
	EnergyCost = 12,
	Damage = 36,
	Range = 28,
	Execute = function(ctx)
		local target = ctx:NearestEnemy(ctx.AimPosition, 14)
		if target then
			ctx:FX("Afterimage", { Model = ctx.Caster, Color = ctx.Color })
			local behind = target.Root.CFrame * CFrame.new(0, 0, 4)
			ctx:Teleport(CFrame.lookAt(behind.Position, target.Root.Position))
			ctx:Wait(0.05)
			ctx:Sound("Stab")
			ctx:Damage(target, { Damage = 1.3, Stun = 0.8, Knockback = 15, ForceCrit = true })
			ctx:FX("HitSpark", { Position = target.Root.Position, Color = ctx.Color, Heavy = true })
		else
			dashStrike(ctx, 16, 5, { Stun = 0.5 })
		end
	end,
}

WeaponSkills.Dagger_FanOfKnives = {
	Name = "Fan of Knives",
	Description = "Throw a spread of spectral knives.",
	Cooldown = 9,
	EnergyCost = 16,
	Damage = 18,
	Range = 40,
	Execute = function(ctx)
		ctx:Anim("Weapon_Throw")
		for i = -2, 2 do
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(i * 10)) * ctx.AimDirection).Unit
			ctx:Projectile({
				Direction = dir,
				Speed = 120,
				Range = 40,
				Radius = 3,
				Visual = { Kind = "Knife", Color = ctx.Color, Size = 1.5 },
				Spec = { Stun = 0.3 },
			})
		end
		ctx:Sound("Throw")
	end,
}

WeaponSkills.Dagger_Assassinate = {
	Name = "Assassinate",
	Description = "ULTIMATE: Mark all nearby enemies, then strike each one in the blink of an eye.",
	Cooldown = 30,
	EnergyCost = 40,
	Damage = 70,
	Range = 30,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		ctx:IFrames(2)
		local targets = ctx:Enemies(ctx.Root.Position, 30)
		ctx:FX("ScreenFlash", { Color = Color3.new(0, 0, 0), Duration = 0.25, Position = ctx.Root.Position })
		for i, target in ipairs(targets) do
			if i > 6 then
				break
			end
			ctx:Teleport(target.Root.CFrame * CFrame.new(0, 0, 3.5))
			ctx:FX("Slash", { CFrame = target.Root.CFrame, Color = ctx.Color, Size = 10, Heavy = true })
			ctx:Damage(target, { Damage = 1, Stun = 1.2, ForceCrit = true })
			ctx:Sound("Stab")
			if not ctx:Wait(0.15) then
				return
			end
		end
	end,
}

-- SCYTHE ---------------------------------------------------------------------------------------
WeaponSkills.Scythe_Reap = {
	Name = "Reap",
	Description = "Spin the scythe, pulling enemies inward.",
	Cooldown = 7,
	EnergyCost = 14,
	Damage = 30,
	Range = 12,
	Execute = function(ctx)
		ctx:Anim("Weapon_Spin")
		ctx:Sound("Whoosh")
		ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = ctx.Color, Size = 24 })
		ctx:HitRadius(ctx.Root.Position, 12, { Stun = 0.7, Pull = ctx.Root.Position })
	end,
}

WeaponSkills.Scythe_SoulHarvest = {
	Name = "Soul Harvest",
	Description = "A crescent wave that heals you for part of the damage.",
	Cooldown = 10,
	EnergyCost = 18,
	Damage = 32,
	Range = 36,
	Execute = function(ctx)
		ctx:Anim("Weapon_Heavy")
		ctx:Projectile({
			Speed = 90,
			Range = 36,
			Radius = 7,
			Pierce = true,
			Visual = { Kind = "Crescent", Color = ctx.Color, Size = 10 },
			Spec = { Stun = 0.5, Knockback = 20 },
			OnHit = function(c, _target, dealt)
				c:Heal(c.Entity, dealt * 0.25)
			end,
		})
	end,
}

WeaponSkills.Scythe_DeathsDance = {
	Name = "Death's Dance",
	Description = "ULTIMATE: A storm of spinning blades that devours life.",
	Cooldown = 34,
	EnergyCost = 45,
	Damage = 24,
	Range = 18,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		ctx:SuperArmor(2.5)
		ctx:Aura(2.5)
		for _ = 1, 10 do
			ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = ctx.Color, Size = 36 })
			local hits = ctx:HitRadius(ctx.Root.Position, 18, { Stun = 0.35, Pull = ctx.Root.Position })
			ctx:Heal(ctx.Entity, #hits * 4)
			if not ctx:Wait(0.2) then
				return
			end
		end
		groundSlam(ctx, 18, { Damage = 3, Knockback = 70, Ragdoll = 1 })
	end,
}

-- SPEAR ----------------------------------------------------------------------------------------
WeaponSkills.Spear_Lunge = {
	Name = "Piercing Lunge",
	Description = "A long-reach thrust that pierces lines of enemies.",
	Cooldown = 6,
	EnergyCost = 10,
	Damage = 30,
	Range = 20,
	Execute = function(ctx)
		ctx:Anim("Weapon_Thrust")
		ctx:Sound("Stab")
		ctx:Dash(ctx.AimDirection, 10, 0.12)
		ctx:FX(
			"Beam",
			{ From = ctx.Root.Position, To = ctx.Root.Position + ctx.AimDirection * 20, Color = ctx.Color, Width = 1.5, Duration = 0.2 }
		)
		ctx:HitLine(ctx.Root.Position, ctx.AimDirection, 20, 5, { Stun = 0.5, Knockback = 45 })
	end,
}

WeaponSkills.Spear_Javelin = {
	Name = "Javelin",
	Description = "Hurl an energy spear that explodes.",
	Cooldown = 10,
	EnergyCost = 18,
	Damage = 38,
	Range = 60,
	Execute = function(ctx)
		ctx:Anim("Weapon_Throw")
		ctx:Projectile({
			Speed = 140,
			Range = 60,
			Radius = 3,
			Visual = { Kind = "Spear", Color = ctx.Color, Size = 6 },
			Spec = { Stun = 0.4 },
			OnEnd = function(c, pos)
				c:FX("Explosion", { Position = pos, Color = c.Color, Size = 16 })
				c:HitRadius(pos, 10, { Damage = 0.7, Knockback = 50, Up = 20 })
			end,
		})
	end,
}

WeaponSkills.Spear_SkyfallLance = {
	Name = "Skyfall Lance",
	Description = "ULTIMATE: Rain a barrage of lances on the target area.",
	Cooldown = 32,
	EnergyCost = 45,
	Damage = 30,
	Range = 50,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		local center = ctx.AimPosition
		ctx:Telegraph(center, 18, 0.6)
		ctx:Wait(0.6)
		for _ = 1, 12 do
			local offset = Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
			local pos = center + offset
			ctx:FX("Pillar", { Position = pos, Color = ctx.Color, Size = 3, Height = 60 })
			ctx:HitRadius(pos, 6, { Stun = 0.4 })
			if not ctx:Wait(0.08) then
				return
			end
		end
		ctx:FX("Explosion", { Position = center, Color = ctx.Color, Size = 36 })
		ctx:HitRadius(center, 18, { Damage = 2, Knockback = 60, Up = 30 })
	end,
}

-- GAUNTLETS ------------------------------------------------------------------------------------
WeaponSkills.Gauntlets_RocketPunch = {
	Name = "Rocket Punch",
	Description = "Charge forward with an explosive punch.",
	Cooldown = 6,
	EnergyCost = 10,
	Damage = 34,
	Range = 18,
	Execute = function(ctx)
		ctx:Anim("Weapon_Punch")
		ctx:Dash(ctx.AimDirection, 14, 0.15)
		ctx:Wait(0.15)
		local cf = frontCFrame(ctx, 4)
		ctx:FX("Explosion", { Position = cf.Position, Color = ctx.Color, Size = 10 })
		ctx:HitBox(cf, Vector3.new(8, 8, 8), { Stun = 0.6, Knockback = 70, Up = 15, Ragdoll = 0.8 })
	end,
}

WeaponSkills.Gauntlets_Uppercut = {
	Name = "Rising Dragon",
	Description = "A launching uppercut that starts an air combo.",
	Cooldown = 8,
	EnergyCost = 14,
	Damage = 30,
	Range = 8,
	Execute = function(ctx)
		ctx:Anim("Weapon_Uppercut")
		ctx:Launch(55)
		ctx:FX("Pillar", { Position = ctx.Root.Position, Color = ctx.Color, Size = 5, Height = 25 })
		slash(ctx, 3, Vector3.new(8, 10, 8), { Stun = 0.9, Up = 60, Launch = true })
	end,
}

WeaponSkills.Gauntlets_MeteorFist = {
	Name = "Meteor Fist",
	Description = "ULTIMATE: A flurry of blows ending in a crater-making punch.",
	Cooldown = 30,
	EnergyCost = 40,
	Damage = 16,
	Range = 10,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		ctx:SuperArmor(2)
		for _ = 1, 12 do
			ctx:Sound("Punch")
			slash(ctx, 4, Vector3.new(8, 8, 9), { Stun = 0.3 }, 6)
			if not ctx:Wait(0.07) then
				return
			end
		end
		ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
		ctx:FX("Crater", { Position = ctx.Root.Position + ctx.AimDirection * 6 - Vector3.new(0, 2.5, 0), Size = 14 })
		slash(ctx, 6, Vector3.new(14, 10, 14), { Damage = 5, Knockback = 110, Up = 30, Ragdoll = 1.5, GuardBreak = true, Heavy = true })
	end,
}

-- STAFF ----------------------------------------------------------------------------------------
WeaponSkills.Staff_ArcaneBolt = {
	Name = "Arcane Bolt",
	Description = "Fire a homing arcane bolt.",
	Cooldown = 5,
	EnergyCost = 10,
	Damage = 30,
	Range = 60,
	Execute = function(ctx)
		ctx:Anim("Weapon_Cast")
		ctx:Projectile({
			Speed = 100,
			Range = 60,
			Radius = 3,
			Homing = true,
			Visual = { Kind = "Orb", Color = ctx.Color, Size = 2 },
			Spec = { Stun = 0.4, Knockback = 20 },
		})
	end,
}

WeaponSkills.Staff_ManaNova = {
	Name = "Mana Nova",
	Description = "Release a nova that knocks enemies back.",
	Cooldown = 9,
	EnergyCost = 20,
	Damage = 34,
	Range = 14,
	Execute = function(ctx)
		ctx:Anim("Weapon_Cast")
		ctx:FX("Shockwave", { Position = ctx.Root.Position, Color = ctx.Color, Size = 30 })
		ctx:HitRadius(ctx.Root.Position, 15, { Stun = 0.6, Knockback = 60, Up = 20 })
	end,
}

WeaponSkills.Staff_Starfall = {
	Name = "Starfall",
	Description = "ULTIMATE: Call down falling stars on the target area.",
	Cooldown = 32,
	EnergyCost = 50,
	Damage = 45,
	Range = 60,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1)
		local center = ctx.AimPosition
		ctx:Telegraph(center, 20, 0.8)
		ctx:Wait(0.6)
		for _ = 1, 8 do
			local pos = center + Vector3.new(math.random(-16, 16), 0, math.random(-16, 16))
			ctx:FX("Meteor", { Position = pos, Color = ctx.Color, Size = 6 })
			ctx:Wait(0.12)
			ctx:HitRadius(pos, 8, { Stun = 0.6, Knockback = 30, Up = 25 })
		end
	end,
}

-- DUAL BLADES ----------------------------------------------------------------------------------
WeaponSkills.Dual_Whirlwind = {
	Name = "Whirlwind",
	Description = "Spin forward, hitting multiple times.",
	Cooldown = 7,
	EnergyCost = 12,
	Damage = 12,
	Range = 16,
	Execute = function(ctx)
		ctx:Anim("Weapon_Spin")
		for _ = 1, 5 do
			ctx:Dash(ctx.AimDirection, 3, 0.08)
			ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = ctx.Color, Size = 14 })
			ctx:HitRadius(ctx.Root.Position, 8, { Stun = 0.3 })
			if not ctx:Wait(0.1) then
				return
			end
		end
	end,
}

WeaponSkills.Dual_XSlash = {
	Name = "X-Slash",
	Description = "Launch two crossing energy blades.",
	Cooldown = 9,
	EnergyCost = 16,
	Damage = 28,
	Range = 40,
	Execute = function(ctx)
		ctx:Anim("Weapon_Combo")
		ctx:Projectile({
			Speed = 110,
			Range = 40,
			Radius = 5,
			Pierce = true,
			Visual = { Kind = "Cross", Color = ctx.Color, Size = 8 },
			Spec = { Stun = 0.5, Knockback = 25 },
		})
	end,
}

WeaponSkills.Dual_BladeStorm = {
	Name = "Blade Storm",
	Description = "ULTIMATE: Dash between enemies in a flurry of cuts.",
	Cooldown = 30,
	EnergyCost = 42,
	Damage = 26,
	Range = 26,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(0.8)
		ctx:IFrames(2)
		for _ = 1, 6 do
			local target = ctx:NearestEnemy(ctx.Root.Position, 26)
			if target then
				ctx:Teleport(target.Root.CFrame * CFrame.new(math.random(-3, 3), 0, 3))
				ctx:FX("Slash", { CFrame = target.Root.CFrame * CFrame.Angles(0, 0, math.random() * 3), Color = ctx.Color, Size = 10 })
				ctx:Damage(target, { Stun = 0.5 })
			end
			if not ctx:Wait(0.12) then
				return
			end
		end
		groundSlam(ctx, 14, { Damage = 2, Knockback = 60 })
	end,
}

-- RARE WEAPON SKILLS ---------------------------------------------------------------------------
WeaponSkills.NightSlayer_ShadowCrescent = {
	Name = "Shadow Crescent",
	Description = "Fire a crescent of purple shadow energy that pierces enemies.",
	Cooldown = 7,
	EnergyCost = 16,
	Damage = 46,
	Range = 45,
	Execute = function(ctx)
		ctx:Anim("Weapon_Heavy")
		ctx:Sound("Shadow_Slash")
		ctx:Projectile({
			Speed = 120,
			Range = 45,
			Radius = 6,
			Pierce = true,
			Visual = { Kind = "Crescent", Color = ctx.Color, Size = 12 },
			Spec = { Stun = 0.6, Knockback = 30 },
		})
	end,
}

WeaponSkills.NightSlayer_Nightfall = {
	Name = "Nightfall Slash",
	Description = "ULTIMATE: Darkness swallows the area, then a single colossal slash splits it.",
	Cooldown = 34,
	EnergyCost = 50,
	Damage = 160,
	Range = 30,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1.2)
		ctx:SuperArmor(1.5)
		ctx:FX("Domain", { Position = ctx.Root.Position, Color = Color3.fromRGB(30, 0, 50), Size = 60, Duration = 1.4 })
		ctx:FX("ScreenFlash", { Color = Color3.new(0, 0, 0), Duration = 0.6, Position = ctx.Root.Position })
		ctx:Wait(0.9)
		ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
		slash(
			ctx,
			12,
			Vector3.new(40, 12, 30),
			{ Stun = 1.4, Knockback = 100, Up = 25, Ragdoll = 1.5, GuardBreak = true, Heavy = true },
			45
		)
		ctx:Shake(ctx.Root.Position, 1, 80)
	end,
}

WeaponSkills.DragonFang_DragonRush = {
	Name = "Dragon Rush",
	Description = "Charge as a green dragon, burning everything in your path.",
	Cooldown = 8,
	EnergyCost = 18,
	Damage = 44,
	Range = 30,
	Execute = function(ctx)
		ctx:FX("Aura", { Model = ctx.Caster, Color = ctx.Color, Duration = 0.5 })
		dashStrike(ctx, 28, 8, { Stun = 0.6, Knockback = 40, Up = 15 })
	end,
}

WeaponSkills.DragonFang_Wyrmstorm = {
	Name = "Wyrmstorm",
	Description = "ULTIMATE: Summon a spiraling dragon tornado.",
	Cooldown = 34,
	EnergyCost = 50,
	Damage = 30,
	Range = 20,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1)
		local center = ctx.Root.Position + ctx.AimDirection * 12
		for _ = 1, 8 do
			ctx:FX("Tornado", { Position = center, Color = ctx.Color, Size = 14 })
			ctx:HitRadius(center, 14, { Stun = 0.4, Pull = center, Up = 10 })
			if not ctx:Wait(0.25) then
				return
			end
		end
		ctx:HitRadius(center, 16, { Damage = 3, Knockback = 90, Up = 60, Ragdoll = 1.5 })
	end,
}

WeaponSkills.MoonKatana_LunarArc = {
	Name = "Lunar Arc",
	Description = "A silver arc that deals bonus damage at night.",
	Cooldown = 7,
	EnergyCost = 15,
	Damage = 48,
	Range = 16,
	Execute = function(ctx)
		local night = workspace:GetAttribute("TimePhase") == "Night"
		ctx:Anim("Weapon_Heavy")
		slash(ctx, 7, Vector3.new(18, 8, 14), { Damage = night and 1.4 or 1, Stun = 0.6, Knockback = 40, Heavy = true }, 20)
	end,
}

WeaponSkills.MoonKatana_Eclipse = {
	Name = "Crescent Eclipse",
	Description = "ULTIMATE: The moon descends and shatters.",
	Cooldown = 34,
	EnergyCost = 50,
	Damage = 150,
	Range = 40,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1.2)
		local center = ctx.AimPosition
		ctx:FX("Meteor", { Position = center, Color = Color3.fromRGB(220, 230, 255), Size = 20 })
		ctx:Telegraph(center, 22, 0.9)
		ctx:Wait(0.9)
		ctx:FX("ImpactFrame", { Position = center })
		ctx:FX("Explosion", { Position = center, Color = ctx.Color, Size = 44 })
		ctx:HitRadius(center, 22, { Stun = 1.2, Knockback = 90, Up = 40, Ragdoll = 1.5 })
	end,
}

WeaponSkills.DemonScythe_Hellreap = {
	Name = "Hell Reap",
	Description = "Rip a burning arc through the ground.",
	Cooldown = 8,
	EnergyCost = 18,
	Damage = 50,
	Range = 16,
	Execute = function(ctx)
		ctx:Anim("Weapon_Spin")
		ctx:FX("EnergyRing", { Position = ctx.Root.Position, Color = ctx.Color, Size = 32 })
		ctx:FX("GroundCracks", { Position = ctx.Root.Position - Vector3.new(0, 2.5, 0), Size = 14 })
		ctx:HitRadius(ctx.Root.Position, 16, { Stun = 0.7, Pull = ctx.Root.Position, Burn = true })
	end,
}

WeaponSkills.DemonScythe_Apocalypse = {
	Name = "Crimson Apocalypse",
	Description = "ULTIMATE: Pillars of hellfire erupt around you.",
	Cooldown = 36,
	EnergyCost = 55,
	Damage = 60,
	Range = 30,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1)
		ctx:SuperArmor(2)
		for ring = 1, 3 do
			for i = 1, 6 do
				local angle = (i / 6) * math.pi * 2 + ring
				local pos = ctx.Root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ring * 8)
				ctx:FX("Pillar", { Position = pos, Color = ctx.Color, Size = 5, Height = 40 })
				ctx:HitRadius(pos, 6, { Stun = 0.5, Up = 30, Burn = true })
			end
			if not ctx:Wait(0.3) then
				return
			end
		end
	end,
}

WeaponSkills.ThunderSpear_BoltThrow = {
	Name = "Bolt Throw",
	Description = "Throw a spear of lightning that chains to nearby enemies.",
	Cooldown = 7,
	EnergyCost = 16,
	Damage = 44,
	Range = 60,
	Execute = function(ctx)
		ctx:Anim("Weapon_Throw")
		ctx:Projectile({
			Speed = 180,
			Range = 60,
			Radius = 3,
			Visual = { Kind = "Spear", Color = ctx.Color, Size = 6 },
			Spec = { Stun = 0.5 },
			OnHit = function(c, target)
				local chained = 0
				for _, other in ipairs(c:Enemies(target.Root.Position, 16)) do
					if other ~= target and chained < 3 then
						chained += 1
						c:FX("Lightning", { From = target.Root.Position, To = other.Root.Position, Color = c.Color })
						c:Damage(other, { Damage = 0.5, Stun = 0.4 })
					end
				end
			end,
		})
	end,
}

WeaponSkills.ThunderSpear_Judgement = {
	Name = "Thunder Judgement",
	Description = "ULTIMATE: Leap and call a colossal lightning strike.",
	Cooldown = 34,
	EnergyCost = 50,
	Damage = 140,
	Range = 40,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1)
		ctx:Launch(60)
		local center = ctx.AimPosition
		ctx:Telegraph(center, 20, 0.7)
		ctx:Wait(0.7)
		ctx:FX("Lightning", { From = center + Vector3.new(0, 120, 0), To = center, Color = ctx.Color, Thick = true })
		ctx:FX("ScreenFlash", { Color = Color3.new(1, 1, 1), Duration = 0.1, Position = center })
		ctx:FX("Explosion", { Position = center, Color = ctx.Color, Size = 40 })
		ctx:HitRadius(center, 20, { Stun = 1.4, Knockback = 80, Up = 30, Ragdoll = 1.2 })
	end,
}

WeaponSkills.Celestial_Judgement = {
	Name = "Heaven's Verdict",
	Description = "Drive a pillar of starlight down onto your target.",
	Cooldown = 8,
	EnergyCost = 20,
	Damage = 60,
	Range = 50,
	Execute = function(ctx)
		local pos = ctx.AimPosition
		ctx:Telegraph(pos, 9, 0.35)
		ctx:Wait(0.35)
		ctx:FX("Pillar", { Position = pos, Color = ctx.Color, Size = 9, Height = 120 })
		ctx:HitRadius(pos, 9, { Stun = 0.8, Up = 40 })
	end,
}

WeaponSkills.Celestial_Genesis = {
	Name = "Genesis Blade",
	Description = "ULTIMATE: A blade the size of a mountain falls from the heavens.",
	Cooldown = 38,
	EnergyCost = 60,
	Damage = 240,
	Range = 60,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1.6)
		ctx:SuperArmor(2)
		local center = ctx.AimPosition
		ctx:Telegraph(center, 28, 1.2)
		ctx:FX("Beam", { From = center + Vector3.new(0, 200, 0), To = center, Color = ctx.Color, Width = 18, Duration = 1.4 })
		ctx:Wait(1.2)
		ctx:FX("ImpactFrame", { Position = center })
		ctx:FX("Explosion", { Position = center, Color = ctx.Color, Size = 60 })
		ctx:FX("Crater", { Position = center, Size = 26 })
		ctx:HitRadius(center, 28, { Stun = 1.6, Knockback = 120, Up = 50, Ragdoll = 2, GuardBreak = true })
	end,
}

WeaponSkills.Void_Rend = {
	Name = "Void Rend",
	Description = "Tear space in front of you, pulling enemies into the rift.",
	Cooldown = 8,
	EnergyCost = 20,
	Damage = 52,
	Range = 24,
	Execute = function(ctx)
		local pos = ctx.Root.Position + ctx.AimDirection * 14
		ctx:FX("Singularity", { Position = pos, Color = ctx.Color, Size = 10, Duration = 1 })
		for _ = 1, 4 do
			ctx:HitRadius(pos, 12, { Damage = 0.35, Pull = pos, Stun = 0.4 })
			if not ctx:Wait(0.2) then
				return
			end
		end
		ctx:FX("Explosion", { Position = pos, Color = ctx.Color, Size = 20 })
		ctx:HitRadius(pos, 12, { Damage = 1, Knockback = 60 })
	end,
}

WeaponSkills.Void_Oblivion = {
	Name = "Oblivion",
	Description = "ULTIMATE: Carve the world apart with a void cleave.",
	Cooldown = 36,
	EnergyCost = 60,
	Damage = 190,
	Range = 40,
	Ultimate = true,
	Execute = function(ctx)
		ctx:Cinematic(1.2)
		ctx:SuperArmor(1.8)
		ctx:FX("Domain", { Position = ctx.Root.Position, Color = ctx.Color, Size = 70, Duration = 1.2 })
		ctx:Wait(0.8)
		ctx:FX("ImpactFrame", { Position = ctx.Root.Position })
		slash(ctx, 16, Vector3.new(24, 14, 40), { Stun = 1.4, Knockback = 110, Ragdoll = 1.5, GuardBreak = true, Heavy = true }, 50)
		ctx:Shake(ctx.Root.Position, 1, 90)
	end,
}

return WeaponSkills
