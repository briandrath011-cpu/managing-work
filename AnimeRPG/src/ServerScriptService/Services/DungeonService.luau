--[[
	DungeonService (ModuleScript)
	Location: ServerScriptService.Services.DungeonService

	PHASE 16 - Dungeons for 1-4 players
	Lobby (party at the gate, difficulty select, countdown) -> instanced dungeon built far away
	-> Room 1 waves -> Room 2 elites -> Room 3 miniboss -> Final room boss -> Reward chest.
	Remote: DungeonAction (RemoteFunction)
		("Create", dungeonId, difficulty) ("Join", lobbyId) ("Leave") ("Start") ("SetDifficulty", difficulty)
	        InstanceState (RemoteEvent, server -> client) lobby / room / timer updates
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Dungeons = require(Modules.World.Dungeons)
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local Motion = require(ServerScriptService.ServerModules.Motion)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local DungeonService = {}

local limiter = RateLimiter.new(8, 3)
local lobbies: { [string]: any } = {}
local runs: { [string]: any } = {}
local playerLobby: { [Player]: string } = {}
local playerRun: { [Player]: string } = {}
local usedSlots: { [number]: boolean } = {}
local stateRemote: RemoteEvent

local ROOM_SIZE = 90
local ROOM_GAP = 30

local function send(players: { Player }, kind: string, payload)
	for _, player in ipairs(players) do
		if player.Parent then
			stateRemote:FireClient(player, kind, payload)
		end
	end
end

local function lobbyPayload(lobby)
	local names = {}
	for _, player in ipairs(lobby.Members) do
		table.insert(names, player.DisplayName)
	end
	return {
		Type = "Dungeon",
		LobbyId = lobby.Id,
		Dungeon = lobby.Dungeon,
		Name = Dungeons.List[lobby.Dungeon].DisplayName,
		Difficulty = lobby.Difficulty,
		Members = names,
		Host = lobby.Host.DisplayName,
		Countdown = math.max(0, math.ceil(lobby.StartsAt - os.clock())),
	}
end

local function gatePosition(dungeonId: string): Vector3?
	for _, gate in ipairs(WorldConfig.DungeonGates) do
		if gate.Dungeon == dungeonId then
			return gate.Position
		end
	end
	return nil
end

local function nearGate(player: Player, dungeonId: string): boolean
	local position = gatePosition(dungeonId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return position ~= nil and root ~= nil and (root.Position - position).Magnitude < 30
end

-- INSTANCE GEOMETRY ----------------------------------------------------------------------------------

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildInstance(origin: Vector3, theme, roomCount: number)
	local model = Instance.new("Model")
	model.Name = "DungeonInstance"
	local rooms = {}
	local doors = {}
	-- Lobby platform
	part(model, Vector3.new(40, 2, 40), CFrame.new(origin - Vector3.new(0, 1, 50)), theme.Floor, theme.Material)
	for i = 1, roomCount do
		local center = origin + Vector3.new(0, 0, (i - 1) * (ROOM_SIZE + ROOM_GAP) + ROOM_SIZE / 2)
		part(model, Vector3.new(ROOM_SIZE, 2, ROOM_SIZE), CFrame.new(center - Vector3.new(0, 1, 0)), theme.Floor, theme.Material)
		-- side walls
		part(model, Vector3.new(4, 30, ROOM_SIZE), CFrame.new(center + Vector3.new(-ROOM_SIZE / 2, 15, 0)), theme.Wall, theme.Material)
		part(model, Vector3.new(4, 30, ROOM_SIZE), CFrame.new(center + Vector3.new(ROOM_SIZE / 2, 15, 0)), theme.Wall, theme.Material)
		-- torches
		for _, x in ipairs({ -ROOM_SIZE / 2 + 3, ROOM_SIZE / 2 - 3 }) do
			for _, z in ipairs({ -25, 25 }) do
				local torch =
					part(model, Vector3.new(1.5, 1.5, 1.5), CFrame.new(center + Vector3.new(x, 10, z)), theme.Accent, Enum.Material.Neon)
				local light = Instance.new("PointLight")
				light.Color = theme.Accent
				light.Range = 26
				light.Brightness = 1.5
				light.Parent = torch
			end
		end
		-- corridor to the next room + door
		if i < roomCount then
			local corridorCenter = center + Vector3.new(0, 0, ROOM_SIZE / 2 + ROOM_GAP / 2)
			part(model, Vector3.new(20, 2, ROOM_GAP), CFrame.new(corridorCenter - Vector3.new(0, 1, 0)), theme.Floor, theme.Material)
			local door = part(
				model,
				Vector3.new(20, 20, 2),
				CFrame.new(center + Vector3.new(0, 10, ROOM_SIZE / 2)),
				theme.Accent,
				Enum.Material.ForceField,
				0.3
			)
			doors[i] = door
		else
			part(model, Vector3.new(ROOM_SIZE, 30, 4), CFrame.new(center + Vector3.new(0, 15, ROOM_SIZE / 2)), theme.Wall, theme.Material)
		end
		rooms[i] = center
	end
	-- Entrance wall behind lobby
	part(model, Vector3.new(40, 30, 4), CFrame.new(origin + Vector3.new(0, 15, -70)), theme.Wall, theme.Material)
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = model
	model.Parent = workspace:FindFirstChild("Map") or workspace
	return model, rooms, doors, folder
end

-- RUN LOGIC ---------------------------------------------------------------------------------------

local function alivePlayers(run): { Player }
	local list = {}
	for _, player in ipairs(run.Members) do
		local entity = player.Parent and EntityRegistry.GetForPlayer(player)
		if entity and EntityRegistry.IsAlive(entity) then
			table.insert(list, player)
		end
	end
	return list
end

local function teleportMembers(run, position: Vector3)
	for i, player in ipairs(run.Members) do
		local entity = player.Parent and EntityRegistry.GetForPlayer(player)
		if entity then
			Motion.Teleport(entity, CFrame.new(position + Vector3.new((i - 2.5) * 5, 4, 0)))
		end
	end
end

local function finishRun(run, success: boolean)
	if run.Finished then
		return
	end
	run.Finished = true
	send(run.Members, "End", { Type = "Dungeon", Success = success, Name = run.Def.DisplayName })
	if not success then
		Registry.Get("FXService"):Notify(nil, "Error", "Dungeon failed...")
	end
	task.delay(success and 20 or 4, function()
		local gate = gatePosition(run.Dungeon) or Vector3.new(0, 5, 0)
		for _, player in ipairs(run.Members) do
			playerRun[player] = nil
			local character = player.Character
			if character then
				character:SetAttribute("InInstance", nil)
				local entity = EntityRegistry.GetForPlayer(player)
				if entity then
					Motion.Teleport(entity, CFrame.new(gate + Vector3.new(0, 4, -12)))
				end
			end
		end
		if run.Model then
			run.Model:Destroy()
		end
		usedSlots[run.Slot] = nil
		runs[run.Id] = nil
	end)
end

local function waitForClear(run, folder: Folder, tag: string): boolean
	while not run.Finished do
		task.wait(0.5)
		local remaining = 0
		for _, model in ipairs(folder:GetChildren()) do
			local entity = EntityRegistry.Get(model)
			if entity and EntityRegistry.IsAlive(entity) and model:GetAttribute("Tag") == tag then
				remaining += 1
			end
		end
		if remaining == 0 then
			return true
		end
		if #alivePlayers(run) == 0 then
			-- Everyone is down: give them the respawn window, then fail.
			task.wait(Registry.Has("CharacterService") and GameConfig.Character.RespawnTime + 1.5 or 5)
			if #alivePlayers(run) == 0 then
				finishRun(run, false)
				return false
			end
		end
		if os.clock() > run.Deadline then
			finishRun(run, false)
			return false
		end
	end
	return false
end

local function spawnRoom(run, index: number, room)
	local center = run.Rooms[index]
	local tag = run.Id .. "_R" .. index
	local difficulty = Dungeons.Difficulties[run.Difficulty]
	local level = run.Def.BaseLevel + difficulty.LevelBonus
	local partyScale = 1 + (#run.Members - 1) * 0.35
	if room.Kind == "Boss" then
		Registry.Get("BossService"):SpawnBoss(room.Boss, center + Vector3.new(0, 1, 20), {
			Level = level + 3,
			Tag = tag,
			Folder = run.EnemyFolder,
			HealthScale = difficulty.Health * partyScale,
			DamageScale = difficulty.Damage,
			Radius = ROOM_SIZE,
			Arena = center,
		})
		return tag
	end
	for wave = 1, room.Waves or 1 do
		for i = 1, room.Count do
			local enemyId = room.Enemies[((i - 1) % #room.Enemies) + 1]
			local offset = Vector3.new(math.random(-30, 30), 1, math.random(0, 35))
			Registry.Get("EnemyService"):Spawn(enemyId, {
				Position = center + offset,
				Level = level + (room.Kind == "Elite" and 3 or 0),
				Tag = tag,
				Folder = run.EnemyFolder,
				HealthScale = (room.HealthScale or 1) * difficulty.Health * partyScale,
				DamageScale = difficulty.Damage,
				LeashRange = ROOM_SIZE * 1.5,
			})
		end
		if wave < (room.Waves or 1) then
			if not waitForClear(run, run.EnemyFolder, tag) then
				return nil
			end
			send(run.Members, "Room", { Type = "Dungeon", Room = index, Wave = wave + 1, Text = "Wave " .. (wave + 1) })
		end
	end
	return tag
end

local function spawnRewardChest(run, position: Vector3)
	local chest = Instance.new("Part")
	chest.Name = "RewardChest"
	chest.Anchored = true
	chest.Size = Vector3.new(6, 4, 4)
	chest.Color = Color3.fromRGB(255, 200, 60)
	chest.Material = Enum.Material.Neon
	chest.Position = position + Vector3.new(0, 2, 0)
	chest.Parent = run.Model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim Rewards"
	prompt.ObjectText = run.Def.DisplayName
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = chest
	local claimed = {}
	prompt.Triggered:Connect(function(player)
		if claimed[player] or not table.find(run.Members, player) then
			return
		end
		claimed[player] = true
		local difficulty = Dungeons.Difficulties[run.Difficulty]
		local rewards = run.Def.Rewards
		local drops = Registry.Get("DropService")
		drops:GrantRewards(player, {
			Exp = math.floor(rewards.Exp * difficulty.Rewards),
			Gold = math.floor(rewards.Gold * difficulty.Rewards),
			Gems = math.floor(rewards.Gems * difficulty.Rewards),
		}, "Dungeon cleared: " .. run.Def.DisplayName)
		for _, drop in ipairs(drops:RollTable(rewards.Drops, difficulty.Rewards - 1)) do
			drops:GiveItem(player, drop.Id, drop.Amount, run.Dungeon, chest.Position)
		end
		Registry.Get("PlayerDataService"):AddCounter(player, "DungeonsCleared", 1)
		Registry.Get("QuestService"):OnEvent(player, { Kind = "Dungeon", Target = run.Dungeon })
	end)
	Registry.Get("FXService"):Play("ChestOpen", { Position = chest.Position, Tier = 4 }, chest.Position)
end

local function runDungeon(run)
	local rooms = run.Def.Rooms
	for index, room in ipairs(rooms) do
		if run.Finished then
			return
		end
		run.Checkpoint = run.Rooms[index] - Vector3.new(0, 0, ROOM_SIZE / 2 - 8)
		send(run.Members, "Room", {
			Type = "Dungeon",
			Room = index,
			Total = #rooms,
			Kind = room.Kind,
			Text = room.Kind == "Boss" and "FINAL ROOM" or ("Room " .. index),
			Deadline = run.Deadline - os.clock(),
		})
		task.wait(1.5)
		local tag = spawnRoom(run, index, room)
		if not tag or not waitForClear(run, run.EnemyFolder, tag) then
			return
		end
		local door = run.Doors[index]
		if door then
			door:Destroy()
			Registry.Get("FXService")
				:Play("Shockwave", { Position = door.Position, Color = run.Def.Theme.Accent, Size = 24 }, door.Position)
		end
	end
	spawnRewardChest(run, run.Rooms[#rooms])
	finishRun(run, true)
end

function DungeonService:StartLobby(lobby)
	lobbies[lobby.Id] = nil
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local def = Dungeons.List[lobby.Dungeon]
	local origin = GameConfig.Dungeons.InstanceOrigin + Vector3.new(0, 0, (slot - 1) * GameConfig.Dungeons.RoomOriginSpacing)
	local model, rooms, doors, enemyFolder = buildInstance(origin, def.Theme, #def.Rooms)
	local run = {
		Id = lobby.Id,
		Dungeon = lobby.Dungeon,
		Def = def,
		Difficulty = lobby.Difficulty,
		Members = {},
		Slot = slot,
		Model = model,
		Rooms = rooms,
		Doors = doors,
		EnemyFolder = enemyFolder,
		Deadline = os.clock() + def.TimeLimit,
		Checkpoint = origin - Vector3.new(0, 0, 50),
		Finished = false,
	}
	for _, player in ipairs(lobby.Members) do
		playerLobby[player] = nil
		if player.Parent then
			table.insert(run.Members, player)
			playerRun[player] = run.Id
			if player.Character then
				player.Character:SetAttribute("InInstance", "Dungeon")
			end
		end
	end
	if #run.Members == 0 then
		model:Destroy()
		usedSlots[slot] = nil
		return
	end
	runs[run.Id] = run
	teleportMembers(run, origin - Vector3.new(0, 0, 50))
	send(run.Members, "Start", { Type = "Dungeon", Name = def.DisplayName, Difficulty = run.Difficulty, TimeLimit = def.TimeLimit })
	task.spawn(runDungeon, run)
end

-- Respawn point for players who die inside a dungeon (used by CharacterService).
function DungeonService:GetRespawn(player: Player): CFrame?
	local runId = playerRun[player]
	local run = runId and runs[runId]
	if run and not run.Finished then
		task.defer(function()
			if player.Character then
				player.Character:SetAttribute("InInstance", "Dungeon")
			end
		end)
		return CFrame.new(run.Checkpoint + Vector3.new(0, 4, 0))
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
		stateRemote:FireClient(player, "LobbyClosed", { Type = "Dungeon" })
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

local function onAction(player: Player, action: any, a: any, b: any): (boolean, any)
	if not limiter:Check(player) then
		return false, "Slow down"
	end
	local data = Registry.Get("PlayerDataService"):Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if playerRun[player] then
		return false, "You're already in a dungeon"
	end
	if action == "Create" then
		local def = Validate.String(a, 40) and Dungeons.List[a]
		if not def then
			return false, "Unknown dungeon"
		end
		if not nearGate(player, a) then
			return false, "Stand at the dungeon gate"
		end
		if data.Level < def.LevelRequired then
			return false, "Requires level " .. def.LevelRequired
		end
		local difficulty = Dungeons.Difficulties[b] and b or "Normal"
		leave(player)
		local lobby = {
			Id = HttpService:GenerateGUID(false),
			Dungeon = a,
			Difficulty = difficulty,
			Host = player,
			Members = { player },
			StartsAt = os.clock() + GameConfig.Dungeons.LobbyCountdown,
		}
		lobbies[lobby.Id] = lobby
		playerLobby[player] = lobby.Id
		send(lobby.Members, "Lobby", lobbyPayload(lobby))
		return true, lobbyPayload(lobby)
	elseif action == "Join" then
		local lobby = Validate.String(a, 64) and lobbies[a]
		if not lobby then
			return false, "Lobby not found"
		end
		local def = Dungeons.List[lobby.Dungeon]
		if #lobby.Members >= GameConfig.Dungeons.MaxPlayers then
			return false, "Lobby is full"
		end
		if not nearGate(player, lobby.Dungeon) then
			return false, "Stand at the dungeon gate"
		end
		if data.Level < def.LevelRequired then
			return false, "Requires level " .. def.LevelRequired
		end
		leave(player)
		table.insert(lobby.Members, player)
		playerLobby[player] = lobby.Id
		send(lobby.Members, "Lobby", lobbyPayload(lobby))
		return true, lobbyPayload(lobby)
	elseif action == "Leave" then
		leave(player)
		return true
	elseif action == "Start" or action == "SetDifficulty" then
		local lobby = playerLobby[player] and lobbies[playerLobby[player]]
		if not lobby or lobby.Host ~= player then
			return false, "Only the host can do that"
		end
		if action == "Start" then
			lobby.StartsAt = os.clock()
		elseif Dungeons.Difficulties[a] then
			lobby.Difficulty = a
			send(lobby.Members, "Lobby", lobbyPayload(lobby))
		end
		return true
	elseif action == "List" then
		-- Open lobbies for a gate (so players can join).
		local list = {}
		for _, lobby in pairs(lobbies) do
			if lobby.Dungeon == a then
				table.insert(list, lobbyPayload(lobby))
			end
		end
		return true, list
	end
	return false, "Unknown action"
end

function DungeonService:Init()
	stateRemote = Net.Event("InstanceState")
	Net.Function("DungeonAction").OnServerInvoke = onAction
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		local runId = playerRun[player]
		local run = runId and runs[runId]
		if run then
			local index = table.find(run.Members, player)
			if index then
				table.remove(run.Members, index)
			end
			if #run.Members == 0 then
				finishRun(run, false)
			end
		end
		playerRun[player] = nil
	end)
end

function DungeonService:Start()
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	-- Gate prompts open the dungeon UI on the client.
	local gates = workspace:WaitForChild("Interactables"):WaitForChild("DungeonGates", 30)
	if gates then
		for _, gate in ipairs(gates:GetChildren()) do
			local prompt = gate:FindFirstChild("GatePrompt", true) :: ProximityPrompt?
			local dungeonId = gate:GetAttribute("DungeonId")
			if prompt and dungeonId then
				prompt.Triggered:Connect(function(player)
					local list = {}
					for _, lobby in pairs(lobbies) do
						if lobby.Dungeon == dungeonId then
							table.insert(list, lobbyPayload(lobby))
						end
					end
					stateRemote:FireClient(player, "OpenGate", { Type = "Dungeon", Dungeon = dungeonId, Lobbies = list })
				end)
			end
		end
	end
	-- Lobby countdown loop
	while true do
		task.wait(1)
		for _, lobby in pairs(lobbies) do
			if os.clock() >= lobby.StartsAt then
				task.spawn(DungeonService.StartLobby, DungeonService, lobby)
			else
				send(lobby.Members, "Lobby", lobbyPayload(lobby))
			end
		end
		for _, run in pairs(runs) do
			if not run.Finished then
				send(run.Members, "Timer", { Type = "Dungeon", Remaining = math.max(0, run.Deadline - os.clock()) })
			end
		end
	end
end

return DungeonService
