--[[
	ItemUtil (ModuleScript)
	Location: ReplicatedStorage.Modules.Items.ItemUtil
	Single lookup for any item id (weapons + all other items) and inventory helpers.
]]
local Modules = script.Parent.Parent
local ItemCatalog = require(script.Parent.ItemCatalog)
local WeaponCatalog = require(Modules.Weapons.WeaponCatalog)
local WeaponClasses = require(Modules.Weapons.WeaponClasses)

local ItemUtil = {}

ItemUtil.Categories = { "Weapon", "Armor", "Head", "Accessory", "Material", "Consumable", "Cosmetic" }

-- Which equipment slots accept which category.
ItemUtil.SlotCategory = {
	Weapon = "Weapon",
	Armor = "Armor",
	Head = "Head",
	Accessory1 = "Accessory",
	Accessory2 = "Accessory",
}

function ItemUtil.Get(id: string?)
	if not id then
		return nil
	end
	return WeaponCatalog[id] or ItemCatalog[id]
end

function ItemUtil.IsStackable(id: string): boolean
	local def = ItemUtil.Get(id)
	return def ~= nil and def.Stackable == true
end

function ItemUtil.GetWeaponClass(id: string)
	local def = WeaponCatalog[id]
	return def and WeaponClasses.List[def.Class] or nil
end

-- Returns skill ids for a weapon: overrides first, class defaults otherwise.
function ItemUtil.GetWeaponSkills(id: string): { string }
	local def = WeaponCatalog[id]
	local class = def and WeaponClasses.List[def.Class]
	if not def or not class then
		return {}
	end
	local out = {}
	for i = 1, 3 do
		out[i] = (def.Skills and def.Skills[i]) or class.Skills[i]
	end
	return out
end

-- Counts how many of an item id the inventory holds (sum of stacks).
function ItemUtil.CountInInventory(inventory: { [string]: any }, id: string): number
	local total = 0
	for _, entry in pairs(inventory) do
		if entry.Id == id then
			total += entry.Amount or 1
		end
	end
	return total
end

function ItemUtil.All()
	local out = table.clone(ItemCatalog)
	for id, def in pairs(WeaponCatalog) do
		out[id] = def
	end
	return out
end

return ItemUtil
