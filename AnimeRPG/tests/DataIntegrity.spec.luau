-- Cross-checks every id reference between the content catalogs so typos are caught before
-- they turn into runtime errors in Studio.
local RarityConfig = require(Modules.Config.RarityConfig)
local ItemUtil = require(Modules.Items.ItemUtil)
local ItemCatalog = require(Modules.Items.ItemCatalog)
local Recipes = require(Modules.Items.Recipes)
local WeaponCatalog = require(Modules.Weapons.WeaponCatalog)
local WeaponClasses = require(Modules.Weapons.WeaponClasses)
local WeaponSkills = require(Modules.Weapons.WeaponSkills)
local PowerRegistry = require(Modules.Powers.PowerRegistry)
local EnemyCatalog = require(Modules.Enemies.EnemyCatalog)
local EnemySkills = require(Modules.Enemies.EnemySkills)
local BossCatalog = require(Modules.Bosses.BossCatalog)
local BossSkills = require(Modules.Bosses.BossSkills)
local NPCCatalog = require(Modules.NPCs.NPCCatalog)
local QuestCatalog = require(Modules.Quests.QuestCatalog)
local WorldConfig = require(Modules.World.WorldConfig)
local Dungeons = require(Modules.World.Dungeons)
local Raids = require(Modules.World.Raids)
local WorldEvents = require(Modules.World.WorldEvents)
local Titles = require(Modules.Progression.Titles)
local Traits = require(Modules.Progression.Traits)
local Transformations = require(Modules.Progression.Transformations)
local Achievements = require(Modules.Progression.Achievements)
local FightingStyles = require(Modules.Combat.FightingStyles)
local Modifiers = require(Modules.Combat.Modifiers)
local AssetIds = require(Modules.Assets.AssetIds)

local function assertItem(id, context)
	if not ItemUtil.Get(id) then
		error("Unknown item '" .. tostring(id) .. "' in " .. context, 2)
	end
end

local function assertDrops(drops, context)
	for _, drop in ipairs(drops or {}) do
		assertItem(drop.Id, context)
		expect(drop.Chance).toBeBetween(0, 1)
		expect((drop.Max or drop.Min or 1) >= (drop.Min or 1)).toBeTruthy()
	end
end

local function assertModifiers(mods, context)
	for key in pairs(mods or {}) do
		if not Modifiers.Keys[key] then
			error("Unknown modifier '" .. key .. "' in " .. context, 2)
		end
	end
end

local function isRarity(rarity)
	return RarityConfig.Rank[rarity] ~= nil
end

local waypointIds, secretIds, regionIds = {}, {}, {}
for _, w in ipairs(WorldConfig.Waypoints) do
	waypointIds[w.Id] = true
end
for _, s in ipairs(WorldConfig.Secrets) do
	secretIds[s.Id] = true
end
for _, r in ipairs(WorldConfig.Regions) do
	regionIds[r.Id] = true
end

describe("Items", function()
	it("every item has a valid category, rarity and modifiers", function()
		for id, def in pairs(ItemUtil.All()) do
			expect(def.Id).toBe(id)
			expect(table.find({ "Weapon", "Armor", "Head", "Accessory", "Material", "Consumable", "Cosmetic" }, def.Category) ~= nil).toBeTruthy()
			expect(isRarity(def.Rarity)).toBeTruthy()
			assertModifiers(def.Modifiers, id)
			if def.Passive then
				assertModifiers(def.Passive.Modifiers, id)
				assertModifiers(def.Passive.NightModifiers, id)
			end
		end
	end)

	it("no id is used by both a weapon and another item", function()
		for id in pairs(WeaponCatalog) do
			expect(ItemCatalog[id]).toBe(nil)
		end
	end)

	it("consumable unlocks point at real transformations", function()
		for id, def in pairs(ItemCatalog) do
			if def.Use and def.Use.UnlockTransformation then
				expect(Transformations.Get(def.Use.UnlockTransformation) ~= nil).toBeTruthy()
			end
			local _ = id
		end
		for id, def in pairs(Transformations.List) do
			if def.UnlockItem then
				assertItem(def.UnlockItem, "transformation " .. id)
			end
			assertModifiers(def.Modifiers, id)
		end
	end)

	it("recipes use existing items and stations", function()
		local stations = {}
		for _, npc in pairs(NPCCatalog) do
			if npc.CraftStation then
				stations[npc.CraftStation] = true
			end
		end
		for _, recipe in ipairs(Recipes) do
			assertItem(recipe.Result, recipe.Id)
			for material, amount in pairs(recipe.Materials) do
				assertItem(material, recipe.Id)
				expect(amount).toBeGreaterThan(0)
			end
			expect(recipe.Station == "Any" or stations[recipe.Station] == true).toBeTruthy()
		end
	end)
end)

