--[[
	WorldEvents (ModuleScript)
	Location: ReplicatedStorage.Modules.World.WorldEvents
	PHASE 19 - Random world events. Weight = chance of being picked. Message is broadcast
	to every player. Rewards go to every participant (dealt damage to event enemies / harvested).
]]
return {
	Meteor = {
		DisplayName = "Meteor Shower",
		Weight = 3,
		Duration = 180,
		Message = "☄ A meteor shower is striking the land!",
		Rewards = { Gems = 15, Items = { MeteorFragment = 2 } },
	},
	DemonInvasion = {
		DisplayName = "Demon Invasion",
		Weight = 3,
		Duration = 240,
		Message = "⚠ Demons are invading! Defend the realm!",
		Rewards = { Gems = 20, Spins = 1 },
	},
	WorldBoss = {
		DisplayName = "World Boss",
		Weight = 2,
		Duration = 600,
		Message = "⚠ The Ruin Colossus has awakened!",
		Rewards = { Gems = 30, Spins = 1 },
	},
	Portal = {
		DisplayName = "Mysterious Portal",
		Weight = 3,
		Duration = 240,
		Message = "⚠ A mysterious portal has appeared!",
		Rewards = { Gems = 20, Items = { PortalShard = 2 } },
	},
	Treasure = {
		DisplayName = "Treasure Rush",
		Weight = 3,
		Duration = 180,
		Message = "💰 Treasure chests have appeared across the world!",
		Rewards = {},
	},
	BloodMoon = {
		DisplayName = "Blood Moon",
		Weight = 2,
		Duration = 240,
		NightOnly = true,
		Message = "🩸 A Blood Moon rises... enemies grow fierce, drops are doubled!",
		Rewards = { Gems = 25, Items = { BloodMoonEssence = 1 } },
	},
	ThunderStorm = {
		DisplayName = "Thunder Storm",
		Weight = 2,
		Duration = 180,
		Message = "⚡ A violent thunder storm rolls in! Collect Storm Essence!",
		Rewards = { Gems = 15 },
	},
}
