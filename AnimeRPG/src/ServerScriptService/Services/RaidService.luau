--[[
	RaidService (ModuleScript)
	Location: ServerScriptService.Services.RaidService

	PHASE 20 - Raids (endgame, up to 8 players)
	- Lobby at the Raid Gate (Celestial Realm), countdown, instanced arena
	- Raid boss with 3 phases + mechanics:
	    Shield  (phase 2): boss immune until all Eclipse Crystals are destroyed
	    Eclipse (phase 3): darkness every ~20s, stand in a light circle or take massive damage
	- Revive system: lethal damage downs a player; teammates hold E to revive
	- Wipe when every member is down / dead; rare drops on success
	Remote: RaidAction (RemoteFunction) ("Create") ("Join", lobbyId) ("Leave") ("Start")
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Raids = require(Modules.World.Raids)
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local RaidService = {}

local limiter = RateLimiter.new(8, 3)
local lobbies: { [string]: any } = {}
local runs: { [string]: any } = {}
local playerLobby: { [Player]: string } = {}
local playerRun: { [Player]: string } = {}
local usedSlots: { [number]: boolean } = {}
local stateRemote: RemoteEvent

local ARENA_RADIUS = 110

local function send(players: { Player }, kind: string, payload)
	for _, player in ipairs(players) do
		if player.Parent then
			stateRemote:FireClient(player, kind, payload)
		end
	end
end

local function nearGate(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - WorldConfig.RaidGate.Position).Magnitude < 30
end

local function lobbyPayload(lobby)
	local names = {}
	for _, player in ipairs(lobby.Members) do
		table.insert(names, player.DisplayName)
	end
	return {
		Type = "Raid",
		LobbyId = lobby.Id,
		Name = Raids[lobby.Raid].DisplayName,
		Members = names,
		Host = lobby.Host.DisplayName,
		Countdown = math.max(0, math.ceil(lobby.StartsAt - os.clock())),
		MaxPlayers = GameConfig.Raids.MaxPlayers,
	}
end

-- ARENA ----------------------------------------------------------------------------------------------

local function buildArena(origin: Vector3, theme)
	local model = Instance.new("Model")
	model.Name = "RaidInstance"
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(4, ARENA_RADIUS * 2, ARENA_RADIUS * 2)
	floor.CFrame = CFrame.new(origin - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Color = theme.Floor
	floor.Material = Enum.Material.Slate
	floor.Parent = model
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(30, 40, 4)
		wall.CFrame = CFrame.new(origin + Vector3.new(math.cos(angle) * ARENA_RADIUS, 20, math.sin(angle) * ARENA_RADIUS))
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
		wall.Color = theme.Floor:Lerp(Color3.new(0, 0, 0), 0.3)
		wall.Material = Enum.Material.Slate
		wall.Parent = model
		if i % 3 == 0 then
			local rune = Instance.new("Part")
			rune.Anchored = true
			rune.CanCollide = false
			rune.Size = Vector3.new(3, 3, 1)
			rune.CFrame = wall.CFrame * CFrame.new(0, 0, -2.6)
			rune.Color = theme.Accent
			rune.Material = Enum.Material.Neon
			rune.Parent = model
		end
	end
	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = model
	model.Parent = workspace:FindFirstChild("Map") or workspace
	return model, enemies
end

-- DOWN / REVIVE ----------------------------------------------------------------------------------------

function RaidService:IsInRaid(player: Player): boolean
	return playerRun[player] ~= nil
end

-- Called by DamageService instead of letting a raid member die.
function RaidService:Down(entity)
	local player = entity.Player
	if not player or entity.State.Downed then
		return
	end
	entity.State.Downed = true
	entity.Humanoid.Health = 1
	entity.Model:SetAttribute("Downed", true)
	Net.Event("ClientMotion"):FireClient(player, "Downed", { Duration = GameConfig.Raids.DownedDuration })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = GameConfig.Raids.ReviveTime
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = entity.Root
	local revived = false
	prompt.Triggered:Connect(function(helper)
		if helper == player or not playerRun[helper] or revived then
			return
		end
		revived = true
		prompt:Destroy()
		entity.State.Downed = false
		entity.Model:SetAttribute("Downed", false)
		entity.Humanoid.Health = entity.Humanoid.MaxHealth * 0.35
		entity.State.IFramesUntil = os.clock() + 2
		Net.Event("ClientMotion"):FireClient(player, "Revived", {})
		Registry.Get("FXService"):Play("Revive", { Model = entity.Model }, entity.Root.Position)
		Registry.Get("FXService"):Notify(player, "Reward", helper.DisplayName .. " revived you!")
	end)
	task.delay(GameConfig.Raids.DownedDuration, function()
		if not revived and entity.Model.Parent and entity.State.Downed then
			prompt:Destroy()
			entity.State.Downed = false
			entity.Humanoid.Health = 0
		end
	end)
end

local function aliveMembers(run): { Player }
	local list = {}
	for _, player in ipairs(run.Members) do
		local entity = player.Parent and EntityRegistry.GetForPlayer(player)
		if entity and EntityRegistry.IsAlive(entity) then
			table.insert(list, player)
		end
	end
	return list
end

-- MECHANICS -------------------------------------------------------------------------------------------

local function shieldMechanic(run, bossEntity)
	local fx = Registry.Get("FXService")
	bossEntity.State.IFramesUntil = math.huge
	bossEntity.Model:SetAttribute("Shielded", true)
	send(run.Members, "Mechanic", { Text = "The Tyrant is shielded! Destroy the Eclipse Crystals!", Color = Color3.fromRGB(255, 200, 80) })
	fx:Play("Aura", { Model = bossEntity.Model, Color = Color3.fromRGB(255, 220, 120), Duration = 60 }, bossEntity.Root.Position)
	local crystals = {}
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local position = run.Origin + Vector3.new(math.cos(angle) * 70, 1, math.sin(angle) * 70)
		local entity = Registry.Get("EnemyService"):Spawn({
			Id = "EclipseCrystal",
			DisplayName = "Eclipse Crystal",
			Level = run.Level,
			Behaviour = "Caster",
			HealthMultiplier = 6 * (1 + (#run.Members - 1) * 0.4),
			DamageMultiplier = 0.5,
			WalkSpeed = 0,
			AggroRange = 60,
			BlockChance = 0,
			DodgeChance = 0,
			Skills = { "Beam" },
			Colors = { Body = Color3.fromRGB(40, 20, 60), Accent = Color3.fromRGB(255, 200, 80) },
			AttackColor = Color3.fromRGB(255, 200, 80),
		}, { Position = position, Tag = run.Id, Folder = run.EnemyFolder, NoRewards = true, LeashRange = 5 })
		if entity then
			table.insert(crystals, entity)
		end
	end
	task.spawn(function()
		while not run.Finished do
			task.wait(0.5)
			local alive = 0
			for _, crystal in ipairs(crystals) do
				if EntityRegistry.IsAlive(crystal) then
					alive += 1
				end
			end
			if alive == 0 then
				break
			end
		end
		if bossEntity.Model.Parent then
			bossEntity.State.IFramesUntil = 0
			bossEntity.Model:SetAttribute("Shielded", false)
			send(run.Members, "Mechanic", { Text = "The shield shatters!", Color = Color3.fromRGB(120, 255, 160) })
			fx:Play(
				"Explosion",
				{ Position = bossEntity.Root.Position, Color = Color3.fromRGB(255, 220, 120), Size = 40 },
				bossEntity.Root.Position
			)
		end
	end)
end

local function eclipseMechanic(run, bossEntity)
	task.spawn(function()
		local fx = Registry.Get("FXService")
		while not run.Finished and bossEntity.Model.Parent and bossEntity.Humanoid.Health > 0 do
			local safeZones = {}
			for _ = 1, math.max(2, math.ceil(#run.Members / 2)) do
				local angle = math.random() * math.pi * 2
				local dist = math.random(20, 70)
				table.insert(safeZones, run.Origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
			end
			send(run.Members, "Mechanic", { Text = "ECLIPSE! Get into the light!", Color = Color3.fromRGB(255, 80, 80), Darkness = 4 })
			for _, zone in ipairs(safeZones) do
				fx:Play("SafeZone", { Position = zone, Radius = 12, Duration = 4.2 }, zone)
			end
			task.wait(4.2)
			for _, player in ipairs(aliveMembers(run)) do
				local entity = EntityRegistry.GetForPlayer(player)
				if entity then
					local safe = false
					for _, zone in ipairs(safeZones) do
						local flat = Vector3.new(entity.Root.Position.X - zone.X, 0, entity.Root.Position.Z - zone.Z)
						if flat.Magnitude <= 13 then
							safe = true
						end
					end
					if not safe then
						Registry.Get("DamageService"):Deal(
							bossEntity,
							entity,
							{
								Base = entity.Humanoid.MaxHealth * 0.7,
								Kind = "Ultimate",
								DamageType = "True",
								Unblockable = true,
								Color = Color3.fromRGB(80, 0, 40),
								AllowDeadAttacker = true,
							}
						)
					end
				end
			end
			fx:Play("ScreenFlash", { Color = Color3.fromRGB(40, 0, 20), Duration = 0.5, Position = run.Origin }, run.Origin)
			task.wait(18)
		end
	end)
end

-- RUN --------------------------------------------------------------------------------------------------

local function finishRun(run, success: boolean)
	if run.Finished then
		return
	end
	run.Finished = true
	send(run.Members, "End", { Type = "Raid", Success = success, Name = run.Def.DisplayName })
	if success then
		local drops = Registry.Get("DropService")
		for _, player in ipairs(run.Members) do
			if player.Parent then
				local rewards = run.Def.Rewards
				drops:GrantRewards(
					player,
					{ Exp = rewards.Exp, Gold = rewards.Gold, Gems = rewards.Gems, Title = rewards.Title },
					"Raid cleared: " .. run.Def.DisplayName
				)
				for _, drop in ipairs(drops:RollTable(rewards.Drops, 0)) do
					drops:GiveItem(player, drop.Id, drop.Amount, run.RaidId, run.Origin)
				end
				Registry.Get("PlayerDataService"):AddCounter(player, "RaidsCleared", 1)
				Registry.Get("QuestService"):OnEvent(player, { Kind = "Raid", Target = run.RaidId })
			end
		end
		Registry.Get("FXService"):Notify(nil, "Server", "⚔ A raid party has defeated the " .. run.Def.DisplayName .. "!")
	end
	task.delay(success and 15 or 5, function()
		for _, player in ipairs(run.Members) do
			playerRun[player] = nil
			local entity = player.Parent and EntityRegistry.GetForPlayer(player)
			if entity then
				entity.Model:SetAttribute("InInstance", nil)
				entity.Model:SetAttribute("CanBeDowned", nil)
				Motion.Teleport(entity, CFrame.new(WorldConfig.RaidGate.Position + Vector3.new(0, 4, -12)))
			end
		end
		run.Model:Destroy()
		usedSlots[run.Slot] = nil
		runs[run.Id] = nil
	end)
end

local function runRaid(run)
	task.wait(3)
	local phaseHandled = {}
	local bossEntity = Registry.Get("BossService"):SpawnBoss(run.Def.Boss, run.Origin + Vector3.new(0, 1, 40), {
		Level = run.Level,
		Tag = run.Id,
		Folder = run.EnemyFolder,
		HealthScale = 1 + (#run.Members - 1) * 0.6,
		Radius = ARENA_RADIUS + 20,
		Arena = run.Origin,
		OnDeath = function()
			finishRun(run, true)
		end,
	})
	if not bossEntity then
		finishRun(run, false)
		return
	end
	local brain = Registry.Get("EnemyService"):GetBrain(bossEntity.Model)
	while not run.Finished do
		task.wait(0.5)
		if brain then
			local phase = run.Def and brain.Def.Phases[brain.Phase]
			if phase and phase.Mechanic and not phaseHandled[brain.Phase] then
				phaseHandled[brain.Phase] = true
				if phase.Mechanic == "Shield" then
					shieldMechanic(run, bossEntity)
				elseif phase.Mechanic == "Eclipse" then
					eclipseMechanic(run, bossEntity)
				end
			end
		end
		if #aliveMembers(run) == 0 then
			task.wait(2)
			if #aliveMembers(run) == 0 then
				Registry.Get("FXService"):Notify(nil, "Error", "The raid party was wiped out...")
				if bossEntity.Model.Parent then
					bossEntity.Model:Destroy()
				end
				finishRun(run, false)
			end
		end
		if os.clock() > run.Deadline then
			finishRun(run, false)
		end
	end
end

function RaidService:StartLobby(lobby)
	lobbies[lobby.Id] = nil
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local def = Raids[lobby.Raid]
	local origin = GameConfig.Raids.InstanceOrigin + Vector3.new(0, 0, (slot - 1) * 600)
	local model, enemyFolder = buildArena(origin, def.Theme)
	local run = {
		Id = lobby.Id,
		RaidId = lobby.Raid,
		Def = def,
		Level = def.Level,
		Members = {},
		Slot = slot,
		Model = model,
		EnemyFolder = enemyFolder,
		Origin = origin,
		Deadline = os.clock() + def.TimeLimit,
		Finished = false,
	}
	for i, player in ipairs(lobby.Members) do
		playerLobby[player] = nil
		local entity = player.Parent and EntityRegistry.GetForPlayer(player)
		if entity then
			table.insert(run.Members, player)
			playerRun[player] = run.Id
			entity.Model:SetAttribute("InInstance", "Raid")
			entity.Model:SetAttribute("CanBeDowned", true)
			local angle = (i / #lobby.Members) * math.pi * 2
			Motion.Teleport(entity, CFrame.new(origin + Vector3.new(math.cos(angle) * 25, 4, -40 + math.sin(angle) * 10)))
		end
	end
	if #run.Members == 0 then
		model:Destroy()
		usedSlots[slot] = nil
		return
	end
	runs[run.Id] = run
	send(run.Members, "Start", { Type = "Raid", Name = def.DisplayName, TimeLimit = def.TimeLimit })
	task.spawn(runRaid, run)
end

function RaidService:GetRespawn(player: Player): CFrame?
	local runId = playerRun[player]
	local run = runId and runs[runId]
	if run and not run.Finished then
		-- Dead raiders spectate from the edge until the fight ends.
		task.defer(function()
			if player.Character then
				player.Character:SetAttribute("InInstance", "Raid")
				player.Character:SetAttribute("CanBeDowned", true)
			end
		end)
		return CFrame.new(run.Origin + Vector3.new(0, 4, -ARENA_RADIUS + 10))
	end
	return nil
end

local function leave(player: Player)
	local lobbyId = playerLobby[player]
	local lobby = lobbyId and lobbies[lobbyId]
	if lobby then
		local index = table.find(lobby.Members, player)
		if index then
			table.remove(lobby.Members, index)
		end
		playerLobby[player] = nil
		stateRemote:FireClient(player, "LobbyClosed", { Type = "Raid" })
		if #lobby.Members == 0 then
			lobbies[lobbyId] = nil
		else
			if lobby.Host == player then
				lobby.Host = lobby.Members[1]
			end
			send(lobby.Members, "Lobby", lobbyPayload(lobby))
		end
	end
end

local function onAction(player: Player, action: any, a: any): (boolean, any)
	if not limiter:Check(player) then
		return false, "Slow down"
	end
	local data = Registry.Get("PlayerDataService"):Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if playerRun[player] then
		return false, "Already in a raid"
	end
	local raidId = WorldConfig.RaidGate.Raid
	local def = Raids[raidId]
	if action == "Create" or action == "Join" then
		if not nearGate(player) then
			return false, "Stand at the raid gate"
		end
		if data.Level < def.LevelRequired then
			return false, "Requires level " .. def.LevelRequired
		end
		leave(player)
		local lobby
		if action == "Join" then
			lobby = Validate.String(a, 64) and lobbies[a]
			if not lobby then
				return false, "Lobby not found"
			end
			if #lobby.Members >= GameConfig.Raids.MaxPlayers then
				return false, "Raid is full"
			end
			table.insert(lobby.Members, player)
		else
			lobby = {
				Id = HttpService:GenerateGUID(false),
				Raid = raidId,
				Host = player,
				Members = { player },
				StartsAt = os.clock() + GameConfig.Raids.LobbyCountdown,
			}
			lobbies[lobby.Id] = lobby
		end
		playerLobby[player] = lobby.Id
		send(lobby.Members, "Lobby", lobbyPayload(lobby))
		return true, lobbyPayload(lobby)
	elseif action == "Leave" then
		leave(player)
		return true
	elseif action == "Start" then
		local lobby = playerLobby[player] and lobbies[playerLobby[player]]
		if not lobby or lobby.Host ~= player then
			return false, "Only the host can start"
		end
		lobby.StartsAt = os.clock()
		return true
	end
	return false, "Unknown action"
end

function RaidService:Init()
	stateRemote = Net.Event("InstanceState")
	Net.Function("RaidAction").OnServerInvoke = onAction
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		local runId = playerRun[player]
		local run = runId and runs[runId]
		if run then
			local index = table.find(run.Members, player)
			if index then
				table.remove(run.Members, index)
			end
		end
		playerRun[player] = nil
	end)
end

function RaidService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	local gates = workspace:WaitForChild("Interactables"):WaitForChild("RaidGates", 30)
	if gates then
		for _, gate in ipairs(gates:GetChildren()) do
			local prompt = gate:FindFirstChild("GatePrompt", true) :: ProximityPrompt?
			if prompt then
				prompt.Triggered:Connect(function(player)
					local list = {}
					for _, lobby in pairs(lobbies) do
						table.insert(list, lobbyPayload(lobby))
					end
					stateRemote:FireClient(player, "OpenGate", { Type = "Raid", Raid = WorldConfig.RaidGate.Raid, Lobbies = list })
				end)
			end
		end
	end
	while true do
		task.wait(1)
		for _, lobby in pairs(lobbies) do
			if os.clock() >= lobby.StartsAt then
				task.spawn(RaidService.StartLobby, RaidService, lobby)
			else
				send(lobby.Members, "Lobby", lobbyPayload(lobby))
			end
		end
		for _, run in pairs(runs) do
			if not run.Finished then
				send(run.Members, "Timer", { Type = "Raid", Remaining = math.max(0, run.Deadline - os.clock()) })
			end
		end
	end
end

return RaidService
