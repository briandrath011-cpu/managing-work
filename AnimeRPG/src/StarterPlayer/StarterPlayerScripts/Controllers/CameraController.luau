--[[
	CameraController (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.Controllers.CameraController
	- Camera shake (hit feedback) via Humanoid.CameraOffset (works with default camera on all platforms)
	- FOV kicks (sprint / dash / ultimate)
	- Ultimate / transformation cinematics (short zoom + blur)
	- Lock-on (T / RS / mobile button): camera + aim follow the nearest enemy
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = script.Parent.Parent

local ClientRegistry = require(StarterPlayerScripts.ClientModules.ClientRegistry)
local VFXLib = require(StarterPlayerScripts.ClientModules.VFXLib)

local CameraController = {}
CameraController.LockTarget = nil :: Model?

local player = Players.LocalPlayer
local shakeIntensity = 0
local shakeUntil = 0
local baseFov = 70
local fovBoost = 0
local cinematicUntil = 0

function CameraController:Shake(intensity: number, duration: number)
	if not ClientRegistry.Get("SettingsController").Settings.CameraShake then
		return
	end
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

function CameraController:FovKick(amount: number, duration: number)
	fovBoost = math.max(fovBoost, amount)
	task.delay(duration, function()
		fovBoost = 0
	end)
end

function CameraController:Cinematic(duration: number, style: string?, color: Color3?)
	cinematicUntil = os.clock() + duration
	self:FovKick(style == "Domain" and 25 or 15, duration)
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(0.15), { Size = 10 }):Play()
	task.delay(duration * 0.6, function()
		TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
	end)
	task.delay(duration + 0.4, function()
		blur:Destroy()
	end)
	if color then
		VFXLib.ScreenFlashLocal(color, 0.35, 0.55)
	end
	self:Shake(0.6, duration * 0.5)
end

local function enemyModels(): { Model }
	local list = {}
	for _, folderName in ipairs({ "Enemies", "Bosses" }) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, model in ipairs(folder:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("Entity") and model:FindFirstChild("HumanoidRootPart") then
					table.insert(list, model)
				end
			end
		end
	end
	return list
end
CameraController.EnemyModels = enemyModels

function CameraController:FindNearestEnemy(maxDistance: number, requireInFront: boolean?): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local best, bestScore = nil, math.huge
	for _, model in ipairs(enemyModels()) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart
		if humanoid and humanoid.Health > 0 then
			local offset = targetRoot.Position - root.Position
			local dist = offset.Magnitude
			if dist <= maxDistance then
				local facing = camera and offset.Unit:Dot(camera.CFrame.LookVector) or 1
				if not requireInFront or facing > 0.3 then
					local score = dist * (1.5 - facing)
					if score < bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
	end
	return best
end

function CameraController:ToggleLock()
	if self.LockTarget then
		self.LockTarget = nil
		return
	end
	self.LockTarget = self:FindNearestEnemy(80, false)
end

function CameraController:Init()
	VFXLib.Shake = function(intensity, duration)
		self:Shake(intensity, duration)
	end
	ClientRegistry.Get("InputController"):OnAction("LockOn", function(began)
		if began then
			self:ToggleLock()
		end
	end)
end

function CameraController:Start()
	RunService:BindToRenderStep("AnimeCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not camera or not humanoid then
			return
		end
		-- Shake
		local now = os.clock()
		if now < shakeUntil and shakeIntensity > 0 then
			local i = shakeIntensity
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * i, (math.random() - 0.5) * i, (math.random() - 0.5) * i * 0.5)
		else
			shakeIntensity = 0
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, math.min(1, dt * 12))
		end
		-- FOV
		local sprinting = character:GetAttribute("Sprinting") == true
		local target = baseFov + fovBoost + (sprinting and 6 or 0)
		camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * 8)
		-- Lock-on: rotate camera to keep the target in view
		local lock = self.LockTarget
		if lock then
			local lockRoot = lock:FindFirstChild("HumanoidRootPart") :: BasePart?
			local lockHumanoid = lock:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				not lock.Parent
				or not lockRoot
				or not lockHumanoid
				or lockHumanoid.Health <= 0
				or not root
				or (lockRoot.Position - root.Position).Magnitude > 120
			then
				self.LockTarget = nil
			elseif now > cinematicUntil then
				local camPos = camera.CFrame.Position
				local desired = CFrame.lookAt(camPos, lockRoot.Position:Lerp(root.Position, 0.35))
				camera.CFrame = camera.CFrame:Lerp(desired, math.min(1, dt * 6))
			end
		end
	end)
end

return CameraController
