--[[
	SpinService (ModuleScript)
	Location: ServerScriptService.Services.SpinService

	PHASE 7 - Power Spins. 100% server-side RNG + pity (client only plays the animation).
	Remote: Spin (RemoteFunction) (count 1|10, payWithGems: bool) -> ok, { results, pity }
	Each result: { Uid, PowerId, Rarity, Converted (auto-deleted to gold), PityHit }
	Mythic / Secret pulls are announced to the whole server.
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local RarityConfig = require(Modules.Config.RarityConfig)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local SpinLogic = require(Modules.Powers.SpinLogic)
local TableUtil = require(Modules.Shared.TableUtil)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)

local SpinService = {}
SpinService.PowerObtained = Signal.new() -- (player, powerId, rarity)

local rng = Random.new()
local limiter = RateLimiter.new(3, 1)
local busy: { [Player]: boolean } = {}

local function dataService()
	return Registry.Get("PlayerDataService")
end

function SpinService:DoSpins(player: Player, count: number, payWithGems: boolean): (boolean, any)
	local data = dataService():Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if count ~= 1 and count ~= 10 then
		return false, "Invalid spin count"
	end
	local powers = data.Powers
	local free = powers.StorageSlots - TableUtil.Count(powers.Owned)
	local settings = data.Settings
	-- Need space unless low rarities are auto-converted (worst case every spin is kept).
	if free < count and not (settings.AutoDeleteCommon and free >= 0) then
		return false,
			string.format(
				"Power storage full (%d/%d). Delete powers or upgrade storage.",
				TableUtil.Count(powers.Owned),
				powers.StorageSlots
			)
	end

	-- Payment
	if payWithGems then
		local cost = count == 10 and GameConfig.Spins.TenSpinGemCost or GameConfig.Spins.SpinGemCost
		if not dataService():SpendCurrency(player, "Gems", cost) then
			return false, "Not enough Gems (" .. cost .. ")"
		end
	else
		if data.Spins < count then
			return false, "Not enough spins"
		end
		data.Spins -= count
	end

	local results = {}
	local goldGained = 0
	for _ = 1, count do
		local rarity, pityHit = SpinLogic.RollRarity(rng, data.Pity)
		local power, actualRarity = SpinLogic.PickPower(rng, rarity, PowerRegistry.ByRarity)
		data.Pity = SpinLogic.UpdatePity(data.Pity, actualRarity)
		if power then
			local converted = (actualRarity == "Common" and settings.AutoDeleteCommon)
				or (actualRarity == "Rare" and settings.AutoDeleteRare)
			local stillFree = powers.StorageSlots - TableUtil.Count(powers.Owned)
			if not converted and stillFree <= 0 then
				converted = true -- safety: never exceed storage
			end
			local uid = ""
			if converted then
				goldGained += GameConfig.Spins.GoldConversion[actualRarity] or 0
			else
				uid = (HttpService:GenerateGUID(false):gsub("-", "")):sub(1, 14)
				powers.Owned[uid] = { Id = power.Id, Locked = RarityConfig.IsAtLeast(actualRarity, "Legendary"), Obtained = os.time() }
				if powers.EquippedUid == "" then
					powers.EquippedUid = uid
				end
			end
			table.insert(results, { Uid = uid, PowerId = power.Id, Rarity = actualRarity, Converted = converted, PityHit = pityHit })
			self.PowerObtained:Fire(player, power.Id, actualRarity)
			if RarityConfig.IsAtLeast(actualRarity, "Mythic") then
				local text =
					string.format("✦ %s obtained the %s power %s! ✦", player.DisplayName, string.upper(actualRarity), power.DisplayName)
				Registry.Get("FXService"):Notify(nil, "Server", text, { Color = RarityConfig.GetColor(actualRarity) })
				Net.Event("SpinReveal"):FireAllClients(player.UserId, power.Id, actualRarity)
			end
		end
	end
	if goldGained > 0 then
		data.Gold += goldGained
		dataService():Replicate(player, "Gold")
	end
	data.Counters.SpinsUsed += count
	dataService():Replicate(player, "Spins")
	dataService():Replicate(player, "Pity")
	dataService():Replicate(player, "Powers")
	dataService():Replicate(player, "Counters")
	dataService().CounterChanged:Fire(player, "SpinsUsed", data.Counters.SpinsUsed)
	return true, { Results = results, Pity = data.Pity, Gold = goldGained }
end

function SpinService:Init()
	Net.Function("Spin").OnServerInvoke = function(player, count, payWithGems)
		if not limiter:Check(player) then
			return false, "Slow down"
		end
		if busy[player] then
			return false, "Spin in progress"
		end
		busy[player] = true
		local ok, result = pcall(function()
			return table.pack(SpinService:DoSpins(player, count, payWithGems == true))
		end)
		busy[player] = nil
		if not ok then
			warn("[SpinService] " .. tostring(result))
			return false, "Spin failed"
		end
		return result[1], result[2]
	end
end

return SpinService
