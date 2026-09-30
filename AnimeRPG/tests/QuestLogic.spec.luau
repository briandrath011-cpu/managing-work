local QuestCatalog = require(Modules.Quests.QuestCatalog)
local QuestLogic = require(Modules.Quests.QuestLogic)

local function newData(level)
	return { Level = level, Quests = { Active = {}, Completed = {} } }
end

describe("QuestLogic", function()
	it("respects level requirement and prerequisites", function()
		local def = QuestCatalog.Get("GW_Bandits")
		local data = newData(1)
		expect((QuestLogic.IsAvailable(def, data, false))).toBeFalsy()
		data.Level = 10
		expect((QuestLogic.IsAvailable(def, data, false))).toBeFalsy() -- prerequisite missing
		data.Quests.Completed.GW_Wolves = 1
		expect((QuestLogic.IsAvailable(def, data, false))).toBeTruthy()
	end)

	it("night-only quests need the night", function()
		local def = QuestCatalog.Get("NT_Moonpetal")
		local data = newData(50)
		expect((QuestLogic.IsAvailable(def, data, false))).toBeFalsy()
		expect((QuestLogic.IsAvailable(def, data, true))).toBeTruthy()
	end)

	it("completed quests are not offered again unless repeatable", function()
		local data = newData(50)
		data.Quests.Completed.GW_Wolves = 1
		expect((QuestLogic.IsAvailable(QuestCatalog.Get("GW_Wolves"), data, false))).toBeFalsy()
		data.Quests.Completed.NT_Moonpetal = 1
		expect((QuestLogic.IsAvailable(QuestCatalog.Get("NT_Moonpetal"), data, true))).toBeTruthy()
	end)

	it("kill events progress matching objectives only", function()
		local def = QuestCatalog.Get("GW_Brutes")
		local progress = QuestLogic.NewProgress(def)
		expect(QuestLogic.ApplyEvent(def, progress, { Kind = "Kill", Target = "BanditBrute" })).toBeTruthy()
		expect(QuestLogic.ApplyEvent(def, progress, { Kind = "Kill", Target = "ForestWolf" })).toBeFalsy()
		expect(progress[1]).toBe(1)
		expect(progress[2]).toBe(0)
	end)

	it("progress never exceeds the objective count", function()
		local def = QuestCatalog.Get("GW_Wolves")
		local progress = QuestLogic.NewProgress(def)
		for _ = 1, 50 do
			QuestLogic.ApplyEvent(def, progress, { Kind = "Kill", Target = "ForestWolf" })
		end
		expect(progress[1]).toBe(def.Objectives[1].Count)
	end)

	it("'Any' kill objectives count bosses too", function()
		local def = QuestCatalog.Get("DY_Slayer")
		local progress = QuestLogic.NewProgress(def)
		QuestLogic.ApplyEvent(def, progress, { Kind = "Boss", Target = "BanditChief" })
		expect(progress[1]).toBe(1)
	end)

	it("collect quests read the inventory", function()
		local def = QuestCatalog.Get("GW_Herbs")
		local progress = QuestLogic.NewProgress(def)
		expect(QuestLogic.IsComplete(def, progress, function()
			return 4
		end)).toBeFalsy()
		expect(QuestLogic.IsComplete(def, progress, function()
			return 5
		end)).toBeTruthy()
	end)

	it("day and week keys roll over", function()
		expect(QuestLogic.DayKey(86400 * 10 + 5)).toBe(10)
		expect(QuestLogic.WeekKey(0) ~= QuestLogic.WeekKey(86400 * 8)).toBeTruthy()
	end)
end)
