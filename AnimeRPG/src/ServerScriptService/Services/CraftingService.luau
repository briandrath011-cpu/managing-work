--[[
	CraftingService (ModuleScript)
	Location: ServerScriptService.Services.CraftingService
	PHASE 17 - Crafting at Crafter NPCs (station per region, "Any" recipes work everywhere).
	Remote: CraftAction (RemoteFunction) ("Craft", recipeId, npcId)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Recipes = require(Modules.Items.Recipes)
local NPCCatalog = require(Modules.NPCs.NPCCatalog)
local ItemUtil = require(Modules.Items.ItemUtil)
local WorldConfig = require(Modules.World.WorldConfig)
local Net = require(Modules.Shared.Net)
local Registry = require(ServerScriptService.ServerModules.Registry)
local RateLimiter = require(ServerScriptService.ServerModules.RateLimiter)
local Validate = require(ServerScriptService.ServerModules.Validate)

local CraftingService = {}

local limiter = RateLimiter.new(5, 2)

local function findRecipe(id: string)
	for _, recipe in ipairs(Recipes) do
		if recipe.Id == id then
			return recipe
		end
	end
	return nil
end

local function nearNpc(player: Player, npcId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, placement in ipairs(WorldConfig.NPCs) do
		if placement.Npc == npcId and (placement.Position - root.Position).Magnitude < 25 then
			return true
		end
	end
	return false
end

function CraftingService:Craft(player: Player, recipeId: string, npcId: string): (boolean, string?)
	local recipe = findRecipe(recipeId)
	local npc = NPCCatalog[npcId]
	local dataService = Registry.Get("PlayerDataService")
	local data = dataService:Get(player)
	if not recipe or not npc or not data then
		return false, "Invalid recipe"
	end
	if not table.find(npc.Roles, "Crafter") or not nearNpc(player, npcId) then
		return false, "Visit a crafter"
	end
	if recipe.Station ~= "Any" and recipe.Station ~= npc.CraftStation then
		return false, "This crafter can't make that"
	end
	local inventory = Registry.Get("InventoryService")
	for itemId, amount in pairs(recipe.Materials) do
		if inventory:CountItem(player, itemId) < amount then
			local def = ItemUtil.Get(itemId)
			return false, "Missing " .. (def and def.DisplayName or itemId)
		end
	end
	if data.Gold < recipe.Gold then
		return false, "Not enough Gold"
	end
	-- Take everything first, then give (atomic from the player's point of view).
	dataService:SpendCurrency(player, "Gold", recipe.Gold)
	for itemId, amount in pairs(recipe.Materials) do
		inventory:RemoveItem(player, itemId, amount, true)
	end
	dataService:Replicate(player, "Inventory")
	inventory:AddItem(player, recipe.Result, recipe.Amount)
	dataService:AddCounter(player, "ItemsCrafted", 1)
	local result = ItemUtil.Get(recipe.Result)
	Registry.Get("FXService")
		:Notify(
			player,
			"Craft",
			"Crafted " .. (result and result.DisplayName or recipe.Result) .. "!",
			{ Rarity = result and result.Rarity }
		)
	Registry.Get("FXService"):PlayFor(player, "CraftSuccess", { Item = recipe.Result })
	return true
end

function CraftingService:Init()
	Net.Function("CraftAction").OnServerInvoke = function(player, action, recipeId, npcId)
		if not limiter:Check(player) then
			return false, "Slow down"
		end
		if action ~= "Craft" or not Validate.String(recipeId, 40) or not Validate.String(npcId, 40) then
			return false, "Invalid request"
		end
		return CraftingService:Craft(player, recipeId, npcId)
	end
end

return CraftingService
