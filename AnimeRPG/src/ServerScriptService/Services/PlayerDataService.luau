--[[
	PlayerDataService (ModuleScript)
	Location: ServerScriptService.Services.PlayerDataService

	PHASE 1 - Player Data + Level + EXP + Stats
	- DataStoreService with session locking (prevents item duplication across servers)
	- Retries with backoff, autosave, BindToClose, reconcile old saves with DataTemplate
	- Replicates data to the owning client through the "DataSync" RemoteEvent
	- Level/EXP/Stat Points logic (server only). Client may only REQUEST stat allocation.

	Remotes used: DataSync (RemoteEvent), StatAction (RemoteFunction)
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local DataTemplate = require(Modules.Config.DataTemplate)
local Progression = require(Modules.Config.Progression)
local TableUtil = require(Modules.Shared.TableUtil)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local PlayerDataService = {}

PlayerDataService.ProfileLoaded = Signal.new() -- (player, data)
PlayerDataService.DataChanged = Signal.new() -- (player, key, value)
PlayerDataService.LevelUp = Signal.new() -- (player, newLevel, levelsGained)
PlayerDataService.CounterChanged = Signal.new() -- (player, counterName, newValue)

type Profile = {
	Data: { [string]: any },
	Key: string,
	Loaded: boolean,
	LastSave: number,
	Releasing: boolean,
}

local profiles: { [Player]: Profile } = {}
local memoryStore: { [string]: any } = {} -- Studio fallback
local store: DataStore? = nil
local useMemory = false
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local statLimiter = RateLimiter.new(20, 10)

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function retry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local lastErr
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[PlayerData] Attempt %d/%d failed: %s", attempt, attempts, tostring(result)))
		task.wait(math.min(2 ^ attempt, 16))
	end
	return false, tostring(lastErr)
end

-- Removes data that should never be saved (e.g. functions) and strips the lock wrapper.
local function sanitize(data: { [string]: any }): { [string]: any }
	local copy = TableUtil.DeepCopy(data)
	copy.__Lock = nil
	return copy
end

local function repairData(data: { [string]: any })
	-- Clamp values to legal ranges in case of corrupted saves or old bugs.
	data.Level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, GameConfig.Progression.MaxLevel)
	data.Exp = math.max(0, math.floor(tonumber(data.Exp) or 0))
	data.Gold = math.max(0, math.floor(tonumber(data.Gold) or 0))
	data.Gems = math.max(0, math.floor(tonumber(data.Gems) or 0))
	data.Spins = math.max(0, math.floor(tonumber(data.Spins) or 0))
	local spent = 0
	for _, stat in ipairs(GameConfig.Stats) do
		data.Stats[stat] = math.clamp(math.floor(tonumber(data.Stats[stat]) or 0), 0, GameConfig.Progression.MaxStatPerAttribute)
		spent += data.Stats[stat]
	end
	local total = Progression.TotalStatPoints(data.Level)
	if spent > total then
		-- Illegal stat distribution: refund everything.
		for _, stat in ipairs(GameConfig.Stats) do
			data.Stats[stat] = 0
		end
		spent = 0
	end
	data.StatPoints = total - spent
end

local function loadData(player: Player): (boolean, { [string]: any }?)
	local key = keyFor(player)
	if useMemory then
		local existing = memoryStore[key]
		local data = existing and TableUtil.DeepCopy(existing) or TableUtil.DeepCopy(DataTemplate)
		return true, data
	end

	local loaded: { [string]: any }? = nil
	local lockedElsewhere = false
	for attempt = 1, GameConfig.Data.MaxLoadRetries do
		lockedElsewhere = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				old = old or TableUtil.DeepCopy(DataTemplate)
				local lock = old.__Lock
				local now = os.time()
				if lock and lock.JobId ~= jobId and now - (lock.Time or 0) < GameConfig.Data.SessionLockTimeout then
					lockedElsewhere = true
					return nil -- cancel write
				end
				old.__Lock = { JobId = jobId, Time = now }
				loaded = old
				return old
			end)
		end)
		if ok and loaded then
			break
		end
		if not ok then
			warn("[PlayerData] Load error:", err)
		end
		if lockedElsewhere and attempt == GameConfig.Data.MaxLoadRetries - 1 then
			-- Last try: the other server is probably dead. Steal the lock.
			warn("[PlayerData] Session lock held by another server, forcing takeover for", player.Name)
			local okSteal = pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old)
					old = old or TableUtil.DeepCopy(DataTemplate)
					old.__Lock = { JobId = jobId, Time = os.time() }
					loaded = old
					return old
				end)
			end)
			if okSteal and loaded then
				break
			end
		end
		task.wait(math.min(2 ^ attempt, 10))
	end
	if not loaded then
		return false, nil
	end
	return true, sanitize(loaded :: any)
