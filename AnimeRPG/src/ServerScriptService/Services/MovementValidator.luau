--[[
	MovementValidator (ModuleScript)
	Location: ServerScriptService.Services.MovementValidator
	PHASE 2 / 22 - Server-side movement sanity checks.
	Every CheckInterval the server compares how far each character moved horizontally with
	what is physically allowed (sprint speed + dash/knockback allowances). Repeated
	violations rubber-band the player back and add AntiExploit strikes.
	Remote: MovementState (client reports Flight / WallRun so allowances are correct)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)

local MovementValidator = {}

local M = GameConfig.Movement

type Track = {
	LastPosition: Vector3?,
	LastTime: number,
	AllowanceSpeed: number,
	AllowanceUntil: number,
	TeleportUntil: number,
	Strikes: number,
	State: string,
}

local tracks: { [Player]: Track } = {}
local limiter = RateLimiter.new(10, 4)

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = {
			LastPosition = nil,
			LastTime = os.clock(),
			AllowanceSpeed = 0,
			AllowanceUntil = 0,
			TeleportUntil = 0,
			Strikes = 0,
			State = "Ground",
		}
		tracks[player] = t
	end
	return t
end

-- Temporarily allow a higher speed (dash, knockback, skills).
function MovementValidator:GrantAllowance(player: Player, speed: number, duration: number)
	local t = track(player)
	local now = os.clock()
	if now < t.AllowanceUntil then
		t.AllowanceSpeed = math.max(t.AllowanceSpeed, speed)
	else
		t.AllowanceSpeed = speed
	end
	t.AllowanceUntil = math.max(t.AllowanceUntil, now + duration)
end

-- Server-initiated teleports (fast travel, skills, spawns) reset tracking.
function MovementValidator:AllowTeleport(player: Player)
	local t = track(player)
	t.TeleportUntil = os.clock() + 2
	t.LastPosition = nil
end

function MovementValidator:Init()
	Net.Event("MovementState").OnServerEvent:Connect(function(player, state)
		if not limiter:Check(player) then
			return
		end
		if state ~= "Ground" and state ~= "Flight" and state ~= "WallRun" then
			return
		end
		local character = player.Character
		if state == "Flight" and not (character and character:GetAttribute("FlightUnlocked")) then
			Registry.Get("AntiExploitService"):Flag(player, "Flight without unlock", 3)
			return
		end
		track(player).State = state
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

function MovementValidator:Start()
	while true do
		task.wait(M.CheckInterval)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local t = track(player)
			if not root or not humanoid or humanoid.Health <= 0 then
				t.LastPosition = nil
				continue
			end
			local position = root.Position
			if t.LastPosition == nil or now < t.TeleportUntil then
				t.LastPosition = position
				t.LastTime = now
				continue
			end
			local dt = math.max(0.05, now - t.LastTime)
			local delta = position - t.LastPosition
			local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
			local baseSpeed = (character :: Model):GetAttribute("SprintSpeed") or M.FlightSpeed
			local buffSpeed = (character :: Model):GetAttribute("BuffSpeed") or 0
			local allowed = (
				math.max(baseSpeed, t.State == "Flight" and M.FlightSpeed or 0, t.State == "WallRun" and M.WallRunSpeed or 0) + buffSpeed
			) * M.SpeedTolerance
			if now < t.AllowanceUntil + dt then
				allowed += t.AllowanceSpeed
			end
			-- Each check interval may include one dash that wasn't reported yet (latency).
			allowed += M.DashSpeed * M.DashDuration / dt
			if horizontal > allowed then
				t.Strikes += 1
				if t.Strikes >= M.MaxStrikesBeforeRubberband then
					character:PivotTo(CFrame.new(t.LastPosition) * root.CFrame.Rotation)
					Registry.Get("AntiExploitService"):Flag(player, string.format("Speed %.0f > %.0f", horizontal, allowed), 2)
					t.Strikes = 0
					t.LastTime = now
					continue
				end
			else
				t.Strikes = math.max(0, t.Strikes - 0.5)
			end
			t.LastPosition = position
			t.LastTime = now
		end
	end
end

return MovementValidator
