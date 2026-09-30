--[[
	CharacterService (ModuleScript)
	Location: ServerScriptService.Services.CharacterService

	- Spawns characters only after the client pressed PLAY (Players.CharacterAutoLoads = false)
	- Applies stats: Max Health (Level + Defense), Energy (Energy stat), move speed (Agility)
	- Aggregates build modifiers: Trait + Power passive + Equipment + Fighting Style + Transformation
	- Energy regen, out-of-combat health regen, overhead name/level/title
	Remotes: RequestStart (RemoteFunction)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local Progression = require(Modules.Config.Progression)
local Modifiers = require(Modules.Combat.Modifiers)
local FightingStyles = require(Modules.Combat.FightingStyles)
local Traits = require(Modules.Progression.Traits)
local Titles = require(Modules.Progression.Titles)
local ItemUtil = require(Modules.Items.ItemUtil)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local RarityConfig = require(Modules.Config.RarityConfig)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)

local CharacterService = {}
CharacterService.CharacterReady = Signal.new() -- (player, character, entity)
CharacterService.ModifiersChanged = Signal.new() -- (player)

local started: { [Player]: boolean } = {}
local energy: { [Player]: number } = {}
local modifierCache: { [Player]: { [string]: number } } = {}

local REFRESH_KEYS = {
	Stats = true,
	Level = true,
	Trait = true,
	Equipment = true,
	Powers = true,
	FightingStyle = true,
	Titles = true,
	Inventory = false,
}

local function data(player: Player)
	return Registry.Get("PlayerDataService"):Get(player)
end

-- MODIFIERS -------------------------------------------------------------------

function CharacterService:ComputeModifiers(player: Player): { [string]: number }
	local d = data(player)
	if not d then
		return Modifiers.Empty()
	end
	local list = {}
	local trait = Traits.Get(d.Trait)
	if trait then
		table.insert(list, trait.Modifiers)
	end
	local style = FightingStyles[d.FightingStyle]
	if style then
		table.insert(list, style.Modifiers)
	end
	local equippedPower = d.Powers.Owned[d.Powers.EquippedUid]
	if equippedPower then
		local power = PowerRegistry.Get(equippedPower.Id)
		if power and power.Passive then
			table.insert(list, power.Passive.Modifiers)
		end
	end
	for _, slot in ipairs({ "Weapon", "Armor", "Head", "Accessory1", "Accessory2" }) do
		local uid = d.Equipment[slot]
		local item = uid ~= "" and d.Inventory[uid] or nil
		if item then
			local def = ItemUtil.Get(item.Id)
			if def and def.Modifiers then
				table.insert(list, def.Modifiers)
			end
		end
	end
	local character = player.Character
	if character and character:GetAttribute("Transformed") then
		local transformation = Registry.Get("TransformationService"):GetActiveDefinition(player)
		if transformation then
			table.insert(list, transformation.Modifiers)
		end
	end
	return Modifiers.Aggregate(list)
end

function CharacterService:GetModifiers(player: Player): { [string]: number }
	local cached = modifierCache[player]
	if cached then
		return cached
	end
	local mods = self:ComputeModifiers(player)
	modifierCache[player] = mods
	return mods
end

function CharacterService:GetEnergy(player: Player): number
	return energy[player] or 0
end

function CharacterService:GetMaxEnergy(player: Player): number
	local d = data(player)
	if not d then
		return 0
	end
	return Progression.MaxEnergy(d.Stats.Energy, self:GetModifiers(player).MaxEnergy)
end

function CharacterService:SpendEnergy(player: Player, amount: number): boolean
	local current = energy[player] or 0
	if current < amount then
		return false
	end
	energy[player] = current - amount
	local character = player.Character
	if character then
		character:SetAttribute("Energy", math.floor(energy[player]))
	end
	return true
end

function CharacterService:RestoreEnergy(player: Player, amount: number)
	energy[player] = math.min(self:GetMaxEnergy(player), (energy[player] or 0) + amount)
end

-- Applies all derived stats to the humanoid/entity. Call after anything build related changes.
function CharacterService:Refresh(player: Player)
	modifierCache[player] = nil
	local d = data(player)
	local character = player.Character
	if not d or not character then
		return
	end
	local entity = EntityRegistry.Get(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not entity or not humanoid or humanoid.Health <= 0 then
		return
	end
	local mods = self:GetModifiers(player)
	entity.Level = d.Level
	entity.Stats = table.clone(d.Stats)
	entity.Modifiers = mods
	local armorDefense = 0
	for _, slot in ipairs({ "Armor", "Head", "Accessory1", "Accessory2" }) do
		local uid = d.Equipment[slot]
		local item = uid ~= "" and d.Inventory[uid] or nil
		local def = item and ItemUtil.Get(item.Id)
		if def and def.Defense then
			armorDefense += def.Defense
		end
	end
	entity.Defense = d.Stats.Defense * 0.8 + armorDefense + mods.FlatDefense

	local oldMax = humanoid.MaxHealth
	local newMax = Progression.MaxHealth(d.Level, d.Stats.Defense, mods.MaxHealth)
	local ratio = oldMax > 0 and humanoid.Health / oldMax or 1
	humanoid.MaxHealth = newMax
	humanoid.Health = math.clamp(newMax * ratio, 1, newMax)

	local maxEnergy = self:GetMaxEnergy(player)
	energy[player] = math.min(energy[player] or maxEnergy, maxEnergy)
	character:SetAttribute("MaxEnergy", maxEnergy)
	character:SetAttribute("Energy", math.floor(energy[player]))

	local bonusSpeed = Progression.MoveSpeedBonus(d.Stats.Agility) + mods.MoveSpeed
	character:SetAttribute("BaseWalkSpeed", GameConfig.Character.WalkSpeed + bonusSpeed)
	character:SetAttribute("SprintSpeed", GameConfig.Character.SprintSpeed + bonusSpeed)
	character:SetAttribute("DashCooldown", Progression.DashCooldown(d.Stats.Agility) * (1 - mods.DashCooldown))
	character:SetAttribute("Level", d.Level)
	character:SetAttribute("FlightUnlocked", d.Unlocks.Flight == true)
	character:SetAttribute("DoubleJump", d.Unlocks.DoubleJump == true)
	character:SetAttribute("WallRun", d.Unlocks.WallRun == true)
	self:UpdateOverhead(player)
	self.ModifiersChanged:Fire(player)
end

-- OVERHEAD --------------------------------------------------------------------

function CharacterService:UpdateOverhead(player: Player)
	local d = data(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not d or not head then
		return
	end
	local gui = head:FindFirstChild("Overhead") :: BillboardGui?
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Overhead"
		billboard.Size = UDim2.fromOffset(220, 56)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 90
		billboard.LightInfluence = 0
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0.35, 0)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextStrokeTransparency = 0.4
		title.Parent = billboard
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromScale(0, 0.35)
		nameLabel.Size = UDim2.new(1, 0, 0.65, 0)
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Parent = billboard
		billboard.Parent = head
		gui = billboard
	end
	local titleDef = Titles.Get(d.Titles.Equipped)
	local titleLabel = (gui :: BillboardGui):FindFirstChild("Title") :: TextLabel
	local nameLabel = (gui :: BillboardGui):FindFirstChild("PlayerName") :: TextLabel
	nameLabel.Text = string.format("%s  [Lv. %d]", player.DisplayName, d.Level)
	if titleDef then
		titleLabel.Text = "« " .. titleDef.DisplayName .. " »"
		titleLabel.TextColor3 = RarityConfig.GetColor(titleDef.Rarity)
	else
		titleLabel.Text = ""
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- SPAWNING --------------------------------------------------------------------

function CharacterService:GetSpawnCFrame(player: Player): CFrame
	for _, instanceService in ipairs({ "DungeonService", "RaidService" }) do
		if Registry.Has(instanceService) then
			local cf = Registry.Get(instanceService):GetRespawn(player)
			if cf then
				return cf
			end
		end
	end
	local d = data(player)
	local waypoint = d and d.Discovered.LastWaypoint or "GreenwoodVillage"
	local world = Registry.Get("WorldBuilder")
	return world:GetWaypointCFrame(waypoint) or world:GetWaypointCFrame("GreenwoodVillage") or CFrame.new(0, 20, 0)
end

function CharacterService:Spawn(player: Player)
	Registry.Get("WorldBuilder"):WaitUntilBuilt()
	if not player.Parent then
		return
	end
	-- LoadCharacterAsync is the modern API; fall back for older engine versions.
	local ok = pcall(function()
		(player :: any):LoadCharacterAsync()
	end)
	if not ok then
		player:LoadCharacter()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid then
		return
	end
	local d = data(player)
	if not d then
		return
	end
	task.defer(function()
		if character.Parent then
			local spawnCf = CharacterService:GetSpawnCFrame(player)
			if Registry.Has("MovementValidator") then
				Registry.Get("MovementValidator"):AllowTeleport(player)
			end
			character:PivotTo(spawnCf + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
		end
	end)

	humanoid.BreakJointsOnDeath = false
	humanoid.JumpPower = GameConfig.Character.JumpPower
	humanoid.UseJumpPower = true
	local entity = EntityRegistry.Register(character, {
		Player = player,
		Team = "Players",
		Level = d.Level,
		Stats = table.clone(d.Stats),
	})
	energy[player] = nil
	CharacterService:Refresh(player)
	humanoid.Health = humanoid.MaxHealth
	energy[player] = CharacterService:GetMaxEnergy(player)

	humanoid.Died:Connect(function()
		Registry.Get("PlayerDataService"):AddCounter(player, "Deaths", 1)
		EntityRegistry.Unregister(character)
		task.delay(GameConfig.Character.RespawnTime, function()
			if player.Parent and player.Character == character then
				CharacterService:Spawn(player)
			end
		end)
	end)

	CharacterService.CharacterReady:Fire(player, character, entity)
end

function CharacterService:HasStarted(player: Player): boolean
	return started[player] == true
end

function CharacterService:Init()
	Players.CharacterAutoLoads = false

	Net.Function("RequestStart").OnServerInvoke = function(player)
		local dataService = Registry.Get("PlayerDataService")
		local d = dataService:WaitForData(player, 20)
		if not d then
			return false, "Data not loaded"
		end
		if started[player] then
			return true
		end
		started[player] = true
		task.defer(function()
			CharacterService:Spawn(player)
		end)
		return true
	end

	Registry.Get("PlayerDataService").DataChanged:Connect(function(player, key)
		if REFRESH_KEYS[key] then
			CharacterService:Refresh(player)
		end
	end)
end

function CharacterService:Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		started[player] = nil
		energy[player] = nil
		modifierCache[player] = nil
	end)

	-- Single regen loop for all players (energy + out of combat health).
	local TICK = 0.25
	while true do
		task.wait(TICK)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local entity = character and EntityRegistry.Get(character)
			local d = data(player)
			if entity and d and EntityRegistry.IsAlive(entity) then
				local mods = entity.Modifiers
				local maxEnergy = self:GetMaxEnergy(player)
				local regen = Progression.EnergyRegen(d.Stats.Energy) * (1 + (mods.EnergyRegen or 0))
				energy[player] = math.min(maxEnergy, (energy[player] or 0) + regen * TICK)
				character:SetAttribute("Energy", math.floor(energy[player]))

				local inCombat = now - entity.State.LastCombatTime < GameConfig.Character.OutOfCombatRegenDelay
				character:SetAttribute("InCombat", inCombat)
				local humanoid = entity.Humanoid
				if not inCombat and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(
						humanoid.MaxHealth,
						humanoid.Health + humanoid.MaxHealth * GameConfig.Character.OutOfCombatRegenPercent * TICK
					)
				end
			end
		end
	end
end

return CharacterService
