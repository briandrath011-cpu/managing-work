--[[
	NPCAnimator (ModuleScript)
	Location: ServerScriptService.ServerModules.NPCAnimator
	Idle / walk / run animations for server-controlled rigs (enemies, bosses, summons, NPCs).
	Played on the server's Animator so they replicate to every client. Ids in
	Modules.Assets.AssetIds.NPCAnimations. Fails silently if an id can't be loaded.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Modules.Assets.AssetIds)

local NPCAnimator = {}

local tracks: { [Humanoid]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local current: { [Humanoid]: string } = setmetatable({}, { __mode = "k" }) :: any

local function load(humanoid: Humanoid)
	if tracks[humanoid] then
		return tracks[humanoid]
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid
		animator = newAnimator
	end
	local loaded = {}
	for name, id in pairs(AssetIds.NPCAnimations) do
		if id ~= "" and humanoid.RigType == Enum.HumanoidRigType.R15 then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Core
				loaded[name] = track
			end
		end
	end
	tracks[humanoid] = loaded
	return loaded
end

-- Call a few times per second; switches between Idle / Walk / Run by speed.
function NPCAnimator.Update(humanoid: Humanoid, root: BasePart)
	local set = load(humanoid)
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local wanted = speed > 20 and "Run" or (speed > 1.5 and "Walk" or "Idle")
	if not set[wanted] then
		wanted = set.Walk and speed > 1.5 and "Walk" or "Idle"
	end
	if current[humanoid] == wanted then
		return
	end
	local old = current[humanoid] and set[current[humanoid]]
	if old then
		old:Stop(0.2)
	end
	local track = set[wanted]
	if track then
		track:Play(0.2)
	end
	current[humanoid] = wanted
end

return NPCAnimator