end

local function saveData(player: Player, profile: Profile, release: boolean): boolean
	local snapshot = sanitize(profile.Data)
	if useMemory then
		memoryStore[profile.Key] = snapshot
		profile.LastSave = os.clock()
		return true
	end
	local ok = retry(GameConfig.Data.MaxSaveRetries, function()
		(store :: DataStore):UpdateAsync(profile.Key, function(old)
			if old and old.__Lock and old.__Lock.JobId ~= jobId then
				-- Another server took over this profile; never overwrite its data.
				warn("[PlayerData] Save skipped, lock owned by another server:", player.Name)
				return nil
			end
			local toWrite = TableUtil.DeepCopy(snapshot)
			if not release then
				toWrite.__Lock = { JobId = jobId, Time = os.time() }
			end
			return toWrite
		end)
		return true
	end)
	if ok then
		profile.LastSave = os.clock()
	end
	return ok
end

local function setupLeaderstats(player: Player, data: { [string]: any })
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.Level
	level.Parent = stats
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = data.Gold
	gold.Parent = stats
	stats.Parent = player
end

local function updateLeaderstats(player: Player, key: string, value: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local object = stats:FindFirstChild(key)
	if object and type(value) == "number" then
		(object :: IntValue).Value = value
	end
end

-- PUBLIC API ------------------------------------------------------------------

function PlayerDataService:Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	if profile and profile.Loaded then
		return profile.Data
	end
	return nil
end

function PlayerDataService:WaitForData(player: Player, timeout: number?): { [string]: any }?
	local start = os.clock()
	while player.Parent and os.clock() - start < (timeout or 30) do
		local data = self:Get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

-- Sends the current value of a top-level key to the owning client.
function PlayerDataService:Replicate(player: Player, key: string)
	local data = self:Get(player)
	if not data then
		return
	end
	Net.Event("DataSync"):FireClient(player, "Set", key, data[key])
	updateLeaderstats(player, key, data[key])
	self.DataChanged:Fire(player, key, data[key])
end

function PlayerDataService:Set(player: Player, key: string, value: any)
	local data = self:Get(player)
	if not data then
		return
	end
	data[key] = value
	self:Replicate(player, key)
end

-- Mutate a (usually nested) key with a callback, then replicate it once.
function PlayerDataService:Update(player: Player, key: string, fn: (any) -> any?)
	local data = self:Get(player)
	if not data then
		return
	end
	local result = fn(data[key])
	if result ~= nil then
		data[key] = result
	end
	self:Replicate(player, key)
end

function PlayerDataService:AddCurrency(player: Player, currency: string, amount: number): boolean
	assert(currency == "Gold" or currency == "Gems" or currency == "Spins" or currency == "TraitRolls", "bad currency")
	local data = self:Get(player)
	if not data then
		return false
	end
	amount = math.floor(amount)
	if data[currency] + amount < 0 then
		return false
	end
	data[currency] += amount
	self:Replicate(player, currency)
	return true
end

function PlayerDataService:SpendCurrency(player: Player, currency: string, amount: number): boolean
	if amount < 0 then
		return false
	end
	return self:AddCurrency(player, currency, -amount)
end

function PlayerDataService:AddCounter(player: Player, counter: string, amount: number?)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Counters[counter] = (data.Counters[counter] or 0) + (amount or 1)
	self:Replicate(player, "Counters")
	self.CounterChanged:Fire(player, counter, data.Counters[counter])
end

-- Adds exp (already multiplied by bonuses by the caller) and handles level ups.
function PlayerDataService:AddExp(player: Player, amount: number)
	local data = self:Get(player)
	if not data or amount <= 0 then
		return
	end
	local oldLevel = data.Level
	local level, exp, gained = Progression.ApplyExp(data.Level, data.Exp, amount)
	data.Level = level
	data.Exp = exp
	if gained > 0 then
		data.StatPoints += gained * GameConfig.Progression.StatPointsPerLevel
		local spinsEarned = 0
		local gemsEarned = 0
		for lvl = oldLevel + 1, level do
			if lvl % GameConfig.Progression.SpinEveryNLevels == 0 then
				spinsEarned += 1
			end
			if lvl % 10 == 0 then
				gemsEarned += GameConfig.Progression.GemsPerLevelMilestone
			end
		end
		data.Spins += spinsEarned
		data.Gems += gemsEarned
		self:Replicate(player, "StatPoints")
		self:Replicate(player, "Spins")
		self:Replicate(player, "Gems")
		self:Replicate(player, "Level")
		local notify =
			string.format("LEVEL UP! You are now level %d (+%d stat points)", level, gained * GameConfig.Progression.StatPointsPerLevel)
		if spinsEarned > 0 then
			notify ..= string.format(" +%d Spin", spinsEarned)
		end
		Net.Event("Notify"):FireClient(player, "LevelUp", notify, { Level = level })
		if Registry.Has("FXService") and player.Character then
			Registry.Get("FXService"):Play("LevelUp", { Model = player.Character }, player.Character:GetPivot().Position)
		end
		self.LevelUp:Fire(player, level, gained)
	end
	self:Replicate(player, "Exp")
end

function PlayerDataService:AllocateStat(player: Player, stat: string, amount: number): (boolean, string?)
	local data = self:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if not table.find(GameConfig.Stats, stat) then
		return false, "Unknown stat"
	end
	amount = math.floor(amount)
	if amount < 1 or amount > data.StatPoints then
		return false, "Not enough stat points"
	end
	local maxStat = GameConfig.Progression.MaxStatPerAttribute
	amount = math.min(amount, maxStat - data.Stats[stat])
	if amount <= 0 then
		return false, "Stat is maxed"
	end
	data.Stats[stat] += amount
	data.StatPoints -= amount
	self:Replicate(player, "Stats")
	self:Replicate(player, "StatPoints")
	return true
end

function PlayerDataService:ResetStats(player: Player): (boolean, string?)
	local data = self:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local cost = 100
	if data.Gems < cost then
		return false, "Stat reset costs " .. cost .. " Gems"
	end
	data.Gems -= cost
	for _, stat in ipairs(GameConfig.Stats) do
		data.Stats[stat] = 0
	end
	data.StatPoints = Progression.TotalStatPoints(data.Level)
	self:Replicate(player, "Gems")
	self:Replicate(player, "Stats")
	self:Replicate(player, "StatPoints")
	return true
end

function PlayerDataService:SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return false
	end
	return saveData(player, profile, false)
end

function PlayerDataService:IsMemoryMode(): boolean
	return useMemory
end

-- LIFECYCLE ---------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local ok, data = loadData(player)
	if not player.Parent then
		return
	end
	if not ok or not data then
		player:Kick("Your data could not be loaded. Please rejoin in a moment (your progress is safe).")
		return
	end
	TableUtil.Reconcile(data, DataTemplate)
	repairData(data)
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
	data.LastLogin = os.time()

	local profile: Profile = {
		Data = data,
		Key = keyFor(player),
		Loaded = true,
		LastSave = os.clock(),
		Releasing = false,
	}
	profiles[player] = profile
	setupLeaderstats(player, data)
	Net.Event("DataSync"):FireClient(player, "Full", data)
	PlayerDataService.ProfileLoaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile or profile.Releasing then
		return
	end
	profile.Releasing = true
	if profile.Loaded then
		saveData(player, profile, true)
	end
	profiles[player] = nil
end

function PlayerDataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok then
		store = result
		-- Probe: Studio without "Enable Studio Access to API Services" throws here.
		local probeOk, probeErr = pcall(function()
			return (store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			if RunService:IsStudio() and GameConfig.Data.AllowMemoryFallbackInStudio then
				warn(
					"[PlayerData] DataStore unavailable in Studio ("
						.. tostring(probeErr)
						.. "). Using MEMORY mode - nothing will persist. Enable Game Settings > Security > Studio Access to API Services."
				)
				useMemory = true
			else
				warn("[PlayerData] DataStore probe failed: " .. tostring(probeErr))
			end
		end
	else
		warn("[PlayerData] DataStore unavailable: " .. tostring(result))
		useMemory = RunService:IsStudio()
	end

	Net.Function("StatAction").OnServerInvoke = function(player, action, stat, amount)
		if not statLimiter:Check(player) then
			return false, "Slow down"
		end
		if action == "Allocate" then
			if not Validate.String(stat, 16) or not Validate.Integer(amount, 1, 1000) then
				return false, "Invalid request"
			end
			return self:AllocateStat(player, stat, amount)
		elseif action == "Reset" then
			return self:ResetStats(player)
		end
		return false, "Unknown action"
	end

	-- Fallback full sync if the client missed the initial "Full" DataSync event.
	Net.Function("GetData").OnServerInvoke = function(player)
		if not statLimiter:Check(player) then
			return false, "Slow down"
		end
		local data = self:WaitForData(player, 20)
		if not data then
			return false, "Data not loaded"
		end
		return true, data
	end

	-- Titles, settings and transformation choice (small profile changes).
	local profileLimiter = RateLimiter.new(15, 5)
	local SETTING_RULES = {
		Quality = function(v)
			return v == "Auto" or v == "Low" or v == "Medium" or v == "High"
		end,
		MusicVolume = function(v)
			return Validate.Number(v, 0, 1)
		end,
		SfxVolume = function(v)
			return Validate.Number(v, 0, 1)
		end,
		CameraShake = Validate.Boolean,
		DamageNumbers = Validate.Boolean,
		AutoDeleteCommon = Validate.Boolean,
		AutoDeleteRare = Validate.Boolean,
		SkipSpinAnimation = Validate.Boolean,
	}
	Net.Function("ProfileAction").OnServerInvoke = function(player, action, a, b)
		if not profileLimiter:Check(player) then
			return false, "Slow down"
		end
		local data = self:Get(player)
		if not data then
			return false, "Data not loaded"
		end
		if action == "EquipTitle" then
			if a ~= "" and not (Validate.String(a, 40) and data.Titles.Owned[a]) then
				return false, "Title not owned"
			end
			data.Titles.Equipped = a
			self:Replicate(player, "Titles")
			return true
		elseif action == "SetSetting" then
			local rule = Validate.String(a, 32) and SETTING_RULES[a]
			if not rule or not rule(b) then
				return false, "Invalid setting"
			end
			data.Settings[a] = b
			self:Replicate(player, "Settings")
			return true
		elseif action == "EquipTransformation" then
			if not Validate.String(a, 40) then
				return false, "Invalid"
			end
			return Registry.Get("TransformationService"):Equip(player, a)
		end
		return false, "Unknown action"
	end
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop (one loop for all players).
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player, profile in pairs(profiles) do
				if profile.Loaded and not profile.Releasing then
					profile.Data.Counters.PlayTime += GameConfig.Data.AutosaveInterval
					task.spawn(saveData, player, profile, false)
					task.wait(0.5) -- spread requests to respect DataStore budgets
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in pairs(profiles) do
			if profile.Loaded and not profile.Releasing then
				pending += 1
				profile.Releasing = true
				task.spawn(function()
					saveData(player, profile, true)
					pending -= 1
				end)
			end
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
