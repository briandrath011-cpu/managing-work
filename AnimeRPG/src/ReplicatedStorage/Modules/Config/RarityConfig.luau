--[[
	RarityConfig (ModuleScript)
	Location: ReplicatedStorage.Modules.Config.RarityConfig
	All rarity chances, colors and pity thresholds in one place.
]]
local RarityConfig = {}

RarityConfig.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

RarityConfig.Rank = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 5,
	Secret = 6,
}

-- Power spin chances in percent. Must add up to 100 (tests check this).
RarityConfig.SpinChances = {
	Common = 45,
	Rare = 28,
	Epic = 15,
	Legendary = 8,
	Mythic = 3,
	Secret = 1,
}

-- Trait rolls use their own table.
RarityConfig.TraitChances = {
	Common = 50,
	Rare = 28,
	Epic = 14,
	Legendary = 6,
	Mythic = 1.7,
	Secret = 0.3,
}

-- Pity: after N spins without getting at least this rarity, the next spin is guaranteed.
-- Stored per player on the server (PlayerData.Pity).
RarityConfig.Pity = {
	{ Rarity = "Legendary", Threshold = 40 },
	{ Rarity = "Mythic", Threshold = 120 },
	{ Rarity = "Secret", Threshold = 400 },
}

RarityConfig.Colors = {
	Common = Color3.fromRGB(190, 190, 190),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 60, 90),
	Secret = Color3.fromRGB(20, 255, 200),
}

-- Visual intensity of reveals / drop effects.
RarityConfig.RevealStyle = {
	Common = { Flash = false, Shake = 0, Duration = 0.6 },
	Rare = { Flash = false, Shake = 0.1, Duration = 0.8 },
	Epic = { Flash = true, Shake = 0.2, Duration = 1.0 },
	Legendary = { Flash = true, Shake = 0.4, Duration = 1.4 },
	Mythic = { Flash = true, Shake = 0.7, Duration = 2.2, Special = "Mythic" },
	Secret = { Flash = true, Shake = 1.0, Duration = 3.0, Special = "Secret" },
}

function RarityConfig.IsAtLeast(rarity: string, minimum: string): boolean
	return (RarityConfig.Rank[rarity] or 0) >= (RarityConfig.Rank[minimum] or 0)
end

function RarityConfig.GetColor(rarity: string): Color3
	return RarityConfig.Colors[rarity] or RarityConfig.Colors.Common
end

return RarityConfig
