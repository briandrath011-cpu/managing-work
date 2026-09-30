--[[
	Titles (ModuleScript)
	Location: ReplicatedStorage.Modules.Progression.Titles
	Cosmetic titles shown above the head. Granted by achievements, bosses, raids and events.
]]
local Titles = {}

Titles.List = {
	Newcomer = { DisplayName = "Newcomer", Rarity = "Common", Source = "Join the game" },
	Bandit_Bane = { DisplayName = "Bandit Bane", Rarity = "Common", Source = "Defeat the Bandit Chief" },
	Sandwalker = { DisplayName = "Sandwalker", Rarity = "Rare", Source = "Defeat the Sand Pharaoh" },
	Stormcaller = { DisplayName = "Stormcaller", Rarity = "Epic", Source = "Defeat the Thunder Tyrant" },
	Frostborn = { DisplayName = "Frostborn", Rarity = "Epic", Source = "Defeat the Frost Empress" },
	Demon_Slayer = { DisplayName = "Demonbreaker", Rarity = "Legendary", Source = "Defeat the Demon Lord" },
	Celestial = { DisplayName = "Celestial", Rarity = "Mythic", Source = "Defeat the Celestial Sovereign" },
	Raid_Legend = { DisplayName = "Raid Legend", Rarity = "Mythic", Source = "Clear the Eclipse Raid" },
	Dungeon_Master = { DisplayName = "Dungeon Master", Rarity = "Legendary", Source = "Clear 25 dungeons" },
	Gambler = { DisplayName = "Gambler", Rarity = "Rare", Source = "Use 100 spins" },
	Secret_Keeper = { DisplayName = "Secret Keeper", Rarity = "Secret", Source = "Obtain a Secret power" },
	Night_Hunter = { DisplayName = "Night Hunter", Rarity = "Epic", Source = "Defeat the Midnight Wraith" },
	Explorer = { DisplayName = "Explorer", Rarity = "Rare", Source = "Discover every region" },
	Treasure_Hunter = { DisplayName = "Treasure Hunter", Rarity = "Rare", Source = "Open 25 chests" },
	Max_Level = { DisplayName = "Transcendent", Rarity = "Mythic", Source = "Reach max level" },
	Event_Hero = { DisplayName = "Event Hero", Rarity = "Epic", Source = "Complete 10 world events" },
	Artisan = { DisplayName = "Artisan", Rarity = "Rare", Source = "Craft 20 items" },
}

function Titles.Get(id: string?)
	if not id or id == "" then
		return nil
	end
	return Titles.List[id]
end

return Titles
