--[[
	ShopService (ModuleScript)
	Location: ServerScriptService.Services.ShopService
	Merchants, style trainers, weapon/power trainers.
	Remote: ShopAction (RemoteFunction)
		("GetShop", npcId) -> entries
		("Buy", npcId, index, amount)
		("Sell", uid, amount)
		("BuyStyle", npcId, styleId) ("EquipStyle", styleId)
		("Train", npcId, "Weapon"|"Power")
	All prices/ranges are validated on the server; the NPC must be nearby.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local NPCCatalog = require(Modules.NPCs.NPCCatalog)
local FightingStyles = require(Modules.Combat.FightingStyles)
local ItemUtil = require(Modules.Items.ItemUtil)
local RarityConfig = require(Modules.Config.RarityConfig)
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local ShopService = {}

local limiter = RateLimiter.new(10, 4)
local trainCooldown: { [Player]: number } = {}
local SELL_PRICE = { Common = 10, Rare = 40, Epic = 150, Legendary = 600, Mythic = 2500, Secret = 8000 }

local function near(player: Player, npcId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, placement in ipairs(WorldConfig.NPCs) do
		if placement.Npc == npcId and (placement.Position - root.Position).Magnitude <= 25 then
			return true
		end
	end
	return false
end

local function hasRole(npcId: string, role: string): boolean
	local def = NPCCatalog[npcId]
	return def ~= nil and table.find(def.Roles, role) ~= nil
end

function ShopService:TrainCost(level: number): number
	return math.floor(150 + level ^ 1.6 * 12)
end

local function onAction(player: Player, action: any, a: any, b: any, c: any): (boolean, any)
	if not limiter:Check(player) then
		return false, "Slow down"
	end
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end

	if action == "GetShop" then
		local def = Validate.String(a, 40) and NPCCatalog[a]
		if not def or not def.Shop then
			return false, "No shop"
		end
		return true, def.Shop
	elseif action == "Buy" then
		local def = Validate.String(a, 40) and NPCCatalog[a]
		if not def or not def.Shop or not near(player, a) then
			return false, "Too far from the merchant"
		end
		if not Validate.Integer(b, 1, #def.Shop) then
			return false, "Invalid item"
		end
		local amount = Validate.Integer(c, 1, 99) and c or 1
		local entry = def.Shop[b]
		local itemDef = ItemUtil.Get(entry.Item)
		if not itemDef then
			return false, "Invalid item"
		end
		if not itemDef.Stackable then
			amount = 1
		end
		if (entry.LevelRequired or 1) > data.Level then
			return false, "Requires level " .. entry.LevelRequired
		end
		local total = entry.Price * amount
		if not dataService:SpendCurrency(player, entry.Currency, total) then
			return false, "Not enough " .. entry.Currency
		end
		if not Registry.Get("InventoryService"):AddItem(player, entry.Item, amount) then
			dataService:AddCurrency(player, entry.Currency, total) -- refund
			return false, "Inventory full"
		end
		return true
	elseif action == "Sell" then
		local entry = Validate.String(a, 32) and data.Inventory[a]
		if not entry then
			return false, "Item not found"
		end
		local itemDef = ItemUtil.Get(entry.Id)
		if not itemDef or itemDef.QuestItem then
			return false, "Can't sell that"
		end
		if entry.Locked then
			return false, "Item is locked"
		end
		if Registry.Get("InventoryService"):IsEquipped(player, a) then
			return false, "Unequip it first"
		end
		local amount = math.min(entry.Amount, Validate.Integer(b, 1, 1e6) and b or 1)
		local price = (SELL_PRICE[itemDef.Rarity] or 5) * amount
		entry.Amount -= amount
		if entry.Amount <= 0 then
			data.Inventory[a] = nil
		end
		dataService:Replicate(player, "Inventory")
		dataService:AddCurrency(player, "Gold", price)
		return true, price
	elseif action == "BuyStyle" then
		if not Validate.String(a, 40) or not hasRole(a, "StyleTrainer") or not near(player, a) then
			return false, "Find a style trainer"
		end
		local style = Validate.String(b, 40) and FightingStyles[b]
		if not style then
			return false, "Unknown style"
		end
		if data.FightingStyles[style.Id] then
			return false, "Already learned"
		end
		if data.Level < style.LevelRequired then
			return false, "Requires level " .. style.LevelRequired
		end
		if not dataService:SpendCurrency(player, "Gold", style.Cost) then
			return false, "Not enough Gold"
		end
		data.FightingStyles[style.Id] = true
		data.FightingStyle = style.Id
		dataService:Replicate(player, "FightingStyles")
		dataService:Replicate(player, "FightingStyle")
		Registry.Get("FXService"):Notify(player, "Unlock", "Learned fighting style: " .. style.DisplayName)
		return true
	elseif action == "EquipStyle" then
		if not Validate.String(a, 40) or not data.FightingStyles[a] then
			return false, "Style not learned"
		end
		data.FightingStyle = a
		dataService:Replicate(player, "FightingStyle")
		return true
	elseif action == "Train" then
		local role = b == "Weapon" and "WeaponTrainer" or (b == "Power" and "PowerTrainer" or nil)
		if not role or not Validate.String(a, 40) or not hasRole(a, role) or not near(player, a) then
			return false, "Find a trainer"
		end
		local now = os.clock()
		if now < (trainCooldown[player] or 0) then
			return false, string.format("Rest for %d seconds", math.ceil(trainCooldown[player] - now))
		end
		local cost = ShopService:TrainCost(data.Level)
		if b == "Weapon" then
			local weapon = Registry.Get("WeaponService"):GetEquipped(player)
			if not weapon then
				return false, "Equip a weapon first"
			end
			if not dataService:SpendCurrency(player, "Gold", cost) then
				return false, "Training costs " .. cost .. " Gold"
			end
			Registry.Get("WeaponService"):AddMastery(player, weapon.Def.Id, 60)
		else
			local power = Registry.Get("PowerService"):GetEquippedPower(player)
			if not power then
				return false, "Equip a power first"
			end
			if not dataService:SpendCurrency(player, "Gold", cost) then
				return false, "Training costs " .. cost .. " Gold"
			end
			Registry.Get("PowerService"):AddMastery(player, power.Id, 60)
		end
		trainCooldown[player] = now + 45
		return true, cost
	end
	return false, "Unknown action"
end

function ShopService:Init()
	Net.Function("ShopAction").OnServerInvoke = onAction
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		trainCooldown[player] = nil
	end)
end

ShopService.SellPrices = SELL_PRICE
ShopService.RarityOrder = RarityConfig.Order

return ShopService
