--[[
	MovementController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.MovementController

	PHASE 2 - Movement (client side; the server validates speed in MovementValidator)
	Sprint (Shift / L3 / mobile toggle), Dash (Q / B / button: front, side, back, air),
	Double Jump, Air Dash, Wall Jump, Wall Run, Flight (unlockable, H / Y).
	Also applies server-driven motion (knockback, pulls, freezes, ragdoll, downed)
	and movement locks (stun, block slow, freeze).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)
local AnimationLib = require(StarterPlayerScripts.ClientModules.AnimationLib)
local SoundLib = require(StarterPlayerScripts.ClientModules.SoundLib)

local MovementController = {}

local M = GameConfig.Movement
local player = Players.LocalPlayer

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local state = {
	Sprinting = false,
	LastDash = 0,
	AirDashesUsed = 0,
	ExtraJumpsUsed = 0,
	LastWallJump = 0,
	WallRunning = false,
	WallRunStart = 0,
	WallNormal = Vector3.zero,
	Flying = false,
	MotionUntil = 0,
	FrozenUntil = 0,
	RagdollUntil = 0,
	Downed = false,
	LastJumpStart = 0,
}

local motionVelocity: LinearVelocity? = nil
local flightVelocity: LinearVelocity? = nil
local flightGyro: AlignOrientation? = nil
local reportedState = "Ground"

local function reportState(newState: string)
	if newState ~= reportedState then
		reportedState = newState
		Net.Event("MovementState"):FireServer(newState)
	end
end

local function isAirborne(): boolean
	return humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
end

local function canMove(): boolean
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = os.clock()
	return not character:GetAttribute("Stunned") and now >= state.FrozenUntil and now >= state.RagdollUntil and not state.Downed
end

local function ensureAttachment(): Attachment?
	if not root then
		return nil
	end
	local attachment = root:FindFirstChild("MoveAttachment") :: Attachment?
	if not attachment then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = "MoveAttachment"
		newAttachment.Parent = root
		attachment = newAttachment
	end
	return attachment
end

-- Applies a velocity to our own character for `duration` seconds.
function MovementController:ApplyVelocity(velocity: Vector3, duration: number)
	local attachment = ensureAttachment()
	if not attachment or not root then
		return
	end
	if motionVelocity then
		motionVelocity:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "DashVelocity"
	lv.Attachment0 = attachment
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = velocity
	lv.Parent = root
	motionVelocity = lv
	state.MotionUntil = os.clock() + duration
	task.delay(duration, function()
		if motionVelocity == lv then
			lv:Destroy()
			motionVelocity = nil
		end
	end)
end

-- DASH ----------------------------------------------------------------------------------------------

function MovementController:Dash()
	if not canMove() or not root or not humanoid or not character then
		return
	end
	if character:GetAttribute("Blocking") then
		return
	end
	local now = os.clock()
	local cooldown = character:GetAttribute("DashCooldown") or M.DashCooldown
	if now - state.LastDash < cooldown then
		return
	end
	local airborne = isAirborne()
	if airborne and state.AirDashesUsed >= M.AirDashes then
		return
	end
	state.LastDash = now
	local camera = Workspace.CurrentCamera
	local moveDir = humanoid.MoveDirection
	local look = camera and Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit or root.CFrame.LookVector
	local direction = moveDir.Magnitude > 0.1 and moveDir.Unit or look
	local kind = "Front"
	local dot = direction:Dot(look)
	if airborne then
		kind = "Air"
		state.AirDashesUsed += 1
	elseif dot < -0.5 then
		kind = "Back"
	elseif math.abs(dot) <= 0.5 then
		kind = "Side"
	end
	Net.Event("CombatAction"):FireServer("Dash", { Direction = kind })
	local speed = M.DashSpeed * (kind == "Back" and 0.85 or 1)
	local velocity = direction * speed
	if airborne then
		velocity += Vector3.new(0, 8, 0)
	end
	self:ApplyVelocity(velocity, M.DashDuration)
	AnimationLib.Play(character, "Dash")
	VFXLib.Play("DashFX", { Model = character })
	SoundLib.Play("Dash", root.Position)
	ClientRegistry.Get("CameraController"):FovKick(8, 0.2)
end

-- JUMPS / WALL ---------------------------------------------------------------------------------------

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

local function wallCheck(direction: Vector3): RaycastResult?
	if not root or not character then
		return nil
	end
	wallParams.FilterDescendantsInstances = { character, Workspace:FindFirstChild("Effects") or character }
	return Workspace:Raycast(root.Position, direction * 3.2, wallParams)
end

local function onJumpRequest()
	if not canMove() or not humanoid or not root or not character then
		return
	end
	if state.Flying then
		return
	end
	local now = os.clock()
	if state.WallRunning then
		-- Jump off the wall
		MovementController:StopWallRun()
		state.LastWallJump = now
		root.AssemblyLinearVelocity = state.WallNormal * M.WallJumpPush + Vector3.new(0, M.WallJumpPower, 0) + root.CFrame.LookVector * 20
		VFXLib.Play("DashFX", { Model = character })
		return
	end
	if not isAirborne() then
		return
	end
	-- Wall jump
	local front = wallCheck(root.CFrame.LookVector)
	if front and character:GetAttribute("WallRun") ~= false and now - state.LastWallJump > 0.35 then
		state.LastWallJump = now
		root.AssemblyLinearVelocity = front.Normal * M.WallJumpPush + Vector3.new(0, M.WallJumpPower, 0)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(front.Normal.X, 0, front.Normal.Z))
		VFXLib.Play("DashFX", { Model = character })
		return
	end
	-- Double jump (JumpRequest repeats while the button is held, so wait a moment after the first jump)
	if
		character:GetAttribute("DoubleJump") ~= false
		and state.ExtraJumpsUsed < 1
		and now - state.LastJumpStart > 0.25
		and root.AssemblyLinearVelocity.Y < 40
	then
		state.ExtraJumpsUsed += 1
		local vel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(vel.X, M.DoubleJumpPower, vel.Z)
		VFXLib.Play("Shockwave", { Position = root.Position - Vector3.new(0, 3, 0), Color = Color3.fromRGB(220, 230, 255), Size = 8 })
		SoundLib.Play("Jump", root.Position)
	end
