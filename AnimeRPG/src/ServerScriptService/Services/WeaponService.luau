--[[
	WeaponService (ModuleScript)
	Location: ServerScriptService.Services.WeaponService
	PHASE 8 / 9 - Weapons + Weapon Mastery
	- Resolves the equipped weapon (validated from server inventory)
	- Weapon mastery EXP (per weapon Id, saved in PlayerData.WeaponMastery)
	- Unlocks: 20 = skill Z, 50 = skill X, 100 = ultimate C
	- Weapon models on the character
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Progression = require(Modules.Config.Progression)
local ItemUtil = require(Modules.Items.ItemUtil)
local WeaponCatalog = require(Modules.Weapons.WeaponCatalog)
local WeaponClasses = require(Modules.Weapons.WeaponClasses)
local WeaponSkills = require(Modules.Weapons.WeaponSkills)
local Registry = require(ServerScriptService.ServerModules.Registry)
local WeaponVisual = require(ServerScriptService.ServerModules.WeaponVisual)

local WeaponService = {}

local dirty: { [Player]: boolean } = {}

local function dataService()
	return Registry.Get("PlayerDataService")
end

function WeaponService:GetEquipped(player: Player)
	local data = dataService():Get(player)
	if not data then
		return nil
	end
	local uid = data.Equipment.Weapon
	local entry = uid ~= "" and data.Inventory[uid] or nil
	local def = entry and WeaponCatalog[entry.Id]
	if not def then
		return nil
	end
	local class = WeaponClasses.List[def.Class]
	local mastery = data.WeaponMastery[def.Id]
	return {
		Uid = uid,
		Def = def,
		Class = class,
		Mastery = mastery and mastery.Level or 0,
	}
end

function WeaponService:GetMastery(player: Player, weaponId: string): number
	local data = dataService():Get(player)
	local record = data and data.WeaponMastery[weaponId]
	return record and record.Level or 0
end

function WeaponService:GetSkill(player: Player, slot: number)
	local info = self:GetEquipped(player)
	if not info then
		return nil
	end
	local skillId = ItemUtil.GetWeaponSkills(info.Def.Id)[slot]
	local skill = skillId and WeaponSkills[skillId]
	if not skill then
		return nil
	end
	return skill, info, WeaponClasses.MasteryUnlocks[slot]
end

function WeaponService:AddMastery(player: Player, weaponId: string, amount: number)
	local data = dataService():Get(player)
	if not data or not WeaponCatalog[weaponId] then
		return
	end
	local record = data.WeaponMastery[weaponId]
	if not record then
		record = { Level = 0, Exp = 0 }
		data.WeaponMastery[weaponId] = record
	end
	local old = record.Level
	record.Level, record.Exp = Progression.ApplyMasteryExp(record.Level, record.Exp, amount)
	if record.Level > old then
		for slot, required in ipairs(WeaponClasses.MasteryUnlocks) do
			if old < required and record.Level >= required then
				local skillId = ItemUtil.GetWeaponSkills(weaponId)[slot]
				local skill = skillId and WeaponSkills[skillId]
				Registry.Get("FXService"):Notify(
					player,
					"Unlock",
					string.format(
						"%s Mastery %d: unlocked %s!",
						WeaponCatalog[weaponId].DisplayName,
						required,
						skill and skill.Name or "a new skill"
					)
				)
			end
		end
		Registry.Get("FXService")
			:Notify(player, "Mastery", string.format("%s mastery %d", WeaponCatalog[weaponId].DisplayName, record.Level))
	end
	dirty[player] = true
end

-- Night-only passives (Moon Katana).
function WeaponService:GetNightModifiers(player: Player)
	local info = self:GetEquipped(player)
	if info and info.Def.Passive and info.Def.Passive.NightModifiers then
		return info.Def.Passive.NightModifiers
	end
	return nil
end

function WeaponService:RefreshVisual(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local info = self:GetEquipped(player)
	if info then
		WeaponVisual.Attach(character, info.Def, info.Class)
		character:SetAttribute("WeaponClass", info.Def.Class)
		character:SetAttribute("WeaponColor", info.Def.Glow or info.Def.Accent or info.Def.Color)
	else
		WeaponVisual.Clear(character)
		character:SetAttribute("WeaponClass", nil)
		character:SetAttribute("WeaponColor", nil)
	end
end

function WeaponService:Init() end

function WeaponService:Start()
	Registry.Get("CharacterService").CharacterReady:Connect(function(player)
		WeaponService:RefreshVisual(player)
	end)
	-- Batched replication of mastery (hits happen many times per second).
	while true do
		task.wait(1)
		for player in pairs(dirty) do
			dirty[player] = nil
			if player.Parent then
				dataService():Replicate(player, "WeaponMastery")
			end
		end
	end
end

return WeaponService
