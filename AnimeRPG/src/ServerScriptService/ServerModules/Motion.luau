--[[
	Motion (ModuleScript)
	Location: ServerScriptService.ServerModules.Motion
	Knockback, launch, pull, freeze and ragdoll for any entity.
	- NPCs: applied directly on the server (server owns their physics).
	- Players: the character's physics is owned by its client, so the server sends a
	  "ClientMotion" event and the client applies it (MovementController). The server also
	  grants a MovementValidator allowance so the anti-cheat doesn't flag the burst of speed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)

local Motion = {}

local function allow(entity, speed: number, duration: number)
	if entity.Player and Registry.Has("MovementValidator") then
		Registry.Get("MovementValidator"):GrantAllowance(entity.Player, speed, duration)
	end
end

function Motion.Velocity(entity, velocity: Vector3, duration: number)
	if velocity.Magnitude < 0.1 then
		return
	end
	if entity.Player then
		allow(entity, velocity.Magnitude, duration + 0.5)
		Net.Event("ClientMotion"):FireClient(entity.Player, "Velocity", { Velocity = velocity, Duration = duration })
		return
	end
	local root = entity.Root
	if root.Anchored then
		return
	end
	local attachment = root:FindFirstChild("MotionAttachment") :: Attachment?
	if not attachment then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = "MotionAttachment"
		newAttachment.Parent = root
		attachment = newAttachment
	end
	local old = root:FindFirstChild("MotionVelocity")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MotionVelocity"
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, duration)
end

-- Push away from a point.
function Motion.Knockback(entity, fromPosition: Vector3, force: number, up: number?)
	local offset = entity.Root.Position - fromPosition
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local dir = flat.Magnitude > 0.05 and flat.Unit or entity.Root.CFrame.LookVector * -1
	local velocity = dir * force + Vector3.new(0, up or 0, 0)
	Motion.Velocity(entity, velocity, 0.22)
end

function Motion.Launch(entity, up: number)
	Motion.Velocity(entity, Vector3.new(0, up, 0), 0.25)
end

-- Pull toward a point (arrives roughly in `duration`).
function Motion.Pull(entity, toPosition: Vector3, force: number)
	local offset = toPosition - entity.Root.Position
	if offset.Magnitude < 3 then
		return
	end
	local speed = math.min(force, offset.Magnitude / 0.2)
	Motion.Velocity(entity, offset.Unit * speed, 0.2)
end

function Motion.Freeze(entity, duration: number)
	entity.State.FrozenUntil = math.max(entity.State.FrozenUntil, os.clock() + duration)
	entity.Model:SetAttribute("Frozen", true)
	if entity.Player then
		Net.Event("ClientMotion"):FireClient(entity.Player, "Freeze", { Duration = duration })
	else
		entity.Root.Anchored = true
	end
	task.delay(duration, function()
		if os.clock() >= entity.State.FrozenUntil - 0.01 and entity.Model.Parent then
			entity.Model:SetAttribute("Frozen", false)
			if not entity.Player then
				entity.Root.Anchored = false
			end
		end
	end)
end

function Motion.Ragdoll(entity, duration: number)
	entity.Model:SetAttribute("Ragdolled", true)
	if entity.Player then
		Net.Event("ClientMotion"):FireClient(entity.Player, "Ragdoll", { Duration = duration })
	else
		entity.Humanoid.PlatformStand = true
	end
	task.delay(duration, function()
		if entity.Model.Parent then
			entity.Model:SetAttribute("Ragdolled", false)
			if not entity.Player then
				entity.Humanoid.PlatformStand = false
				-- Stand the NPC back up.
				local root = entity.Root
				local _, yaw = root.CFrame:ToOrientation()
				root.CFrame = CFrame.new(root.Position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, yaw, 0)
			end
		end
	end)
end

-- Moves the entity itself (dash skills). distance over duration.
function Motion.Dash(entity, direction: Vector3, distance: number, duration: number)
	if direction.Magnitude < 0.01 then
		return
	end
	local velocity = direction.Unit * (distance / math.max(duration, 0.05))
	if entity.Player then
		allow(entity, velocity.Magnitude, duration + 0.5)
		Net.Event("ClientMotion"):FireClient(entity.Player, "Dash", { Velocity = velocity, Duration = duration })
	else
		Motion.Velocity(entity, velocity, duration)
	end
end

function Motion.Teleport(entity, cframe: CFrame)
	if entity.Player and Registry.Has("MovementValidator") then
		Registry.Get("MovementValidator"):AllowTeleport(entity.Player)
	end
	entity.Model:PivotTo(cframe)
	if entity.Player then
		Net.Event("ClientMotion"):FireClient(entity.Player, "Teleport", { CFrame = cframe })
	end
end

return Motion
