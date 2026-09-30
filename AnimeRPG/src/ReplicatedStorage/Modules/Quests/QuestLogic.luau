--[[
	QuestLogic (ModuleScript)
	Location: ReplicatedStorage.Modules.Quests.QuestLogic
	Pure quest rules shared by QuestService (server, authoritative) and the quest UI (client, display).
	Unit tested.
]]
local QuestLogic = {}

-- data: PlayerData table (or the subset Level/Quests)
function QuestLogic.IsAvailable(def, data, isNight: boolean): (boolean, string?)
	if not def then
		return false, "Unknown quest"
	end
	if def.Type == "Daily" or def.Type == "Weekly" then
		return false, "Board quest"
	end
	local quests = data.Quests
	if quests.Active[def.Id] then
		return false, "Already active"
	end
	if quests.Completed[def.Id] and not def.Repeatable then
		return false, "Already completed"
	end
	if data.Level < (def.LevelRequired or 1) then
		return false, "Requires level " .. tostring(def.LevelRequired)
	end
	if def.Prerequisite and not quests.Completed[def.Prerequisite] then
		return false, "Locked"
	end
	if def.NightOnly and not isNight then
		return false, "Only at night"
	end
	return true
end

function QuestLogic.NewProgress(def): { number }
	local progress = {}
	for i = 1, #def.Objectives do
		progress[i] = 0
	end
	return progress
end

local function matches(target: string, value: string): boolean
	return target == "Any" or target == value
end

-- event: { Kind = "Kill"|"Boss"|"Explore"|"Dungeon"|"Raid"|"Talk", Target = id, Amount = n }
-- Returns true if any objective progressed.
function QuestLogic.ApplyEvent(def, progress: { number }, event): boolean
	local changed = false
	for i, objective in ipairs(def.Objectives) do
		local count = objective.Count or 1
		if (progress[i] or 0) < count then
			local kind = objective.Kind
			-- Bosses also count for "kill anything" objectives.
			local hit = (kind == event.Kind and matches(objective.Target, event.Target))
				or (kind == "Kill" and event.Kind == "Boss" and objective.Target == "Any")
			if hit then
				progress[i] = math.min(count, (progress[i] or 0) + (event.Amount or 1))
				changed = true
			end
		end
	end
	return changed
end

-- countItem(itemId) -> number (inventory lookup)
function QuestLogic.ObjectiveProgress(objective, stored: number, countItem: (string) -> number): (number, number)
	local count = objective.Count or 1
	if objective.Kind == "Collect" or objective.Kind == "Deliver" then
		return math.min(count, countItem(objective.Item)), count
	end
	return math.min(count, stored or 0), count
end

function QuestLogic.IsComplete(def, progress: { number }, countItem: (string) -> number): boolean
	for i, objective in ipairs(def.Objectives) do
		local have, need = QuestLogic.ObjectiveProgress(objective, progress[i], countItem)
		if have < need then
			return false
		end
	end
	return true
end

function QuestLogic.Describe(objective, have: number, need: number): string
	local kind = objective.Kind
	local target = objective.Target or objective.Item or ""
	local verbs = {
		Kill = "Defeat",
		Boss = "Defeat boss",
		Collect = "Collect",
		Deliver = "Deliver",
		Explore = "Discover",
		Dungeon = "Clear dungeon",
		Raid = "Clear raid",
		Talk = "Talk to",
	}
	if kind == "Explore" or kind == "Talk" then
		return string.format("%s %s", verbs[kind], target)
	end
	return string.format("%s %s (%d/%d)", verbs[kind] or kind, target, have, need)
end

-- Day / week keys used for daily & weekly resets (UTC).
function QuestLogic.DayKey(unixTime: number): number
	return math.floor(unixTime / 86400)
end

function QuestLogic.WeekKey(unixTime: number): number
	-- Unix epoch was a Thursday; shift so weeks start on Monday.
	return math.floor((unixTime / 86400 + 3) / 7)
end

return QuestLogic