describe("Weapons", function()
	it("every weapon resolves a class and 3 skills", function()
		for id, def in pairs(WeaponCatalog) do
			expect(WeaponClasses.List[def.Class] ~= nil).toBeTruthy()
			local skills = ItemUtil.GetWeaponSkills(id)
			for slot = 1, 3 do
				local skill = WeaponSkills[skills[slot]]
				if not skill then
					error("Weapon " .. id .. " slot " .. slot .. " has no skill")
				end
				expect(type(skill.Execute)).toBe("function")
			end
			expect(WeaponSkills[skills[3]].Ultimate).toBe(true)
		end
	end)
end)

describe("Powers", function()
	it("loads every power module with 3 skills + ultimate", function()
		local count = 0
		for id, def in pairs(PowerRegistry.All()) do
			count += 1
			expect(def.Id).toBe(id)
			expect(isRarity(def.Rarity)).toBeTruthy()
			expect(#def.Skills).toBe(4)
			expect(def.Skills[4].Ultimate).toBe(true)
			assertModifiers(def.Passive.Modifiers, id)
			for _, skill in ipairs(def.Skills) do
				expect(type(skill.Execute)).toBe("function")
				expect(type(skill.Cooldown)).toBe("number")
				expect(type(skill.EnergyCost)).toBe("number")
				expect(type(skill.Damage)).toBe("number")
			end
		end
		expect(count).toBeGreaterThan(10)
	end)

	it("every rarity can be spun", function()
		for _, rarity in ipairs(RarityConfig.Order) do
			expect(#PowerRegistry.ByRarity(rarity)).toBeGreaterThan(0)
		end
	end)

	it("the requested showcase powers exist", function()
		for _, id in ipairs({ "Rinnegan", "TimeStand", "Limitless", "ShadowMonarch", "SaiyanPower", "RubberPower", "Sharingan" }) do
			expect(PowerRegistry.Get(id) ~= nil).toBeTruthy()
		end
	end)

	it("mastery unlocks follow 0 / 15 / 35 / 75", function()
		local unlocks = PowerRegistry.MasteryUnlocks
		expect(unlocks[1]).toBe(0)
		expect(unlocks[2]).toBe(15)
		expect(unlocks[3]).toBe(35)
		expect(unlocks[4]).toBe(75)
	end)
end)

describe("Enemies and bosses", function()
	it("enemy skills and drops exist", function()
		for id, def in pairs(EnemyCatalog) do
			for _, skill in ipairs(def.Skills) do
				if not EnemySkills[skill] then
					error("Enemy " .. id .. " uses unknown skill " .. skill)
				end
			end
			assertDrops(def.Drops, id)
			if def.WeaponClass then
				expect(WeaponClasses.List[def.WeaponClass] ~= nil).toBeTruthy()
			end
		end
	end)

	it("boss phases, ultimates, minions, titles and drops exist", function()
		for id, def in pairs(BossCatalog) do
			for _, phase in ipairs(def.Phases) do
				for _, skill in ipairs(phase.Skills) do
					if not BossSkills[skill] then
						error("Boss " .. id .. " uses unknown skill " .. skill)
					end
				end
			end
			expect(def.Phases[1].Threshold).toBe(1)
			if def.Ultimate then
				expect(BossSkills[def.Ultimate] ~= nil and BossSkills[def.Ultimate].Ultimate == true).toBeTruthy()
			end
			if def.Minion then
				expect(EnemyCatalog[def.Minion] ~= nil).toBeTruthy()
			end
			if def.Title then
				expect(Titles.Get(def.Title) ~= nil).toBeTruthy()
			end
			if def.Music then
				expect(AssetIds.Music[def.Music] ~= nil).toBeTruthy()
			end
			assertDrops(def.Drops, id)
		end
	end)

	it("the Night Slayer can drop from a boss", function()
		local found = false
		for _, def in pairs(BossCatalog) do
			for _, drop in ipairs(def.Drops) do
				if drop.Id == "NightSlayer" then
					found = true
				end
			end
		end
		expect(found).toBeTruthy()
	end)
end)

describe("NPCs and quests", function()
	it("npc quests exist and shops sell real items", function()
		for id, npc in pairs(NPCCatalog) do
			for _, questId in ipairs(npc.Quests) do
				if not QuestCatalog.Get(questId) then
					error("NPC " .. id .. " offers unknown quest " .. questId)
				end
			end
			for _, entry in ipairs(npc.Shop or {}) do
				assertItem(entry.Item, id .. " shop")
				expect(entry.Currency == "Gold" or entry.Currency == "Gems").toBeTruthy()
			end
		end
	end)

	it("quest objectives, NPCs and rewards reference real content", function()
		for id, quest in pairs(QuestCatalog.List) do
			expect(quest.Id).toBe(id)
			if quest.Giver then
				expect(NPCCatalog[quest.Giver] ~= nil).toBeTruthy()
			end
			if quest.TurnIn then
				expect(NPCCatalog[quest.TurnIn] ~= nil).toBeTruthy()
			end
			if quest.Prerequisite then
				expect(QuestCatalog.Get(quest.Prerequisite) ~= nil).toBeTruthy()
			end
			for _, objective in ipairs(quest.Objectives) do
				local kind, target = objective.Kind, objective.Target
				local ok = true
				if kind == "Kill" then
					ok = target == "Any" or EnemyCatalog[target] ~= nil
				elseif kind == "Boss" then
					ok = target == "Any" or BossCatalog[target] ~= nil
				elseif kind == "Collect" or kind == "Deliver" then
					ok = ItemUtil.Get(objective.Item) ~= nil
					if kind == "Deliver" then
						ok = ok and NPCCatalog[objective.To] ~= nil
					end
				elseif kind == "Explore" then
					ok = waypointIds[target] or secretIds[target] or regionIds[target] or false
				elseif kind == "Dungeon" then
					ok = target == "Any" or Dungeons.List[target] ~= nil
				elseif kind == "Raid" then
					ok = target == "Any" or Raids[target] ~= nil
				elseif kind == "Talk" then
					ok = NPCCatalog[target] ~= nil
				else
					ok = false
				end
				if not ok then
					error("Quest " .. id .. " has invalid objective " .. kind .. " " .. tostring(target or objective.Item))
				end
			end
			for itemId in pairs(quest.Rewards.Items or {}) do
				assertItem(itemId, "quest " .. id)
			end
		end
		for _, id in ipairs(QuestCatalog.DailyPool) do
			expect(QuestCatalog.Get(id).Type).toBe("Daily")
		end
		for _, id in ipairs(QuestCatalog.WeeklyPool) do
			expect(QuestCatalog.Get(id).Type).toBe("Weekly")
		end
	end)

	it("covers every quest type", function()
		local types = {}
		for _, quest in pairs(QuestCatalog.List) do
			types[quest.Type] = true
		end
		for _, t in ipairs({ "Kill", "Boss", "Collect", "Delivery", "Exploration", "Dungeon", "Daily", "Weekly", "Secret" }) do
			expect(types[t]).toBe(true)
		end
	end)
end)

describe("World", function()
	it("spawns, bosses, NPCs and gates reference real content", function()
		for _, spawner in ipairs(WorldConfig.EnemySpawns) do
			expect(EnemyCatalog[spawner.Enemy] ~= nil).toBeTruthy()
			expect(WorldConfig.RegionAt(spawner.Center) ~= nil).toBeTruthy()
		end
		for _, boss in ipairs(WorldConfig.Bosses) do
			expect(BossCatalog[boss.Boss] ~= nil).toBeTruthy()
		end
		for _, placement in ipairs(WorldConfig.NPCs) do
			expect(NPCCatalog[placement.Npc] ~= nil).toBeTruthy()
		end
		for _, gate in ipairs(WorldConfig.DungeonGates) do
			expect(Dungeons.List[gate.Dungeon] ~= nil).toBeTruthy()
		end
		expect(Raids[WorldConfig.RaidGate.Raid] ~= nil).toBeTruthy()
	end)

	it("waypoints sit inside their region", function()
		for _, waypoint in ipairs(WorldConfig.Waypoints) do
			local region = WorldConfig.RegionAt(waypoint.Position)
			expect(region ~= nil and region.Id == waypoint.Region).toBeTruthy()
		end
	end)

	it("has the six requested regions with increasing level ranges", function()
		expect(#WorldConfig.Regions).toBe(6)
		for i = 2, #WorldConfig.Regions do
			expect(WorldConfig.Regions[i].LevelRange[1] >= WorldConfig.Regions[i - 1].LevelRange[1]).toBeTruthy()
		end
	end)

	it("dungeon rooms and rewards are valid", function()
		for id, dungeon in pairs(Dungeons.List) do
			expect(#dungeon.Rooms).toBe(4)
			for _, room in ipairs(dungeon.Rooms) do
				if room.Kind == "Boss" then
					expect(BossCatalog[room.Boss] ~= nil).toBeTruthy()
				else
					for _, enemy in ipairs(room.Enemies) do
						if not EnemyCatalog[enemy] then
							error("Dungeon " .. id .. " uses unknown enemy " .. enemy)
						end
					end
				end
			end
			assertDrops(dungeon.Rewards.Drops, id)
		end
		for id, raid in pairs(Raids) do
			expect(BossCatalog[raid.Boss] ~= nil).toBeTruthy()
			assertDrops(raid.Rewards.Drops, id)
			expect(Titles.Get(raid.Rewards.Title) ~= nil).toBeTruthy()
		end
	end)

	it("world events give real rewards", function()
		for id, event in pairs(WorldEvents) do
			for itemId in pairs(event.Rewards.Items or {}) do
				assertItem(itemId, "event " .. id)
			end
		end
	end)
end)

describe("Progression content", function()
	it("achievement rewards and traits are valid", function()
		for _, achievement in ipairs(Achievements) do
			if achievement.Reward.Title then
				expect(Titles.Get(achievement.Reward.Title) ~= nil).toBeTruthy()
			end
		end
		for _, id in ipairs(Traits.Rollable) do
			local trait = Traits.List[id]
			expect(isRarity(trait.Rarity)).toBeTruthy()
			assertModifiers(trait.Modifiers, id)
		end
		for id, style in pairs(FightingStyles) do
			expect(style.Id).toBe(id)
			assertModifiers(style.Modifiers, id)
		end
	end)
end)