end

function MovementController:StartWallRun(result: RaycastResult)
	if not root then
		return
	end
	state.WallRunning = true
	state.WallRunStart = os.clock()
	state.WallNormal = result.Normal
	reportState("WallRun")
end

function MovementController:StopWallRun()
	state.WallRunning = false
	reportState(state.Flying and "Flight" or "Ground")
end

local function updateWallRun()
	if not root or not humanoid or not character then
		return
	end
	if state.WallRunning then
		local side = wallCheck(-state.WallNormal)
		local elapsed = os.clock() - state.WallRunStart
		if not side or elapsed > M.WallRunDuration or not isAirborne() or not canMove() then
			MovementController:StopWallRun()
			return
		end
		local along = Vector3.new(0, 1, 0):Cross(side.Normal)
		if along:Dot(root.CFrame.LookVector) < 0 then
			along = -along
		end
		root.AssemblyLinearVelocity = along * M.WallRunSpeed + Vector3.new(0, -2 - elapsed * 6, 0)
		return
	end
	-- Start conditions: airborne, sprinting, falling slowly, wall on the left or right
	if character:GetAttribute("WallRun") == false or not state.Sprinting or not isAirborne() or state.Flying then
		return
	end
	if os.clock() - state.LastWallJump < 0.3 or humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end
	for _, dir in ipairs({ root.CFrame.RightVector, -root.CFrame.RightVector }) do
		local result = wallCheck(dir)
		if result and math.abs(result.Normal.Y) < 0.3 then
			MovementController:StartWallRun(result)
			return
		end
	end
end

-- FLIGHT --------------------------------------------------------------------------------------------

function MovementController:SetFlying(enabled: boolean)
	if not root or not humanoid or not character then
		return
	end
	if enabled and not character:GetAttribute("FlightUnlocked") then
		ClientRegistry.Get("HUD"):Toast("Flight is not unlocked yet (Wings of Freedom, level " .. M.FlightUnlockLevel .. ")", "Error")
		return
	end
	state.Flying = enabled
	if enabled then
		local attachment = ensureAttachment() :: Attachment
		local lv = Instance.new("LinearVelocity")
		lv.Name = "FlightVelocity"
		lv.Attachment0 = attachment
		lv.MaxForce = 1e6
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = Vector3.zero
		lv.Parent = root
		flightVelocity = lv
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxTorque = 1e6
		align.Responsiveness = 25
		align.Parent = root
		flightGyro = align
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		VFXLib.Play("Shockwave", { Position = root.Position, Color = Color3.fromRGB(220, 240, 255), Size = 14 })
		reportState("Flight")
	else
		if flightVelocity then
			flightVelocity:Destroy()
			flightVelocity = nil
		end
		if flightGyro then
			flightGyro:Destroy()
			flightGyro = nil
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		reportState("Ground")
	end
