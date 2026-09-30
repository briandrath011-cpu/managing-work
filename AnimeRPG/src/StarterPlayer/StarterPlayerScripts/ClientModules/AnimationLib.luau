--[[
	AnimationLib (ModuleScript)
	Location: StarterPlayer.StarterPlayerScripts.ClientModules.AnimationLib
	Plays animations by NAME (Modules.Assets.AssetIds.Animations).
	If no animation id is set, a PROCEDURAL fallback pose is played by tweening the
	character's Motor6D C0 values locally - so combat looks alive without any assets.
	Works on R15 and R6 rigs.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Modules.Assets.AssetIds)

local AnimationLib = {}

local trackCache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local baseC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local busy: { [Motor6D]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local R = math.rad

-- Joint name candidates for R15 / R6
local JOINTS = {
	RightArm = { "RightShoulder", "Right Shoulder" },
	LeftArm = { "LeftShoulder", "Left Shoulder" },
	RightLeg = { "RightHip", "Right Hip" },
	LeftLeg = { "LeftHip", "Left Hip" },
	Torso = { "Waist", "RootJoint" },
}

-- Procedural poses: list of { joint, rotation (CFrame.Angles), duration }
local POSES = {
	SwingRight = {
		{ "RightArm", CFrame.Angles(R(110), R(20), R(40)), 0.08 },
		{ "RightArm", CFrame.Angles(R(40), R(-30), R(-40)), 0.12 },
		{ "Torso", CFrame.Angles(0, R(-25), 0), 0.12 },
	},
	SwingLeft = {
		{ "RightArm", CFrame.Angles(R(90), R(-40), R(-60)), 0.08 },
		{ "RightArm", CFrame.Angles(R(50), R(40), R(50)), 0.12 },
		{ "Torso", CFrame.Angles(0, R(25), 0), 0.12 },
	},
	SwingOverhead = {
		{ "RightArm", CFrame.Angles(R(170), 0, 0), 0.12 },
		{ "RightArm", CFrame.Angles(R(30), 0, 0), 0.1 },
		{ "LeftArm", CFrame.Angles(R(150), 0, 0), 0.12 },
	},
	PunchRight = { { "RightArm", CFrame.Angles(R(90), 0, 0), 0.07 }, { "Torso", CFrame.Angles(0, R(-20), 0), 0.07 } },
	PunchLeft = { { "LeftArm", CFrame.Angles(R(90), 0, 0), 0.07 }, { "Torso", CFrame.Angles(0, R(20), 0), 0.07 } },
	PunchBoth = { { "RightArm", CFrame.Angles(R(95), 0, 0), 0.06 }, { "LeftArm", CFrame.Angles(R(95), 0, 0), 0.06 } },
	Kick = { { "RightLeg", CFrame.Angles(R(80), 0, 0), 0.08 }, { "Torso", CFrame.Angles(R(-10), 0, 0), 0.08 } },
	CastForward = { { "RightArm", CFrame.Angles(R(90), 0, 0), 0.12 }, { "LeftArm", CFrame.Angles(R(90), 0, 0), 0.12 } },
	CastUp = { { "RightArm", CFrame.Angles(R(170), 0, R(-20)), 0.15 }, { "LeftArm", CFrame.Angles(R(170), 0, R(20)), 0.15 } },
	PointRight = { { "RightArm", CFrame.Angles(R(90), 0, 0), 0.08 } },
	Guard = { { "RightArm", CFrame.Angles(R(80), 0, R(-50)), 0.08 }, { "LeftArm", CFrame.Angles(R(80), 0, R(50)), 0.08 } },
	Lean = { { "Torso", CFrame.Angles(R(-20), 0, 0), 0.08 } },
}

local function findJoint(model: Model, key: string): Motor6D?
	for _, name in ipairs(JOINTS[key]) do
		local joint = model:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil
end

local function playPose(model: Model, poseName: string, hold: number?)
	local pose = POSES[poseName]
	if not pose then
		return
	end
	for _, step in ipairs(pose) do
		local joint = findJoint(model, step[1])
		if joint then
			if not baseC0[joint] then
				baseC0[joint] = joint.C0
			end
			local base = baseC0[joint]
			if busy[joint] then
				busy[joint]:Cancel()
			end
			local out =
				TweenService:Create(joint, TweenInfo.new(step[3], Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * step[2] })
			busy[joint] = out
			out:Play()
			task.delay(step[3] + (hold or 0.12), function()
				if busy[joint] == out and joint.Parent then
					local back =
						TweenService:Create(joint, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { C0 = base })
					busy[joint] = back
					back:Play()
				end
			end)
		end
	end
end

function AnimationLib.Play(model: Model?, name: string, speed: number?, hold: number?): AnimationTrack?
	if not model then
		return nil
	end
	local entry = AssetIds.Animations[name]
	if not entry then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if entry.Id ~= "" and animator then
		local cache = trackCache[animator]
		if not cache then
			cache = {}
			trackCache[animator] = cache
		end
		local track = cache[name]
		if not track then
			local animation = Instance.new("Animation")
			animation.AnimationId = entry.Id
			local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
			if not ok then
				playPose(model, entry.Fallback, hold)
				return nil
			end
			track = loaded
			cache[name] = track
		end
		track:Play(0.05, 1, speed or 1)
		return track
	end
	playPose(model, entry.Fallback, hold)
	return nil
end

-- True when a real animation id is configured (it then replicates from the owning client).
function AnimationLib.HasAsset(name: string): boolean
	local entry = AssetIds.Animations[name]
	return entry ~= nil and entry.Id ~= ""
end

-- Resets every procedural pose (used when a character respawns).
function AnimationLib.Reset(model: Model)
	for _, key in ipairs({ "RightArm", "LeftArm", "RightLeg", "LeftLeg", "Torso" }) do
		local joint = findJoint(model, key)
		if joint and baseC0[joint] then
			joint.C0 = baseC0[joint]
		end
	end
end

return AnimationLib
