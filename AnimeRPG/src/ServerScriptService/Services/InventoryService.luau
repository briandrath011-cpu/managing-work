--[[
	InventoryService (ModuleScript)
	Location: ServerScriptService.Services.InventoryService

	PHASE 10 - Inventory + Equipment (server authority)
	Remote: InventoryAction (RemoteFunction)
		("Equip", uid, slot?) ("Unequip", slot) ("Lock", uid) ("Favorite", uid)
		("Delete", uid, amount?) ("Use", uid) ("EquipCosmetic", uid|"")
	Sort / search / filter are purely visual and happen in the client UI.
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.Config.GameConfig)
local ItemUtil = require(Modules.Items.ItemUtil)
local Signal = require(Modules.Shared.Signal)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local EntityRegistry = require(ServerScriptService.ServerModules.EntityRegistry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local InventoryService = {}
InventoryService.ItemAdded = Signal.new() -- (player, itemId, amount)
InventoryService.MaxUniqueItems = 250

local limiter = RateLimiter.new(15, 6)
local SLOTS = { "Weapon", "Armor", "Head", "Accessory1", "Accessory2" }

local function dataService()
	return Registry.Get("PlayerDataService")
end

local function newUid(): string
	return (HttpService:GenerateGUID(false):gsub("-", "")):sub(1, 14)
end

local function countUnique(inventory): number
	local n = 0
	for _ in pairs(inventory) do
		n += 1
	end
	return n
end

-- Adds items. Returns the uid of the (last) entry or nil if the inventory is full.
function InventoryService:AddItem(player: Player, itemId: string, amount: number?): string?
	local data = dataService():Get(player)
	local def = ItemUtil.Get(itemId)
	if not data or not def then
		return nil
	end
	local count = math.max(1, math.floor(amount or 1))
	local inventory = data.Inventory
	local lastUid: string? = nil
	if def.Stackable then
		for uid, entry in pairs(inventory) do
			if entry.Id == itemId then
				entry.Amount += count
				lastUid = uid
				break
			end
		end
		if not lastUid then
			if countUnique(inventory) >= self.MaxUniqueItems then
				return nil
			end
			local uid = newUid()
			lastUid = uid
			inventory[uid] = { Id = itemId, Amount = count, Locked = false, Favorite = false, Obtained = os.time() }
		end
	else
		for _ = 1, count do
			if countUnique(inventory) >= self.MaxUniqueItems then
				break
			end
			local uid = newUid()
			inventory[uid] = { Id = itemId, Amount = 1, Locked = false, Favorite = false, Obtained = os.time() }
			lastUid = uid
		end
	end
	dataService():Replicate(player, "Inventory")
	self.ItemAdded:Fire(player, itemId, count)
	return lastUid
end

function InventoryService:CountItem(player: Player, itemId: string): number
	local data = dataService():Get(player)
	return data and ItemUtil.CountInInventory(data.Inventory, itemId) or 0
end

-- Removes `amount` of an item id (stackable or not). Never removes equipped/locked unique items.
function InventoryService:RemoveItem(player: Player, itemId: string, amount: number, silent: boolean?): boolean
	local data = dataService():Get(player)
	if not data or self:CountItem(player, itemId) < amount then
		return false
	end
	local equipped = {}
	for _, slot in ipairs(SLOTS) do
		equipped[data.Equipment[slot]] = true
	end
	local remaining = amount
	for uid, entry in pairs(data.Inventory) do
		if remaining <= 0 then
			break
		end
		if entry.Id == itemId and not equipped[uid] and not (entry.Locked and not ItemUtil.IsStackable(itemId)) then
			local take = math.min(entry.Amount, remaining)
			entry.Amount -= take
			remaining -= take
			if entry.Amount <= 0 then
				data.Inventory[uid] = nil
			end
		end
	end
	if not silent then
		dataService():Replicate(player, "Inventory")
	end
	return remaining <= 0
end

function InventoryService:Equip(player: Player, uid: string, slot: string?): (boolean, string?)
	local data = dataService():Get(player)
	local entry = data and data.Inventory[uid]
	if not entry then
		return false, "Item not found"
	end
	local def = ItemUtil.Get(entry.Id)
	if not def then
		return false, "Unknown item"
	end
	if (def.LevelRequired or 1) > data.Level then
		return false, "Requires level " .. def.LevelRequired
	end
	local target = slot
	if def.Category == "Accessory" then
		if target ~= "Accessory1" and target ~= "Accessory2" then
			target = (data.Equipment.Accessory1 == "" or data.Equipment.Accessory1 == uid) and "Accessory1" or "Accessory2"
		end
	else
		target = def.Category
	end
	if ItemUtil.SlotCategory[target :: string] ~= def.Category then
		return false, "Can't equip that there"
	end
	-- An accessory can't be in both slots.
	for _, s in ipairs(SLOTS) do
		if data.Equipment[s] == uid then
			data.Equipment[s] = ""
		end
	end
	data.Equipment[target :: string] = uid
	dataService():Replicate(player, "Equipment")
	if target == "Weapon" then
		Registry.Get("WeaponService"):RefreshVisual(player)
	end
	return true
end

function InventoryService:Unequip(player: Player, slot: string): (boolean, string?)
	local data = dataService():Get(player)
	if not data or not table.find(SLOTS, slot) then
		return false, "Invalid slot"
	end
	data.Equipment[slot] = ""
	dataService():Replicate(player, "Equipment")
	if slot == "Weapon" then
		Registry.Get("WeaponService"):RefreshVisual(player)
	end
	return true
end

function InventoryService:IsEquipped(player: Player, uid: string): boolean
	local data = dataService():Get(player)
	if not data then
		return false
	end
	for _, slot in ipairs(SLOTS) do
		if data.Equipment[slot] == uid then
			return true
		end
	end
	return false
end

local function useItem(self, player: Player, uid: string): (boolean, string?)
	local data = dataService():Get(player)
	local entry = data and data.Inventory[uid]
	local def = entry and ItemUtil.Get(entry.Id)
	if not def or not def.Use then
		return false, "Can't use that"
	end
	local use = def.Use
	local entity = EntityRegistry.GetForPlayer(player)
	if use.Heal then
		if not entity or not EntityRegistry.IsAlive(entity) then
			return false, "You must be alive"
		end
		Registry.Get("DamageService"):Heal(entity, entity.Humanoid.MaxHealth * use.Heal)
	end
	if use.Energy then
		Registry.Get("CharacterService"):RestoreEnergy(player, Registry.Get("CharacterService"):GetMaxEnergy(player) * use.Energy)
	end
	if use.Buff then
		if not entity then
			return false, "You must be alive"
		end
		entity.State.Buffs[use.Buff] = { Modifiers = use.Modifiers, Expires = os.clock() + use.Duration }
	end
	if use.Spins then
		dataService():AddCurrency(player, "Spins", use.Spins)
	end
	if use.TraitRolls then
		dataService():AddCurrency(player, "TraitRolls", use.TraitRolls)
	end
	if use.UnlockTransformation then
		local ok, err = Registry.Get("TransformationService"):Unlock(player, use.UnlockTransformation)
		if not ok then
			return false, err
		end
	end
	if use.UnlockFlight then
		if data.Level < GameConfig.Movement.FlightUnlockLevel then
			return false, "Requires level " .. GameConfig.Movement.FlightUnlockLevel
		end
		if data.Unlocks.Flight then
			return false, "Flight already unlocked"
		end
		data.Unlocks.Flight = true
		dataService():Replicate(player, "Unlocks")
		Registry.Get("CharacterService"):Refresh(player)
	end
	self:RemoveItem(player, entry.Id, 1)
	return true
end

function InventoryService:ApplyCosmetic(player: Player)
	local data = dataService():Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local def = ItemUtil.Get(data.Cosmetics.Aura)
	character:SetAttribute("CosmeticAura", def and def.AuraColor or nil)
end

local function onAction(player: Player, action: any, a: any, b: any): (boolean, any)
	if not limiter:Check(player) then
		return false, "Slow down"
	end
	local data = dataService():Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if action == "Equip" then
		if not Validate.String(a, 32) then
			return false, "Invalid"
		end
		return InventoryService:Equip(player, a, Validate.String(b, 16) and b or nil)
	elseif action == "Unequip" then
		return InventoryService:Unequip(player, a)
	elseif action == "Lock" or action == "Favorite" then
		local entry = Validate.String(a, 32) and data.Inventory[a]
		if not entry then
			return false, "Item not found"
		end
		local key = action == "Lock" and "Locked" or "Favorite"
		entry[key] = not entry[key]
		dataService():Replicate(player, "Inventory")
		return true
	elseif action == "Delete" then
		local entry = Validate.String(a, 32) and data.Inventory[a]
		if not entry then
			return false, "Item not found"
		end
		if entry.Locked then
			return false, "Item is locked"
		end
		if InventoryService:IsEquipped(player, a) then
			return false, "Unequip it first"
		end
		local amount = Validate.Integer(b, 1, 1e6) and b or entry.Amount
		amount = math.min(amount, entry.Amount)
		entry.Amount -= amount
		if entry.Amount <= 0 then
			data.Inventory[a] = nil
		end
		dataService():Replicate(player, "Inventory")
		return true
	elseif action == "Use" then
		if not Validate.String(a, 32) then
			return false, "Invalid"
		end
		return useItem(InventoryService, player, a)
	elseif action == "EquipCosmetic" then
		if a == "" then
			data.Cosmetics.Aura = ""
		else
			local entry = Validate.String(a, 32) and data.Inventory[a]
			local def = entry and ItemUtil.Get(entry.Id)
			if not def or def.Category ~= "Cosmetic" then
				return false, "Not a cosmetic"
			end
			data.Cosmetics.Aura = entry.Id
		end
		dataService():Replicate(player, "Cosmetics")
		InventoryService:ApplyCosmetic(player)
		return true
	end
	return false, "Unknown action"
end

function InventoryService:Init()
	Net.Function("InventoryAction").OnServerInvoke = onAction
	Registry.Get("PlayerDataService").ProfileLoaded:Connect(function(player, data)
		-- Starter kit for brand-new players.
		if next(data.Inventory) == nil and data.Counters.EnemiesDefeated == 0 then
			local uid = InventoryService:AddItem(player, "WoodenKatana", 1)
			InventoryService:AddItem(player, "HealthPotion", 3)
			if uid then
				data.Equipment.Weapon = uid
				dataService():Replicate(player, "Equipment")
			end
			if not data.Titles.Owned.Newcomer then
				data.Titles.Owned.Newcomer = true
				data.Titles.Equipped = "Newcomer"
				dataService():Replicate(player, "Titles")
			end
		end
	end)
end

function InventoryService:Start()
	Registry.Get("CharacterService").CharacterReady:Connect(function(player)
		InventoryService:ApplyCosmetic(player)
	end)
end

return InventoryService