end

local function updateFlight()
	if not state.Flying or not flightVelocity or not flightGyro or not humanoid then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local move = humanoid.MoveDirection
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.zAxis
	local forwardAmount = move:Dot(flatLook)
	local velocity = move * M.FlightSpeed + Vector3.new(0, look.Y * forwardAmount * M.FlightSpeed, 0)
	if
		UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		or humanoid.Jump
	then
		velocity += Vector3.new(0, M.FlightSpeed * 0.7, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		velocity -= Vector3.new(0, M.FlightSpeed * 0.7, 0)
	end
	flightVelocity.VectorVelocity = velocity
	flightGyro.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
end

-- SERVER MOTION -------------------------------------------------------------------------------------

local function onClientMotion(kind: string, params)
	if not root or not humanoid then
		return
	end
	if kind == "Velocity" or kind == "Dash" then
		if state.Flying and kind == "Velocity" then
			MovementController:SetFlying(false)
		end
		MovementController:ApplyVelocity(params.Velocity, params.Duration)
	elseif kind == "Freeze" then
		state.FrozenUntil = os.clock() + params.Duration
		root.Anchored = true
		task.delay(params.Duration, function()
			if os.clock() >= state.FrozenUntil - 0.01 and root then
				root.Anchored = false
			end
		end)
	elseif kind == "Ragdoll" then
		state.RagdollUntil = os.clock() + params.Duration
		humanoid.PlatformStand = true
		task.delay(params.Duration, function()
			if os.clock() >= state.RagdollUntil - 0.01 and humanoid then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	elseif kind == "Downed" then
		state.Downed = true
		humanoid.PlatformStand = true
		ClientRegistry.Get("HUD"):Toast("You are DOWN! Wait for a teammate to revive you.", "Error")
	elseif kind == "Revived" then
		state.Downed = false
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	elseif kind == "Teleport" then
		if state.Flying then
			MovementController:SetFlying(false)
		end
	end
end

-- SPEED ---------------------------------------------------------------------------------------------

local function updateSpeed()
	if not humanoid or not character then
		return
	end
	local walk = character:GetAttribute("BaseWalkSpeed") or GameConfig.Character.WalkSpeed
	local sprint = character:GetAttribute("SprintSpeed") or GameConfig.Character.SprintSpeed
	local buff = character:GetAttribute("BuffSpeed") or 0
	local speed = (state.Sprinting and sprint or walk) + buff
	if character:GetAttribute("Blocking") then
		speed = 8
	end
	if not canMove() then
		speed = 0
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = canMove() and GameConfig.Character.JumpPower or 0
	character:SetAttribute("Sprinting", state.Sprinting and humanoid.MoveDirection.Magnitude > 0.1)
end

-- LIFECYCLE -----------------------------------------------------------------------------------------

local function onCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	state.Flying = false
	state.WallRunning = false
	state.Downed = false
	state.FrozenUntil = 0
	state.RagdollUntil = 0
	motionVelocity = nil
	flightVelocity = nil
	flightGyro = nil
	reportedState = "Ground"
	local hum = humanoid :: Humanoid
	hum.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping then
			state.LastJumpStart = os.clock()
		end
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			state.AirDashesUsed = 0
			state.ExtraJumpsUsed = 0
			if state.WallRunning then
				MovementController:StopWallRun()
			end
		end
	end)
end

function MovementController:IsSprinting(): boolean
	return state.Sprinting
end

function MovementController:Init()
	local input = ClientRegistry.Get("InputController")
	input:OnAction("Sprint", function(began)
		state.Sprinting = began
	end)
	input:OnAction("Dash", function(began)
		if began then
			self:Dash()
		end
	end)
	input:OnAction("Flight", function(began)
		if began then
			self:SetFlying(not state.Flying)
		end
	end)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	Net.Event("ClientMotion").OnClientEvent:Connect(onClientMotion)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function MovementController:Start()
	RunService.Heartbeat:Connect(function()
		if not character or not humanoid then
			return
		end
		updateSpeed()
		updateWallRun()
		updateFlight()
		if state.Flying and (not canMove() or humanoid.Health <= 0) then
			self:SetFlying(false)
		end
	end)
end

return MovementController
